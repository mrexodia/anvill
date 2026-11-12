source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_reg_RAX = external local_unnamed_addr global i64
@__anvill_ra = external global i64
@__anvill_stack_0 = external local_unnamed_addr global i64

; Function Attrs: noinline
define i32 @sum(i32 %0) local_unnamed_addr #0 !pc !0 {
  br label %inst_401002.i, !pc !0

inst_401002.i:                                    ; preds = %5, %1
  %2 = phi i32 [ 0, %1 ], [ %6, %5 ], !pc !1
  %3 = phi i32 [ %0, %1 ], [ %7, %5 ], !pc !1
  %4 = icmp eq i32 %3, 0, !pc !1
  br i1 %4, label %sub_401000__AII_B_0.lifted.exit, label %5, !pc !2

5:                                                ; preds = %inst_401002.i
  %6 = add i32 %3, %2, !pc !3
  %7 = add i32 %3, -1, !pc !4
  br label %inst_401002.i, !pc !5

sub_401000__AII_B_0.lifted.exit:                  ; preds = %inst_401002.i
  ret i32 %2
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_zero(i1 noundef zeroext, ...) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_sign(i1 noundef zeroext, ...) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i8 @__remill_undefined_8() local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_compare_eq(i1 noundef zeroext) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_carry(i1 noundef zeroext, ...) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_overflow(i1 noundef zeroext, ...) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) local_unnamed_addr #1

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }

!0 = !{i64 4198400}
!1 = !{i64 4198402}
!2 = !{i64 4198404}
!3 = !{i64 4198406}
!4 = !{i64 4198408}
!5 = !{i64 4198410}
