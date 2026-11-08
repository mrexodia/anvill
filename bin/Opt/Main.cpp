/*
 * Copyright (c) 2019-present, Trail of Bits, Inc.
 * All rights reserved.
 *
 * This source code is licensed in accordance with the terms specified in
 * the LICENSE file found in the root directory of this source tree.
 */

// anvill-opt: run individual anvill passes (and LLVM passes) on an LLVM IR
// file, like LLVM's `opt`. This is used by the golden tests in `tests/golden`
// to document the exact behavior of every pass.
//
// Conventions understood by this tool (all optional, written into the input
// `.ll` file so that every test case is self-contained):
//
//  * Entities: a global value named `sub_<hex>...`, `var_<hex>...` or
//    `data_<hex>...` is treated as the lifted entity at address `<hex>` by the
//    cross-reference resolver used by passes that need one.
//
//  * Memory: the named metadata `!anvill.memory` lists memory ranges for the
//    memory provider, e.g.
//
//        !anvill.memory = !{!0}
//        !0 = !{i64 4096, !"00112233", !"rx"}
//
//    where the second operand is the hex-encoded bytes and the third operand
//    is the permission (`r`, `rw`, `rx` or `rwx`).

#include <anvill/CrossReferenceResolver.h>
#include <anvill/Lifters.h>
#include <anvill/Passes/BranchAnalysis.h>
#include <anvill/Passes/CodeQualityStatCollector.h>
#include <anvill/Passes/JumpTableAnalysis.h>
#include <anvill/Providers.h>
#include <anvill/Specification.h>
#include <anvill/Transforms.h>
#include <anvill/Type.h>
#include <gflags/gflags.h>
#include <glog/logging.h>
#include <llvm/ADT/StringExtras.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Metadata.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/PassManager.h>
#include <llvm/IR/Verifier.h>
#include <llvm/IRReader/IRReader.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Support/SourceMgr.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/TargetParser/Triple.h>
#include <remill/Arch/Arch.h>
#include <remill/Arch/Name.h>
#include <remill/OS/OS.h>

#include <map>
#include <memory>
#include <optional>
#include <sstream>
#include <string>
#include <vector>

DEFINE_string(passes, "",
              "Comma-separated list of passes. Anvill passes are named after "
              "their class (e.g. RecoverBasicStackFrame); anything else is "
              "parsed as an LLVM function pass pipeline element (e.g. "
              "instcombine, sroa<modify-cfg>).");
DEFINE_string(function, "",
              "Only run on the function with this name (default: all "
              "functions with a body).");
DEFINE_string(o, "-", "Output file for the transformed IR.");
DEFINE_string(arch, "",
              "Remill architecture name (default: derived from the triple).");
DEFINE_string(os, "", "Remill OS name (default: derived from the triple).");
DEFINE_string(pc_metadata, "pc", "Name of the PC metadata kind.");
DEFINE_string(stack_init, "symbolic",
              "Stack frame initialization: none, zeroes, undef, symbolic.");
DEFINE_uint64(stack_lower_padding, 0, "Stack frame lower padding.");
DEFINE_uint64(stack_higher_padding, 0, "Stack frame higher padding.");
DEFINE_uint64(stack_max_size, 8192, "Maximum stack frame size.");
DEFINE_uint32(stack_word_size, 0, "Stack frame word size (0 = pointer size).");
DEFINE_string(stack_offset_metadata, "stack_offset",
              "Name of the stack offset metadata kind (empty to disable).");
DEFINE_bool(stack_grows_up, false, "Stack grows towards higher addresses.");
DEFINE_bool(verify, true, "Verify the module after running the passes.");

namespace {

// Parse the address out of `sub_<hex>`, `var_<hex>` or `data_<hex>`.
static std::optional<uint64_t> AddressFromName(llvm::StringRef name) {
  for (llvm::StringRef prefix : {"sub_", "var_", "data_"}) {
    if (!name.consume_front(prefix)) {
      continue;
    }
    auto hex = name.take_while([](char c) { return llvm::isHexDigit(c); });
    uint64_t addr = 0;
    if (hex.empty() || hex.getAsInteger(16, addr)) {
      return std::nullopt;
    }
    return addr;
  }
  return std::nullopt;
}

// Resolves entities by the naming convention described at the top of the file.
class NamedEntityResolver final : public anvill::CrossReferenceResolver {
 public:
  explicit NamedEntityResolver(llvm::Module &module_) : module(module_) {}

  std::optional<uint64_t> AddressOfEntity(llvm::Constant *ent) const override {
    if (auto gv = llvm::dyn_cast<llvm::GlobalValue>(
            ent->stripPointerCastsAndAliases())) {
      return AddressFromName(gv->getName());
    }
    return std::nullopt;
  }

  llvm::Constant *EntityAtAddress(uint64_t addr, llvm::Type *,
                                  unsigned) const override {
    for (auto &func : module) {
      if (AddressFromName(func.getName()) == addr) {
        return &func;
      }
    }
    for (auto &var : module.globals()) {
      if (AddressFromName(var.getName()) == addr) {
        return &var;
      }
    }
    for (auto &alias : module.aliases()) {
      if (AddressFromName(alias.getName()) == addr) {
        return &alias;
      }
    }
    return nullptr;
  }

 private:
  llvm::Module &module;
};

// Memory provider backed by the `!anvill.memory` named metadata.
class MetadataMemoryProvider final : public anvill::MemoryProvider {
 public:
  explicit MetadataMemoryProvider(llvm::Module &module) {
    auto md = module.getNamedMetadata("anvill.memory");
    if (!md) {
      return;
    }
    for (auto node : md->operands()) {
      CHECK_GE(node->getNumOperands(), 2u);
      auto addr = llvm::mdconst::extract<llvm::ConstantInt>(node->getOperand(0))
                      ->getZExtValue();
      auto bytes = llvm::cast<llvm::MDString>(node->getOperand(1))->getString();
      auto perm = anvill::BytePermission::kReadable;
      if (node->getNumOperands() > 2) {
        auto p = llvm::cast<llvm::MDString>(node->getOperand(2))->getString();
        if (p == "rw") {
          perm = anvill::BytePermission::kReadableWritable;
        } else if (p == "rx") {
          perm = anvill::BytePermission::kReadableExecutable;
        } else if (p == "rwx") {
          perm = anvill::BytePermission::kReadableWritableExecutable;
        }
      }
      CHECK_EQ(bytes.size() % 2, 0u);
      for (size_t i = 0; i < bytes.size(); i += 2) {
        unsigned byte = 0;
        CHECK(!bytes.substr(i, 2).getAsInteger(16, byte));
        memory[addr + i / 2] = {static_cast<uint8_t>(byte), perm};
      }
    }
  }

  std::tuple<uint8_t, anvill::ByteAvailability, anvill::BytePermission>
  Query(uint64_t address) const override {
    auto it = memory.find(address);
    if (it == memory.end()) {
      return {0, anvill::ByteAvailability::kUnavailable,
              anvill::BytePermission::kUnknown};
    }
    return {it->second.first, anvill::ByteAvailability::kAvailable,
            it->second.second};
  }

 private:
  std::map<uint64_t, std::pair<uint8_t, anvill::BytePermission>> memory;
};

static anvill::StackFrameStructureInitializationProcedure
StackInitFromFlag(void) {
  using P = anvill::StackFrameStructureInitializationProcedure;
  if (FLAGS_stack_init == "none") {
    return P::kNone;
  } else if (FLAGS_stack_init == "zeroes") {
    return P::kZeroes;
  } else if (FLAGS_stack_init == "undef") {
    return P::kUndef;
  } else if (FLAGS_stack_init == "symbolic") {
    return P::kSymbolic;
  }
  LOG(FATAL) << "Unknown --stack_init value: " << FLAGS_stack_init;
  return P::kSymbolic;
}

}  // namespace

int main(int argc, char *argv[]) {
  google::SetUsageMessage("anvill-opt [options] input.ll");
  google::ParseCommandLineFlags(&argc, &argv, true);
  google::InitGoogleLogging(argv[0]);
  FLAGS_logtostderr = true;

  if (argc != 2) {
    std::cerr << "Usage: anvill-opt --passes=... [options] input.ll\n";
    return EXIT_FAILURE;
  }

  llvm::LLVMContext context;
  llvm::SMDiagnostic diag;
  auto module = llvm::parseIRFile(argv[1], diag, context);
  if (!module) {
    diag.print(argv[0], llvm::errs());
    return EXIT_FAILURE;
  }

  // Work out the architecture from the flags or the module's triple.
  llvm::Triple triple(module->getTargetTriple());
  auto arch_name = FLAGS_arch.empty() ? remill::GetArchName(triple)
                                      : remill::GetArchName(FLAGS_arch);
  auto os_name = FLAGS_os.empty() ? remill::GetOSName(triple)
                                  : remill::GetOSName(FLAGS_os);
  if (os_name == remill::kOSInvalid) {
    os_name = remill::kOSLinux;
  }
  auto arch = remill::Arch::Build(&context, os_name, arch_name);
  if (!arch) {
    std::cerr << "Unable to build a remill architecture for triple '"
              << module->getTargetTriple() << "'; pass --arch/--os\n";
    return EXIT_FAILURE;
  }

  // Preserve the input's data layout and triple: the entity lifter prepares
  // the module for the architecture, which may override them.
  const auto data_layout = module->getDataLayoutStr();
  const auto target_triple = module->getTargetTriple();

  anvill::TypeDictionary type_dictionary(context);
  anvill::NullTypeProvider type_provider(type_dictionary);
  anvill::NullControlFlowProvider control_flow_provider;
  MetadataMemoryProvider memory_provider(*module);
  anvill::LifterOptions options(arch.get(), *module, type_provider,
                                control_flow_provider, memory_provider);
  options.pc_metadata_name =
      FLAGS_pc_metadata.empty() ? nullptr : FLAGS_pc_metadata.c_str();

  auto &sfo = options.stack_frame_recovery_options;
  sfo.stack_frame_struct_init_procedure = StackInitFromFlag();
  sfo.stack_frame_lower_padding = FLAGS_stack_lower_padding;
  sfo.stack_frame_higher_padding = FLAGS_stack_higher_padding;
  sfo.max_stack_frame_size = FLAGS_stack_max_size;
  sfo.stack_frame_word_size = FLAGS_stack_word_size;
  sfo.stack_offset_metadata_name = FLAGS_stack_offset_metadata.empty()
                                       ? nullptr
                                       : FLAGS_stack_offset_metadata.c_str();
  sfo.stack_grows_down = !FLAGS_stack_grows_up;

  anvill::EntityLifter lifter(options);
  module->setDataLayout(data_layout);
  module->setTargetTriple(target_triple);

  NamedEntityResolver resolver(*module);
  std::optional<unsigned> pc_metadata_id;
  if (options.pc_metadata_name) {
    pc_metadata_id = context.getMDKindID(options.pc_metadata_name);
  }

  llvm::PassBuilder pb;
  llvm::LoopAnalysisManager lam;
  llvm::FunctionAnalysisManager fam;
  llvm::CGSCCAnalysisManager cam;
  llvm::ModuleAnalysisManager mam;
  pb.registerModuleAnalyses(mam);
  pb.registerCGSCCAnalyses(cam);
  pb.registerFunctionAnalyses(fam);
  pb.registerLoopAnalyses(lam);
  fam.registerPass([&] { return anvill::BranchAnalysis(); });
  fam.registerPass([&] { return anvill::JumpTableAnalysis(lifter); });
  pb.crossRegisterProxies(lam, fam, cam, mam);

  llvm::FunctionPassManager fpm;
  std::stringstream ss(FLAGS_passes);
  for (std::string name; std::getline(ss, name, ',');) {
    if (name.empty()) {
      continue;
    } else if (name == "SinkSelectionsIntoBranchTargets") {
      anvill::AddSinkSelectionsIntoBranchTargets(fpm);
    } else if (name == "RemoveUnusedFPClassificationCalls") {
      anvill::AddRemoveUnusedFPClassificationCalls(fpm);
    } else if (name == "RemoveDelaySlotIntrinsics") {
      anvill::AddRemoveDelaySlotIntrinsics(fpm);
    } else if (name == "RemoveErrorIntrinsics") {
      anvill::AddRemoveErrorIntrinsics(fpm);
    } else if (name == "LowerRemillMemoryAccessIntrinsics") {
      anvill::AddLowerRemillMemoryAccessIntrinsics(fpm);
    } else if (name == "RemoveCompilerBarriers") {
      anvill::AddRemoveCompilerBarriers(fpm);
    } else if (name == "LowerTypeHintIntrinsics") {
      anvill::AddLowerTypeHintIntrinsics(fpm);
    } else if (name == "HoistUsersOfSelectsAndPhis") {
      anvill::AddHoistUsersOfSelectsAndPhis(fpm);
    } else if (name == "ConvertMasksToCasts") {
      anvill::AddConvertMasksToCasts(fpm);
    } else if (name == "RemoveTrivialPhisAndSelects") {
      anvill::AddRemoveTrivialPhisAndSelects(fpm);
    } else if (name == "RemoveStackPointerCExprs") {
      anvill::AddRemoveStackPointerCExprs(fpm, sfo);
    } else if (name == "RecoverBasicStackFrame") {
      anvill::AddRecoverBasicStackFrame(fpm, sfo);
    } else if (name == "SplitStackFrameAtReturnAddress") {
      anvill::AddSplitStackFrameAtReturnAddress(fpm, sfo);
    } else if (name == "CombineAdjacentShifts") {
      anvill::AddCombineAdjacentShifts(fpm);
    } else if (name == "ConvertAddressesToEntityUses") {
      anvill::AddConvertAddressesToEntityUses(fpm, resolver, pc_metadata_id);
    } else if (name == "BranchRecovery") {
      anvill::AddBranchRecovery(fpm);
    } else if (name == "LowerSwitchIntrinsics") {
      anvill::AddLowerSwitchIntrinsics(fpm, memory_provider);
    } else if (name == "TransformRemillJumpIntrinsics") {
      anvill::AddTransformRemillJumpIntrinsics(fpm, resolver);
    } else if (name == "RemoveRemillFunctionReturns") {
      anvill::AddRemoveRemillFunctionReturns(fpm, resolver);
    } else if (name == "ConvertSymbolicReturnAddressToConcreteReturnAddress") {
      anvill::AddConvertSymbolicReturnAddressToConcreteReturnAddress(fpm);
    } else if (name == "LowerRemillUndefinedIntrinsics") {
      anvill::AddLowerRemillUndefinedIntrinsics(fpm);
    } else if (name == "RemoveUnusedBranchHints") {
      anvill::AddRemoveFailedBranchHints(fpm);
    } else if (name == "SpreadPCMetadata") {
      anvill::AddSpreadPCMetadata(fpm, options);
    } else if (name == "CodeQualityStatCollector") {
      fpm.addPass(anvill::CodeQualityStatCollector());
    } else if (name == "ConvertXorsToCmps") {
      anvill::AddConvertXorsToCmps(fpm);
    } else if (auto err = pb.parsePassPipeline(fpm, name)) {
      std::cerr << "Unknown pass '" << name
                << "': " << llvm::toString(std::move(err)) << "\n";
      return EXIT_FAILURE;
    }
  }

  for (auto &func : *module) {
    if (func.isDeclaration()) {
      continue;
    }
    if (!FLAGS_function.empty() && func.getName() != FLAGS_function) {
      continue;
    }
    fpm.run(func, fam);
  }

  int ret = EXIT_SUCCESS;
  if (FLAGS_verify && llvm::verifyModule(*module, &llvm::errs())) {
    std::cerr << "Module verification failed\n";
    ret = EXIT_FAILURE;
  }

  std::error_code ec;
  llvm::raw_fd_ostream os(FLAGS_o, ec);
  if (ec) {
    std::cerr << "Unable to open " << FLAGS_o << ": " << ec.message() << "\n";
    return EXIT_FAILURE;
  }
  module->print(os, nullptr);

  fam.clear();
  mam.clear();
  cam.clear();
  lam.clear();
  return ret;
}
