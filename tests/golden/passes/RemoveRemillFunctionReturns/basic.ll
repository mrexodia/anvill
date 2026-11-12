; Returns to the real return address are removed: the
; __remill_function_return call is replaced by its memory pointer and the
; return-address computation is erased. A return to a value loaded from the
; stack (not yet resolved by stack recovery) is left alone. A return to any
; other value means the function changed its return address: the value is
; stored into the return address slot (llvm.addressofreturnaddress) and the
; call is removed.
; RUN: --passes=RemoveRemillFunctionReturns
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_ra = external global i8
@__anvill_sp = external global i8

declare ptr @__remill_function_return(ptr, i64, ptr)
declare i64 @__remill_read_memory_64(ptr, i64)

define ptr @returns_normally(ptr %mem) {
  %m = call ptr @__remill_function_return(ptr undef, i64 ptrtoint (ptr @__anvill_ra to i64), ptr %mem), !pc !0
  ret ptr %m
}

define ptr @returns_to_stack_value(ptr %mem) {
  %ra = call i64 @__remill_read_memory_64(ptr %mem, i64 ptrtoint (ptr @__anvill_sp to i64))
  %m = call ptr @__remill_function_return(ptr undef, i64 %ra, ptr %mem)
  ret ptr %m
}

define ptr @returns_elsewhere(ptr %mem, i64 %target) {
  %m = call ptr @__remill_function_return(ptr undef, i64 %target, ptr %mem), !pc !1
  ret ptr %m
}

!0 = !{i64 4096}
!1 = !{i64 8192}
