source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_reg_RAX = external global i64
@__anvill_sp = external global i64
@__anvill_ra = external global i64
@__anvill_pc = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @apply], section "llvm.metadata"

; Function Attrs: noinline
define i32 @apply(ptr %0, i32 %1) #0 !pc !0 {
  %3 = load i64, ptr @__anvill_reg_RAX, align 8, !pc !0
  %4 = call ptr @__remill_write_memory_64(ptr null, i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @__anvill_ra to i64)), !pc !0
  %5 = call noundef ptr @__remill_write_memory_64(ptr noundef %4, i64 noundef add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 noundef %3) #2, !pc !0
  %6 = call noundef ptr @__remill_write_memory_64(ptr noundef %5, i64 noundef add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -16), i64 noundef add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198408)) #2, !pc !1
  %7 = call i64 @__remill_read_memory_64(ptr %6, i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -16)), !pc !1
  %8 = call i32 %0(i32 %1) #3, !pc !1
  %9 = call noundef i64 @__remill_read_memory_64(ptr noundef %6, i64 noundef add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8)) #2, !pc !2
  %10 = call noundef i64 @__remill_read_memory_64(ptr noundef %6, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #2, !pc !3
  %11 = call ptr @__remill_function_return(ptr undef, i64 %10, ptr %6), !pc !3
  call void @__anvill_memory_escape(ptr %11)
  ret i32 %8
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
attributes #3 = { nounwind }

!0 = !{i64 4198400}
!1 = !{i64 4198406}
!2 = !{i64 4198408}
!3 = !{i64 4198409}
