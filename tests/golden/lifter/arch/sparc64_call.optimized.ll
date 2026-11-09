source_filename = "lifted_code"
target datalayout = "E-m:e-i64:64-n32:64-S128"
target triple = "sparcv9-pc-linux-gnu-elf"

@__anvill_ra = external global i64

; Function Attrs: noinline
define i64 @f(i64 %0) local_unnamed_addr #0 !pc !0 {
sleigh_remill_instruction_function_401000.exit:
  %1 = add i64 %0, 1, !pc !1
  %2 = call i64 @g(i64 %1) #2, !pc !1
  %3 = add i64 %2, %0, !pc !2
  ret i64 %3, !pc !2
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) local_unnamed_addr #1

; Function Attrs: noinline
define i64 @g(i64 %0) local_unnamed_addr #0 !pc !3 {
  %2 = shl i64 %0, 1, !pc !3
  ret i64 %2, !pc !3
}

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nounwind }

!0 = !{i64 4198400}
!1 = !{i64 4198404}
!2 = !{i64 4198412}
!3 = !{i64 4198420}
