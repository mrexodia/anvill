source_filename = "tests/golden/passes/SinkSelectionsIntoBranchTargets/basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @f(i1 %c, i32 %a, i32 %b) {
entry:
  br i1 %c, label %taken, label %not_taken

taken:                                            ; preds = %entry
  %t = add i32 %a, 1
  ret i32 %t

not_taken:                                        ; preds = %entry
  %n = mul i32 %b, 2
  ret i32 %n
}
