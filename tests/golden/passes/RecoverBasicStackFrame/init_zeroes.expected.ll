source_filename = "init_zeroes.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

%sub_401000__AI_B_0.frame_type = type { [4 x i64] }

@__anvill_sp = external global i8
@__anvill_ra = external global i8

define i32 @sub_401000__AI_B_0(i32 %x) {
  %1 = alloca %sub_401000__AI_B_0.frame_type, align 8, !__anvill_stack_zero !0
  %2 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  store i64 0, ptr %2, align 8
  %3 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 1
  store i64 0, ptr %3, align 8
  %4 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 2
  store i64 0, ptr %4, align 8
  %5 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 3
  store i64 0, ptr %5, align 8
  %6 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 2
  %7 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  %8 = getelementptr i32, ptr %7, i32 1
  %9 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 3
  %10 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  %11 = getelementptr i32, ptr %10, i32 1
  %12 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 2
  %13 = ptrtoint ptr %12 to i64
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr %6, align 8, !pc !1
  store i32 %x, ptr %8, align 4
  %arg = load i32, ptr %9, align 4
  %l = load i32, ptr %11, align 4
  %addr = add i64 %13, -4
  %r = add i32 %l, %arg
  ret i32 %r
}

!0 = !{i64 16}
!1 = !{i64 4198400}
