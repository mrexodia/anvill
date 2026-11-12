source_filename = "absent.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @f(i32 %x) {
  ret i32 %x
}
