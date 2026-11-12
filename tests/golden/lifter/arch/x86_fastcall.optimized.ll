source_filename = "lifted_code"
target datalayout = "e-m:e-p:32:32-f64:32:64-f80:32-n8:16:32-S128"
target triple = "i386-pc-linux-gnu-elf"

@__anvill_ra = external global i32
@__anvill_stack_0 = external local_unnamed_addr global i32
@__anvill_stack_plus_4 = external local_unnamed_addr global i32

; Function Attrs: noinline
define x86_fastcallcc i32 @add3(i32 %0, i32 %1, i32 %2) local_unnamed_addr #0 !pc !0 {
  %4 = add i32 %1, %0, !pc !0
  %5 = add i32 %4, %2, !pc !1
  ret i32 %5, !pc !1
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_carry(i1 noundef zeroext, ...) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_zero(i1 noundef zeroext, ...) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_sign(i1 noundef zeroext, ...) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_overflow(i1 noundef zeroext, ...) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) local_unnamed_addr #1

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }

!0 = !{i32 4198400}
!1 = !{i32 4198403}
