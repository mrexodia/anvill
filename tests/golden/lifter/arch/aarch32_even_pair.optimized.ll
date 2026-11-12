source_filename = "lifted_code"
target datalayout = "e-m:e-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64"
target triple = "arm-pc-linux-gnu-elf"

@__anvill_ra = external global i32

; Function Attrs: noinline
define i32 @f(i32 %0, i32 %1, i32 %2) local_unnamed_addr #0 !pc !0 {
  %4 = add i32 %1, %0, !pc !0
  ret i32 %4, !pc !0
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) local_unnamed_addr #1

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }

!0 = !{i32 4198400}
