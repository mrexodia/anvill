source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_reg_RBP = external local_unnamed_addr global i64
@__anvill_ra = external global i64
@__anvill_pc = external global i64
@__anvill_stack_minus_32 = external local_unnamed_addr global i64
@__anvill_stack_minus_24 = external local_unnamed_addr global i64
@__anvill_stack_minus_16 = external local_unnamed_addr global i64
@__anvill_stack_minus_8 = external local_unnamed_addr global i64
@__anvill_stack_0 = external local_unnamed_addr global i64
@__anvill_stack_plus_8 = external local_unnamed_addr global i64
@__anvill_stack_plus_16 = external local_unnamed_addr global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @g], section "llvm.metadata"

; Function Attrs: noinline
define i32 @f(i32 %0) local_unnamed_addr #0 !pc !0 {
  %locals1 = alloca [4 x i64], align 8, !pc !1
  %2 = getelementptr inbounds i8, ptr %locals1, i64 8, !pc !0
  %3 = getelementptr inbounds i8, ptr %locals1, i64 16, !pc !0
  %4 = getelementptr inbounds i8, ptr %locals1, i64 24, !pc !0
  %5 = getelementptr inbounds i8, ptr %locals1, i64 20, !pc !2
  %parameters2 = alloca [2 x i64], align 8, !pc !3
  %6 = getelementptr inbounds i8, ptr %parameters2, i64 8, !pc !3
  %7 = load i64, ptr @__anvill_stack_minus_32, align 8, !pc !0
  store i64 %7, ptr %locals1, align 8, !pc !0
  %8 = load i64, ptr @__anvill_stack_minus_24, align 8, !pc !0
  store i64 %8, ptr %2, align 8, !pc !0
  %9 = load i64, ptr @__anvill_stack_minus_16, align 8, !pc !0
  store i64 %9, ptr %3, align 8, !pc !0
  %10 = load i64, ptr @__anvill_stack_minus_8, align 8, !pc !0
  store i64 %10, ptr %4, align 8, !pc !0
  %11 = load i64, ptr @__anvill_stack_plus_8, align 8, !pc !0
  store i64 %11, ptr %parameters2, align 8, !pc !0
  %12 = load i64, ptr @__anvill_stack_plus_16, align 8, !pc !0
  store i64 %12, ptr %6, align 8, !pc !0
  %13 = load i64, ptr @__anvill_reg_RBP, align 8, !pc !0
  store i64 %13, ptr %4, align 8, !pc !0
  store i32 %0, ptr %5, align 4, !pc !2
  %14 = sext i32 %0 to i64, !pc !4
  %15 = mul nsw i64 %14, 3, !pc !4
  store i64 4198419, ptr %locals1, align 8, !pc !1
  %16 = trunc i64 %15 to i32, !pc !1
  %17 = call i32 @g(i32 %16) #2, !pc !1
  %18 = load i32, ptr %5, align 4, !pc !5
  %19 = add i32 %18, %17, !pc !5
  ret i32 %19, !pc !5
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
declare dso_local zeroext i8 @__remill_undefined_8() local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) local_unnamed_addr #1

; Function Attrs: noinline
declare !pc !6 i32 @g(i32) #0

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #2 = { nounwind }

!0 = !{i64 4198400}
!1 = !{i64 4198414}
!2 = !{i64 4198408}
!3 = !{i64 4198404}
!4 = !{i64 4198411}
!5 = !{i64 4198419}
!6 = !{i64 4202496}
