source_filename = "lifted_code"
target datalayout = "e-m:e-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64"
target triple = "arm-pc-linux-gnu-elf"

@__anvill_ra = external global i32
@llvm.compiler.used = appending global [1 x ptr] [ptr @f], section "llvm.metadata"

; Function Attrs: noinline
define i32 @f(i32 %0, i32 %1, i32 %2) #0 !pc !0 {
  %4 = add i32 %1, %0, !pc !0
  %5 = call ptr @__remill_function_return(ptr undef, i32 ptrtoint (ptr @__anvill_ra to i32), ptr null), !pc !1
  call void @__anvill_memory_escape(ptr %5)
  ret i32 %4
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }

!0 = !{i32 4198400}
!1 = !{i32 4198404}
