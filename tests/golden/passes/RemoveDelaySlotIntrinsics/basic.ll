; Calls to __remill_delay_slot_begin/__remill_delay_slot_end are replaced by
; their memory-pointer argument; their metadata is copied onto the memory
; pointer when it is an instruction.
; RUN: --passes=RemoveDelaySlotIntrinsics
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare ptr @__remill_delay_slot_begin(ptr)
declare ptr @__remill_delay_slot_end(ptr)
declare ptr @__remill_write_memory_32(ptr, i64, i32)

define ptr @f(ptr %mem) {
  %m0 = call ptr @__remill_delay_slot_begin(ptr %mem), !pc !0
  %m1 = call ptr @__remill_write_memory_32(ptr %m0, i64 16, i32 1)
  %m2 = call ptr @__remill_delay_slot_end(ptr %m1), !pc !1
  ret ptr %m2
}

!0 = !{i64 4096}
!1 = !{i64 4100}
