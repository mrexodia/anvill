source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i64
@__anvill_ra = external global i64
@__anvill_pc = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @table_switch], section "llvm.metadata"

; Function Attrs: noinline
define i32 @table_switch(i32 %0) #0 !pc !0 {
  %2 = call ptr @__remill_write_memory_64(ptr null, i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @__anvill_ra to i64)), !pc !0
  %3 = add i32 %0, -3
  %4 = icmp ult i32 %0, 3, !pc !0
  %5 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_carry(i1 noundef zeroext %4, i32 noundef %0, i32 noundef 3, i32 noundef %3) #4, !pc !0
  %6 = xor i32 %3, %0, !pc !0
  %7 = icmp eq i32 %0, 3, !pc !0
  %8 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %7, i32 noundef %0, i32 noundef 3, i32 noundef %3) #4, !pc !0
  %9 = icmp slt i32 %3, 0, !pc !0
  %10 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %9, i32 noundef %0, i32 noundef 3, i32 noundef %3) #4, !pc !0
  %11 = lshr i32 %0, 31, !pc !0
  %12 = lshr i32 %6, 31, !pc !0
  %13 = add nuw nsw i32 %12, %11, !pc !0
  %14 = icmp eq i32 %13, 2, !pc !0
  %15 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 noundef zeroext %14, i32 noundef %0, i32 noundef 3, i32 noundef %3) #4, !pc !0
  %16 = or i1 %8, %5
  %17 = xor i1 %16, true
  %18 = call zeroext i1 @__remill_compare_ugt(i1 noundef zeroext %17) #5, !pc !1
  br i1 %18, label %19, label %22, !pc !1

19:                                               ; preds = %1
  %20 = call noundef i64 @__remill_read_memory_64(ptr noundef %2, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #4, !pc !2
  %21 = call ptr @__remill_function_return(ptr undef, i64 %20, ptr %2), !pc !2
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

22:                                               ; preds = %1
  %23 = zext i32 %0 to i64, !pc !3
  %24 = shl nuw nsw i64 %23, 2
  %25 = add i64 %24, add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198456), !pc !4
  %26 = call noundef i32 @__remill_read_memory_32(ptr noundef %2, i64 noundef %25) #4, !pc !4
  %27 = sext i32 %26 to i64, !pc !4
  %28 = add i64 %27, add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198456), !pc !5
  %29 = icmp ult i64 %28, %27, !pc !5
  %30 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_carry(i1 noundef zeroext %29, i64 noundef %27, i64 noundef add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198456), i64 noundef %28) #4, !pc !5
  %31 = xor i64 %28, %27, !pc !5
  %32 = icmp eq i64 %28, 0, !pc !5
  %33 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %32, i64 noundef %27, i64 noundef add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198456), i64 noundef %28) #4, !pc !5
  %34 = icmp slt i64 %28, 0, !pc !5
  %35 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %34, i64 noundef %27, i64 noundef add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198456), i64 noundef %28) #4, !pc !5
  %36 = lshr i64 %31, 63, !pc !5
  %37 = xor i64 %28, add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198456), !pc !5
  %38 = lshr i64 %37, 63, !pc !5
  %39 = add nuw nsw i64 %36, %38, !pc !5
  %40 = icmp eq i64 %39, 2, !pc !5
  %41 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 noundef zeroext %40, i64 noundef %27, i64 noundef add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198456), i64 noundef %28) #4, !pc !5
  %42 = call i64 (i64, ...) @__anvill_complete_switch(i64 %28, i64 4198423, i64 4198429, i64 4198435, i64 4198441) #6, !pc !6
  switch i64 %42, label %43 [
    i64 0, label %inst_401017.i
    i64 1, label %inst_40101d.i
    i64 2, label %inst_401023.i
    i64 3, label %inst_401029.i
  ], !pc !6

43:                                               ; preds = %22
  unreachable, !pc !0

inst_401017.i:                                    ; preds = %22
  %44 = call noundef i64 @__remill_read_memory_64(ptr noundef %2, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #4, !pc !7
  %45 = call ptr @__remill_function_return(ptr undef, i64 %44, ptr %2), !pc !7
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

inst_40101d.i:                                    ; preds = %22
  %46 = call noundef i64 @__remill_read_memory_64(ptr noundef %2, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #4, !pc !8
  %47 = call ptr @__remill_function_return(ptr undef, i64 %46, ptr %2), !pc !8
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

inst_401023.i:                                    ; preds = %22
  %48 = call noundef i64 @__remill_read_memory_64(ptr noundef %2, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #4, !pc !9
  %49 = call ptr @__remill_function_return(ptr undef, i64 %48, ptr %2), !pc !9
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

inst_401029.i:                                    ; preds = %22
  %50 = call noundef i64 @__remill_read_memory_64(ptr noundef %2, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #4, !pc !10
  %51 = call ptr @__remill_function_return(ptr undef, i64 %50, ptr %2), !pc !10
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

sub_401000__AII_B_0.lifted.exit:                  ; preds = %inst_401029.i, %inst_401023.i, %inst_40101d.i, %inst_401017.i, %19
  %52 = phi i32 [ -1, %19 ], [ 400, %inst_401029.i ], [ 300, %inst_401023.i ], [ 200, %inst_40101d.i ], [ 100, %inst_401017.i ]
  %53 = phi ptr [ %21, %19 ], [ %51, %inst_401029.i ], [ %49, %inst_401023.i ], [ %47, %inst_40101d.i ], [ %45, %inst_401017.i ], !pc !0
  call void @__anvill_memory_escape(ptr %53)
  ret i32 %52
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

declare dso_local zeroext i1 @__remill_compare_ugt(i1 noundef zeroext) #2

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i64 @__remill_read_memory_64(ptr noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i32 @__remill_read_memory_32(ptr noundef, i64 noundef) #1

; Function Attrs: memory(none)
declare i64 @__anvill_complete_switch(i64, ...) #3

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #2 = { "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #3 = { memory(none) }
attributes #4 = { nobuiltin nounwind "no-builtins" }
attributes #5 = { alwaysinline nobuiltin nounwind "no-builtins" }
attributes #6 = { nounwind }

!0 = !{i64 4198400}
!1 = !{i64 4198403}
!2 = !{i64 4198452}
!3 = !{i64 4198405}
!4 = !{i64 4198414}
!5 = !{i64 4198418}
!6 = !{i64 4198421}
!7 = !{i64 4198428}
!8 = !{i64 4198434}
!9 = !{i64 4198440}
!10 = !{i64 4198446}
