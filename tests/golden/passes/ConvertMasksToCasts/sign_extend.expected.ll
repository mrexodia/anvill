source_filename = "sign_extend.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @half(i32 %v) {
  %1 = trunc i32 %v to i16
  %2 = sext i16 %1 to i32
  ret i32 %2
}

define i32 @byte(i32 %v) {
  %1 = trunc i32 %v to i8
  %2 = sext i8 %1 to i32
  ret i32 %2
}

define i64 @odd_width(i64 %v) {
  %1 = trunc i64 %v to i44
  %2 = sext i44 %1 to i64
  ret i64 %2
}

define i32 @different_amounts(i32 %v) {
  %s = shl i32 %v, 16
  %r = ashr i32 %s, 8
  ret i32 %r
}
