; The compare is not inverted when another user needs its original value
; (here a zext, and a select that also uses it as a value).
; RUN: --passes=ConvertXorsToCmps
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i64 @zext_user(i32 %a, i32 %b) {
  %c = icmp sgt i32 %a, %b
  %x = xor i1 %c, true
  %z = zext i1 %c to i64
  %zx = zext i1 %x to i64
  %r = add i64 %z, %zx
  ret i64 %r
}

define i1 @select_value_user(i32 %a, i32 %b, i1 %d) {
  %c = icmp ne i32 %a, %b
  %x = xor i1 %c, true
  %s = select i1 %c, i1 %c, i1 %d
  %r = and i1 %s, %x
  ret i1 %r
}

define i32 @not_true(i32 %a, i32 %b) {
  %c = icmp eq i32 %a, %b
  %x = xor i1 %c, false
  %r = select i1 %x, i32 1, i32 2
  ret i32 %r
}
