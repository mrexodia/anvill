source_filename = "after_recovery.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

%sub_401000__AI_B_0.frame_type = type { [4 x i64] }

@__anvill_sp = external global i8
@__anvill_ra = external global i8

define i32 @sub_401000__AI_B_0(i32 %x) {
  %locals = alloca i64, i64 2, align 8, !stack_offset !0
  %1 = getelementptr i64, ptr %locals, i32 1, !stack_offset !1
  %2 = getelementptr i32, ptr %locals, i32 1, !stack_offset !0
  %parameters = alloca i64, i64 1, align 8, !stack_offset !2
  %return_address_loc = alloca i64, i64 1, align 8, !stack_offset !3
  %3 = ptrtoint ptr %return_address_loc to i64, !stack_offset !3
  %4 = ptrtoint ptr %return_address_loc to i64, !stack_offset !3
  %5 = alloca %sub_401000__AI_B_0.frame_type, align 8, !stack_offset !4
  store i64 0, ptr %locals, align 8
  store i64 0, ptr %1, align 8
  store i64 0, ptr %return_address_loc, align 8
  store i64 0, ptr %parameters, align 8
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr %return_address_loc, align 8, !pc !5
  store i32 %x, ptr %2, align 4
  %arg = load i32, ptr %parameters, align 4
  %l = load i32, ptr %2, align 4
  %addr = add i64 %4, -4
  %r = add i32 %l, %arg
  ret i32 %r
}

!0 = !{i64 12}
!1 = !{i64 8}
!2 = !{i64 -8}
!3 = !{i64 0}
!4 = !{i64 16}
!5 = !{i64 4198400}
