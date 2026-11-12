source_filename = "non_compare.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @branch_on_not(i1 %a, i1 %b) {
entry:
  %o = or i1 %a, %b
  br i1 %o, label %no, label %yes

yes:                                              ; preds = %entry
  ret i32 1

no:                                               ; preds = %entry
  ret i32 0
}

define i1 @kept_for_other_user(i1 %a) {
entry:
  %x = xor i1 %a, true
  br i1 %a, label %no, label %yes

yes:                                              ; preds = %entry
  ret i1 %x

no:                                               ; preds = %entry
  ret i1 false
}
