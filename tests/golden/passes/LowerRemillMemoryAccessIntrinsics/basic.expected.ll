source_filename = "basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare i8 @__remill_read_memory_8(ptr, i64)

declare i16 @__remill_read_memory_16(ptr, i64)

declare i32 @__remill_read_memory_32(ptr, i64)

declare i64 @__remill_read_memory_64(ptr, i64)

declare float @__remill_read_memory_f32(ptr, i64)

declare double @__remill_read_memory_f64(ptr, i64)

declare ptr @__remill_write_memory_8(ptr, i64, i8)

declare ptr @__remill_write_memory_16(ptr, i64, i16)

declare ptr @__remill_write_memory_32(ptr, i64, i32)

declare ptr @__remill_write_memory_64(ptr, i64, i64)

declare ptr @__remill_write_memory_f32(ptr, i64, float)

declare ptr @__remill_write_memory_f64(ptr, i64, double)

define ptr @f(ptr %mem, i64 %addr) {
  %1 = inttoptr i64 %addr to ptr, !pc !0
  %2 = load i8, ptr %1, align 1, !pc !0
  %3 = inttoptr i64 %addr to ptr
  %4 = load i16, ptr %3, align 2
  %5 = inttoptr i64 %addr to ptr
  %6 = load i32, ptr %5, align 4
  %7 = inttoptr i64 %addr to ptr
  %8 = load i64, ptr %7, align 8
  %9 = inttoptr i64 %addr to ptr
  %10 = load float, ptr %9, align 4
  %11 = inttoptr i64 %addr to ptr
  %12 = load double, ptr %11, align 8
  store i8 %2, ptr inttoptr (i64 16 to ptr), align 1, !pc !1
  store i16 %4, ptr inttoptr (i64 32 to ptr), align 2
  store i32 %6, ptr inttoptr (i64 48 to ptr), align 4
  store i64 %8, ptr inttoptr (i64 64 to ptr), align 8
  store float %10, ptr inttoptr (i64 80 to ptr), align 4
  store double %12, ptr inttoptr (i64 96 to ptr), align 8
  ret ptr %mem
}

!0 = !{i64 4096}
!1 = !{i64 4100}
