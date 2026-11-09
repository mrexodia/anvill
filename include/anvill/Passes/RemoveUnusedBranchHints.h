#include <anvill/Passes/BranchAnalysis.h>
#include <anvill/Passes/BranchHintPass.h>
#include <anvill/Passes/IntrinsicPass.h>


namespace anvill {

// This pass consumes the analysis from BranchAnalysis and replaces the compare intrinsic
// with an icmp of the form icmp compare compared.0 compared.1 which was proven equivalent to the flag
// computation.

class RemoveUnusedBranchHints
    : public IntrinsicPass<RemoveUnusedBranchHints, llvm::PreservedAnalyses>,
      public llvm::PassInfoMixin<RemoveUnusedBranchHints> {
 public:
  // Maps CallInst to anvill_compare prims to the result
  using Result = llvm::PreservedAnalyses;

  static Result INIT_RES;


  static bool isTargetInstrinsic(const llvm::CallInst *callinsn) {
    if (const auto *callee = callinsn->getCalledFunction()) {
      const auto name = callee->getName();

      // `__remill_compare_exchange_*` are atomic memory operations, not
      // branch hints, even though they share the `__remill_compare` prefix.
      return (name.starts_with(kCompareInstrinsicPrefix) &&
              !name.starts_with(kCompareExchangePrefix)) ||
             name.starts_with(kFlagIntrinsicPrefix);
    }

    return false;
  }


  Result runOnIntrinsic(llvm::CallInst *indirectJump,
                        llvm::FunctionAnalysisManager &am, Result agg);


  static llvm::StringRef name();
};
}  // namespace anvill