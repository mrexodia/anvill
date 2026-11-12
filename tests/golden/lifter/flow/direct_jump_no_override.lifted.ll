source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i64
@__anvill_ra = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @skip], section "llvm.metadata"

; Function Attrs: noinline
define i32 @skip(i32 %0) #0 !pc !0 {
  %2 = call ptr @__remill_write_memory_64(ptr null, i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @__anvill_ra to i64)), !pc !0
  %3 = add i32 %0, 2
  %4 = call noundef i64 @__remill_read_memory_64(ptr noundef %2, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #2, !pc !1
  %5 = call ptr @__remill_function_return(ptr undef, i64 %4, ptr %2), !pc !1
  call void @__anvill_memory_escape(ptr %5)
  ret i32 %3
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_64(ptr noundef, i64 noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i64 @__remill_read_memory_64(ptr noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #2 = { nobuiltin nounwind "no-builtins" }

!0 = !{i64 4198400}
!1 = !{i64 4198407}
