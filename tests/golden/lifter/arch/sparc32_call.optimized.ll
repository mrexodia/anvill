source_filename = "lifted_code"
target datalayout = "E-m:e-p:32:32-i64:64-f128:64-n32-S64"
target triple = "sparc-pc-linux-gnu-elf"

@__anvill_ra = external global i32

; Function Attrs: noinline
define i32 @f(i32 %0) local_unnamed_addr #0 !pc !0 {
sleigh_remill_instruction_function_401000.exit:
  %1 = add i32 %0, 1, !pc !1
  %2 = call i32 @g(i32 %1) #2, !pc !1
  %3 = add i32 %2, %0, !pc !2
  ret i32 %3, !pc !2
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) local_unnamed_addr #1

; Function Attrs: noinline
define i32 @g(i32 %0) local_unnamed_addr #0 !pc !3 {
  %2 = shl i32 %0, 1, !pc !3
  ret i32 %2, !pc !3
}

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nounwind }

!0 = !{i32 4198400}
!1 = !{i32 4198404}
!2 = !{i32 4198412}
!3 = !{i32 4198420}
