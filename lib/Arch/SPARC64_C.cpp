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
#include <llvm/IR/DerivedTypes.h>
#include <llvm/IR/Module.h>
#include <remill/Arch/Name.h>
#include <remill/BC/Util.h>

#include <algorithm>
#include <string>

#include "Arch.h"

namespace anvill {
namespace {

// Parameter and return value locations follow the SPARC V9 (64-bit) ABI,
// System V ABI SPARC Processor Supplement for V9, "Function Calling
// Sequence", with the register names of remill's Sleigh-based SPARC64
// architecture (`kArchSparc64_SLEIGH`):
//
//  - Arguments occupy 8-byte slots, numbered from 0. Integers, pointers and
//    the words of small aggregates in slots 0-5 are in O0-O5. Wider values
//    (`i128`, `fp128`) take two slots, starting at an even slot.
//  - A `float` in slot k (k < 16) is in FS(2k+1), a `double` in FD(2k), a
//    `long double` (`fp128`) in FQ(2k); their integer register is unused.
//  - Other slots are on the stack, at `[SP + 2047 + 176 + 8 * (k - 6)]`
//    (2047 is the stack bias, 176 the register save area plus the six
//    reserved argument words). A value smaller than 8 bytes is
//    right-justified in its slot (big-endian), e.g. an `int` in slot 6 is at
//    `[SP + 2227]`.
//  - Aggregates of at most 16 bytes are passed as `i64` words in their slots;
//    larger ones are passed by reference.
//  - Results: integers in O0 (`i128`: O0, O1), `float` in FS0, `double` in
//    FD0, `fp128` in FQ0, integer-only aggregates of at most 32 bytes in
//    O0-O3 as `i64` words. Anything else is returned in memory: the caller
//    passes the address as a hidden first argument (O0), and the callee
//    returns it in O0.
//
// Simplifications: floating-point members of small aggregates are treated as
// integer words (the ABI puts them in FP registers), and variadic floating-
// point arguments are not moved to integer registers.
//
// (Previously this used the generic allocator with the register names of
// remill's hand-written SPARC64 architecture (`o0`, `f1`, `d0`, ...), which no
// longer has semantics; floating-point arguments were not slot-based and
// integer results wider than 64 bits were typed `i32`.)

static constexpr uint64_t kStackArgBase = 2047u + 176u;

static bool IsAggregate(llvm::Type *type) {
  return type->isStructTy() || type->isArrayTy();
}

static std::vector<llvm::Type *> WordsOf(const llvm::DataLayout &dl,
                                         llvm::Type *type) {
  const auto size = dl.getTypeAllocSize(type).getFixedValue();
  auto i64 = llvm::Type::getInt64Ty(type->getContext());
  return std::vector<llvm::Type *>(std::max<uint64_t>(1u, (size + 7u) / 8u),
                                   i64);
}

static bool HasFloatingPointLeaf(llvm::Type *type) {
  if (auto st = llvm::dyn_cast<llvm::StructType>(type)) {
    for (auto elem : st->elements()) {
      if (HasFloatingPointLeaf(elem)) {
        return true;
      }
    }
    return false;
  } else if (auto at = llvm::dyn_cast<llvm::ArrayType>(type)) {
    return HasFloatingPointLeaf(at->getElementType());
  } else {
    return type->isFloatingPointTy() || type->isVectorTy();
  }
}

}  // namespace

class SPARC64_C : public CallingConvention {
 public:
  explicit SPARC64_C(const remill::Arch *arch);
  virtual ~SPARC64_C(void) = default;

  llvm::Error AllocateSignature(FunctionDecl &fdecl,
                                llvm::Function &func) override;

 private:
  llvm::Error BindParameters(llvm::Function &function, bool injected_sret,
                             std::vector<ParameterDecl> &param_decls);

  llvm::Error BindReturnValues(llvm::Function &function, bool &injected_sret,
                               std::vector<ValueDecl> &ret_decls);

  const remill::Register *Reg(const std::string &name) const {
    auto reg = arch->RegisterByName(name);
    CHECK(reg) << "Missing SPARC64 register " << name;
    return reg;
  }
};

std::unique_ptr<CallingConvention>
CallingConvention::CreateSPARC64_C(const remill::Arch *arch) {
  return std::unique_ptr<CallingConvention>(new SPARC64_C(arch));
}

SPARC64_C::SPARC64_C(const remill::Arch *arch)
    : CallingConvention(llvm::CallingConv::C, arch) {}

llvm::Error SPARC64_C::AllocateSignature(FunctionDecl &fdecl,
                                         llvm::Function &func) {
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
  fdecl.return_stack_pointer = Reg("SP");

  // The callee returns to `O7 + 8`, skipping the call and its delay slot.
  fdecl.return_address.reg = Reg("O7");
  fdecl.return_address.type = fdecl.return_address.reg->type;

  return llvm::Error::success();
}

llvm::Error
SPARC64_C::BindReturnValues(llvm::Function &function, bool &injected_sret,
                            std::vector<anvill::ValueDecl> &ret_values) {
  llvm::Type *ret_type = function.getReturnType();
  auto &context = function.getContext();
  const auto &dl = function.getParent()->getDataLayout();
  injected_sret = false;

  auto add = [&](const std::string &name, llvm::Type *type) {
    auto &decl = ret_values.emplace_back();
    decl.reg = Reg(name);
    decl.type = type;
  };

  if (function.hasStructRetAttr()) {
    if (!ret_type->isVoidTy()) {
      return llvm::createStringError(
          std::errc::invalid_argument,
          "Function '%s' with sret-attributed parameter has non-void return type '%s'",
          function.getName().str().c_str(),
          remill::LLVMThingToString(ret_type).c_str());
    }
    add("O0", llvm::PointerType::get(context, 0));
    return llvm::Error::success();
  }

  if (ret_type->isVoidTy()) {
    return llvm::Error::success();
  }

  if (ret_type->isPointerTy() ||
      (ret_type->isIntegerTy() && ret_type->getIntegerBitWidth() <= 64)) {
    add("O0", ret_type);
    return llvm::Error::success();
  }

  if (ret_type->isIntegerTy() && ret_type->getIntegerBitWidth() <= 128) {
    add("O0", llvm::Type::getInt64Ty(context));
    add("O1", llvm::Type::getInt64Ty(context));
    return llvm::Error::success();
  }

  if (ret_type->isHalfTy() || ret_type->isFloatTy()) {
    add("FS0", ret_type);
    return llvm::Error::success();
  } else if (ret_type->isDoubleTy()) {
    add("FD0", ret_type);
    return llvm::Error::success();
  } else if (ret_type->isFP128Ty()) {
    add("FQ0", ret_type);
    return llvm::Error::success();
  }

  if (IsAggregate(ret_type) && !HasFloatingPointLeaf(ret_type) &&
      dl.getTypeAllocSize(ret_type).getFixedValue() <= 32u) {
    auto i = 0u;
    for (auto word : WordsOf(dl, ret_type)) {
      add("O" + std::to_string(i++), word);
    }
    return llvm::Error::success();
  }

  if (IsAggregate(ret_type) || ret_type->isIntegerTy()) {
    injected_sret = true;
    add("O0", llvm::PointerType::get(context, 0));
    return llvm::Error::success();
  }

  return llvm::createStringError(
      std::errc::invalid_argument,
      "Could not allocate unsupported type '%s' to return register in function '%s'",
      remill::LLVMThingToString(ret_type).c_str(),
      function.getName().str().c_str());
}

llvm::Error
SPARC64_C::BindParameters(llvm::Function &function, bool injected_sret,
                          std::vector<ParameterDecl> &parameter_declarations) {
  const auto param_names = TryRecoverParamNames(function);
  const llvm::DataLayout &dl = function.getParent()->getDataLayout();
  auto &context = function.getContext();
  auto ptr_type = llvm::PointerType::get(context, 0);
  const auto sp_reg = Reg("SP");

  auto slot = 0u;

  // Location of one 8-byte slot for an integer-class value of `size` bytes.
  auto int_slot = [&](ParameterDecl &decl, unsigned k, uint64_t size) {
    if (k < 6u) {
      decl.reg = Reg("O" + std::to_string(k));
    } else {
      decl.mem_reg = sp_reg;
      decl.mem_offset = static_cast<int64_t>(
          kStackArgBase + 8u * (k - 6u) + (8u - std::min<uint64_t>(size, 8u)));
    }
  };

  if (injected_sret) {
    auto &decl = parameter_declarations.emplace_back();
    decl.name = "__struct_ret_ptr";
    decl.type = ptr_type;
    int_slot(decl, slot++, 8u);
  }

  for (auto &argument : function.args()) {
    const auto &param_name = param_names[argument.getArgNo()];
    auto param_type = argument.getType();
    auto size = dl.getTypeAllocSize(param_type).getFixedValue();

    if (IsAggregate(param_type) && size > 16u) {
      param_type = ptr_type;
      size = 8u;
    }

    const auto prev_size = parameter_declarations.size();

    // Floating-point values use the FP register of their slot.
    if (param_type->isFloatTy() || param_type->isHalfTy() ||
        param_type->isDoubleTy() || param_type->isFP128Ty()) {
      if (param_type->isFP128Ty()) {
        slot = (slot + 1u) & ~1u;
      }
      auto &decl = parameter_declarations.emplace_back();
      decl.name = param_name;
      decl.type = param_type;
      if (slot < 16u) {
        if (param_type->isFP128Ty()) {
          decl.reg = Reg("FQ" + std::to_string(2u * slot));
        } else if (param_type->isDoubleTy()) {
          decl.reg = Reg("FD" + std::to_string(2u * slot));
        } else {
          decl.reg = Reg("FS" + std::to_string(2u * slot + 1u));
        }
      } else {
        decl.mem_reg = sp_reg;
        decl.mem_offset = static_cast<int64_t>(
            kStackArgBase + 8u * (slot - 6u) +
            (size < 8u ? 8u - size : 0u));
      }
      slot += param_type->isFP128Ty() ? 2u : 1u;
      continue;
    }

    // Integers and pointers of at most 64 bits: one slot, keeping the type.
    if (param_type->isPointerTy() ||
        (param_type->isIntegerTy() && param_type->getIntegerBitWidth() <= 64)) {
      auto &decl = parameter_declarations.emplace_back();
      decl.name = param_name;
      decl.type = param_type;
      int_slot(decl, slot++, size);
      continue;
    }

    // Wide integers and small aggregates: `i64` words; 16-byte values start
    // at an even slot.
    if (dl.getABITypeAlign(param_type).value() >= 16u ||
        (param_type->isIntegerTy() && size == 16u)) {
      slot = (slot + 1u) & ~1u;
    }
    for (auto word : WordsOf(dl, param_type)) {
      auto &decl = parameter_declarations.emplace_back();
      decl.type = word;
      int_slot(decl, slot++, 8u);
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
