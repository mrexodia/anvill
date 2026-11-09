source_filename = "lifted_code"
target datalayout = "E-m:e-i64:64-n32:64-S128"
target triple = "sparcv9-pc-linux-gnu-elf"

@__anvill_pc = external global i64
@__anvill_ra = external global i64
@llvm.compiler.used = appending global [2 x ptr] [ptr @f, ptr @g], section "llvm.metadata"

; Function Attrs: noinline
define i64 @f(i64 %0) #0 !pc !0 {
  br i1 true, label %2, label %3, !pc !0

2:                                                ; preds = %1
  br label %sleigh_remill_instruction_function_401000.exit, !pc !0

3:                                                ; preds = %1
  br label %sleigh_remill_instruction_function_401000.exit, !pc !0

sleigh_remill_instruction_function_401000.exit:   ; preds = %3, %2
  %4 = add i64 %0, 1, !pc !1
  %5 = call i64 inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198420) to ptr)(i64 %4) #2, !pc !1
  br i1 true, label %6, label %8, !pc !2

6:                                                ; preds = %sleigh_remill_instruction_function_401000.exit
  %7 = add i64 %5, %0, !pc !2
  br label %sleigh_remill_instruction_function_40100c.exit, !pc !2

8:                                                ; preds = %sleigh_remill_instruction_function_401000.exit
  br label %sleigh_remill_instruction_function_40100c.exit, !pc !2

sleigh_remill_instruction_function_40100c.exit:   ; preds = %8, %6
  %9 = phi i64 [ %7, %6 ], [ poison, %8 ]
  %10 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !2
  call void @__anvill_memory_escape(ptr %10)
  ret i64 %9
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

; Function Attrs: noinline
define i64 @g(i64 %0) #0 !pc !3 {
  %2 = shl i64 %0, 1, !pc !3
  %3 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !3
  call void @__anvill_memory_escape(ptr %3)
  ret i64 %2
}

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nounwind }

!0 = !{i64 4198400}
!1 = !{i64 4198404}
!2 = !{i64 4198412}
!3 = !{i64 4198420}
