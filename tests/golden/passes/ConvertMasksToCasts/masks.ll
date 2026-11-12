; (and V, M) where M keeps exactly the low half of the bits becomes
; (zext (trunc V)). Other masks are unchanged.
; RUN: --passes=ConvertMasksToCasts
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @low_half_i32(i32 %v) {
  %r = and i32 %v, 65535, !pc !0
  ret i32 %r
}

define i64 @low_half_i64_commuted(i64 %v) {
  %r = and i64 4294967295, %v
  ret i64 %r
}

define i64 @not_half(i64 %v) {
  %r = and i64 %v, 65535
  ret i64 %r
}

define i32 @not_low_bits(i32 %v) {
  %r = and i32 %v, 65520
  ret i32 %r
}

!0 = !{i64 4096}
