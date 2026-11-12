source_filename = "select.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @select_lhs(i1 %c, i32 %a, i32 %b) {
  %1 = sub i32 %a, 100
  %2 = sub i32 %b, 100
  %3 = select i1 %c, i32 %1, i32 %2
  ret i32 %3
}

define i32 @select_rhs(i1 %c, i32 %a, i32 %b) {
  %1 = sub i32 100, %a
  %2 = sub i32 100, %b
  %3 = select i1 %c, i32 %1, i32 %2
  ret i32 %3
}

define i32 @not_constant(i1 %c, i32 %a, i32 %b, i32 %k) {
  %s = select i1 %c, i32 %a, i32 %b
  %r = sub i32 %s, %k
  ret i32 %r
}

define i64 @cast(i1 %c, i32 %a, i32 %b) {
  %1 = zext i32 %a to i64
  %2 = zext i32 %b to i64
  %3 = select i1 %c, i64 %1, i64 %2
  ret i64 %3
}

define ptr @gep_index(i1 %c, ptr %p) {
  %1 = getelementptr inbounds [4 x i32], ptr %p, i64 0, i64 1
  %2 = getelementptr inbounds [4 x i32], ptr %p, i64 0, i64 3
  %3 = select i1 %c, ptr %1, ptr %2
  ret ptr %3
}

define ptr @gep_base(i1 %c, ptr %p, ptr %q) {
  %1 = getelementptr inbounds i32, ptr %p, i64 2
  %2 = getelementptr inbounds i32, ptr %q, i64 2
  %3 = select i1 %c, ptr %1, ptr %2
  ret ptr %3
}
