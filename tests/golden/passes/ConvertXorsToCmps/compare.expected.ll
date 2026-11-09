source_filename = "tests/golden/passes/ConvertXorsToCmps/compare.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @only_xor(i32 %a, i32 %b) {
  %1 = icmp sge i32 %a, %b, !pc !0
  %r = select i1 %1, i32 1, i32 2
  ret i32 %r
}

define i32 @two_branches(i32 %a, i32 %b, ptr %p) {
entry:
  %0 = icmp uge i32 %a, %b
  store i1 %0, ptr %p, align 1
  br i1 %0, label %f1, label %t1

t1:                                               ; preds = %entry
  br label %mid

f1:                                               ; preds = %entry
  br label %mid

mid:                                              ; preds = %f1, %t1
  %v = phi i32 [ 1, %t1 ], [ 2, %f1 ]
  br i1 %0, label %f2, label %t2

t2:                                               ; preds = %mid
  ret i32 %v

f2:                                               ; preds = %mid
  ret i32 0
}

define i32 @select_condition(i32 %a, i32 %b) {
  %1 = icmp ne i32 %a, %b
  %s = select i1 %1, i32 %b, i32 %a
  %t = select i1 %1, i32 10, i32 %s
  ret i32 %t
}

!0 = !{i64 4096}
