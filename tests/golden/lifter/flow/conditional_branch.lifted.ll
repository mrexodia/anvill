source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i64
@__anvill_ra = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @pick], section "llvm.metadata"

; Function Attrs: noinline
define i32 @pick(i32 %0) #0 !pc !0 {
  %2 = call ptr @__remill_write_memory_64(ptr null, i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @__anvill_ra to i64)), !pc !0
  %3 = icmp eq i32 %0, 0, !pc !0
  %4 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %3, i32 noundef %0, i32 noundef %0, i32 noundef %0) #2, !pc !0
  %5 = icmp slt i32 %0, 0, !pc !0
  %6 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %5, i32 noundef %0, i32 noundef %0, i32 noundef %0) #2, !pc !0
  %7 = call zeroext i8 @__remill_undefined_8() #3, !pc !0
  %8 = call zeroext i1 @__remill_compare_eq(i1 noundef zeroext %4) #3, !pc !1
  br i1 %8, label %9, label %12, !pc !1

9:                                                ; preds = %1
  %10 = call noundef i64 @__remill_read_memory_64(ptr noundef %2, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #2, !pc !2
  %11 = call ptr @__remill_function_return(ptr undef, i64 %10, ptr %2), !pc !2
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

12:                                               ; preds = %1
  %13 = call noundef i64 @__remill_read_memory_64(ptr noundef %2, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #2, !pc !3
  %14 = call ptr @__remill_function_return(ptr undef, i64 %13, ptr %2), !pc !3
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

sub_401000__AII_B_0.lifted.exit:                  ; preds = %12, %9
  %15 = phi i32 [ 20, %9 ], [ 10, %12 ]
  %16 = phi ptr [ %11, %9 ], [ %14, %12 ], !pc !0
  call void @__anvill_memory_escape(ptr %16)
  ret i32 %15
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
!2 = !{i64 4198415}
!3 = !{i64 4198409}
