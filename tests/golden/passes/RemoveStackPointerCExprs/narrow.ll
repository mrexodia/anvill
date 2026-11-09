; Constant expressions involving the stack pointer (`__anvill_sp`) that are
; narrower than a pointer (e.g. the low bits of RSP used by flag
; computations) are folded using a concrete stack pointer value:
; 0x00007ffc07000000 on 64-bit targets and 0x00860000 on 32-bit targets
; (0xffff7ffc07000000 / 0xff860000 when stack_pointer_is_negative is set).
; Pointer-sized stack pointer expressions are left for
; RecoverBasicStackFrame.
; RUN: --passes=RemoveStackPointerCExprs
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i8

declare i1 @__remill_flag_computation_zero(i1, ...)

define i32 @f(i64 %x) {
  ; Low 32 bits of RSP - 12: folded to 0x06fffff4.
  %low32 = add i32 trunc (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -12) to i32), 1
  ; Low 8 bits of RSP + 3: folded to 3.
  %low8 = zext i8 trunc (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 3) to i8) to i32
  ; Pointer-sized: unchanged.
  %full = add i64 ptrtoint (ptr @__anvill_sp to i64), %x
  %t = trunc i64 %full to i32
  %r0 = add i32 %low32, %low8
  %r = add i32 %r0, %t
  ret i32 %r
}
