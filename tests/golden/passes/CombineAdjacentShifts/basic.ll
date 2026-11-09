; (ashr (shl V, A), B) with A = N/2 and B < A sign-extends the low half of V
; and shifts it left by A - B:
;   trunc V to iA ; sext to iN ; shl by (A - B)
; Other shift amounts are left alone. Previously the two shift amounts were
; swapped while matching, so the pass rewrote (ashr (shl V, 8), 16) -- a
; right shift -- into a left shift, and skipped the valid case.
; RUN: --passes=CombineAdjacentShifts
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

; A = 16 = N/2, B = 8: combined.
define i32 @half_then_less(i32 %v) {
  %s = shl i32 %v, 16
  %r = ashr i32 %s, 8, !pc !0
  ret i32 %r
}

; A = 8, B = 16 (B > A): not a left shift, unchanged.
define i32 @more_than_shl(i32 %v) {
  %s = shl i32 %v, 8
  %r = ashr i32 %s, 16
  ret i32 %r
}

; A = 24 is not half the width: unchanged.
define i32 @not_half(i32 %v) {
  %s = shl i32 %v, 24
  %r = ashr i32 %s, 8
  ret i32 %r
}

; A = B: a plain sign extension, left to ConvertMasksToCasts.
define i32 @equal(i32 %v) {
  %s = shl i32 %v, 16
  %r = ashr i32 %s, 16
  ret i32 %r
}

; 64-bit: A = 32, B = 4.
define i64 @wide(i64 %v) {
  %s = shl i64 %v, 32
  %r = ashr i64 %s, 4
  ret i64 %r
}

!0 = !{i64 4096}
