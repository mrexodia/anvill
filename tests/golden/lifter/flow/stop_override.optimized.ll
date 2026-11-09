source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

; Function Attrs: noinline
define i32 @stops() local_unnamed_addr #0 !pc !0 {
  unreachable, !pc !1
}

attributes #0 = { noinline }

!0 = !{i64 4198400}
!1 = !{i64 4198405}
