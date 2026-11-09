source_filename = "lifted_code"
target datalayout = "E-m:e-p:32:32-i64:64-f128:64-n32-S64"
target triple = "sparc-pc-linux-gnu-elf"

@__anvill_pc = external global i32
@__anvill_ra = external global i32
@llvm.compiler.used = appending global [2 x ptr] [ptr @f, ptr @g], section "llvm.metadata"

; Function Attrs: noinline
define i32 @f(i32 %0) #0 !pc !0 {
  br i1 true, label %2, label %3, !pc !0

2:                                                ; preds = %1
  br label %sleigh_remill_instruction_function_401000.exit, !pc !0

3:                                                ; preds = %1
  br label %sleigh_remill_instruction_function_401000.exit, !pc !0

sleigh_remill_instruction_function_401000.exit:   ; preds = %3, %2
  %4 = add i32 %0, 1, !pc !1
  %5 = call i32 inttoptr (i32 add (i32 ptrtoint (ptr @__anvill_pc to i32), i32 4198420) to ptr)(i32 %4) #2, !pc !1
  br i1 true, label %6, label %8, !pc !2

6:                                                ; preds = %sleigh_remill_instruction_function_401000.exit
  %7 = add i32 %5, %0, !pc !2
  br label %sleigh_remill_instruction_function_40100c.exit, !pc !2

8:                                                ; preds = %sleigh_remill_instruction_function_401000.exit
  br label %sleigh_remill_instruction_function_40100c.exit, !pc !2

sleigh_remill_instruction_function_40100c.exit:   ; preds = %8, %6
  %9 = phi i32 [ %7, %6 ], [ poison, %8 ]
  %10 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !2
  call void @__anvill_memory_escape(ptr %10)
  ret i32 %9
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

; Function Attrs: noinline
define i32 @g(i32 %0) #0 !pc !3 {
  %2 = shl i32 %0, 1, !pc !3
  %3 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !3
  call void @__anvill_memory_escape(ptr %3)
  ret i32 %2
}

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nounwind }

!0 = !{i32 4198400}
!1 = !{i32 4198404}
!2 = !{i32 4198412}
!3 = !{i32 4198420}
