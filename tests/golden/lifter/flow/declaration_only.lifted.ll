source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@llvm.compiler.used = appending global [1 x ptr] [ptr @declared], section "llvm.metadata"

; Function Attrs: noinline
declare !pc !0 i32 @declared(i32) #0

attributes #0 = { noinline }

!0 = !{i64 4198400}
