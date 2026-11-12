; An indirect jump (__remill_jump) whose target is the return address is a
; return: the call is redirected to __remill_function_return (with an undef
; state pointer), and the function is cleaned up with DCE, SROA, SimplifyCFG
; and InstCombine. The return address is recognized directly
; (ptrtoint @__anvill_ra), or through arbitrary arithmetic that still
; evaluates to the magic return address value 0x4141414141414141 (e.g. a
; byte-by-byte reassembly). Other targets are left alone.
; RUN: --passes=TransformRemillJumpIntrinsics
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_ra = external global i8

declare ptr @__remill_jump(ptr, i64, ptr)

define ptr @direct(ptr %state, ptr %mem) {
  %m = call ptr @__remill_jump(ptr %state, i64 ptrtoint (ptr @__anvill_ra to i64), ptr %mem), !pc !0
  ret ptr %m
}

define ptr @reassembled(ptr %state, ptr %mem) {
  %ra = ptrtoint ptr @__anvill_ra to i64
  %hi = lshr i64 %ra, 32
  %lo = and i64 %ra, 4294967295
  %hi2 = shl i64 %hi, 32
  %back = or i64 %hi2, %lo
  %m = call ptr @__remill_jump(ptr %state, i64 %back, ptr %mem)
  ret ptr %m
}

define ptr @unknown_target(ptr %state, ptr %mem, i64 %target) {
  %m = call ptr @__remill_jump(ptr %state, i64 %target, ptr %mem)
  ret ptr %m
}

!0 = !{i64 4096}
