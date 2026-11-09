source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_ra = external global i64
@__anvill_pc = external global i64
@__anvill_stack_0 = external local_unnamed_addr global i64

; Function Attrs: noinline
define i32 @table_switch(i32 %0) local_unnamed_addr #0 !pc !0 {
  %2 = icmp ugt i32 %0, 3, !pc !1
  br i1 %2, label %3, label %4, !pc !1

3:                                                ; preds = %4, %1
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

4:                                                ; preds = %1
  switch i32 %0, label %3 [
    i32 0, label %inst_401017.i
    i32 1, label %inst_40101d.i
    i32 2, label %inst_401023.i
    i32 3, label %inst_401029.i
  ], !pc !2

inst_401017.i:                                    ; preds = %4
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

inst_40101d.i:                                    ; preds = %4
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

inst_401023.i:                                    ; preds = %4
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

inst_401029.i:                                    ; preds = %4
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

sub_401000__AII_B_0.lifted.exit:                  ; preds = %inst_401029.i, %inst_401023.i, %inst_40101d.i, %inst_401017.i, %3
  %5 = phi i32 [ -1, %3 ], [ 400, %inst_401029.i ], [ 300, %inst_401023.i ], [ 200, %inst_40101d.i ], [ 100, %inst_401017.i ]
  ret i32 %5
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
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) local_unnamed_addr #1

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }

!0 = !{i64 4198400}
!1 = !{i64 4198403}
!2 = !{i64 4198418}
