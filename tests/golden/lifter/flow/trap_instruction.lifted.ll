source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_reg_RAX = external global i64
@__anvill_sp = external global i64
@__anvill_ra = external global i64
@__anvill_pc = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @checked], section "llvm.metadata"

; Function Attrs: noinline
define i32 @checked(i32 %0) #0 !pc !0 {
  %2 = load i64, ptr @__anvill_reg_RAX, align 8, !pc !0
  %3 = call ptr @__remill_write_memory_64(ptr null, i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @__anvill_ra to i64)), !pc !0
  %4 = icmp eq i32 %0, 0, !pc !0
  %5 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %4, i32 noundef %0, i32 noundef %0, i32 noundef %0) #2, !pc !0
  %6 = icmp slt i32 %0, 0, !pc !0
  %7 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %6, i32 noundef %0, i32 noundef %0, i32 noundef %0) #2, !pc !0
  %8 = call zeroext i8 @__remill_undefined_8() #3, !pc !0
  %9 = xor i1 %5, true
  %10 = call zeroext i1 @__remill_compare_neq(i1 noundef zeroext %9) #3, !pc !1
  br i1 %10, label %11, label %14, !pc !1

11:                                               ; preds = %1
  %12 = call noundef i64 @__remill_read_memory_64(ptr noundef %3, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #2, !pc !2
  %13 = call ptr @__remill_function_return(ptr undef, i64 %12, ptr %3), !pc !2
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

14:                                               ; preds = %1
  %15 = select i1 %10, i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198406), i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198404), !pc !1
  %16 = call ptr @__remill_error(ptr undef, i64 %15, ptr %3), !pc !1
  %17 = trunc i64 %2 to i32
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

sub_401000__AII_B_0.lifted.exit:                  ; preds = %14, %11
  %18 = phi i32 [ %0, %11 ], [ %17, %14 ]
  %19 = phi ptr [ %13, %11 ], [ %16, %14 ], !pc !0
  call void @__anvill_memory_escape(ptr %19)
  ret i32 %18
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
declare dso_local zeroext i1 @__remill_compare_neq(i1 noundef zeroext) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i64 @__remill_read_memory_64(ptr noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_error(ptr noundef nonnull align 16 dereferenceable(3504), i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #2 = { nobuiltin nounwind "no-builtins" }
attributes #3 = { alwaysinline nobuiltin nounwind "no-builtins" }

!0 = !{i64 4198400}
!1 = !{i64 4198402}
!2 = !{i64 4198408}
