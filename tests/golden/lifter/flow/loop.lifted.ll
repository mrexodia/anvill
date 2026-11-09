source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_reg_RAX = external global i64
@__anvill_sp = external global i64
@__anvill_ra = external global i64
@__anvill_pc = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @sum], section "llvm.metadata"

; Function Attrs: noinline
define i32 @sum(i32 %0) #0 !pc !0 {
  %2 = load i64, ptr @__anvill_reg_RAX, align 8, !pc !0
  %3 = call ptr @__remill_write_memory_64(ptr null, i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @__anvill_ra to i64)), !pc !0
  %4 = trunc i64 %2 to i32
  %5 = trunc i64 %2 to i32, !pc !0
  %6 = xor i32 %4, %5, !pc !0
  %7 = icmp eq i32 %5, %4, !pc !0
  %8 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %7, i32 noundef %5, i32 noundef %4, i32 noundef %6) #2, !pc !0
  %9 = icmp slt i32 %6, 0, !pc !0
  %10 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %9, i32 noundef %5, i32 noundef %4, i32 noundef %6) #2, !pc !0
  %11 = call zeroext i8 @__remill_undefined_8() #3, !pc !0
  br label %inst_401002.i, !pc !0

inst_401002.i:                                    ; preds = %21, %1
  %12 = phi i32 [ %6, %1 ], [ %24, %21 ]
  %13 = phi i32 [ %0, %1 ], [ %38, %21 ]
  %14 = phi i64 [ add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198406), %1 ], [ %23, %21 ]
  %15 = icmp eq i32 %13, 0, !pc !1
  %16 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %15, i32 noundef %13, i32 noundef %13, i32 noundef %13) #2, !pc !1
  %17 = icmp slt i32 %13, 0, !pc !1
  %18 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %17, i32 noundef %13, i32 noundef %13, i32 noundef %13) #2, !pc !1
  %19 = call zeroext i8 @__remill_undefined_8() #3, !pc !1
  %20 = call zeroext i1 @__remill_compare_eq(i1 noundef zeroext %16) #3, !pc !2
  br i1 %20, label %sub_401000__AII_B_0.lifted.exit, label %21, !pc !2

21:                                               ; preds = %inst_401002.i
  %22 = add i64 %14, 6, !pc !2
  %23 = select i1 %20, i64 %22, i64 %14, !pc !2
  %24 = add i32 %13, %12, !pc !3
  %25 = icmp ult i32 %24, %12, !pc !3
  %26 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_carry(i1 noundef zeroext %25, i32 noundef %12, i32 noundef %13, i32 noundef %24) #2, !pc !3
  %27 = xor i32 %24, %12, !pc !3
  %28 = icmp eq i32 %24, 0, !pc !3
  %29 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %28, i32 noundef %12, i32 noundef %13, i32 noundef %24) #2, !pc !3
  %30 = icmp slt i32 %24, 0, !pc !3
  %31 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %30, i32 noundef %12, i32 noundef %13, i32 noundef %24) #2, !pc !3
  %32 = lshr i32 %27, 31, !pc !3
  %33 = xor i32 %24, %13, !pc !3
  %34 = lshr i32 %33, 31, !pc !3
  %35 = add nuw nsw i32 %32, %34, !pc !3
  %36 = icmp eq i32 %35, 2, !pc !3
  %37 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 noundef zeroext %36, i32 noundef %12, i32 noundef %13, i32 noundef %24) #2, !pc !3
  %38 = add i32 %13, -1, !pc !4
  %39 = xor i32 %38, %13, !pc !4
  %40 = icmp eq i32 %38, 0, !pc !4
  %41 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %40, i32 noundef %13, i32 noundef 1, i32 noundef %38) #2, !pc !4
  %42 = icmp slt i32 %38, 0, !pc !4
  %43 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %42, i32 noundef %13, i32 noundef 1, i32 noundef %38) #2, !pc !4
  %44 = lshr i32 %13, 31, !pc !4
  %45 = lshr i32 %39, 31, !pc !4
  %46 = add nuw nsw i32 %45, %44, !pc !4
  %47 = icmp eq i32 %46, 2, !pc !4
  %48 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 noundef zeroext %47, i32 noundef %13, i32 noundef 1, i32 noundef %38) #2, !pc !4
  br label %inst_401002.i, !pc !5

sub_401000__AII_B_0.lifted.exit:                  ; preds = %inst_401002.i
  %49 = call noundef i64 @__remill_read_memory_64(ptr noundef %3, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #2, !pc !6
  %50 = call ptr @__remill_function_return(ptr undef, i64 %49, ptr %3), !pc !6
  call void @__anvill_memory_escape(ptr %50)
  ret i32 %12
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_64(ptr noundef, i64 noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_zero(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_sign(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i8 @__remill_undefined_8() #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_compare_eq(i1 noundef zeroext) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_carry(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_overflow(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i64 @__remill_read_memory_64(ptr noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #2 = { nobuiltin nounwind "no-builtins" }
attributes #3 = { alwaysinline nobuiltin nounwind "no-builtins" }

!0 = !{i64 4198400}
!1 = !{i64 4198402}
!2 = !{i64 4198404}
!3 = !{i64 4198406}
!4 = !{i64 4198408}
!5 = !{i64 4198410}
!6 = !{i64 4198412}
