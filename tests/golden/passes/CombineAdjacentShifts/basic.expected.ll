source_filename = "basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @half_then_less(i32 %v) {
  %s = shl i32 %v, 16
  %1 = trunc i32 %v to i16
  %2 = sext i16 %1 to i32, !pc !0
  %3 = shl i32 %2, 8
  ret i32 %3
}

define i32 @more_than_shl(i32 %v) {
  %s = shl i32 %v, 8
  %r = ashr i32 %s, 16
  ret i32 %r
}

define i32 @not_half(i32 %v) {
  %s = shl i32 %v, 24
  %r = ashr i32 %s, 8
  ret i32 %r
}

define i32 @equal(i32 %v) {
  %s = shl i32 %v, 16
  %r = ashr i32 %s, 16
  ret i32 %r
}

define i64 @wide(i64 %v) {
  %s = shl i64 %v, 32
  %1 = trunc i64 %v to i32
  %2 = sext i32 %1 to i64
  %3 = shl i64 %2, 28
  ret i64 %3
}

!0 = !{i64 4096}
