; A select whose condition is also the condition of a branch: uses of the
; select dominated by the taken edge use the true value, uses dominated by the
; not-taken edge use the false value. The select is erased once unused.
; RUN: --passes=SinkSelectionsIntoBranchTargets
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @f(i1 %c, i32 %a, i32 %b) {
entry:
  %s = select i1 %c, i32 %a, i32 %b, !pc !0
  br i1 %c, label %taken, label %not_taken
taken:
  %t = add i32 %s, 1
  ret i32 %t
not_taken:
  %n = mul i32 %s, 2
  ret i32 %n
}

!0 = !{i64 4096}
