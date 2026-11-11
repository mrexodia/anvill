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

#include <algorithm>
#include <optional>
#include <string>

#include "AllocationState.h"
#include "Arch.h"

namespace anvill {
namespace {

// Parameter and return value locations follow the AAPCS64 (the "Procedure
// Call Standard for the Arm 64-bit Architecture"), section 6.8:
//
//  - Integers of at most 64 bits and pointers use the next general purpose
//    register (`W<n>` for values of at most 32 bits, `X<n>` otherwise), from
//    X0-X7. A 128-bit integer uses an even-numbered pair `X<2n>`, `X<2n+1>`.
//  - Floating-point values and short vectors use the next SIMD register from
//    V0-V7, named by size: `H<n>` (16 bits), `S<n>` (32), `D<n>` (64),
//    `Q<n>` (128).
//  - A homogeneous floating-point aggregate (HFA: 1-4 members of the same
//    floating-point type) or homogeneous short-vector aggregate (HVA: 1-4
//    members of the same 64- or 128-bit vector type) uses consecutive SIMD
//    registers, one per member.
//  - Other aggregates of at most 16 bytes use one or two general purpose
//    registers (an even-numbered pair if their alignment is 16); larger
//    aggregates are passed by reference, i.e. as a pointer.
//  - Values that do not fit in the remaining registers go on the stack,
//    in 8-byte aligned slots (16-byte aligned for 16-byte aligned values);
//    once a class of registers is exhausted, it stays exhausted.
//  - Results that would be passed in memory are returned through a buffer
//    whose address the caller passes in X8.
//
// (Previously the generic allocator was used. Its constraint list included
// V0-V7 as *integer* registers, so a ninth integer argument went to `V0`, an
// `i128` argument went to `V0`, an `i128` result was typed as two `i32`s,
// `sret` pointers went to X0 instead of X8, and aggregates larger than the
// available registers were rejected.)

static llvm::Type *IntegerOfBytes(llvm::LLVMContext &context, uint64_t bytes) {
  if (bytes <= 1) {
    return llvm::Type::getInt8Ty(context);
  } else if (bytes <= 2) {
    return llvm::Type::getInt16Ty(context);
  } else if (bytes <= 4) {
    return llvm::Type::getInt32Ty(context);
  } else {
    return llvm::Type::getInt64Ty(context);
  }
}

// Flattens an aggregate into its leaf types.
static void FlattenLeaves(llvm::Type *type,
                          std::vector<llvm::Type *> &leaves) {
  if (auto st = llvm::dyn_cast<llvm::StructType>(type)) {
    for (auto elem : st->elements()) {
      FlattenLeaves(elem, leaves);
    }
  } else if (auto at = llvm::dyn_cast<llvm::ArrayType>(type)) {
    for (auto i = 0u; i < at->getNumElements(); ++i) {
      FlattenLeaves(at->getElementType(), leaves);
    }
  } else {
    leaves.push_back(type);
  }
}

static bool IsSIMDScalar(llvm::Type *type) {
  if (type->isHalfTy() || type->isBFloatTy() || type->isFloatTy() ||
      type->isDoubleTy() || type->isFP128Ty()) {
    return true;
  }
  if (auto vt = llvm::dyn_cast<llvm::FixedVectorType>(type)) {
    const auto bits = vt->getPrimitiveSizeInBits().getFixedValue();
    return bits == 64u || bits == 128u;
  }
  return false;
}

// Returns the member type of a homogeneous floating-point aggregate (HFA) or
// homogeneous short-vector aggregate (HVA: members that are all the same
// 64- or 128-bit vector), and the number of members, or `nullptr` if `type`
// is neither. Both are passed and returned in SIMD registers.
static std::pair<llvm::Type *, unsigned> GetHFA(llvm::Type *type) {
  std::vector<llvm::Type *> leaves;
  FlattenLeaves(type, leaves);
  if (leaves.empty() || leaves.size() > 4u) {
    return {nullptr, 0u};
  }
  const auto member = leaves.front();
  const auto is_short_vector = member->isVectorTy() && IsSIMDScalar(member);
  if (!is_short_vector &&
      (!member->isFloatingPointTy() || member->isX86_FP80Ty())) {
    return {nullptr, 0u};
  }
  for (auto leaf : leaves) {
    if (leaf != leaves.front()) {
      return {nullptr, 0u};
    }
  }
  return {leaves.front(), static_cast<unsigned>(leaves.size())};
}


static std::string SIMDRegisterName(llvm::Type *type, unsigned num) {
  const auto bits = type->getPrimitiveSizeInBits().getFixedValue();
  const char *prefix = bits <= 16 ? "H" : bits <= 32 ? "S" : bits <= 64 ? "D"
                                                                        : "Q";
  return prefix + std::to_string(num);
}

static std::string GPRName(llvm::Type *type, unsigned num) {
  const auto is_small = type->isIntegerTy() && type->getIntegerBitWidth() <= 32;
  return (is_small ? "W" : "X") + std::to_string(num);
}

// Next General-purpose Register Number, Next SIMD and Floating-point Register
// Number (AAPCS64 terminology).
struct AAPCS64State {
  unsigned ngrn{0};
  unsigned nsrn{0};
};

// Tries to assign `type` to registers. Returns `std::nullopt` and updates the
// state as the AAPCS64 requires when `type` must go on the stack.
static std::optional<std::vector<ValueDecl>>
AssignAAPCS64(const remill::Arch *arch, const llvm::DataLayout &dl,
              AAPCS64State &state, llvm::Type *type) {
  auto &context = type->getContext();
  std::vector<ValueDecl> ret;
  auto add = [&](const std::string &name, llvm::Type *ty) {
    auto &decl = ret.emplace_back();
    decl.reg = arch->RegisterByName(name);
    CHECK(decl.reg) << "Missing AArch64 register " << name;
    decl.type = ty;
  };

  if (IsSIMDScalar(type)) {
    if (state.nsrn < 8u) {
      add(SIMDRegisterName(type, state.nsrn++), type);
      return ret;
    }
    return std::nullopt;
  }

  if (type->isStructTy() || type->isArrayTy()) {
    if (auto [member, count] = GetHFA(type); member) {
      if (state.nsrn + count <= 8u) {
        for (auto i = 0u; i < count; ++i) {
          add(SIMDRegisterName(member, state.nsrn++), member);
        }
        return ret;
      }
      state.nsrn = 8u;
      return std::nullopt;
    }
  }

  // General purpose registers: integers, pointers and small aggregates.
  const auto size = dl.getTypeAllocSize(type).getFixedValue();
  if (type->isPointerTy() ||
      (type->isIntegerTy() && type->getIntegerBitWidth() <= 64)) {
    if (state.ngrn < 8u) {
      add(GPRName(type, state.ngrn++), type);
      return ret;
    }
    return std::nullopt;
  }

  if (size > 16u) {
    return std::nullopt;  // Handled by the caller (by reference or memory).
  }

  auto num_regs = static_cast<unsigned>((size + 7u) / 8u);
  if (dl.getABITypeAlign(type).value() == 16u ||
      (type->isIntegerTy() && type->getIntegerBitWidth() > 64)) {
    state.ngrn = (state.ngrn + 1u) & ~1u;
  }
  if (state.ngrn + num_regs > 8u) {
    state.ngrn = 8u;
    return std::nullopt;
  }
  for (auto i = 0u; i < num_regs; ++i) {
    const auto chunk = std::min<uint64_t>(8u, size - i * 8u);
    auto chunk_type = IntegerOfBytes(context, chunk);
    add(GPRName(chunk_type, state.ngrn++), chunk_type);
  }
  return ret;
}

}  // namespace

// This is the only calling convention for 64-bit ARMv8 code.
class AArch64_C : public CallingConvention {
 public:
  explicit AArch64_C(const remill::Arch *arch);
  virtual ~AArch64_C(void) = default;

  llvm::Error AllocateSignature(FunctionDecl &fdecl,
                                llvm::Function &func) override;

 private:
  llvm::Error BindParameters(llvm::Function &function, bool injected_sret,
                             std::vector<ParameterDecl> &param_decls);

  llvm::Error BindReturnValues(llvm::Function &function, bool &injected_sret,
                               std::vector<ValueDecl> &ret_decls);
};

std::unique_ptr<CallingConvention>
CallingConvention::CreateAArch64_C(const remill::Arch *arch) {
  return std::unique_ptr<CallingConvention>(new AArch64_C(arch));
}

AArch64_C::AArch64_C(const remill::Arch *arch)
    : CallingConvention(llvm::CallingConv::C, arch) {}

// Allocates the elements of the function signature of func to memory or
// registers. This includes parameters/arguments, return values, and the return
// stack pointer.
llvm::Error AArch64_C::AllocateSignature(FunctionDecl &fdecl,
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

  fdecl.return_address.reg = arch->RegisterByName("X30");
  fdecl.return_address.type = fdecl.return_address.reg->type;

  return llvm::Error::success();
}

llvm::Error
AArch64_C::BindReturnValues(llvm::Function &function, bool &injected_sret,
                            std::vector<anvill::ValueDecl> &ret_values) {

  llvm::Type *ret_type = function.getReturnType();
  injected_sret = false;

  // If there is an sret parameter then its address is passed in X8 (see
  // BindParameters). The callee is not required to preserve X8, so there is
  // no return value. (Previously X8 was also treated as the return value.)
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

  // Results are returned in the registers in which they would be passed as
  // the first argument; otherwise through a buffer whose address is in X8.
  const auto &dl = function.getParent()->getDataLayout();
  AAPCS64State state;
  if (ret_type->isIntegerTy() && ret_type->getIntegerBitWidth() > 128u) {
    // `_BitInt(N)` for N > 128 is returned in memory.
  } else if (ret_type->isX86_FP80Ty()) {
    return llvm::createStringError(
        std::errc::invalid_argument,
        "Could not allocate unsupported type '%s' to return register in function '%s'",
        remill::LLVMThingToString(ret_type).c_str(),
        function.getName().str().c_str());
  } else if (auto regs = AssignAAPCS64(arch, dl, state, ret_type)) {
    ret_values.insert(ret_values.end(), regs->begin(), regs->end());
    return llvm::Error::success();
  }

  // Indirect result: the caller passes the buffer's address in X8. The
  // callee is not required to preserve X8, so there is no return value.
  injected_sret = true;
  return llvm::Error::success();
}

llvm::Error
AArch64_C::BindParameters(llvm::Function &function, bool injected_sret,
                          std::vector<ParameterDecl> &parameter_declarations) {
  const auto param_names = TryRecoverParamNames(function);
  const llvm::DataLayout &dl = function.getParent()->getDataLayout();
  auto ptr_type = llvm::PointerType::get(function.getContext(), 0);

  AAPCS64State state;
  uint64_t stack_offset = 0;
  const auto sp_reg = arch->RegisterByName("SP");

  // The address of an indirect result is passed in X8, which is not one of
  // the argument registers.
  if (injected_sret) {
    auto &decl = parameter_declarations.emplace_back();
    decl.name = "__struct_ret_ptr";
    decl.type = ptr_type;
    decl.reg = arch->RegisterByName("X8");
  }

  for (auto &argument : function.args()) {
    const auto &param_name = param_names[argument.getArgNo()];
    auto param_type = argument.getType();

    // An explicit `sret` parameter is the indirect result address in X8.
    if (argument.hasStructRetAttr()) {
      auto &decl = parameter_declarations.emplace_back();
      decl.name = param_name;
      decl.type = param_type;
      decl.reg = arch->RegisterByName("X8");
      continue;
    }

    // Aggregates larger than 16 bytes that are not HFAs, and integers wider
    // than 128 bits, are copied by the caller and passed by reference.
    const auto size = dl.getTypeAllocSize(param_type).getFixedValue();
    if (((param_type->isStructTy() || param_type->isArrayTy()) &&
         size > 16u && !GetHFA(param_type).first) ||
        (param_type->isIntegerTy() && param_type->getIntegerBitWidth() > 128)) {
      param_type = ptr_type;
    }

    if (auto regs = AssignAAPCS64(arch, dl, state, param_type)) {
      const auto prev_size = parameter_declarations.size();
      for (const auto &reg : *regs) {
        auto &decl = parameter_declarations.emplace_back();
        decl.reg = reg.reg;
        decl.type = reg.type;
      }
      if (regs->size() == 1u) {
        parameter_declarations[prev_size].name = param_name;
      } else if (!param_name.empty()) {
        for (auto i = 0u; i < regs->size(); ++i) {
          parameter_declarations[prev_size + i].name =
              param_name + std::to_string(i);
        }
      }
      continue;
    }

    // On the stack: 8-byte slots, 16-byte aligned for 16-byte aligned
    // values.
    const auto align =
        std::max<uint64_t>(8u, dl.getABITypeAlign(param_type).value());
    stack_offset = llvm::alignTo(stack_offset, std::min<uint64_t>(align, 16u));

    auto &decl = parameter_declarations.emplace_back();
    decl.name = param_name;
    decl.type = param_type;
    decl.mem_reg = sp_reg;
    decl.mem_offset = static_cast<int64_t>(stack_offset);
    stack_offset += llvm::alignTo(dl.getTypeAllocSize(param_type), 8u);
  }

  return llvm::Error::success();
}

}  // namespace anvill
