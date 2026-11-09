source_filename = "lifted_code"
target datalayout = "E-m:e-i64:64-n32:64-S128"
target triple = "sparcv9-pc-linux-gnu-elf"

@__anvill_ra = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @pick], section "llvm.metadata"

; Function Attrs: noinline
define i64 @pick(i64 %0) #0 !pc !0 {
  %2 = icmp eq i64 %0, 0, !pc !0
  br i1 %2, label %sub_401000__ALL_B_0.lifted.exit, label %3, !pc !0

3:                                                ; preds = %1
  br label %sub_401000__ALL_B_0.lifted.exit, !pc !1

sub_401000__ALL_B_0.lifted.exit:                  ; preds = %3, %1
  %4 = phi i64 [ 20, %1 ], [ 10, %3 ]
  %5 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !1
  call void @__anvill_memory_escape(ptr %5)
  ret i64 %4
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }

!0 = !{i64 4198400}
!1 = !{i64 4198412}
