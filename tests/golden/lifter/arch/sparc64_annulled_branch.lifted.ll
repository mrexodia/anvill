source_filename = "lifted_code"
target datalayout = "E-m:e-i64:64-n32:64-S128"
target triple = "sparcv9-pc-linux-gnu-elf"

@__anvill_ra = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @pick], section "llvm.metadata"

; Function Attrs: noinline
define i64 @pick(i64 %0) #0 !pc !0 {
  %2 = icmp eq i64 %0, 0, !pc !1
  br i1 %2, label %3, label %sleigh_remill_instruction_function_401004.exit, !pc !1

3:                                                ; preds = %1
  br label %sleigh_remill_instruction_function_401004.exit, !pc !1

sleigh_remill_instruction_function_401004.exit:   ; preds = %3, %1
  %4 = phi i64 [ 7, %1 ], [ 20, %3 ]
  br i1 %2, label %5, label %7, !pc !1

5:                                                ; preds = %sleigh_remill_instruction_function_401004.exit
  %6 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !2
  br label %sub_401000__ALL_B_0.lifted.exit, !pc !0

7:                                                ; preds = %sleigh_remill_instruction_function_401004.exit
  %8 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !3
  br label %sub_401000__ALL_B_0.lifted.exit, !pc !0

sub_401000__ALL_B_0.lifted.exit:                  ; preds = %7, %5
  %9 = phi ptr [ %6, %5 ], [ %8, %7 ], !pc !0
  call void @__anvill_memory_escape(ptr %9)
  ret i64 %4
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }

!0 = !{i64 4198400}
!1 = !{i64 4198404}
!2 = !{i64 4198420}
!3 = !{i64 4198412}
