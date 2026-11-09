; 32-bit x86 (concrete ESP 0x00860000): a sign-flag computation on ESP - 12.
; The comparison is an instruction (icmp constant expressions no longer
; exist in LLVM 19), and the pointer-sized operands are left alone.
; RUN: --passes=RemoveStackPointerCExprs
target datalayout = "e-m:e-p:32:32-f64:32:64-f80:32-n8:16:32-S128"
target triple = "i386-pc-linux-gnu-elf"

@__anvill_sp = external global i8

declare zeroext i1 @__remill_flag_computation_sign(i1 zeroext, ...)

define i1 @slice() {
  %c = icmp slt i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12), 0
  %1 = call zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 zeroext %c, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12))
  %low = trunc i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12) to i8
  %lowi = trunc i8 trunc (i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12) to i8) to i1
  %r = and i1 %1, %lowi
  ret i1 %r
}
