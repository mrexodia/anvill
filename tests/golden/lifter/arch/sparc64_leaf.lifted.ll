source_filename = "lifted_code"
target datalayout = "E-m:e-i64:64-n32:64-S128"
target triple = "sparcv9-pc-linux-gnu-elf"

@__anvill_ra = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @add], section "llvm.metadata"

; Function Attrs: noinline
define i64 @add(i64 %0, i64 %1) #0 !pc !0 {
  %3 = add i64 %1, %0, !pc !0
  %4 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !0
  call void @__anvill_memory_escape(ptr %4)
  ret i64 %3
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }

!0 = !{i64 4198400}
