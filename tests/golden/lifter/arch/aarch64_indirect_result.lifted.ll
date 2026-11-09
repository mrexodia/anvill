source_filename = "lifted_code"
target datalayout = "e-m:e-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128"
target triple = "aarch64-pc-linux-gnu-elf"

@__anvill_ra = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @make], section "llvm.metadata"

; Function Attrs: noinline
define void @make(ptr %0, i64 %1, i64 %2) #0 !pc !0 {
  %4 = ptrtoint ptr %0 to i64, !pc !0
  %5 = call ptr @__remill_write_memory_64(ptr noundef null, i64 noundef %4, i64 noundef %1) #2, !pc !0
  %6 = add i64 %4, 8, !pc !0
  %7 = call noundef ptr @__remill_write_memory_64(ptr noundef %5, i64 noundef %6, i64 noundef %2) #2, !pc !0
  %8 = add i64 %4, 16, !pc !1
  %9 = call noundef ptr @__remill_write_memory_64(ptr noundef %7, i64 noundef %8, i64 noundef %1) #2, !pc !1
  %10 = call ptr @__remill_function_return(ptr undef, i64 ptrtoint (ptr @__anvill_ra to i64), ptr %9), !pc !2
  call void @__anvill_memory_escape(ptr %10)
  ret void
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_64(ptr noundef, i64 noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="non-leaf" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nobuiltin nounwind "no-builtins" }

!0 = !{i64 4198400}
!1 = !{i64 4198404}
!2 = !{i64 4198408}
