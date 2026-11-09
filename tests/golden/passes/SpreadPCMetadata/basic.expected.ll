source_filename = "basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @f(i32 %a, i32 %b) {
entry:
  %x = add i32 %a, 1, !pc !0
  %y = mul i32 %x, %b, !pc !0
  %z = sub i32 %y, 3, !pc !1
  %w = xor i32 %z, %a, !pc !1
  %tail = add i32 %w, 1, !pc !1
  br label %next, !pc !1

next:                                             ; preds = %entry
  %n = add i32 %tail, %x
  ret i32 %n
}

!0 = !{i64 4096}
!1 = !{i64 4100}
