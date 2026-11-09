source_filename = "basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare ptr @__remill_delay_slot_begin(ptr)

declare ptr @__remill_delay_slot_end(ptr)

declare ptr @__remill_write_memory_32(ptr, i64, i32)

define ptr @f(ptr %mem) {
  %m1 = call ptr @__remill_write_memory_32(ptr %mem, i64 16, i32 1), !pc !0
  ret ptr %m1
}

!0 = !{i64 4100}
