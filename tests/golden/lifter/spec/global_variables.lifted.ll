source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@counter = global i32 42
@magic = constant i64 1234605616436508552
@llvm.compiler.used = appending global [2 x ptr] [ptr @counter, ptr @magic], section "llvm.metadata"
