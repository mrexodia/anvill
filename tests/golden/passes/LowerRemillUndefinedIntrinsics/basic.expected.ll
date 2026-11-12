source_filename = "basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare i8 @__remill_undefined_8()

declare i32 @__remill_undefined_32()

declare double @__remill_undefined_f64()

define i32 @f(i32 %x) {
  %z = zext i8 undef to i32
  %r = or i32 %z, undef
  %fpi = fptosi double undef to i32
  %s = add i32 %r, %fpi
  ret i32 %s
}
