; (xor V, true) of a non-compare i1 used by branches: the branches use V and
; swap their successors; the xor is erased if nothing else uses it.
; RUN: --passes=ConvertXorsToCmps
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @branch_on_not(i1 %a, i1 %b) {
entry:
  %o = or i1 %a, %b
  %x = xor i1 %o, true
  br i1 %x, label %yes, label %no
yes:
  ret i32 1
no:
  ret i32 0
}

define i1 @kept_for_other_user(i1 %a) {
entry:
  %x = xor i1 %a, true
  br i1 %x, label %yes, label %no
yes:
  ret i1 %x
no:
  ret i1 false
}
