source_filename = "shared_target.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare i64 @__anvill_complete_switch(i64, ...)

define i32 @sub_401000__AII_B_0(i32 %x) {
entry:
  %oob = icmp ugt i32 %x, 3
  br i1 %oob, label %default, label %dispatch

dispatch:                                         ; preds = %entry
  %idx = zext i32 %x to i64
  %off = shl nuw nsw i64 %idx, 2
  %addr = add i64 %off, 4198456
  %p = inttoptr i64 %addr to ptr
  %entry_val = load i32, ptr %p, align 4
  %rel = sext i32 %entry_val to i64
  %target = add i64 %rel, 4198456
  switch i32 %x, label %default [
    i32 0, label %case0
    i32 1, label %case1
    i32 2, label %case1
    i32 3, label %case3
  ]

unreachable:                                      ; No predecessors!
  unreachable

case0:                                            ; preds = %dispatch
  br label %exit

case1:                                            ; preds = %dispatch, %dispatch
  br label %exit

case2:                                            ; No predecessors!
  br label %exit

case3:                                            ; preds = %dispatch
  br label %exit

default:                                          ; preds = %dispatch, %entry
  br label %exit

exit:                                             ; preds = %default, %case3, %case2, %case1, %case0
  %r = phi i32 [ 100, %case0 ], [ 200, %case1 ], [ poison, %case2 ], [ 400, %case3 ], [ -1, %default ]
  ret i32 %r
}

!anvill.memory = !{!0}

!0 = !{i64 4198456, !"dfffffffe5ffffffe5fffffff1ffffff", !"r"}
