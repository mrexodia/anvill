source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_reg_RAX = external local_unnamed_addr global i64
@__anvill_pc = external global i64
@__anvill_stack_minus_16 = external local_unnamed_addr global i64
@__anvill_stack_minus_8 = external local_unnamed_addr global i64
@__anvill_stack_0 = external local_unnamed_addr global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @die], section "llvm.metadata"

; Function Attrs: noinline
define i32 @calls_die() local_unnamed_addr #0 !pc !0 {
  call void @die() #2, !pc !1
  unreachable, !pc !1
}

; Function Attrs: noinline noreturn
declare !pc !2 void @die() #1

attributes #0 = { noinline }
attributes #1 = { noinline noreturn }
attributes #2 = { noreturn nounwind }

!0 = !{i64 4198400}
!1 = !{i64 4198401}
!2 = !{i64 4202496}
