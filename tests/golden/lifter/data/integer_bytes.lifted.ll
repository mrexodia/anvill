source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@u16_8001 = global i16 -32767
@u32_018000ff = global i32 25166079
@i64_minus_2 = global i64 -2
@u8_200 = global i8 -56
@u16_array = global [3 x i16] [i16 -1, i16 -32768, i16 4660]
@llvm.compiler.used = appending global [5 x ptr] [ptr @u16_8001, ptr @u32_018000ff, ptr @i64_minus_2, ptr @u8_200, ptr @u16_array], section "llvm.metadata"
