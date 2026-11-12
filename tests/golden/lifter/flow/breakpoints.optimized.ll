source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_ra = external global i64
@__anvill_pc = external global i64
@__anvill_stack_0 = external local_unnamed_addr global i64

; Function Attrs: noinline
define i32 @inc(i32 %0) local_unnamed_addr #0 !pc !0 {
  %2 = call ptr @breakpoint_401000(ptr null, i64 ptrtoint (ptr @inc to i64), i64 ptrtoint (ptr @inc to i64)) #3, !pc !0
  %3 = add i32 %0, 1, !pc !1
  %4 = call ptr @breakpoint_401003(ptr null, i64 ptrtoint (ptr @inc to i64), i64 4198403) #3, !pc !1
  ret i32 %3, !pc !1
}

; Function Attrs: noinline optnone memory(none)
declare ptr @breakpoint_401000(ptr, i64, i64) local_unnamed_addr #1

; Function Attrs: noinline optnone memory(none)
declare ptr @breakpoint_401003(ptr, i64, i64) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) local_unnamed_addr #2

attributes #0 = { noinline }
attributes #1 = { noinline optnone memory(none) }
attributes #2 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #3 = { nounwind }

!0 = !{i64 4198400}
!1 = !{i64 4198403}
