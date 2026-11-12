source_filename = "basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare i32 @fpclassify(double)

declare i32 @__fpclassifyd(double)

declare i32 @__fpclassifyf(float)

declare i32 @__fpclassifyld(x86_fp80)

declare i32 @other(double)

define i32 @f(double %d, float %s, x86_fp80 %l) {
  %kept_other = call i32 @other(double %d)
  %used = call i32 @__fpclassifyd(double %d)
  ret i32 %used
}
