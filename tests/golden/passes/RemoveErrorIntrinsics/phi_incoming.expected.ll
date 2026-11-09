source_filename = "tests/golden/passes/RemoveErrorIntrinsics/phi_incoming.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare ptr @__remill_error(ptr, i64, ptr)

define i32 @f(ptr %state, ptr %mem, i32 %sel) {
entry:
  switch i32 %sel, label %a [
    i32 1, label %b
    i32 2, label %err1
    i32 3, label %err2
  ]

a:                                                ; preds = %entry
  br label %join

b:                                                ; preds = %entry
  br label %join

err1:                                             ; preds = %entry
  unreachable

err2:                                             ; preds = %entry
  unreachable

join:                                             ; preds = %b, %a
  %0 = phi i32 [ 1, %a ], [ 2, %b ]
  %1 = phi i32 [ 10, %a ], [ 10, %b ]
  %sum = add i32 %0, %1
  ret i32 %sum

only_errors:                                      ; No predecessors!
  ret i32 undef
}
