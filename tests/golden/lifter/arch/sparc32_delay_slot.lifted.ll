source_filename = "lifted_code"
target datalayout = "E-m:e-p:32:32-i64:64-f128:64-n32-S64"
target triple = "sparc-pc-linux-gnu-elf"

@__anvill_ra = external global i32
@llvm.compiler.used = appending global [1 x ptr] [ptr @add], section "llvm.metadata"

; Function Attrs: noinline
define i32 @add(i32 %0, i32 %1) #0 !pc !0 {
  %3 = add i32 %1, %0, !pc !0
  %4 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !0
  call void @__anvill_memory_escape(ptr %4)
  ret i32 %3
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }

!0 = !{i32 4198400}
