; Values that resolve to the address of a lifted entity (here, globals named
; sub_/var_/data_<hex>, see anvill-opt) through @__anvill_pc-relative
; arithmetic are replaced by references to the entity; the entity gets the
; `pc` metadata of its address. Addresses that are not entities stay as
; they are; stack-pointer and return-address values are never converted.
; NOTE: anvill-opt's resolver only knows exact entity addresses, so the
; interior address below is not converted here; the lifter's resolver maps
; interior addresses to GEPs into the containing variable.
; RUN: --passes=ConvertAddressesToEntityUses
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_pc = external global i8
@__anvill_sp = external global i8
@var_404000_I = global i32 7
@var_404010_L = global i64 0
declare i32 @sub_402000__AII_B_0(i32)

define i32 @f(i32 %x) {
  ; Load of a global through its PC-relative address.
  %v = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4210688) to ptr)
  ; Interior address of a global (offset 4 into var_404010_L).
  %p = inttoptr i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4210708) to ptr
  store i32 %x, ptr %p
  ; A function address used as an integer.
  %fp = add i64 ptrtoint (ptr @__anvill_pc to i64), 4202496
  %fptr = inttoptr i64 %fp to ptr
  %r = call i32 %fptr(i32 %v)
  ; Not an entity, and a stack address.
  %unknown = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4227072) to ptr)
  %stack = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8) to ptr)
  %s0 = add i32 %r, %unknown
  %s = add i32 %s0, %stack
  ret i32 %s
}
