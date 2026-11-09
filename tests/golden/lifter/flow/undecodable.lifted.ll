source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i64
@__anvill_ra = external global i64
@__anvill_pc = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @garbage], section "llvm.metadata"

; Function Attrs: noinline
define void @garbage() #0 !pc !0 {
  %1 = call ptr @__remill_write_memory_64(ptr null, i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @__anvill_ra to i64)), !pc !0
  %2 = call ptr @__remill_error(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198400), ptr %1), !pc !0
  call void @__anvill_memory_escape(ptr %2)
  ret void
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_64(ptr noundef, i64 noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_error(ptr noundef nonnull align 16 dereferenceable(3504), i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }

!0 = !{i64 4198400}
