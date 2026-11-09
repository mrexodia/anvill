; A binary operator with a constant other operand, a cast, or a GEP that uses
; a select is pushed into both arms of the select:
;   (op (select c, a, b), K) -> (select c, (op a, K), (op b, K))
; The operand order is preserved: (sub K, select) becomes
; (select c, (sub K, a), (sub K, b)). Previously the select was always put
; on the left, turning `sub 100, x` into `sub x, 100`.
; (Not scheduled by OptimizeModule.)
; RUN: --passes=HoistUsersOfSelectsAndPhis
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @select_lhs(i1 %c, i32 %a, i32 %b) {
  %s = select i1 %c, i32 %a, i32 %b
  %r = sub i32 %s, 100
  ret i32 %r
}

define i32 @select_rhs(i1 %c, i32 %a, i32 %b) {
  %s = select i1 %c, i32 %a, i32 %b
  %r = sub i32 100, %s
  ret i32 %r
}

define i32 @not_constant(i1 %c, i32 %a, i32 %b, i32 %k) {
  %s = select i1 %c, i32 %a, i32 %b
  %r = sub i32 %s, %k
  ret i32 %r
}

define i64 @cast(i1 %c, i32 %a, i32 %b) {
  %s = select i1 %c, i32 %a, i32 %b
  %r = zext i32 %s to i64
  ret i64 %r
}

define ptr @gep_index(i1 %c, ptr %p) {
  %s = select i1 %c, i64 1, i64 3
  %g = getelementptr inbounds [4 x i32], ptr %p, i64 0, i64 %s
  ret ptr %g
}

define ptr @gep_base(i1 %c, ptr %p, ptr %q) {
  %s = select i1 %c, ptr %p, ptr %q
  %g = getelementptr inbounds i32, ptr %s, i64 2
  ret ptr %g
}
