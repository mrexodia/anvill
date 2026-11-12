; (xor (icmp P a, b), true) becomes (icmp !P a, b) when every other user of
; the compare is a branch or a select condition: those branches get their
; successors swapped and those selects their values swapped, so they keep
; their meaning. Previously only the *last* such user was swapped (the list
; was cleared per use), silently inverting the others.
; RUN: --passes=ConvertXorsToCmps
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @only_xor(i32 %a, i32 %b) {
  %c = icmp slt i32 %a, %b
  %x = xor i1 %c, true, !pc !0
  %r = select i1 %x, i32 1, i32 2
  ret i32 %r
}

define i32 @two_branches(i32 %a, i32 %b, ptr %p) {
entry:
  %c = icmp ult i32 %a, %b
  %x = xor i1 true, %c
  store i1 %x, ptr %p
  br i1 %c, label %t1, label %f1
t1:
  br label %mid
f1:
  br label %mid
mid:
  %v = phi i32 [ 1, %t1 ], [ 2, %f1 ]
  br i1 %c, label %t2, label %f2
t2:
  ret i32 %v
f2:
  ret i32 0
}

define i32 @select_condition(i32 %a, i32 %b) {
  %c = icmp eq i32 %a, %b
  %x = xor i1 %c, true
  %s = select i1 %c, i32 %a, i32 %b
  %t = select i1 %x, i32 10, i32 %s
  ret i32 %t
}

!0 = !{i64 4096}
