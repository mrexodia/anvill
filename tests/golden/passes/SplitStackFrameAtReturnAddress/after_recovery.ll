; After RecoverBasicStackFrame, the frame is split at the slot that holds the
; return address into three allocas: the callee's locals (lower addresses),
; `return_address_loc`, and the caller's stack `parameters` (higher
; addresses). Uses are rewritten to point into the matching part and get
; `stack_offset` metadata (the displacement from the stack pointer at
; function entry). Previously the locals/parameters names were swapped.
; RUN: --passes=RecoverBasicStackFrame,SplitStackFrameAtReturnAddress --stack_init=zeroes
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
