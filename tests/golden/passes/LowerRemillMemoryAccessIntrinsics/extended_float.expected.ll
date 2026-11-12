source_filename = "extended_float.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare ptr @__remill_read_memory_f80(ptr, i64, ptr)

declare ptr @__remill_write_memory_f80(ptr, i64, ptr)

declare double @__remill_read_memory_f128(ptr, i64)

declare ptr @__remill_write_memory_f128(ptr, i64, double)

define ptr @f(ptr %mem, i64 %addr, ptr %buf) {
  %1 = inttoptr i64 %addr to ptr, !pc !0
  %2 = load x86_fp80, ptr %1, align 16, !pc !0
  store x86_fp80 %2, ptr %buf, align 16, !pc !0
  %3 = load x86_fp80, ptr %buf, align 16, !pc !1
  store x86_fp80 %3, ptr inttoptr (i64 64 to ptr), align 16, !pc !1
  %4 = inttoptr i64 %addr to ptr
  %5 = load fp128, ptr %4, align 16
  %6 = fptrunc fp128 %5 to double
  %7 = fpext double %6 to fp128
  store fp128 %7, ptr inttoptr (i64 128 to ptr), align 16
  ret ptr %mem
}

!0 = !{i64 4096}
!1 = !{i64 4100}
