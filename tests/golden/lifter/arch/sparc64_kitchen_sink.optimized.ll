source_filename = "lifted_code"
target datalayout = "E-m:e-i64:64-n32:64-S128"
target triple = "sparcv9-pc-linux-gnu-elf"

%0 = type { i64, i64 }

@__anvill_ra = external global i64
@counter = local_unnamed_addr global i32 5
@__anvill_stack_plus_2216 = external local_unnamed_addr global i64
@__anvill_stack_plus_2224 = external local_unnamed_addr global i64

; Function Attrs: noinline
define i64 @max(i64 %0, i64 %1) local_unnamed_addr #0 !pc !0 {
sub_401000__ALLL_B_0.lifted.exit:
  %2 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %0, i64 %1), !pc !0
  %3 = extractvalue { i64, i1 } %2, 1, !pc !0
  %4 = sub i64 %0, %1, !pc !0
  %5 = icmp sgt i64 %4, -1, !pc !0
  %6 = xor i1 %5, %3, !pc !0
  %spec.select = select i1 %6, i64 %0, i64 %1, !pc !0
  ret i64 %spec.select, !pc !0
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.ssub.with.overflow.i64(i64, i64) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) local_unnamed_addr #2

; Function Attrs: noinline
define i32 @bump(i32 %0) local_unnamed_addr #0 !pc !1 {
  %2 = load i32, ptr inttoptr (i64 4210688 to ptr), align 4, !pc !2
  %3 = add i32 %2, %0, !pc !3
  store i32 %3, ptr inttoptr (i64 4210688 to ptr), align 4, !pc !3
  ret i32 %3, !pc !3
}

; Function Attrs: noinline
define i64 @seventh(i64 %0, i64 %1, i64 %2, i64 %3, i64 %4, i64 %5, i64 %6) local_unnamed_addr #0 !pc !4 {
  %8 = add i64 %6, %0, !pc !5
  ret i64 %8, !pc !5
}

; Function Attrs: noinline
define double @twice(double %0) local_unnamed_addr #0 !pc !6 {
  %2 = fadd double %0, %0, !pc !6
  ret double %2, !pc !6
}

; Function Attrs: noinline
define %0 @swap(i64 %0, i64 %1) local_unnamed_addr #0 !pc !7 {
  %3 = insertvalue %0 undef, i64 %1, 0
  %4 = insertvalue %0 %3, i64 %0, 1
  ret %0 %4
}

; Function Attrs: noinline
define i64 @use_swap(i64 %0, i64 %1) local_unnamed_addr #0 !pc !8 {
sleigh_remill_instruction_function_401050.exit:
  %2 = call %0 @swap(i64 %0, i64 %1) #3, !pc !9
  %3 = extractvalue %0 %2, 1, !pc !9
  %4 = extractvalue %0 %2, 0, !pc !9
  %5 = add i64 %3, %4, !pc !10
  ret i64 %5, !pc !10
}

attributes #0 = { noinline }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #3 = { nounwind }

!0 = !{i64 4198400}
!1 = !{i64 4198424}
!2 = !{i64 4198428}
!3 = !{i64 4198436}
!4 = !{i64 4198444}
!5 = !{i64 4198448}
!6 = !{i64 4198456}
!7 = !{i64 4198464}
!8 = !{i64 4198480}
!9 = !{i64 4198488}
!10 = !{i64 4198496}
