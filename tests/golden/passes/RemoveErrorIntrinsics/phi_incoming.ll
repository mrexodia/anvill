; PHI nodes lose the incoming values from blocks that now end in
; `unreachable`: a PHI left with one incoming value is replaced by it, with
; several it is rebuilt, and with none its block becomes unreachable too
; (and its value undef), which propagates to the PHIs it feeds.
; RUN: --passes=RemoveErrorIntrinsics
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare ptr @__remill_error(ptr, i64, ptr)

define i32 @f(ptr %state, ptr %mem, i32 %sel) {
entry:
  switch i32 %sel, label %a [ i32 1, label %b
                              i32 2, label %err1
                              i32 3, label %err2 ]

a:
  br label %join

b:
  br label %join

err1:
  %e1 = call ptr @__remill_error(ptr %state, i64 1, ptr %mem)
  br label %join

err2:
  %e2 = call ptr @__remill_error(ptr %state, i64 2, ptr %mem)
  br label %only_errors

join:
  %v = phi i32 [ 1, %a ], [ 2, %b ], [ 3, %err1 ]
  %single = phi i32 [ 10, %a ], [ 30, %err1 ], [ 10, %b ]
  %sum = add i32 %v, %single
  ret i32 %sum

only_errors:
  %dead = phi i32 [ 5, %err2 ]
  ret i32 %dead
}
