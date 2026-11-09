/*
 * Copyright (c) 2019-present, Trail of Bits, Inc.
 * All rights reserved.
 *
 * This source code is licensed in accordance with the terms specified in
 * the LICENSE file found in the root directory of this source tree.
 */

#include <anvill/Declarations.h>
#include <glog/logging.h>
#include <remill/Arch/Arch.h>
#include <remill/Arch/Name.h>

#include "AllocationState.h"
#include "Arch.h"

namespace anvill {
namespace {

// Parameter and return value locations follow the base (soft-float)
// variant of the AAPCS ("Procedure Call Standard for the Arm Architecture"),
// sections 6.4 and 6.5, as used by `arm-linux-gnueabi`:
//
//  - Arguments are sequences of 4-byte words passed in R0-R3, then on the
//    stack. Floating-point values use the core registers too.
//  - Values with 8-byte alignment (`long long`, `double`, aggregates
//    containing them) start at an even register (R0 or R2) and at an 8-byte
//    aligned stack offset.
//  - An argument that does not fit in the remaining registers is split
//    between the last registers and the stack, as long as nothing has been
//    put on the stack yet; after that, all arguments go on the stack.
//  - A single-word value keeps its type; each word of a multi-word value is
//    an `i32`.
//  - Results of at most 4 bytes are returned in R0; `long long` and
//    `double` in R0:R1. Aggregates larger than 4 bytes (and wider integers)
//    are returned in memory: the caller passes the address in R0, and all
//    other arguments shift by one register.
//
// (Previously the generic allocator was used: `i64` arguments were not
// aligned to even registers, `float`/`double` arguments were put on the
// stack, a `double` result was declared as two `double`s in R0 and R1, and
// a large aggregate result declared its pointer as the R0 return value
// without shifting the arguments.)

// Returns the words of `type` (as an `i32` each), or just `type` if it
// fits in one word.
static std::vector<llvm::Type *> WordsOf(const llvm::DataLayout &dl,
                                         llvm::Type *type) {
  const auto size = dl.getTypeAllocSize(type).getFixedValue();
  if (size <= 4u && !type->isStructTy() && !type->isArrayTy()) {
    return {type};
  }
  auto i32 = llvm::Type::getInt32Ty(type->getContext());
  return std::vector<llvm::Type *>((size + 3u) / 4u, i32);
}

static bool IsDoublewordAligned(const llvm::DataLayout &dl, llvm::Type *type) {
  return dl.getABITypeAlign(type).value() >= 8u;
}

}  // namespace

// This is AAPCS calling convention for armv7 architecture. It does not
// support AAPCS_VFP calling convention
// TODO(akshayk) Support AAPCS_VFP calling convention for VFP and advance
// SIMD support
class AArch32_C : public CallingConvention {
 public:
  explicit AArch32_C(const remill::Arch *arch);
  virtual ~AArch32_C(void) = default;

  llvm::Error AllocateSignature(FunctionDecl &fdecl,
                                llvm::Function &func) override;

 private:
  llvm::Error BindParameters(llvm::Function &function, bool injected_sret,
                             std::vector<ParameterDecl> &param_decls);

  llvm::Error BindReturnValues(llvm::Function &function, bool &injected_sret,
                               std::vector<ValueDecl> &ret_decls);
};

std::unique_ptr<CallingConvention>
CallingConvention::CreateAArch32_C(const remill::Arch *arch) {
  return std::unique_ptr<CallingConvention>(new AArch32_C(arch));
}

AArch32_C::AArch32_C(const remill::Arch *arch)
    : CallingConvention(llvm::CallingConv::C, arch) {}

// Allocates the elements of the function signature of func to memory or
// registers. This includes parameters/arguments, return values, and the return
// stack pointer.
llvm::Error AArch32_C::AllocateSignature(FunctionDecl &fdecl,
                                         llvm::Function &func) {

  // Bind return values first to see if we have injected an sret into the
  // parameter list. Then, bind the parameters. It is important that we bind the
  // return values before the parameters in case we inject an sret.
  bool injected_sret = false;
  auto err = BindReturnValues(func, injected_sret, fdecl.returns);
  if (remill::IsError(err)) {
    return err;
  }

  err = BindParameters(func, injected_sret, fdecl.params);
  if (remill::IsError(err)) {
    return err;
  }

  fdecl.return_stack_pointer_offset = 0;
  fdecl.return_stack_pointer = arch->RegisterByName("SP");

  fdecl.return_address.reg = arch->RegisterByName("LR");
  fdecl.return_address.type = fdecl.return_address.reg->type;

  return llvm::Error::success();
}


llvm::Error
AArch32_C::BindReturnValues(llvm::Function &function, bool &injected_sret,
                            std::vector<anvill::ValueDecl> &ret_values) {

  llvm::Type *ret_type = function.getReturnType();
  injected_sret = false;

  // An explicit `sret` parameter is the first argument (R0). The callee is
  // not required to return the address, so there is no return value.
  if (function.hasStructRetAttr()) {
    if (!ret_type->isVoidTy()) {
      return llvm::createStringError(
          std::errc::invalid_argument,
          "Function '%s' with sret-attributed parameter has non-void return type '%s'",
          function.getName().str().c_str(),
          remill::LLVMThingToString(ret_type).c_str());
    }
    return llvm::Error::success();
  }

  if (ret_type->isVoidTy()) {
    return llvm::Error::success();
  }

  const auto &dl = function.getParent()->getDataLayout();
  const auto size = dl.getTypeAllocSize(ret_type).getFixedValue();
  const auto is_aggregate = ret_type->isStructTy() || ret_type->isArrayTy();

  if (ret_type->isX86_FP80Ty() || ret_type->isFP128Ty()) {
    return llvm::createStringError(
        std::errc::invalid_argument,
        "Could not allocate unsupported type '%s' to return register in function '%s'",
        remill::LLVMThingToString(ret_type).c_str(),
        function.getName().str().c_str());
  }

  // Aggregates of at most 4 bytes are returned in R0, as an integer.
  if (is_aggregate && size <= 4u) {
    auto &decl = ret_values.emplace_back();
    decl.reg = arch->RegisterByName("R0");
    decl.type = llvm::Type::getInt32Ty(function.getContext());
    return llvm::Error::success();
  }

  // Fundamental types of at most 8 bytes (including 64-bit vectors) are
  // returned in R0 or R0:R1.
  if (!is_aggregate && size <= 8u) {
    const char *names[] = {"R0", "R1"};
    auto i = 0u;
    for (auto word : WordsOf(dl, ret_type)) {
      auto &decl = ret_values.emplace_back();
      decl.reg = arch->RegisterByName(names[i++]);
      decl.type = word;
    }
    return llvm::Error::success();
  }

  // Everything else is returned in memory.
  injected_sret = true;
  return llvm::Error::success();
}

llvm::Error
AArch32_C::BindParameters(llvm::Function &function, bool injected_sret,
                          std::vector<ParameterDecl> &parameter_declarations) {

  const auto param_names = TryRecoverParamNames(function);
  const llvm::DataLayout &dl = function.getParent()->getDataLayout();
  const char *const kRegs[] = {"R0", "R1", "R2", "R3"};
  const auto sp_reg = arch->RegisterByName("SP");

  auto ncrn = 0u;          // Next core register number.
  uint64_t nsaa = 0u;      // Next stacked argument address, relative to SP.

  if (injected_sret) {
    auto &decl = parameter_declarations.emplace_back();
    decl.name = "__struct_ret_ptr";
    decl.type = llvm::PointerType::get(function.getContext(), 0);
    decl.reg = arch->RegisterByName(kRegs[ncrn++]);
  }

  for (auto &argument : function.args()) {
    const auto &param_name = param_names[argument.getArgNo()];
    const auto param_type = argument.getType();
    const auto words = WordsOf(dl, param_type);
    const auto dw_aligned = IsDoublewordAligned(dl, param_type);

    if (dw_aligned) {
      ncrn = (ncrn + 1u) & ~1u;
    }

    const auto prev_size = parameter_declarations.size();

    // Entirely in registers, or split between registers and the stack
    // (only while nothing has been put on the stack).
    if (ncrn < 4u && (ncrn + words.size() <= 4u || !nsaa)) {
      for (auto word : words) {
        auto &decl = parameter_declarations.emplace_back();
        decl.type = word;
        if (ncrn < 4u) {
          decl.reg = arch->RegisterByName(kRegs[ncrn++]);
        } else {
          decl.mem_reg = sp_reg;
          decl.mem_offset = static_cast<int64_t>(nsaa);
          nsaa += 4u;
        }
      }

    // Entirely on the stack.
    } else {
      ncrn = 4u;
      if (dw_aligned) {
        nsaa = llvm::alignTo(nsaa, 8u);
      }
      auto &decl = parameter_declarations.emplace_back();
      decl.type = param_type;
      decl.mem_reg = sp_reg;
      decl.mem_offset = static_cast<int64_t>(nsaa);
      nsaa += words.size() * 4u;
    }

    const auto num_parts = parameter_declarations.size() - prev_size;
    if (num_parts == 1u) {
      parameter_declarations[prev_size].name = param_name;
    } else if (!param_name.empty()) {
      for (auto i = 0u; i < num_parts; ++i) {
        parameter_declarations[prev_size + i].name =
            param_name + std::to_string(i);
      }
    }
  }

  return llvm::Error::success();
}

}  // namespace anvill
