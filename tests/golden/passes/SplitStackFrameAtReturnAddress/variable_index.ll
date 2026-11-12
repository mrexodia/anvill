; A GEP with constant and then variable indices into the frame: the new GEP
; must start from the constant part of the offset (slot 1) and be placed
; where the old GEP was, because its variable index (%i) is not available
; in the entry block. Previously the constant part was dropped (the new GEP
; started at slot 0 of the sub-frame) and the GEP was emitted in the entry
; block before %i was defined.
; RUN: --passes=SplitStackFrameAtReturnAddress --stack_offset_metadata=
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_ra = external global i8

%sub_401000__AI_B_0.frame_type = type { [4 x i64] }

define i64 @sub_401000__AI_B_0(i64 %x) {
entry:
  %frame = alloca %sub_401000__AI_B_0.frame_type, align 8
  ; return address in slot 2
  %ra_slot = getelementptr %sub_401000__AI_B_0.frame_type, ptr %frame, i64 0, i32 0, i64 2
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr %ra_slot, align 8
  br label %body

body:
  %i = and i64 %x, 1
  ; slot 0 + %i: a local
  %elem = getelementptr %sub_401000__AI_B_0.frame_type, ptr %frame, i64 0, i32 0, i64 %i
  %v = load i64, ptr %elem, align 8
  ret i64 %v
}
