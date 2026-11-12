; Edge cases of ConvertAddressesToEntityUses:
;  - @phi: an address flowing into a PHI is replaced in the incoming block
;    (the adaptation is inserted before the predecessor's terminator).
;  - @instructions: an address computed by instructions (not a constant
;    expression) is replaced at its use. Replaced values that become unused
;    are erased, but not their operands: `%base` is left behind, dead.
;  - @as_integer: an address used as an integer becomes `ptrtoint @entity`.
;  - @global_relative: an address computed from another global (not
;    __anvill_pc) that lands on an entity is replaced too.
;  - @absolute: a plain integer constant is not "related to the program
;    counter", so it is left alone even though it equals an entity address.
;  - @decl: declarations are skipped.
;  - --pc_metadata= (empty) disables the `pc` annotations on entities.
; RUN: --passes=ConvertAddressesToEntityUses --pc_metadata=
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_pc = external global i8
@var_404000_I = global i32 7
@var_404010_L = global i64 0

define i32 @phi(i1 %c) {
entry:
  br i1 %c, label %a, label %b
a:
  br label %join
b:
  br label %join
join:
  %p = phi ptr [ inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4210688) to ptr), %a ], [ null, %b ]
  %v = load i32, ptr %p
  ret i32 %v
}

define i32 @instructions() {
  %base = ptrtoint ptr @__anvill_pc to i64
  %addr = add i64 %base, 4210688
  %p = inttoptr i64 %addr to ptr
  %v = load i32, ptr %p
  ret i32 %v
}

define i64 @as_integer() {
  ret i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4210704)
}

define i64 @global_relative() {
  %v = load i64, ptr getelementptr (i8, ptr @var_404000_I, i64 16)
  ret i64 %v
}

define i32 @absolute() {
  %v = load i32, ptr inttoptr (i64 4210688 to ptr)
  ret i32 %v
}

declare i32 @decl(ptr)
