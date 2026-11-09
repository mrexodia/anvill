source_filename = "lifted_code"
target datalayout = "e-m:e-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128"
target triple = "aarch64-pc-linux-gnu-elf"

@__anvill_ra = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @add], section "llvm.metadata"

; Function Attrs: noinline
define i32 @add(i32 %0, i32 %1) #0 !pc !0 {
  %3 = add i32 %1, %0
  %4 = call ptr @__remill_function_return(ptr undef, i64 ptrtoint (ptr @__anvill_ra to i64), ptr null), !pc !1
  call void @__anvill_memory_escape(ptr %4)
  ret i32 %3
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="non-leaf" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }

!0 = !{i64 4198400}
!1 = !{i64 4198404}
