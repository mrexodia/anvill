source_filename = "tests/golden/passes/LowerTypeHintIntrinsics/basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare ptr @__anvill_type_hint_Sb(i64)

declare i64 @__anvill_type_hint_L(ptr)

declare ptr @__anvill_type_hint_S(ptr)

define i32 @f(i64 %addr, ptr %p) {
  %1 = inttoptr i64 %addr to ptr, !pc !0
  %v = load i32, ptr %1, align 4
  %2 = ptrtoint ptr %p to i64
  store i64 %2, ptr %p, align 8
  %3 = inttoptr i64 %addr to ptr
  ret i32 %v
}

!0 = !{i64 4096}
