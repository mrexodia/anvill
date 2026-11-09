source_filename = "variable_index.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

%sub_401000__AI_B_0.frame_type = type { [4 x i64] }

@__anvill_ra = external global i8

define i64 @sub_401000__AI_B_0(i64 %x) {
entry:
  %locals = alloca i64, i64 2, align 8
  %return_address_loc = alloca i64, i64 1, align 8
  %frame = alloca %sub_401000__AI_B_0.frame_type, align 8
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr %return_address_loc, align 8
  br label %body

body:                                             ; preds = %entry
  %i = and i64 %x, 1
  %0 = getelementptr [4 x i64], ptr %locals, i64 0, i64 %i
  %v = load i64, ptr %0, align 8
  ret i64 %v
}
