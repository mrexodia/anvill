source_filename = "tests/golden/passes/RemoveUnusedBranchHints/basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare i1 @__remill_compare_eq(i1)

declare i1 @__remill_compare_sle(i1)

declare i1 @__remill_flag_computation_zero(i1, ...)

declare ptr @__remill_compare_exchange_memory_32(ptr, i64, ptr, i32)

define i1 @f(ptr %mem, i32 %a, i32 %b, ptr %expected) {
  %eq = icmp eq i32 %a, %b
  %sle = icmp sle i32 %a, %b
  %z = icmp eq i32 %a, 0
  %m = call ptr @__remill_compare_exchange_memory_32(ptr %mem, i64 16, ptr %expected, i32 %b)
  %x = and i1 %eq, %sle
  %y = and i1 %x, %z
  ret i1 %y
}
