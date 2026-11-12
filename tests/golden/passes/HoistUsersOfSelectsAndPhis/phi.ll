; The same for PHI nodes: the operation is moved into each incoming block
; (before its terminator) and a new PHI merges the results. Operand order is
; preserved.
; RUN: --passes=HoistUsersOfSelectsAndPhis
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @phi_rhs(i1 %c, i32 %a, i32 %b) {
entry:
  br i1 %c, label %l, label %r
l:
  br label %join
r:
  br label %join
join:
  %p = phi i32 [ %a, %l ], [ %b, %r ]
  %x = sub i32 100, %p
  ret i32 %x
}

define i64 @phi_cast(i1 %c, i32 %a, i32 %b) {
entry:
  br i1 %c, label %l, label %r
l:
  br label %join
r:
  br label %join
join:
  %p = phi i32 [ %a, %l ], [ %b, %r ]
  %x = sext i32 %p to i64
  ret i64 %x
}
