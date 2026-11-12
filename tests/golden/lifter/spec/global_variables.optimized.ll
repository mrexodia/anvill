source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@counter = local_unnamed_addr global i32 42
@magic = local_unnamed_addr constant i64 1234605616436508552
