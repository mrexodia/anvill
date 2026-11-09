; The frame (recovered size + padding) is clamped to --stack_max_size. Here
; the recovered frame is 8 bytes ([sp-8, sp)) and --stack_higher_padding adds
; 16, but the alloca is limited to 16 bytes = 2 words; zero initialization
; stores only those 2 words. (Previously 3 words were stored, the last one
; past the end of the alloca.)
; RUN: --passes=RecoverBasicStackFrame --stack_init=zeroes --stack_max_size=16 --stack_higher_padding=16
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i8

define i64 @sub_401000__AI_B_0(i64 %x) {
  store i64 %x, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8) to ptr)
  %l = load i64, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8) to ptr)
  ret i64 %l
}
