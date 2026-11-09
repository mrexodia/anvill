source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@numbers = constant [4 x i32] [i32 1, i32 2, i32 3, i32 4]
@table = global <{ ptr, ptr, ptr, ptr, ptr }> <{ ptr @handler, ptr @numbers, ptr getelementptr (i8, ptr @numbers, i32 8), ptr inttoptr (i64 4210712 to ptr), ptr inttoptr (i64 3735928559 to ptr) }>
@llvm.compiler.used = appending global [3 x ptr] [ptr @handler, ptr @numbers, ptr @table], section "llvm.metadata"

; Function Attrs: noinline
declare !pc !0 void @handler() #0

attributes #0 = { noinline }

!0 = !{i64 4198400}
