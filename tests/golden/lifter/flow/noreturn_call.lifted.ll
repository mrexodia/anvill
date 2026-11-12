source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_reg_RAX = external global i64
@__anvill_sp = external global i64
@__anvill_ra = external global i64
@__anvill_pc = external global i64
@llvm.compiler.used = appending global [2 x ptr] [ptr @calls_die, ptr @die], section "llvm.metadata"

; Function Attrs: noinline
define i32 @calls_die() #0 !pc !0 {
  %1 = load i64, ptr @__anvill_reg_RAX, align 8, !pc !0
  %2 = call ptr @__remill_write_memory_64(ptr null, i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @__anvill_ra to i64)), !pc !0
  %3 = call noundef ptr @__remill_write_memory_64(ptr noundef %2, i64 noundef add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 noundef %1) #3, !pc !0
  %4 = call noundef ptr @__remill_write_memory_64(ptr noundef %3, i64 noundef add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -16), i64 noundef add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198406)) #3, !pc !1
  %5 = call i64 @__remill_read_memory_64(ptr %4, i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -16)), !pc !1
  call void inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4202496) to ptr)() #4, !pc !1
  unreachable
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_64(ptr noundef, i64 noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i64 @__remill_read_memory_64(ptr noundef, i64 noundef) #1

; Function Attrs: noinline noreturn
declare !pc !2 void @die() #2

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #2 = { noinline noreturn }
attributes #3 = { nobuiltin nounwind "no-builtins" }
attributes #4 = { noreturn nounwind }

!0 = !{i64 4198400}
!1 = !{i64 4198401}
!2 = !{i64 4202496}
