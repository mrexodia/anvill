source_filename = "lifted_code"
target datalayout = "E-m:e-p:32:32-i64:64-f128:64-n32-S64"
target triple = "sparc-pc-linux-gnu-elf"

@__anvill_ra = external global i32

; Function Attrs: noinline
define i32 @pick(i32 %0) local_unnamed_addr #0 !pc !0 {
sleigh_remill_instruction_function_401004.exit:
  %1 = icmp eq i32 %0, 0, !pc !1
  br i1 %1, label %2, label %3, !pc !1

2:                                                ; preds = %sleigh_remill_instruction_function_401004.exit
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

3:                                                ; preds = %sleigh_remill_instruction_function_401004.exit
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

sub_401000__AII_B_0.lifted.exit:                  ; preds = %3, %2
  %spec.select = phi i32 [ 7, %3 ], [ 20, %2 ]
  ret i32 %spec.select
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) local_unnamed_addr #1

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }

!0 = !{i32 4198400}
!1 = !{i32 4198404}
