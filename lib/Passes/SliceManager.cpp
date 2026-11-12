/*
 * Copyright (c) 2019-present, Trail of Bits, Inc.
 * All rights reserved.
 *
 * This source code is licensed in accordance with the terms specified in
 * the LICENSE file found in the root directory of this source tree.
 */

#include <anvill/Passes/SliceManager.h>

#include <llvm/ADT/SmallSet.h>
#include <llvm/IR/GlobalValue.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/Operator.h>
#include <llvm/Transforms/Utils/ValueMapper.h>
#include <remill/BC/Util.h>
#include <exception>
#include <iostream>
#include <anvill/ABI.h>

namespace anvill {

llvm::Function *SliceManager::createFunctionForCurrentID(
    SliceID id, llvm::ArrayRef<llvm::Value *> arguments,
    llvm::Value *returnVal) {
  llvm::SmallVector<llvm::Type *> arg_types;

  std::transform(
      arguments.begin(), arguments.end(), std::back_inserter(arg_types),
      [](llvm::Value *arg) -> llvm::Type * { return arg->getType(); });
  llvm::FunctionType *ty =
      llvm::FunctionType::get(returnVal->getType(), arg_types, false);
  auto f = llvm::Function::Create(
      ty, llvm::GlobalValue::LinkageTypes::ExternalLinkage,
      SliceManager::getFunctionName(id), this->mod.get());
  return f;
}

llvm::SmallVector<llvm::Instruction *>
SliceManager::createMapperFromSlice(llvm::ArrayRef<llvm::Instruction *> slice,
                                    llvm::ValueToValueMapTy &mapper) {
  llvm::SmallVector<llvm::Instruction *> cloned_insns;

  std::for_each(slice.begin(), slice.end(),
                [&mapper, &cloned_insns](llvm::Instruction *insn) {
                  auto cloned = insn->clone();
                  cloned_insns.push_back(cloned);
                  mapper.insert({insn, cloned});
                });

  return cloned_insns;
}

void SliceManager::insertClonedSliceIntoFunction(
    SliceID id, llvm::Function *targetFunc, llvm::Value *newReturn,
    llvm::ArrayRef<llvm::Instruction *> slice) {
  auto bb = llvm::BasicBlock::Create(this->mod.get()->getContext(),
                                     "slicebasicblock." + std::to_string(id.id),
                                     targetFunc);

  std::for_each(slice.begin(), slice.end(), [bb](llvm::Instruction *insn) {
    insn->insertInto(bb, bb->end());
  });


  llvm::ReturnInst::Create(this->mod.get()->getContext(), newReturn,
                           bb);
  return;
}

// Rebuild `constant` such that it can be evaluated by the slice interpreter:
// `ptrtoint` of a global variable is replaced by the address of that global
// (`__anvill_pc` is the image base, i.e. zero; other globals need a known
// entity address). Global variables with an initializer are left alone.
//
// NOTE: Constants are uniqued per LLVMContext, so they must never be mutated
//       in place (e.g. with `replaceAllUsesWith`), as that would also change
//       the function being analyzed. Only the operands of the cloned slice
//       instructions are rewritten.
llvm::Constant *SliceManager::makeInterpretable(
    llvm::Constant *constant,
    llvm::DenseMap<llvm::Constant *, llvm::Constant *> &cache) {
  if (auto it = cache.find(constant); it != cache.end()) {
    return it->second;
  }

  llvm::Constant *result = constant;
  if (auto gv = llvm::dyn_cast<llvm::GlobalVariable>(constant)) {
    if (!gv->hasInitializer()) {
      result = nullptr;
    }

  } else if (auto ptoi = llvm::dyn_cast<llvm::PtrToIntOperator>(constant);
             ptoi && llvm::isa<llvm::GlobalVariable>(
                         ptoi->getPointerOperand()->stripPointerCasts())) {
    auto gv = llvm::cast<llvm::GlobalVariable>(
        ptoi->getPointerOperand()->stripPointerCasts());
    auto int_type = llvm::cast<llvm::IntegerType>(ptoi->getType());
    if (gv->getName() == ::anvill::kSymbolicPCName) {
      result = llvm::ConstantInt::get(int_type, 0);
    } else if (std::optional<uint64_t> addr;
               this->lifter.has_value() &&
               (addr = this->lifter->get().AddressOfEntity(gv))) {
      result = llvm::ConstantInt::get(int_type, *addr);
    } else if (!gv->hasInitializer()) {
      result = nullptr;
    }

  } else if (auto ce = llvm::dyn_cast<llvm::ConstantExpr>(constant)) {
    llvm::SmallVector<llvm::Constant *, 4> new_ops;
    bool changed = false;
    for (auto &op : ce->operands()) {
      auto new_op = makeInterpretable(llvm::cast<llvm::Constant>(op), cache);
      if (!new_op) {
        result = nullptr;
        break;
      }
      changed = changed || new_op != op;
      new_ops.push_back(new_op);
    }
    if (result && changed) {
      result = ce->getWithOperands(new_ops);
    }
  }

  cache.insert({constant, result});
  return result;
}

bool SliceManager::replaceAllGVConstantsWithInterpretableValue(
    llvm::ArrayRef<llvm::Instruction *> insns) {
  llvm::DenseMap<llvm::Constant *, llvm::Constant *> cache;
  for (auto insn : insns) {
    for (auto &op : insn->operands()) {
      if (auto constant = llvm::dyn_cast<llvm::Constant>(op.get())) {
        auto new_constant = makeInterpretable(constant, cache);
        if (!new_constant) {
          return false;
        }
        if (new_constant != constant) {
          op.set(new_constant);
        }
      }
    }
  }
  return true;
}


std::optional<SliceID>
SliceManager::addSlice(llvm::ArrayRef<llvm::Instruction *> slice,
                       llvm::Value *returnValue) {
  auto id = this->next_id++;
  llvm::SmallDenseSet<llvm::Value *> defined_value;
  for (auto insn : slice) {
    defined_value.insert(insn);
  }

  llvm::SmallDenseSet<llvm::Value *> lifted_argument_set;
  for (auto insn : slice) {
    for (const auto &use : insn->operands()) {

      if (defined_value.find(use.get()) == defined_value.end() &&
          !llvm::isa<llvm::Constant>(use.get())) {
        lifted_argument_set.insert(use.get());
      }
    }
  }

  if (defined_value.find(returnValue) == defined_value.end()) {
    lifted_argument_set.insert(returnValue);
  }

  llvm::SmallVector<llvm::Value *> ordered_arguments(
      lifted_argument_set.begin(), lifted_argument_set.end());

  llvm::Function *slice_repr =
      this->createFunctionForCurrentID(id, ordered_arguments, returnValue);
  llvm::ValueToValueMapTy mapper;
  auto cloned = this->createMapperFromSlice(slice, mapper);


  auto i = 0;
  for (auto lifted_arg : ordered_arguments) {
    auto arg = slice_repr->getArg(i);
    mapper.insert({lifted_arg, arg});
    i++;
  }

  std::for_each(cloned.begin(), cloned.end(),
                [&mapper](llvm::Instruction *insn) {
                  llvm::RemapInstruction(insn, mapper);

                });


  auto new_ret = mapper[returnValue];


  this->insertClonedSliceIntoFunction(id, slice_repr, new_ret, cloned);

  if (!this->replaceAllGVConstantsWithInterpretableValue(cloned)) {
    slice_repr->eraseFromParent();
    return std::nullopt;
  }
  
  assert(remill::VerifyModule(this->mod.get()));
  return {id};
}


InterpreterBuilder SliceManager::IntoInterpreterBuilder(SliceManager&& x) {
  return InterpreterBuilder(std::move(x.mod));
}

InterpreterBuilder::Slice InterpreterBuilder::getSlice(SliceID i) const {
  auto repr = this->mod->getFunction(SliceManager::getFunctionName(i));
  return InterpreterBuilder::Slice(repr,i);
}

SliceInterpreter InterpreterBuilder::getInterp() const {
  return SliceInterpreter(*this->mod.get());
}

}  // namespace anvill
