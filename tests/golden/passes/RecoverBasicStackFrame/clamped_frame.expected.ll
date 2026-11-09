source_filename = "clamped_frame.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

%sub_401000__AI_B_0.frame_type = type { [2 x i64] }

@__anvill_sp = external global i8

define i64 @sub_401000__AI_B_0(i64 %x) {
  %1 = alloca %sub_401000__AI_B_0.frame_type, align 8, !__anvill_stack_zero !0
  %2 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  store i64 0, ptr %2, align 8
  %3 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 1
  store i64 0, ptr %3, align 8
  %4 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  %5 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  store i64 %x, ptr %4, align 8
  %l = load i64, ptr %5, align 8
  ret i64 %l
}

!0 = !{i64 8}
