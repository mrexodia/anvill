source_filename = "lifted_code"
target datalayout = "E-m:e-p:32:32-i64:64-f128:64-n32-S64"
target triple = "sparc-pc-linux-gnu-elf"

@__anvill_ra = external global i32
@llvm.compiler.used = appending global [1 x ptr] [ptr @pick], section "llvm.metadata"

; Function Attrs: noinline
define i32 @pick(i32 %0) #0 !pc !0 {
  %2 = icmp eq i32 %0, 0, !pc !1
  br i1 %2, label %3, label %sleigh_remill_instruction_function_401004.exit, !pc !1

3:                                                ; preds = %1
  br label %sleigh_remill_instruction_function_401004.exit, !pc !1

sleigh_remill_instruction_function_401004.exit:   ; preds = %3, %1
  %4 = phi i32 [ 7, %1 ], [ 20, %3 ]
  br i1 %2, label %5, label %7, !pc !1

5:                                                ; preds = %sleigh_remill_instruction_function_401004.exit
  %6 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !2
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

7:                                                ; preds = %sleigh_remill_instruction_function_401004.exit
  %8 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !3
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

sub_401000__AII_B_0.lifted.exit:                  ; preds = %7, %5
  %9 = phi ptr [ %6, %5 ], [ %8, %7 ], !pc !0
  call void @__anvill_memory_escape(ptr %9)
  ret i32 %4
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }

!0 = !{i32 4198400}
!1 = !{i32 4198404}
!2 = !{i32 4198420}
!3 = !{i32 4198412}
