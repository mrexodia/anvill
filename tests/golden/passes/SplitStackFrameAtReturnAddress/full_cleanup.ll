; The split frames are designed for SROA: after it the local becomes an SSA
; value and the stack argument a part of the symbolic stack word
; @__anvill_stack_plus_8. The return address slot stays in memory here
; because its address escapes through %addr (an integer pointer computation).
; (The previously unaligned frame produced out-of-bounds accesses, which SROA
; turned into `ret i32 undef`.)
; RUN: --passes=RecoverBasicStackFrame,SplitStackFrameAtReturnAddress,sroa<modify-cfg>,instcombine<no-verify-fixpoint> --stack_init=symbolic
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i8
@__anvill_ra = external global i8

; RA at [sp+0], a local at [sp-12], a stack argument at [sp+8].
define i32 @sub_401000__AI_B_0(i32 %x) {
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr inttoptr (i64 ptrtoint (ptr @__anvill_sp to i64) to ptr), !pc !0
  store i32 %x, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -12) to ptr)
  %arg = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 8) to ptr)
  %l = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -12) to ptr)
  %addr = add i64 ptrtoint (ptr @__anvill_sp to i64), -4
  %r = add i32 %l, %arg
  ret i32 %r
}

!0 = !{i64 4198400}
