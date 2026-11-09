; Remill memory intrinsics become plain loads and stores through
; `inttoptr` of the address; the memory pointer result of a write is
; replaced by its memory-pointer argument. Metadata of the call is copied to
; every new instruction.
; RUN: --passes=LowerRemillMemoryAccessIntrinsics
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
  %b = call i8 @__remill_read_memory_8(ptr %mem, i64 %addr), !pc !0
  %h = call i16 @__remill_read_memory_16(ptr %mem, i64 %addr)
  %w = call i32 @__remill_read_memory_32(ptr %mem, i64 %addr)
  %q = call i64 @__remill_read_memory_64(ptr %mem, i64 %addr)
  %fs = call float @__remill_read_memory_f32(ptr %mem, i64 %addr)
  %fd = call double @__remill_read_memory_f64(ptr %mem, i64 %addr)
  %m1 = call ptr @__remill_write_memory_8(ptr %mem, i64 16, i8 %b), !pc !1
  %m2 = call ptr @__remill_write_memory_16(ptr %m1, i64 32, i16 %h)
  %m3 = call ptr @__remill_write_memory_32(ptr %m2, i64 48, i32 %w)
  %m4 = call ptr @__remill_write_memory_64(ptr %m3, i64 64, i64 %q)
  %m5 = call ptr @__remill_write_memory_f32(ptr %m4, i64 80, float %fs)
  %m6 = call ptr @__remill_write_memory_f64(ptr %m5, i64 96, double %fd)
  ret ptr %m6
}

!0 = !{i64 4096}
!1 = !{i64 4100}
