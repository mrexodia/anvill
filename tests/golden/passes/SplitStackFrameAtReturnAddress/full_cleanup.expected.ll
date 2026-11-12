source_filename = "full_cleanup.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i8
@__anvill_ra = external global i8
@__anvill_stack_minus_16 = external global i64
@__anvill_stack_minus_8 = external global i64
@__anvill_stack_0 = external global i64
@__anvill_stack_plus_8 = external global i64

define i32 @sub_401000__AI_B_0(i32 %x) {
  %locals1 = alloca [2 x i64], align 8
  %1 = getelementptr inbounds i8, ptr %locals1, i64 8
  %2 = getelementptr inbounds i8, ptr %locals1, i64 4
  %3 = load i64, ptr @__anvill_stack_minus_16, align 8
  store i64 %3, ptr %locals1, align 8
  %4 = load i64, ptr @__anvill_stack_minus_8, align 8
  store i64 %4, ptr %1, align 8
  %5 = load i64, ptr @__anvill_stack_plus_8, align 8
  %parameters.sroa.0.0.extract.trunc = trunc i64 %5 to i32
  store i32 %x, ptr %2, align 4
  %r = add i32 %parameters.sroa.0.0.extract.trunc, %x
  ret i32 %r
}
