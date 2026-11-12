; Every use of a constant expression derived from `__anvill_sp` becomes a
; GEP into a new frame alloca (`%<function>.frame_type` = { [N x iW] },
; W = word size). The frame spans the lowest to the highest accessed offset
; (here -12 .. +12, rounded up to words). With --stack_offset_metadata, the
; alloca carries `__anvill_stack_zero` = the frame index of offset 0.
; Initialization (--stack_init=undef):
;   symbolic: each word is loaded from @__anvill_stack_{minus,plus}_<off>
;   zeroes / undef: one store of zeroinitializer / undef
;   none: nothing
; RUN: --passes=RecoverBasicStackFrame --stack_init=undef
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i8
@__anvill_ra = external global i8

; RA at [sp+0], a local at [sp-12], a stack argument at [sp+8].
define i32 @sub_401000__AI_B_0(i32 %x) {
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr inttoptr (i64 ptrtoint (ptr @__anvill_sp to i64) to ptr), !pc !0
  store i32 %x, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -12) to ptr)
  %arg = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 8) to ptr)
  %l = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -12) to ptr)
  %addr = add i64 ptrtoint (ptr @__anvill_sp to i64), -4
  %r = add i32 %l, %arg
  ret i32 %r
}

!0 = !{i64 4198400}
