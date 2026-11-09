; Branch hints that BranchRecovery did not use are removed: calls to
; __remill_compare_* and __remill_flag_computation_* are replaced by their
; first argument (the computed i1). __remill_compare_exchange_* calls are
; atomic memory operations and must be kept (previously they were replaced by
; their memory pointer, deleting the atomic store).
; RUN: --passes=RemoveUnusedBranchHints
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare i1 @__remill_compare_eq(i1)
declare i1 @__remill_compare_sle(i1)
declare i1 @__remill_flag_computation_zero(i1, ...)
declare ptr @__remill_compare_exchange_memory_32(ptr, i64, ptr, i32)

define i1 @f(ptr %mem, i32 %a, i32 %b, ptr %expected) {
  %eq = icmp eq i32 %a, %b
  %h1 = call i1 @__remill_compare_eq(i1 %eq)
  %sle = icmp sle i32 %a, %b
  %h2 = call i1 @__remill_compare_sle(i1 %sle)
  %z = icmp eq i32 %a, 0
  %f = call i1 (i1, ...) @__remill_flag_computation_zero(i1 %z, i32 %a, i32 0, i32 %a)
  %m = call ptr @__remill_compare_exchange_memory_32(ptr %mem, i64 16, ptr %expected, i32 %b)
  %x = and i1 %h1, %h2
  %y = and i1 %x, %f
  ret i1 %y
}
