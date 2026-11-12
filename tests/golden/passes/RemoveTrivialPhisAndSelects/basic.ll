; PHIs whose incoming values are all the same value, and selects whose two
; values are the same, are replaced by that value. Replacements are repeated
; on the users (a worklist), so chains collapse.
; RUN: --passes=RemoveTrivialPhisAndSelects
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @f(i1 %c, i32 %x, i32 %y) {
entry:
  br i1 %c, label %a, label %b
a:
  br label %join
b:
  br label %join
join:
  %p = phi i32 [ %x, %a ], [ %x, %b ]
  %s = select i1 %c, i32 %p, i32 %x
  %q = phi i32 [ %y, %a ], [ %x, %b ]
  %t = select i1 %c, i32 %q, i32 %q
  %r = add i32 %s, %t
  ret i32 %r
}

define i32 @loop(i32 %x, i32 %n) {
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %next, %loop ]
  %self = phi i32 [ %x, %entry ], [ %self, %loop ]
  %next = add i32 %i, 1
  %done = icmp eq i32 %next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret i32 %self
}
