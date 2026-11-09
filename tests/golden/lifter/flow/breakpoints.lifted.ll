source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i64
@__anvill_ra = external global i64
@__anvill_pc = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @inc], section "llvm.metadata"

; Function Attrs: noinline
define i32 @inc(i32 %0) #0 !pc !0 {
  %2 = call ptr @__remill_write_memory_64(ptr null, i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @__anvill_ra to i64)), !pc !0
  %3 = call ptr @breakpoint_401000(ptr %2, i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198400), i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198400)) #3, !pc !0
  %4 = add i32 %0, 1
  %5 = call ptr @breakpoint_401003(ptr %2, i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198400), i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198403)) #3, !pc !1
  %6 = call noundef i64 @__remill_read_memory_64(ptr noundef %2, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #4, !pc !1
  %7 = call ptr @__remill_function_return(ptr undef, i64 %6, ptr %2), !pc !1
  call void @__anvill_memory_escape(ptr %7)
  ret i32 %4
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_64(ptr noundef, i64 noundef, i64 noundef) #1

; Function Attrs: noinline optnone memory(none)
declare ptr @breakpoint_401000(ptr, i64, i64) #2

; Function Attrs: noinline optnone memory(none)
declare ptr @breakpoint_401003(ptr, i64, i64) #2

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i64 @__remill_read_memory_64(ptr noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #2 = { noinline optnone memory(none) }
attributes #3 = { nounwind }
attributes #4 = { nobuiltin nounwind "no-builtins" }

!0 = !{i64 4198400}
!1 = !{i64 4198403}
