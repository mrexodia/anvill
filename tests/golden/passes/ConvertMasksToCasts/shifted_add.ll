; (add (shl V, N), M << N) with N in {8, 16, 32, 64, 128} becomes
; (shl (add V, M), N); the original shl is removed if it has no other users.
; Previously this rewrite did not mark the function as changed.
; RUN: --passes=ConvertMasksToCasts
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i64 @shifted(i64 %v) {
  %s = shl i64 %v, 32
  %r = add i64 %s, 21474836480
  ret i64 %r
}

define i64 @low_bits_set(i64 %v) {
  %s = shl i64 %v, 32
  %r = add i64 %s, 21474836481
  ret i64 %r
}

define i64 @shl_still_used(i64 %v) {
  %s = shl i64 %v, 16
  %r = add i64 %s, 196608
  %u = xor i64 %r, %s
  ret i64 %u
}
