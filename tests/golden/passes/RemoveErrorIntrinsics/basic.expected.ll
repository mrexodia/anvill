source_filename = "tests/golden/passes/RemoveErrorIntrinsics/basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare ptr @__remill_error(ptr, i64, ptr)

define i32 @f(ptr %state, ptr %mem, i1 %c) {
entry:
  br i1 %c, label %bad, label %good

bad:                                              ; preds = %entry
  %x = add i32 1, 2
  unreachable, !pc !0

good:                                             ; preds = %entry
  ret i32 0
}

!0 = !{i64 4096}
