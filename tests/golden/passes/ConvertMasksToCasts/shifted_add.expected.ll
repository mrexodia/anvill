source_filename = "tests/golden/passes/ConvertMasksToCasts/shifted_add.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i64 @shifted(i64 %v) {
  %1 = add i64 %v, 5
  %2 = shl i64 %1, 32
  ret i64 %2
}

define i64 @low_bits_set(i64 %v) {
  %s = shl i64 %v, 32
  %r = add i64 %s, 21474836481
  ret i64 %r
}

define i64 @shl_still_used(i64 %v) {
  %s = shl i64 %v, 16
  %1 = add i64 %v, 3
  %2 = shl i64 %1, 16
  %u = xor i64 %2, %s
  ret i64 %u
}
