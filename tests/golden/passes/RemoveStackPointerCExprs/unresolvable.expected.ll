source_filename = "unresolvable.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i8
@unknown = external global i8

define i64 @f() {
entry:
  %0 = mul i64 ptrtoint (ptr @__anvill_sp to i64), ptrtoint (ptr @unknown to i64)
  br label %next

next:                                             ; preds = %entry
  %v = add i64 %0, 1
  ret i64 %v
}
