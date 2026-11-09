source_filename = "lifted_code"
target datalayout = "E-m:e-i64:64-n32:64-S128"
target triple = "sparcv9-pc-linux-gnu-elf"

@__anvill_ra = external global i64

; Function Attrs: noinline
define i64 @pick(i64 %0) local_unnamed_addr #0 !pc !0 {
sub_401000__ALL_B_0.lifted.exit:
  %1 = icmp eq i64 %0, 0, !pc !0
  %spec.select = select i1 %1, i64 20, i64 10, !pc !0
  ret i64 %spec.select, !pc !0
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) local_unnamed_addr #1

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }

!0 = !{i64 4198400}
