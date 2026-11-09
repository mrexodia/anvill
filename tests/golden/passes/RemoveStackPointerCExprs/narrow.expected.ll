source_filename = "narrow.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i8

declare i1 @__remill_flag_computation_zero(i1, ...)

define i32 @f(i64 %x) {
  %low32 = add i32 117440500, 1
  %low8 = zext i8 3 to i32
  %full = add i64 ptrtoint (ptr @__anvill_sp to i64), %x
  %t = trunc i64 %full to i32
  %r0 = add i32 %low32, %low8
  %r = add i32 %r0, %t
  ret i32 %r
}
