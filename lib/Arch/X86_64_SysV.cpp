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

#include "AllocationState.h"
#include "Arch.h"

namespace anvill {
namespace {

static const std::vector<RegisterConstraint> kParamRegConstraints = {
    RegisterConstraint({
        VariantConstraint("DIL", kTypeIntegral, kMaxBit8),
        VariantConstraint("DI", kTypeIntegral, kMaxBit16),
        VariantConstraint("EDI", kTypeIntegral, kMaxBit32),
        VariantConstraint("RDI", kTypeIntegral, kMaxBit64),
    }),
    RegisterConstraint({
        VariantConstraint("SIL", kTypeIntegral, kMaxBit8),
        VariantConstraint("SI", kTypeIntegral, kMaxBit16),
        VariantConstraint("ESI", kTypeIntegral, kMaxBit32),
        VariantConstraint("RSI", kTypeIntegral, kMaxBit64),
    }),
    RegisterConstraint({
        VariantConstraint("DL", kTypeIntegral, kMaxBit8),
        VariantConstraint("DX", kTypeIntegral, kMaxBit16),
        VariantConstraint("EDX", kTypeIntegral, kMaxBit32),
        VariantConstraint("RDX", kTypeIntegral, kMaxBit64),
    }),
    RegisterConstraint({
        VariantConstraint("CL", kTypeIntegral, kMaxBit8),
        VariantConstraint("CX", kTypeIntegral, kMaxBit16),
        VariantConstraint("ECX", kTypeIntegral, kMaxBit32),
        VariantConstraint("RCX", kTypeIntegral, kMaxBit64),
    }),
    RegisterConstraint({
        VariantConstraint("R8B", kTypeIntegral, kMaxBit8),
        VariantConstraint("R8W", kTypeIntegral, kMaxBit16),
        VariantConstraint("R8D", kTypeIntegral, kMaxBit32),
        VariantConstraint("R8", kTypeIntegral, kMaxBit64),
    }),
    RegisterConstraint({
        VariantConstraint("R9B", kTypeIntegral, kMaxBit8),
        VariantConstraint("R9W", kTypeIntegral, kMaxBit16),
        VariantConstraint("R9D", kTypeIntegral, kMaxBit32),
        VariantConstraint("R9", kTypeIntegral, kMaxBit64),
    }),

    RegisterConstraint(
        {VariantConstraint("XMM0", kTypeFloatOrVec, kMaxBit128)}),
    RegisterConstraint(
        {VariantConstraint("XMM1", kTypeFloatOrVec, kMaxBit128)}),
    RegisterConstraint(
        {VariantConstraint("XMM2", kTypeFloatOrVec, kMaxBit128)}),
    RegisterConstraint(
        {VariantConstraint("XMM3", kTypeFloatOrVec, kMaxBit128)}),
    RegisterConstraint(
        {VariantConstraint("XMM4", kTypeFloatOrVec, kMaxBit128)}),
    RegisterConstraint(
        {VariantConstraint("XMM5", kTypeFloatOrVec, kMaxBit128)}),
    RegisterConstraint(
        {VariantConstraint("XMM6", kTypeFloatOrVec, kMaxBit128)}),
    RegisterConstraint(
        {VariantConstraint("XMM7", kTypeFloatOrVec, kMaxBit128)}),
};

static const std::vector<RegisterConstraint> kAVXParamRegConstraints =
    ApplyX86Ext(kParamRegConstraints, remill::kArchAMD64_AVX);

static const std::vector<RegisterConstraint> kAVX512ParamRegConstraints =
    ApplyX86Ext(kParamRegConstraints, remill::kArchAMD64_AVX512);

// This a bit undocumented and warrants and explanation. For x86_64, clang has
// the option to split a created (not passed by reference) struct over the
// following registers: RAX, RDX, RCX, XMM0, XMM1, ST0, ST1. The first 3 are
// used for integer or pointer types and the last 4 are used for floating
// point values. If there is no valid struct split using these registers then
// the compiler will try RVO.
static const std::vector<RegisterConstraint> kReturnRegConstraints = {
    RegisterConstraint({
        VariantConstraint("AL", kTypeIntegral, kMaxBit8),
        VariantConstraint("AX", kTypeIntegral, kMaxBit16),
        VariantConstraint("EAX", kTypeIntegral, kMaxBit32),
        VariantConstraint("RAX", kTypeIntegral, kMaxBit64),
    }),
    RegisterConstraint({
        VariantConstraint("DL", kTypeIntegral, kMaxBit8),
        VariantConstraint("DX", kTypeIntegral, kMaxBit16),
        VariantConstraint("EDX", kTypeIntegral, kMaxBit32),
        VariantConstraint("RDX", kTypeIntegral, kMaxBit64),
    }),
    RegisterConstraint({
        VariantConstraint("CL", kTypeIntegral, kMaxBit8),
        VariantConstraint("CX", kTypeIntegral, kMaxBit16),
        VariantConstraint("ECX", kTypeIntegral, kMaxBit32),
        VariantConstraint("RCX", kTypeIntegral, kMaxBit64),
    }),
    RegisterConstraint({VariantConstraint("XMM0", kTypeVec, kMaxBit128)}),
    RegisterConstraint({VariantConstraint("XMM1", kTypeVec, kMaxBit128)}),

    // Since the FPU registers are 80 bits wide, they are only able to hold
    // 64-bit values.
    RegisterConstraint({VariantConstraint("ST0", kTypeVec, kMaxBit80)}),
    RegisterConstraint({VariantConstraint("ST1", kTypeVec, kMaxBit80)}),
};

static const std::vector<RegisterConstraint> kAVXReturnRegConstraints =
    ApplyX86Ext(kReturnRegConstraints, remill::kArchAMD64_AVX);

static const std::vector<RegisterConstraint> kAVX512ReturnRegConstraints =
    ApplyX86Ext(kReturnRegConstraints, remill::kArchAMD64_AVX512);

// One eightbyte of an aggregate classified according to the System V AMD64
// psABI (section 3.2.3): `sse` is true for class SSE, false for class
// INTEGER. `type` is the type used to transfer the eightbyte.
struct Eightbyte {
  bool sse{false};
  llvm::Type *type{nullptr};
};

// Visits the scalar leaves of `type` with their byte offsets. Returns false
// if a leaf forces the whole value into memory (x87 `long double`, `fp128`,
// vectors other than 8 or 16 bytes, or anything unknown). An 8-byte vector
// (`__m64`) is one SSE eightbyte; a 16-byte vector (`__m128`) is an SSE
// eightbyte followed by an SSEUP one, i.e. a whole XMM register.
static bool
VisitLeaves(const llvm::DataLayout &dl, llvm::Type *type, uint64_t offset,
            std::vector<std::pair<uint64_t, llvm::Type *>> &leaves) {
  if (auto st = llvm::dyn_cast<llvm::StructType>(type)) {
    const auto layout = dl.getStructLayout(st);
    for (auto i = 0u; i < st->getNumElements(); ++i) {
      if (!VisitLeaves(dl, st->getElementType(i),
                       offset + layout->getElementOffset(i), leaves)) {
        return false;
      }
    }
    return true;
  } else if (auto at = llvm::dyn_cast<llvm::ArrayType>(type)) {
    const auto elem_size = dl.getTypeAllocSize(at->getElementType());
    for (auto i = 0u; i < at->getNumElements(); ++i) {
      if (!VisitLeaves(dl, at->getElementType(), offset + i * elem_size,
                       leaves)) {
        return false;
      }
    }
    return true;
  } else if (auto it = llvm::dyn_cast<llvm::IntegerType>(type)) {
    if (it->getBitWidth() <= 64) {
      leaves.emplace_back(offset, type);
      return true;
    }

    // `__int128` is two INTEGER eightbytes.
    if (it->getBitWidth() <= 128) {
      auto i64 = llvm::Type::getInt64Ty(type->getContext());
      leaves.emplace_back(offset, i64);
      leaves.emplace_back(offset + 8, i64);
      return true;
    }
    return false;
  } else if (type->isPointerTy() || type->isHalfTy() || type->isFloatTy() ||
             type->isDoubleTy()) {
    leaves.emplace_back(offset, type);
    return true;
  } else if (auto vt = llvm::dyn_cast<llvm::FixedVectorType>(type)) {
    const auto size = dl.getTypeAllocSize(vt).getFixedValue();
    if (size == 8u || size == 16u) {
      leaves.emplace_back(offset, type);
      return true;
    }
    return false;
  } else {
    return false;
  }
}

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

// Classifies an aggregate (or a 65-128-bit integer) of at most 16 bytes into
// eightbytes. Returns `std::nullopt` when the value is of class MEMORY.
//
//  - An eightbyte is INTEGER if any leaf in it is an integer or pointer, and
//    SSE if all of its leaves are floating-point. Fully padded eightbytes are
//    dropped.
//  - INTEGER eightbytes are transferred as the smallest of i8/i16/i32/i64
//    that covers the bytes used in the eightbyte (`{i32, i32}` is one `i64`).
//  - SSE eightbytes are transferred as `float` (one float at the start),
//    `<2 x float>` (two floats), the vector type (a vector member), or
//    `double` (anything else). A 16-byte vector member covers both
//    eightbytes (SSE and SSEUP), and is transferred whole in one register.
static std::optional<std::vector<Eightbyte>>
ClassifyEightbytes(const llvm::DataLayout &dl, llvm::Type *type) {
  const auto size = dl.getTypeAllocSize(type).getFixedValue();
  if (size > 16) {
    return std::nullopt;
  }

  std::vector<std::pair<uint64_t, llvm::Type *>> leaves;
  if (!VisitLeaves(dl, type, 0, leaves)) {
    return std::nullopt;
  }

  auto &context = type->getContext();
  std::vector<Eightbyte> ret;
  for (uint64_t eb = 0; eb * 8 < size; ++eb) {
    auto has_int = false;
    auto num_leaves = 0u;
    auto num_floats = 0u;
    uint64_t end = 0;
    llvm::Type *first = nullptr;
    for (auto [offset, leaf] : leaves) {
      if (offset < eb * 8 || offset >= (eb + 1) * 8) {
        continue;
      }
      if (!first) {
        first = leaf;
      }
      ++num_leaves;
      num_floats += leaf->isFloatTy() ? 1u : 0u;
      has_int = has_int || leaf->isIntegerTy() || leaf->isPointerTy();
      end = std::max<uint64_t>(
          end, offset - eb * 8 + dl.getTypeStoreSize(leaf).getFixedValue());
    }
    if (!num_leaves) {
      continue;
    }
    auto &out = ret.emplace_back();
    if (has_int) {
      out.sse = false;
      out.type = (num_leaves == 1 && first->isPointerTy())
                     ? first
                     : IntegerOfBytes(context, end);
    } else {
      out.sse = true;
      if (num_leaves == 1 &&
          (first->isFloatTy() || first->isDoubleTy() || first->isVectorTy())) {
        out.type = first;
      } else if (num_leaves == 2 && num_floats == 2) {
        out.type =
            llvm::FixedVectorType::get(llvm::Type::getFloatTy(context), 2);
      } else {
        out.type = llvm::Type::getDoubleTy(context);
      }
    }
  }
  return ret;
}

// Assigns classified eightbytes to the first free registers of `state` that
// accept the eightbyte's class. Either all eightbytes get a register or none
// do (the state is left unchanged); this is the psABI rule that an argument
// which does not fit entirely in registers goes on the stack. At most
// `max_int`/`max_sse` registers of each class are considered, which limits
// return values to RAX, RDX and XMM0, XMM1.
static std::optional<std::vector<ValueDecl>>
AssignEightbytes(AllocationState &state, const std::vector<Eightbyte> &ebs,
                 unsigned max_int, unsigned max_sse) {
  std::vector<ValueDecl> ret;
  auto reserved = state.reserved;
  for (const auto &eb : ebs) {
    const TypeConstraint want = eb.sse ? kTypeFloatOrVec : kTypeIntegral;
    auto seen = 0u;
    auto found = false;
    for (auto i = 0u; i < state.constraints.size(); ++i) {
      const auto &rc = state.constraints[i];
      if (!(rc.variants.front().type_constraint & want) ||
          (rc.variants.front().type_constraint & kTypeIntegral) !=
              (want & kTypeIntegral)) {
        continue;
      }
      if (++seen > (eb.sse ? max_sse : max_int)) {
        break;
      }
      if (reserved[i] || state.fill[i]) {
        continue;
      }
      const uint64_t bits =
          eb.type->isPointerTy()
              ? 64u
              : eb.type->getPrimitiveSizeInBits().getFixedValue();
      const SizeConstraint want_size = bits <= 8    ? kBit8
                                       : bits <= 16 ? kBit16
                                       : bits <= 32 ? kBit32
                                       : bits <= 64 ? kBit64
                                                    : kBit128;
      for (const auto &vc : rc.variants) {
        if (vc.size_constraint & want_size) {
          auto &decl = ret.emplace_back();
          decl.reg = state.arch->RegisterByName(vc.register_name);
          decl.type = eb.type;
          reserved[i] = true;
          found = true;
          break;
        }
      }
      if (found) {
        break;
      }
    }
    if (!found) {
      return std::nullopt;
    }
  }
  state.reserved = std::move(reserved);
  return ret;
}

// Whether `type` is classified eightbyte by eightbyte (aggregates and
// 65-128-bit integers) rather than as a single scalar or vector.
static bool IsClassifiedByEightbytes(llvm::Type *type) {
  if (type->isStructTy() || type->isArrayTy()) {
    return true;
  }
  if (auto it = llvm::dyn_cast<llvm::IntegerType>(type)) {
    return it->getBitWidth() > 64 && it->getBitWidth() <= 128;
  }
  return false;
}

}  // namespace

class X86_64_SysV : public CallingConvention {
 public:
  explicit X86_64_SysV(const remill::Arch *arch);
  virtual ~X86_64_SysV(void) = default;

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
CallingConvention::CreateX86_64_SysV(const remill::Arch *arch) {
  return std::unique_ptr<CallingConvention>(new X86_64_SysV(arch));
}

X86_64_SysV::X86_64_SysV(const remill::Arch *arch)
    : CallingConvention(llvm::CallingConv::X86_64_SysV, arch),
      parameter_register_constraints(SelectX86Constraint(
          arch->arch_name, kParamRegConstraints, kAVXParamRegConstraints,
          kAVX512ParamRegConstraints)),
      return_register_constraints(SelectX86Constraint(
          arch->arch_name, kReturnRegConstraints, kAVXReturnRegConstraints,
          kAVX512ReturnRegConstraints)) {}

// Allocates the elements of the function signature of func to memory or
// registers. This includes parameters/arguments, return values, and the return
// stack pointer.
llvm::Error X86_64_SysV::AllocateSignature(FunctionDecl &fdecl,
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

  // For the X86_64_SysV ABI, it is always:
  //
  // "return_stack_pointer": {
  //     "offset": "8",
  //     "register": "RSP",
  //     "type": "L"
  // }

  fdecl.return_stack_pointer_offset = 8;
  fdecl.return_stack_pointer = arch->RegisterByName("RSP");

  fdecl.return_address.mem_reg = fdecl.return_stack_pointer;
  fdecl.return_address.mem_offset = 0;
  fdecl.return_address.type = fdecl.return_stack_pointer->type;

  return llvm::Error::success();
}

llvm::Error
X86_64_SysV::BindReturnValues(llvm::Function &function, bool &injected_sret,
                              std::vector<anvill::ValueDecl> &ret_values) {

  llvm::Type *ret_type = function.getReturnType();
  injected_sret = false;

  // If there is an sret parameter then it is a special case. For the
  // X86_64_SysV ABI, the sret parameters are guarenteed the be in %rax. In this
  // case, we can assume the actual return value of the function will be the
  // sret struct pointer.
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

    value_declaration.reg = arch->RegisterByName("RAX");
    return llvm::Error::success();
  }

  switch (ret_type->getTypeID()) {
    case llvm::Type::VoidTyID: return llvm::Error::success();

    case llvm::Type::IntegerTyID: {
      const auto *int_ty = llvm::dyn_cast<llvm::IntegerType>(ret_type);
      const auto int64_ty = llvm::Type::getInt64Ty(int_ty->getContext());
      const auto bit_width = int_ty->getBitWidth();

      // Put into RAX.
      if (bit_width <= 64) {
        auto &value_declaration = ret_values.emplace_back();
        value_declaration.reg = arch->RegisterByName("RAX");
        value_declaration.type = ret_type;
        return llvm::Error::success();

      // Split over RDX:RAX
      } else if (bit_width <= 128) {
        auto &v0 = ret_values.emplace_back();
        v0.reg = arch->RegisterByName("RAX");
        v0.type = int64_ty;

        auto &v1 = ret_values.emplace_back();
        v1.reg = arch->RegisterByName("RDX");
        v1.type = int64_ty;

        return llvm::Error::success();

      // Wider integers (e.g. `_BitInt(256)`) are of class MEMORY: they are
      // returned through a hidden pointer, like large aggregates.
      // (Previously 129-192-bit integers were split over RAX:RDX:RCX.)
      } else {
        injected_sret = true;
        auto &value_declaration = ret_values.emplace_back();
        value_declaration.reg = arch->RegisterByName("RAX");
        value_declaration.type =
            llvm::PointerType::get(function.getContext(), 0);
        return llvm::Error::success();
      }
    }

    // Pointers always fit into `RAX`.
    case llvm::Type::PointerTyID: {
      auto &value_declaration = ret_values.emplace_back();
      value_declaration.reg = arch->RegisterByName("RAX");
      value_declaration.type = ret_type;
      return llvm::Error::success();
    }

    // Floats, doubles and `__float128` always go in `xmm0`.
    case llvm::Type::FloatTyID:
    case llvm::Type::DoubleTyID:
    case llvm::Type::FP128TyID: {
      auto &value_declaration = ret_values.emplace_back();
      value_declaration.reg = arch->RegisterByName("XMM0");
      value_declaration.type = ret_type;
      return llvm::Error::success();
    }

#if LLVM_VERSION_MAJOR < 20
    case llvm::Type::X86_MMXTyID: {
      auto &value_declaration = ret_values.emplace_back();
      value_declaration.reg = arch->RegisterByName("MM0");
      value_declaration.type = ret_type;
      return llvm::Error::success();
    }
#endif

    case llvm::Type::X86_FP80TyID: {
      auto &value_declaration = ret_values.emplace_back();
      value_declaration.reg = arch->RegisterByName("ST0");
      value_declaration.type = ret_type;
      return llvm::Error::success();
    }

    // Aggregates are classified eightbyte by eightbyte (psABI 3.2.3):
    // INTEGER eightbytes are returned in RAX then RDX, SSE eightbytes in
    // XMM0 then XMM1. Aggregates larger than 16 bytes, or containing
    // `long double`, are of class MEMORY: the caller passes a hidden pointer
    // to the result in RDI, and the callee returns that pointer in RAX.
    case llvm::Type::ArrayTyID:
    case llvm::Type::StructTyID: {
      const auto &dl = function.getParent()->getDataLayout();

      // An aggregate whose only member is a `long double` is of class
      // X87/X87UP, and is returned in ST0 like a plain `long double`.
      auto inner = ret_type;
      while (inner->isStructTy() || inner->isArrayTy()) {
        if (auto st = llvm::dyn_cast<llvm::StructType>(inner);
            st && st->getNumElements() == 1) {
          inner = st->getElementType(0);
        } else if (auto at = llvm::dyn_cast<llvm::ArrayType>(inner);
                   at && at->getNumElements() == 1) {
          inner = at->getElementType();
        } else {
          break;
        }
      }
      if (inner->isX86_FP80Ty()) {
        auto &value_declaration = ret_values.emplace_back();
        value_declaration.reg = arch->RegisterByName("ST0");
        value_declaration.type = inner;
        return llvm::Error::success();
      }

      AllocationState alloc_ret(return_register_constraints, arch, this);
      if (auto ebs = ClassifyEightbytes(dl, ret_type)) {
        if (auto mapping = AssignEightbytes(alloc_ret, *ebs, 2u, 2u)) {
          ret_values.insert(ret_values.end(), mapping->begin(),
                            mapping->end());
          return llvm::Error::success();
        }
      }
      injected_sret = true;
      auto &value_declaration = ret_values.emplace_back();
      value_declaration.reg = arch->RegisterByName("RAX");
      value_declaration.type = llvm::PointerType::get(function.getContext(), 0);
      return llvm::Error::success();
    }

    // Vectors are allocated by the generic allocator (see the table in
    // AllocationState.cpp for integer vectors), falling back on RVO.
    case llvm::Type::FixedVectorTyID: {
      AllocationState alloc_ret(return_register_constraints, arch, this);
      auto mapping = alloc_ret.TryRegisterAllocate(*ret_type);

      // There is a valid split over registers, so add the mapping
      if (mapping) {
        return alloc_ret.CoalescePacking(mapping.value(), ret_values);

      // Vector splitting didn't work so do RVO.
      } else {
        injected_sret = true;

        auto &value_declaration = ret_values.emplace_back();
        value_declaration.reg = arch->RegisterByName("RAX");
        value_declaration.type = llvm::PointerType::get(function.getContext(), 0);
        return llvm::Error::success();
      }
    }

    default:
      return llvm::createStringError(
          std::errc::invalid_argument,
          "Could not allocate unsupported type '%s' to return register in function '%s'",
          remill::LLVMThingToString(ret_type).c_str(),
          function.getName().str().c_str());
  }
}

// For X86_64_SysV, the general argument passing behavior is, try to pass the
// arguments in registers RDI, RSI, RDX, RCX, R8, R9 from integral types and
// XMM0 - XMM7 for float types. If the argument is a struct but can be
// completely split over the above registers, then greedily split it over the
// registers. Otherwise, the struct is passed entirely on the stack. If we run
// our of registers then pass the rest of the arguments on the stack.
llvm::Error X86_64_SysV::BindParameters(
    llvm::Function &function, bool injected_sret,
    std::vector<ParameterDecl> &parameter_declarations) {

  const auto param_names = TryRecoverParamNames(function);
  const llvm::DataLayout &dl = function.getParent()->getDataLayout();

  // Used to keep track of which registers have been allocated
  AllocationState alloc_param(parameter_register_constraints, arch, this);

  // Stack offset describes the stack position of the first stack argument on
  // entry to the callee. For X86_64_SysV, this is [rsp + 8] since there is the
  // return address at [rsp].
  uint64_t stack_offset = 8;

  // If the return value is of class MEMORY, then the caller passes a hidden
  // pointer to the return value's storage as the first argument, in RDI.
  // (Previously this parameter was placed in RAX and typed as the returned
  // aggregate itself, while RDI was still reserved.)
  if (injected_sret) {
    auto &decl = parameter_declarations.emplace_back();

    decl.name = "__struct_ret_ptr";
    decl.type = llvm::PointerType::get(function.getContext(), 0);
    decl.reg = arch->RegisterByName("RDI");
    alloc_param.reserved[0] = true;
  }

  const auto rsp_reg = arch->RegisterByName("RSP");

  for (auto &argument : function.args()) {
    const auto &param_name = param_names[argument.getArgNo()];
    const auto param_type = argument.getType();

    // Aggregates and 65-128-bit integers are classified eightbyte by
    // eightbyte; they either go entirely in registers or entirely on the
    // stack. Other values use the generic allocator.
    std::optional<std::vector<ValueDecl>> allocation;
    if (IsClassifiedByEightbytes(param_type)) {
      if (auto ebs = ClassifyEightbytes(dl, param_type)) {
        allocation = AssignEightbytes(alloc_param, *ebs, 6u, 8u);
      }
    } else if (!param_type->isX86_FP80Ty()) {

      // x87 `long double` is of class X87, which is passed in memory. `fp128`
      // (`__float128`) is of class SSE+SSEUP and uses an XMM register.
      allocation = alloc_param.TryRegisterAllocate(*param_type);
    }

    // Try to allocate from a register. If a register is not available then
    // allocate from the stack.
    if (allocation) {
      auto prev_size = parameter_declarations.size();

      for (const auto &param_decl : allocation.value()) {
        auto &declaration = parameter_declarations.emplace_back();
        declaration.type = param_decl.type;
        if (param_decl.reg) {
          declaration.reg = param_decl.reg;
        } else {
          declaration.mem_offset = param_decl.mem_offset;
          declaration.mem_reg = param_decl.mem_reg;
        }
      }

      // The parameter fit in one register / stack slot.
      if ((prev_size + 1u) == parameter_declarations.size()) {
        if (!param_name.empty()) {
          parameter_declarations[prev_size].name = param_name;
        }

      // The parameter was spread across multiple registers.
      } else if (!param_name.empty()) {
        for (auto i = 0u; i < (parameter_declarations.size() - prev_size);
             ++i) {
          parameter_declarations[prev_size + i].name =
              param_name + std::to_string(i);
        }
      }

    // Stack arguments occupy a whole number of eightbytes, and arguments
    // whose alignment is 16 (`long double`, `__int128`, 16-byte vectors)
    // start at a 16-byte aligned offset. Since `[RSP]` holds the return
    // address on entry, 16-byte alignment means `stack_offset % 16 == 8`.
    // (Previously each argument used its exact allocation size, so two
    // stack `int`s were at +8 and +12.)
    } else {
      uint64_t align = 8u;
      if (param_type->isX86_FP80Ty() || param_type->isFP128Ty() ||
          (param_type->isIntegerTy() &&
           param_type->getIntegerBitWidth() > 64) ||
          dl.getABITypeAlign(param_type).value() >= 16) {
        align = 16u;
      }
      if (align == 16u && (stack_offset % 16u) != 8u) {
        stack_offset += 8u;
      }

      auto &declaration = parameter_declarations.emplace_back();
      declaration.type = param_type;
      declaration.mem_offset = static_cast<int64_t>(stack_offset);
      declaration.mem_reg = rsp_reg;
      stack_offset +=
          llvm::alignTo(dl.getTypeAllocSize(argument.getType()), 8u);

      if (!param_name.empty()) {
        declaration.name = param_name;
      }
    }
  }

  return llvm::Error::success();
}

}  // namespace anvill
