source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_reg_RBP = external global i64
@__anvill_sp = external global i64
@__anvill_ra = external global i64
@__anvill_pc = external global i64
@llvm.compiler.used = appending global [2 x ptr] [ptr @f, ptr @g], section "llvm.metadata"

; Function Attrs: noinline
define i32 @f(i32 %0) #0 !pc !0 {
  %2 = load i64, ptr @__anvill_reg_RBP, align 8, !pc !0
  %3 = call ptr @__remill_write_memory_64(ptr null, i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @__anvill_ra to i64)), !pc !0
  %4 = call noundef ptr @__remill_write_memory_64(ptr noundef %3, i64 noundef add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 noundef %2) #2, !pc !0
  %5 = icmp ult i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), 16, !pc !1
  %6 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_carry(i1 noundef zeroext %5, i64 noundef add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 noundef 16, i64 noundef sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16)) #2, !pc !1
  %7 = icmp eq i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), 16, !pc !1
  %8 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %7, i64 noundef add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 noundef 16, i64 noundef sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16)) #2, !pc !1
  %9 = icmp slt i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), 0, !pc !1
  %10 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %9, i64 noundef add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 noundef 16, i64 noundef sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16)) #2, !pc !1
  %11 = lshr i64 xor (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), 63, !pc !1
  %12 = lshr i64 xor (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8)), 63, !pc !1
  %13 = add nuw nsw i64 %12, %11, !pc !1
  %14 = icmp eq i64 %13, 2, !pc !1
  %15 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 noundef zeroext %14, i64 noundef add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 noundef 16, i64 noundef sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16)) #2, !pc !1
  %16 = call noundef ptr @__remill_write_memory_32(ptr noundef %4, i64 noundef sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 4), i32 noundef %0) #2, !pc !2
  %17 = sext i32 %0 to i64
  %18 = mul nsw i64 %17, 3, !pc !3
  %19 = add nsw i64 %18, -2147483648, !pc !3
  %20 = icmp ult i64 %19, -4294967296, !pc !3
  %21 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 noundef zeroext %20, i32 noundef %0, i32 noundef 3, i64 noundef %18) #2, !pc !3
  %22 = call zeroext i8 @__remill_undefined_8() #2, !pc !3
  %23 = call zeroext i8 @__remill_undefined_8() #2, !pc !3
  %24 = call zeroext i8 @__remill_undefined_8() #2, !pc !3
  %25 = call zeroext i8 @__remill_undefined_8() #2, !pc !3
  %26 = call noundef ptr @__remill_write_memory_64(ptr noundef %16, i64 noundef add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 -8), i64 noundef add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198419)) #2, !pc !4
  %27 = call i64 @__remill_read_memory_64(ptr %26, i64 add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 -8)), !pc !4
  %28 = trunc i64 %18 to i32
  %29 = call i32 inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4202496) to ptr)(i32 %28) #3, !pc !4
  %30 = call noundef i32 @__remill_read_memory_32(ptr noundef %26, i64 noundef sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 4)) #2, !pc !5
  %31 = add i32 %30, %29, !pc !5
  %32 = icmp ult i32 %31, %29, !pc !5
  %33 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_carry(i1 noundef zeroext %32, i32 noundef %29, i32 noundef %30, i32 noundef %31) #2, !pc !5
  %34 = xor i32 %31, %29, !pc !5
  %35 = icmp eq i32 %31, 0, !pc !5
  %36 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %35, i32 noundef %29, i32 noundef %30, i32 noundef %31) #2, !pc !5
  %37 = icmp slt i32 %31, 0, !pc !5
  %38 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %37, i32 noundef %29, i32 noundef %30, i32 noundef %31) #2, !pc !5
  %39 = lshr i32 %34, 31, !pc !5
  %40 = xor i32 %31, %30, !pc !5
  %41 = lshr i32 %40, 31, !pc !5
  %42 = add nuw nsw i32 %39, %41, !pc !5
  %43 = icmp eq i32 %42, 2, !pc !5
  %44 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 noundef zeroext %43, i32 noundef %29, i32 noundef %30, i32 noundef %31) #2, !pc !5
  %45 = icmp ult i64 add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 16), sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), !pc !6
  %46 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_carry(i1 noundef zeroext %45, i64 noundef sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 noundef 16, i64 noundef add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 16)) #2, !pc !6
  %47 = icmp eq i64 add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 16), 0, !pc !6
  %48 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %47, i64 noundef sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 noundef 16, i64 noundef add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 16)) #2, !pc !6
  %49 = icmp slt i64 add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 16), 0, !pc !6
  %50 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %49, i64 noundef sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 noundef 16, i64 noundef add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 16)) #2, !pc !6
  %51 = lshr i64 xor (i64 add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 16), i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16)), 63, !pc !6
  %52 = lshr i64 xor (i64 add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 16), i64 16), 63, !pc !6
  %53 = add nuw nsw i64 %51, %52, !pc !6
  %54 = icmp eq i64 %53, 2, !pc !6
  %55 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 noundef zeroext %54, i64 noundef sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 noundef 16, i64 noundef add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 16)) #2, !pc !6
  %56 = call noundef i64 @__remill_read_memory_64(ptr noundef %26, i64 noundef add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 16)) #2, !pc !7
  %57 = call noundef i64 @__remill_read_memory_64(ptr noundef %26, i64 noundef add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 24)) #2, !pc !8
  %58 = call ptr @__remill_function_return(ptr undef, i64 %57, ptr %26), !pc !8
  call void @__anvill_memory_escape(ptr %58)
  ret i32 %31
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_64(ptr noundef, i64 noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_carry(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_zero(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_sign(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_overflow(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_32(ptr noundef, i64 noundef, i32 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i8 @__remill_undefined_8() #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i64 @__remill_read_memory_64(ptr noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i32 @__remill_read_memory_32(ptr noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

; Function Attrs: noinline
declare !pc !9 i32 @g(i32) #0

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #2 = { nobuiltin nounwind "no-builtins" }
attributes #3 = { nounwind }

!0 = !{i64 4198400}
!1 = !{i64 4198404}
!2 = !{i64 4198408}
!3 = !{i64 4198411}
!4 = !{i64 4198414}
!5 = !{i64 4198419}
!6 = !{i64 4198422}
!7 = !{i64 4198426}
!8 = !{i64 4198427}
!9 = !{i64 4202496}
