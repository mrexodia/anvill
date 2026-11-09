; (ashr (shl V, S), S) sign-extends the low N - S bits of V and becomes
; (sext (trunc V to i(N-S))) for any 0 < S < N. Previously it was always
; truncated to half the width, which is wrong unless S = N/2 (e.g. S = 24 on
; i32 must keep 8 bits, not 16).
; RUN: --passes=ConvertMasksToCasts
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @half(i32 %v) {
  %s = shl i32 %v, 16
  %r = ashr i32 %s, 16
  ret i32 %r
}

define i32 @byte(i32 %v) {
  %s = shl i32 %v, 24
  %r = ashr i32 %s, 24
  ret i32 %r
}

define i64 @odd_width(i64 %v) {
  %s = shl i64 %v, 20
  %r = ashr i64 %s, 20
  ret i64 %r
}

define i32 @different_amounts(i32 %v) {
  %s = shl i32 %v, 16
  %r = ashr i32 %s, 8
  ret i32 %r
}
