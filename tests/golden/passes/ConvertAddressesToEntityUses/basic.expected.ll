source_filename = "basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_pc = external global i8
@__anvill_sp = external global i8
@var_404000_I = global i32 7, !pc !0
@var_404010_L = global i64 0

declare !pc !1 i32 @sub_402000__AII_B_0(i32)

define i32 @f(i32 %x) {
  %v = load i32, ptr @var_404000_I, align 4
  %p = inttoptr i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4210708) to ptr
  store i32 %x, ptr %p, align 4
  %r = call i32 @sub_402000__AII_B_0(i32 %v)
  %unknown = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4227072) to ptr), align 4
  %stack = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8) to ptr), align 4
  %s0 = add i32 %r, %unknown
  %s = add i32 %s0, %stack
  ret i32 %s
}

!0 = !{i64 4210688}
!1 = !{i64 4202496}
