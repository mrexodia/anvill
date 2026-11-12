/*
 * Copyright (c) 2019-present, Trail of Bits, Inc.
 * All rights reserved.
 *
 * This source code is licensed in accordance with the terms specified in
 * the LICENSE file found in the root directory of this source tree.
 */

#include <anvill/ABI.h>
#include <anvill/Passes/IndirectJumpPass.h>
#include <anvill/Passes/JumpTableAnalysis.h>
#include <anvill/Passes/LowerSwitchIntrinsics.h>
#include <anvill/Transforms.h>
#include <llvm/ADT/SmallSet.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/Analysis/ConstantFolding.h>
#include <llvm/IR/CFG.h>
#include <llvm/IR/DerivedUser.h>
#include <llvm/IR/Dominators.h>
#include <llvm/IR/InstVisitor.h>
#include <llvm/IR/PatternMatch.h>
#include <llvm/Pass.h>
#include <llvm/Transforms/Utils/BasicBlockUtils.h>

#include <iostream>
#include <map>
#include <memory>
#include <numeric>
#include <optional>
#include <unordered_map>
#include <unordered_set>

namespace anvill {

class PcBinding {
 private:
  llvm::DenseMap<llvm::APInt, llvm::BasicBlock *> mapping;

  PcBinding(llvm::DenseMap<llvm::APInt, llvm::BasicBlock *> mapping)
      : mapping(std::move(mapping)) {}


 public:
  std::optional<llvm::BasicBlock *> Lookup(llvm::APInt targetPc) const {
    if (this->mapping.find(targetPc) != this->mapping.end()) {
      return {this->mapping.find(targetPc)->second};
    }

    return std::nullopt;
  }

  static PcBinding Build(const llvm::CallInst *complete_switch,
                         llvm::SwitchInst *follower) {
    assert(complete_switch->arg_size() - 1 == follower->getNumCases());

    llvm::DenseMap<llvm::APInt, llvm::BasicBlock *> mapping;
    for (auto case_handler : follower->cases()) {
      auto pc_arg = complete_switch->getArgOperand(
          case_handler.getCaseValue()->getValue().getLimitedValue() +
          1);  // is the switch has more than 2^64 cases we have bigger problems
      mapping.insert(
          {llvm::cast<llvm::ConstantInt>(pc_arg)->getValue(),
           case_handler
               .getCaseSuccessor()});  //  the argument to a complete switch should always be a constant int
    }


    return PcBinding(std::move(mapping));
  }
};

// Jump tables with more entries than this are not turned into switches.
static constexpr uint64_t kMaxSwitchCases = 4096u;

class SwitchBuilder {
 private:
  llvm::LLVMContext &context;
  const MemoryProvider &mem_prov;
  const llvm::DataLayout &dl;

  std::optional<llvm::APInt> ReadIntFrom(llvm::IntegerType *ty,
                                         llvm::APInt addr) {
    auto uaddr = addr.getLimitedValue();
    std::vector<uint8_t> memory;
    assert(ty->getBitWidth() % 8 == 0);
    auto target_bytes = ty->getBitWidth() / 8;

    for (uint64_t i = 0; i < target_bytes; i++) {
      auto res = this->mem_prov.Query(uaddr + i);
      ByteAvailability avail = std::get<1>(res);
      if (avail != ByteAvailability::kAvailable) {
        return std::nullopt;
      }

      memory.push_back(std::get<0>(res));
    }


    llvm::APInt res(ty->getBitWidth(), 0);

    // Endianess? may have to flip around memory as needed, yeah looks like
    // LoadIntMemory loads at system memory so need to use flip_memory in
    // llvm::endianess
    llvm::LoadIntFromMemory(res, memory.data(), target_bytes);

    if (this->dl.isLittleEndian() == llvm::sys::IsLittleEndianHost) {
      return res;
    } else {
      return res.byteSwap();
    }
  }

 public:
  SwitchBuilder(llvm::LLVMContext &context, const MemoryProvider &memProv,
                const llvm::DataLayout &dl)
      : context(context),
        mem_prov(memProv),
        dl(dl) {}

  // A native switch utilizes llvms switch construct in the intended manner to
  // dispatch control flow on integer values. This pass converts jump table-
  // based compiler implementations of this construct back into simple switch
  // cases over an integer index that directly jumps to known labels.
  std::optional<llvm::SwitchInst *>
  CreateNativeSwitch(const JumpTableResult &jt, const PcBinding &binding,
                     llvm::LLVMContext &context) {
    auto min_index = jt.bounds.lower;
    if (!jt.bounds.lessThanOrEqual(min_index, jt.bounds.upper)) {
      return std::nullopt;
    }

    // Count the cases without overflowing (`upper - lower + 1` wraps to zero
    // for the full range), and refuse unreasonably large tables.
    const auto span = (jt.bounds.upper - min_index).getLimitedValue();
    if (span >= kMaxSwitchCases) {
      return std::nullopt;
    }
    const uint64_t number_of_cases = span + 1u;
    auto interp = jt.interp.getInterp();
    llvm::SwitchInst *new_switch =
        llvm::SwitchInst::Create(jt.indexRel.getIndex(), jt.defaultOut,
                                 static_cast<unsigned>(number_of_cases));
    llvm::APInt curr_ind_value = min_index;
    for (uint64_t i = 0; i < number_of_cases; ++i, curr_ind_value += 1) {
      auto read_address = jt.indexRel.apply(interp, curr_ind_value);
      std::optional<llvm::APInt> jmp_off =
          this->ReadIntFrom(jt.pcRel.getExpectedType(jt.interp), read_address);
      if (!jmp_off.has_value()) {
        delete new_switch;
        return std::nullopt;
      }

      auto new_pc = jt.pcRel.apply(interp, *jmp_off);
      auto out_block = binding.Lookup(new_pc);
      if (!out_block.has_value()) {
        delete new_switch;
        return std::nullopt;
      }


      if (*out_block != jt.defaultOut) {
        llvm::ConstantInt *index_val =
            llvm::ConstantInt::get(this->context, curr_ind_value);
        new_switch->addCase(index_val, *out_block);
      }
    }
    return new_switch;
  }
};


llvm::PreservedAnalyses
LowerSwitchIntrinsics::runOnIndirectJump(llvm::CallInst *targetCall,
                                         llvm::FunctionAnalysisManager &am,
                                         llvm::PreservedAnalyses agg) {

  const auto &jt_analysis =
      am.getResult<JumpTableAnalysis>(*targetCall->getFunction());
  auto jresult = jt_analysis.find(targetCall);


  if (jresult == jt_analysis.end()) {
    return agg;
  }

  llvm::Function &f = *targetCall->getFunction();
  auto dl = f.getParent()->getDataLayout();
  llvm::LLVMContext &context = f.getParent()->getContext();

  SwitchBuilder sbuilder(context, this->memProv, dl);
  auto following_switch = targetCall->getParent()->getTerminator();

  if (auto *follower = llvm::dyn_cast<llvm::SwitchInst>(following_switch)) {
    // Check that the switch uses the complete switch
    if (follower->getCondition() == targetCall) {
      auto binding = PcBinding::Build(targetCall, follower);
      std::optional<llvm::SwitchInst *> new_switch =
          sbuilder.CreateNativeSwitch(jresult->second, binding, context);

      if (new_switch) {
        llvm::BasicBlock *const block = follower->getParent();

        // Count the edges from `block` to each successor before and after
        // the replacement, so that PHI nodes can be updated.
        std::map<llvm::BasicBlock *, int> edge_delta;
        for (auto succ : llvm::successors(follower)) {
          edge_delta[succ] -= 1;
        }
        for (auto succ : llvm::successors(*new_switch)) {
          edge_delta[succ] += 1;
        }

        // The new default destination is the bounds check's failure block,
        // which is a new successor of `block`: give its PHIs the value they
        // receive from the (dominating) bounds-check block.
        const auto &dt = am.getResult<llvm::DominatorTreeAnalysis>(f);
        for (auto [succ, delta] : edge_delta) {
          for (; delta > 0; --delta) {
            for (auto &phi : succ->phis()) {
              // An existing edge from `block` already gives the value.
              llvm::Value *incoming = nullptr;
              if (auto idx = phi.getBasicBlockIndex(block); idx >= 0) {
                incoming = phi.getIncomingValue(static_cast<unsigned>(idx));
              }
              for (auto i = 0u; !incoming && i < phi.getNumIncomingValues();
                   ++i) {
                if (dt.dominates(phi.getIncomingBlock(i), block)) {
                  incoming = phi.getIncomingValue(i);
                  break;
                }
              }
              phi.addIncoming(incoming ? incoming
                                       : llvm::UndefValue::get(phi.getType()),
                              block);
            }
          }
        }

        // Successors that lose edges from `block` must drop those PHI
        // entries (while `block` is still a predecessor).
        for (auto [succ, delta] : edge_delta) {
          for (; delta < 0; ++delta) {
            succ->removePredecessor(block);
          }
        }

        llvm::ReplaceInstWithInst(follower, *new_switch);
        if (targetCall->uses().empty()) {
          targetCall->eraseFromParent();
        }
        agg.intersect(llvm::PreservedAnalyses::none());
        return agg;
      }
    }
  }

  return agg;
}

llvm::StringRef LowerSwitchIntrinsics::name() {
  return "LowerSwitchIntrinsics";
}

llvm::PreservedAnalyses LowerSwitchIntrinsics::BuildInitialResult() {
  return llvm::PreservedAnalyses::all();
}


void AddLowerSwitchIntrinsics(llvm::FunctionPassManager &fpm,
                              const MemoryProvider &memprov) {
  fpm.addPass(LowerSwitchIntrinsics(memprov));
}

}  // namespace anvill
