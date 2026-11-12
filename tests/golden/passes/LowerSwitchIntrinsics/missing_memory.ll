; Without the table bytes in memory the switch cannot be built and the
; dispatch is left unchanged.
; RUN: --passes=LowerSwitchIntrinsics
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare i64 @__anvill_complete_switch(i64, ...)

define i32 @sub_401000__AII_B_0(i32 %x) {
entry:
  %oob = icmp ugt i32 %x, 3
  br i1 %oob, label %default, label %dispatch

dispatch:
  %idx = zext i32 %x to i64
  %off = shl nuw nsw i64 %idx, 2
  %addr = add i64 %off, 4198456
  %p = inttoptr i64 %addr to ptr
  %entry_val = load i32, ptr %p, align 4
  %rel = sext i32 %entry_val to i64
  %target = add i64 %rel, 4198456
  %sel = call i64 (i64, ...) @__anvill_complete_switch(i64 %target, i64 4198423, i64 4198429, i64 4198435, i64 4198441), !pc !0
  switch i64 %sel, label %unreachable [ i64 0, label %case0
                                        i64 1, label %case1
                                        i64 2, label %case2
                                        i64 3, label %case3 ], !pc !0

unreachable:
  unreachable

case0:
  ret i32 100
case1:
  ret i32 200
case2:
  ret i32 300
case3:
  ret i32 400
default:
  ret i32 -1
}

!0 = !{i64 4198421}
