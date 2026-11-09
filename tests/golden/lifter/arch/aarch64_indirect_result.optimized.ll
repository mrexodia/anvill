source_filename = "lifted_code"
target datalayout = "e-m:e-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128"
target triple = "aarch64-pc-linux-gnu-elf"

@__anvill_ra = external global i64

; Function Attrs: noinline
define void @make(ptr %0, i64 %1, i64 %2) local_unnamed_addr #0 !pc !0 {
  %4 = ptrtoint ptr %0 to i64, !pc !0
  store i64 %1, ptr %0, align 8, !pc !0
  %5 = add i64 %4, 8, !pc !0
  %6 = inttoptr i64 %5 to ptr, !pc !0
  store i64 %2, ptr %6, align 8, !pc !0
  %7 = add i64 %4, 16, !pc !1
  %8 = inttoptr i64 %7 to ptr, !pc !1
  store i64 %1, ptr %8, align 8, !pc !1
  ret void, !pc !1
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) local_unnamed_addr #1

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="non-leaf" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }

!0 = !{i64 4198400}
!1 = !{i64 4198404}
