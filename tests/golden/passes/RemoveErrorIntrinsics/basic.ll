; A call to __remill_error and everything after it in its block is replaced by
; `unreachable` (the call's metadata moves to the `unreachable`). Values
; defined in the removed tail are replaced by undef.
; RUN: --passes=RemoveErrorIntrinsics
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare ptr @__remill_error(ptr, i64, ptr)

define i32 @f(ptr %state, ptr %mem, i1 %c) {
entry:
  br i1 %c, label %bad, label %good

bad:
  %x = add i32 1, 2
  %m = call ptr @__remill_error(ptr %state, i64 4096, ptr %mem), !pc !0
  %after = add i32 %x, 3
  ret i32 %after

good:
  ret i32 0
}

!0 = !{i64 4096}
