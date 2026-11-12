; Extended-precision accesses, with remill's real signatures (amd64.bc):
;   __remill_read_memory_f80(mem, addr, ptr %out)  -> mem   (10-byte buffer)
;   __remill_write_memory_f80(mem, addr, ptr %in)  -> mem
;   __remill_read_memory_f128(mem, addr)           -> double
;   __remill_write_memory_f128(mem, addr, double)  -> mem
; f80 copies an x86_fp80 between memory and the buffer; f128 accesses fp128
; memory, converting from/to double with fptrunc/fpext.
; RUN: --passes=LowerRemillMemoryAccessIntrinsics
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare ptr @__remill_read_memory_f80(ptr, i64, ptr)
declare ptr @__remill_write_memory_f80(ptr, i64, ptr)
declare double @__remill_read_memory_f128(ptr, i64)
declare ptr @__remill_write_memory_f128(ptr, i64, double)

define ptr @f(ptr %mem, i64 %addr, ptr %buf) {
  %m1 = call ptr @__remill_read_memory_f80(ptr %mem, i64 %addr, ptr %buf), !pc !0
  %m2 = call ptr @__remill_write_memory_f80(ptr %m1, i64 64, ptr %buf), !pc !1
  %d = call double @__remill_read_memory_f128(ptr %m2, i64 %addr)
  %m3 = call ptr @__remill_write_memory_f128(ptr %m2, i64 128, double %d)
  ret ptr %m3
}

!0 = !{i64 4096}
!1 = !{i64 4100}
