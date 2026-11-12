; Stack pointer constant expressions that cannot be folded (they mix the stack
; pointer with an unknown global) are turned into instructions in the entry
; block, so that later passes see the individual operations.
; RUN: --passes=RemoveStackPointerCExprs
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i8
@unknown = external global i8

define i64 @f() {
entry:
  br label %next
next:
  %v = add i64 mul (i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @unknown to i64)), 1
  ret i64 %v
}
