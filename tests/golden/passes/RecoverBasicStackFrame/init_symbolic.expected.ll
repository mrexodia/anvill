source_filename = "init_symbolic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

%sub_401000__AI_B_0.frame_type = type { [4 x i64] }

@__anvill_sp = external global i8
@__anvill_ra = external global i8
@__anvill_stack_minus_16 = external global i64
@__anvill_stack_minus_8 = external global i64
@__anvill_stack_0 = external global i64
@__anvill_stack_plus_8 = external global i64

define i32 @sub_401000__AI_B_0(i32 %x) {
  %1 = alloca %sub_401000__AI_B_0.frame_type, align 8, !__anvill_stack_zero !0
  %2 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  %3 = load i64, ptr @__anvill_stack_minus_16, align 8
  store i64 %3, ptr %2, align 8
  %4 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 1
  %5 = load i64, ptr @__anvill_stack_minus_8, align 8
  store i64 %5, ptr %4, align 8
  %6 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 2
  %7 = load i64, ptr @__anvill_stack_0, align 8
  store i64 %7, ptr %6, align 8
  %8 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 3
  %9 = load i64, ptr @__anvill_stack_plus_8, align 8
  store i64 %9, ptr %8, align 8
  %10 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 2
  %11 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  %12 = getelementptr i32, ptr %11, i32 1
  %13 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 3
  %14 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  %15 = getelementptr i32, ptr %14, i32 1
  %16 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 2
  %17 = ptrtoint ptr %16 to i64
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr %10, align 8, !pc !1
  store i32 %x, ptr %12, align 4
  %arg = load i32, ptr %13, align 4
  %l = load i32, ptr %15, align 4
  %addr = add i64 %17, -4
  %r = add i32 %l, %arg
  ret i32 %r
}

!0 = !{i64 16}
!1 = !{i64 4198400}
