source_filename = "tests/golden/passes/HoistUsersOfSelectsAndPhis/phi.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @phi_rhs(i1 %c, i32 %a, i32 %b) {
entry:
  br i1 %c, label %l, label %r

l:                                                ; preds = %entry
  %0 = sub i32 100, %a
  br label %join

r:                                                ; preds = %entry
  %1 = sub i32 100, %b
  br label %join

join:                                             ; preds = %r, %l
  %2 = phi i32 [ %0, %l ], [ %1, %r ]
  ret i32 %2
}

define i64 @phi_cast(i1 %c, i32 %a, i32 %b) {
entry:
  br i1 %c, label %l, label %r

l:                                                ; preds = %entry
  %0 = sext i32 %a to i64
  br label %join

r:                                                ; preds = %entry
  %1 = sext i32 %b to i64
  br label %join

join:                                             ; preds = %r, %l
  %2 = phi i64 [ %0, %l ], [ %1, %r ]
  ret i64 %2
}
