source_filename = "no_stack_uses.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @sub_401000__AI_B_0(i32 %x) {
  ret i32 %x
}
