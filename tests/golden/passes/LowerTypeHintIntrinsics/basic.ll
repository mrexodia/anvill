; Calls to __anvill_type_hint* functions are replaced by a bit/pointer cast of
; their (pointer-cast-stripped) argument to the call's type.
; RUN: --passes=LowerTypeHintIntrinsics
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare ptr @__anvill_type_hint_Sb(i64)
declare i64 @__anvill_type_hint_L(ptr)
declare ptr @__anvill_type_hint_S(ptr)

define i32 @f(i64 %addr, ptr %p) {
  %hinted = call ptr @__anvill_type_hint_Sb(i64 %addr), !pc !0
  %v = load i32, ptr %hinted
  %as_int = call i64 @__anvill_type_hint_L(ptr %p)
  %same = call ptr @__anvill_type_hint_S(ptr %p)
  store i64 %as_int, ptr %same
  %unused = call ptr @__anvill_type_hint_Sb(i64 %addr)
  ret i32 %v
}

!0 = !{i64 4096}
