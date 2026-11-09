source_filename = "basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @f(i1 %c, i32 %x, i32 %y) {
entry:
  br i1 %c, label %a, label %b

a:                                                ; preds = %entry
  br label %join

b:                                                ; preds = %entry
  br label %join

join:                                             ; preds = %b, %a
  %q = phi i32 [ %y, %a ], [ %x, %b ]
  %r = add i32 %x, %q
  ret i32 %r
}

define i32 @loop(i32 %x, i32 %n) {
entry:
  br label %loop

loop:                                             ; preds = %loop, %entry
  %i = phi i32 [ 0, %entry ], [ %next, %loop ]
  %self = phi i32 [ %x, %entry ], [ %self, %loop ]
  %next = add i32 %i, 1
  %done = icmp eq i32 %next, %n
  br i1 %done, label %exit, label %loop

exit:                                             ; preds = %loop
  ret i32 %self
}
