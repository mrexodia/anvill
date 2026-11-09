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

// NOTE: Register names follow remill's (sleigh-based) SPARC32 register table:
//       O0-O5, SP (%o6), O7, FS0-FS31 (single precision) and FD0-FD30
//       (double precision).
namespace {

static const std::vector<RegisterConstraint> kParamRegConstraints = {
    RegisterConstraint({VariantConstraint("O0", kTypeNumeric, kMaxBit32)}),
    RegisterConstraint({VariantConstraint("O1", kTypeNumeric, kMaxBit32)}),
    RegisterConstraint({VariantConstraint("O2", kTypeNumeric, kMaxBit32)}),
    RegisterConstraint({VariantConstraint("O3", kTypeNumeric, kMaxBit32)}),
    RegisterConstraint({VariantConstraint("O4", kTypeNumeric, kMaxBit32)}),
    RegisterConstraint({VariantConstraint("O5", kTypeNumeric, kMaxBit32)}),
};

static const std::vector<RegisterConstraint> kReturnRegConstraints = {
    RegisterConstraint({VariantConstraint("O0", kTypeIntegral, kMaxBit32)}),
    RegisterConstraint({VariantConstraint("O1", kTypeIntegral, kMaxBit32)}),
    RegisterConstraint({VariantConstraint("O2", kTypeIntegral, kMaxBit32)}),
    RegisterConstraint({VariantConstraint("O3", kTypeIntegral, kMaxBit32)}),
    RegisterConstraint({VariantConstraint("O4", kTypeIntegral, kMaxBit32)}),
    RegisterConstraint({VariantConstraint("O5", kTypeIntegral, kMaxBit32)}),

    RegisterConstraint({VariantConstraint("FS0", kTypeFloat, kMaxBit32)}),
    RegisterConstraint({VariantConstraint("FS1", kTypeFloat, kMaxBit32)}),
    RegisterConstraint({VariantConstraint("FS2", kTypeFloat, kMaxBit32)}),
    RegisterConstraint({VariantConstraint("FS3", kTypeFloat, kMaxBit32)}),

    RegisterConstraint({VariantConstraint("FD0", kTypeFloat, kMaxBit64)}),
    RegisterConstraint({VariantConstraint("FD2", kTypeFloat, kMaxBit64)}),
};

// Used to split things like `i64`s into multiple `i32`s.
static llvm::Type *IntegerTypeSplitter(llvm::Type *type) {
  auto int_ty = llvm::dyn_cast<llvm::IntegerType>(type);
  if (!int_ty) {
    return nullptr;
  }

  auto width = int_ty->getBitWidth();
  if (width <= 32) {
    return nullptr;
  }

  auto num_elements = (width + 31u) / 32u;
  auto i32_ty = llvm::Type::getInt32Ty(type->getContext());
  return llvm::ArrayType::get(i32_ty, num_elements);
}

}  // namespace

// This is the only calling convention for 32-bit SPARC code.
class SPARC32_C : public CallingConvention {
 public:
  explicit SPARC32_C(const remill::Arch *arch);
  virtual ~SPARC32_C(void) = default;

  llvm::Error AllocateSignature(FunctionDecl &fdecl,
                                llvm::Function &func) override;

 private:
  llvm::Error BindParameters(llvm::Function &function, bool injected_sret,
                             std::vector<ParameterDecl> &param_decls);

  llvm::Error BindReturnValues(llvm::Function &function, bool &injected_sret,
                               std::vector<ValueDecl> &ret_decls);

  const std::vector<RegisterConstraint> &parameter_register_constraints;
  const std::vector<RegisterConstraint> &return_register_constraints;
};

std::unique_ptr<CallingConvention>
CallingConvention::CreateSPARC32_C(const remill::Arch *arch) {
  return std::unique_ptr<CallingConvention>(new SPARC32_C(arch));
}

SPARC32_C::SPARC32_C(const remill::Arch *arch)
    : CallingConvention(llvm::CallingConv::C, arch),
      parameter_register_constraints(kParamRegConstraints),
      return_register_constraints(kReturnRegConstraints) {}

// Allocates the elements of the function signature of func to memory or
// registers. This includes parameters/arguments, return values, and the return
// stack pointer.
llvm::Error SPARC32_C::AllocateSignature(FunctionDecl &fdecl,
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

  fdecl.return_address.reg = arch->RegisterByName("O7");
  fdecl.return_address.type = fdecl.return_address.reg->type;

  return llvm::Error::success();
}

llvm::Error
SPARC32_C::BindReturnValues(llvm::Function &function, bool &injected_sret,
                            std::vector<anvill::ValueDecl> &ret_values) {

  llvm::Type *ret_type = function.getReturnType();
  injected_sret = false;

  // If there is an sret parameter then it is a special case
  if (function.hasStructRetAttr()) {
    auto &value_declaration = ret_values.emplace_back();

    value_declaration.type = llvm::PointerType::get(function.getContext(), 0);

    if (!ret_type->isVoidTy()) {
      return llvm::createStringError(
          std::errc::invalid_argument,
          "Function '%s' with sret-attributed parameter has non-void return type '%s'",
          function.getName().str().c_str(),
          remill::LLVMThingToString(ret_type).c_str());
    }

    value_declaration.reg = arch->RegisterByName("O0");
    return llvm::Error::success();
  }

  switch (ret_type->getTypeID()) {
    case llvm::Type::VoidTyID: return llvm::Error::success();

    case llvm::Type::IntegerTyID: {
      const auto *int_ty = llvm::dyn_cast<llvm::IntegerType>(ret_type);
      const auto int32_ty = llvm::Type::getInt32Ty(int_ty->getContext());
      const auto bit_width = int_ty->getBitWidth();

      if (bit_width <= 32) {
        auto &value_declaration = ret_values.emplace_back();
        value_declaration.reg = arch->RegisterByName("O0");
        value_declaration.type = ret_type;
        return llvm::Error::success();

      // Split the integer across `o5:o0`. Experimentally, the largest
      // returnable integer is 192 bits in size, any larger and LLVM crashes.
      } else if (bit_width <= 192) {
        const char *ret_names[] = {"O0", "O1", "O2", "O3", "O4", "O5"};
        for (auto i = 0u; i < 6 && (32 * i) < bit_width; ++i) {
          auto &value_declaration = ret_values.emplace_back();
          value_declaration.reg = arch->RegisterByName(ret_names[i]);
          value_declaration.type = int32_ty;
        }
        return llvm::Error::success();
      } else {
        return llvm::createStringError(
            std::errc::invalid_argument,
            "Could not allocate integral type '%s' to return register(s) in function '%s'",
            remill::LLVMThingToString(ret_type).c_str(),
            function.getName().str().c_str());
      }
    }

    case llvm::Type::PointerTyID: {
      auto &value_declaration = ret_values.emplace_back();
      value_declaration.reg = arch->RegisterByName("O0");
      value_declaration.type = ret_type;
      return llvm::Error::success();
    }

    case llvm::Type::HalfTyID:
    case llvm::Type::FloatTyID: {
      auto &value_declaration = ret_values.emplace_back();
      value_declaration.reg = arch->RegisterByName("FS0");
      value_declaration.type = ret_type;
      return llvm::Error::success();
    }

    case llvm::Type::DoubleTyID: {
      auto &value_declaration = ret_values.emplace_back();
      value_declaration.reg = arch->RegisterByName("FD0");
      value_declaration.type = ret_type;
      return llvm::Error::success();
    }

    // Try to split the composite type over registers, and fall back on RVO
    // if it's not possible.
    // Aggregates (and `long double`, which is `fp128`) are returned in
    // memory: the caller stores the address of the result at [SP + 64] in its
    // frame, and the callee returns that address in O0. (Previously the
    // generic allocator tried to split aggregates over O0-O5/F registers.)
    //
    // NOTE: such callees return to `O7 + 12` rather than `O7 + 8`, skipping
    // an `unimp` instruction that holds the size of the result. That is not
    // modelled.
    case llvm::Type::FP128TyID:
    case llvm::Type::ArrayTyID:
    case llvm::Type::StructTyID: {
      injected_sret = true;
      auto &value_declaration = ret_values.emplace_back();
      value_declaration.reg = arch->RegisterByName("O0");
      value_declaration.type = llvm::PointerType::get(function.getContext(), 0);
      return llvm::Error::success();
    }

    case llvm::Type::FixedVectorTyID: {
      AllocationState alloc_ret(return_register_constraints, arch, this);
      alloc_ret.config.type_splitter = IntegerTypeSplitter;
      auto mapping = alloc_ret.TryRegisterAllocate(*ret_type);
      if (mapping) {
        return alloc_ret.CoalescePacking(mapping.value(), ret_values);
      } else {
        break;
      }
    }

    default: break;
  }

  return llvm::createStringError(
      std::errc::invalid_argument,
      "Could not allocate unsupported type '%s' to return register in function '%s'",
      remill::LLVMThingToString(ret_type).c_str(),
      function.getName().str().c_str());
}

// For X86_64_SysV, the general argument passing behavior is, try to pass the
// arguments in registers RDI, RSI, RDX, RCX, R8, R9 from integral types and
// XMM0 - XMM7 for float types. If the argument is a struct but can be
// completely split over the above registers, then greedily split it over the
// registers. Otherwise, the struct is passed entirely on the stack. If we run
// our of registers then pass the rest of the arguments on the stack.
// Parameters follow the SPARC V8 ABI (System V ABI SPARC Processor
// Supplement, "Function Calling Sequence"): every argument is a sequence of
// 4-byte words, and the words of all arguments are passed in O0-O5, then on
// the stack starting at [SP + 92] (word 6 is at [SP + 92], word 7 at
// [SP + 96], ...). Floating-point arguments use the integer registers too,
// and a `double` or `long long` may be split between O5 and the stack.
// Aggregates and `long double` are passed by reference: the word is a
// pointer to a copy. A single-word value keeps its type; each word of a
// multi-word value is an `i32`.
//
// (Previously the generic allocator was used: `double` arguments went
// straight to the stack because no register accepted 64-bit floats, stack
// offsets used the exact allocation sizes, and aggregate results were
// rejected.)
llvm::Error
SPARC32_C::BindParameters(llvm::Function &function, bool injected_sret,
                          std::vector<ParameterDecl> &parameter_declarations) {
  const auto param_names = TryRecoverParamNames(function);
  const llvm::DataLayout &dl = function.getParent()->getDataLayout();
  const auto sp_reg = arch->RegisterByName("SP");
  const char *const kRegs[] = {"O0", "O1", "O2", "O3", "O4", "O5"};
  auto ptr_type = llvm::PointerType::get(function.getContext(), 0);
  auto i32_type = llvm::Type::getInt32Ty(function.getContext());

  // The address of an aggregate result lives in the caller's frame at
  // [SP + 64]; it is not one of the argument words.
  if (injected_sret) {
    auto &decl = parameter_declarations.emplace_back();
    decl.name = "__struct_ret_ptr";
    decl.type = ptr_type;
    decl.mem_reg = sp_reg;
    decl.mem_offset = 64;
  }

  auto word = 0u;
  for (auto &argument : function.args()) {
    const auto &param_name = param_names[argument.getArgNo()];
    auto param_type = argument.getType();

    if (argument.hasStructRetAttr()) {
      auto &decl = parameter_declarations.emplace_back();
      decl.name = param_name;
      decl.type = param_type;
      decl.mem_reg = sp_reg;
      decl.mem_offset = 64;
      continue;
    }

    if (param_type->isStructTy() || param_type->isArrayTy() ||
        param_type->isFP128Ty()) {
      param_type = ptr_type;
    }

    const auto size = dl.getTypeAllocSize(param_type).getFixedValue();
    const auto num_words = static_cast<unsigned>((size + 3u) / 4u);
    const auto prev_size = parameter_declarations.size();

    // Entirely on the stack: keep the value whole.
    if (word >= 6u) {
      auto &decl = parameter_declarations.emplace_back();
      decl.name = param_name;
      decl.type = param_type;
      decl.mem_reg = sp_reg;
      decl.mem_offset = static_cast<int64_t>(92u + 4u * (word - 6u));
      word += num_words;
      continue;
    }

    for (auto i = 0u; i < num_words; ++i, ++word) {
      auto &decl = parameter_declarations.emplace_back();
      decl.type = num_words == 1u ? param_type : i32_type;
      if (word < 6u) {
        decl.reg = arch->RegisterByName(kRegs[word]);
      } else {
        decl.mem_reg = sp_reg;
        decl.mem_offset = static_cast<int64_t>(92u + 4u * (word - 6u));
      }
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
