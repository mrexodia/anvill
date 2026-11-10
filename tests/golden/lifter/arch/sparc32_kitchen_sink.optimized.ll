source_filename = "lifted_code"
target datalayout = "E-m:e-p:32:32-i64:64-f128:64-n32-S64"
target triple = "sparc-pc-linux-gnu-elf"

@__anvill_ra = external global i32
@counter = local_unnamed_addr global i32 5
@__anvill_stack_plus_92 = external local_unnamed_addr global i32
@__anvill_stack_plus_72 = external local_unnamed_addr global i32
@__anvill_stack_plus_76 = external local_unnamed_addr global i32
@__anvill_stack_plus_64 = external local_unnamed_addr global i32
@__anvill_stack_minus_48 = external local_unnamed_addr global i32
@__anvill_stack_minus_44 = external local_unnamed_addr global i32
@__anvill_stack_minus_40 = external local_unnamed_addr global i32
@__anvill_stack_minus_36 = external local_unnamed_addr global i32
@__anvill_stack_minus_32 = external local_unnamed_addr global i32
@__anvill_stack_minus_28 = external local_unnamed_addr global i32
@__anvill_stack_minus_24 = external local_unnamed_addr global i32
@__anvill_stack_minus_20 = external local_unnamed_addr global i32
@__anvill_stack_minus_16 = external local_unnamed_addr global i32
@__anvill_stack_minus_12 = external local_unnamed_addr global i32
@__anvill_stack_minus_8 = external local_unnamed_addr global i32
@__anvill_stack_minus_4 = external local_unnamed_addr global i32

; Function Attrs: noinline
define i32 @max(i32 %0, i32 %1) local_unnamed_addr #0 !pc !0 {
sub_401000__AIII_B_0.lifted.exit:
  %2 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %0, i32 %1), !pc !0
  %3 = extractvalue { i32, i1 } %2, 1, !pc !0
  %4 = sub i32 %0, %1, !pc !0
  %5 = icmp sgt i32 %4, -1, !pc !0
  %6 = xor i1 %5, %3, !pc !0
  %spec.select = select i1 %6, i32 %0, i32 %1, !pc !0
  ret i32 %spec.select, !pc !0
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) local_unnamed_addr #2

; Function Attrs: noinline
define i32 @bump(i32 %0) local_unnamed_addr #0 !pc !1 {
  %2 = load i32, ptr inttoptr (i32 4210688 to ptr), align 4, !pc !2
  %3 = add i32 %2, %0, !pc !3
  store i32 %3, ptr inttoptr (i32 4210688 to ptr), align 4, !pc !4
  ret i32 %3, !pc !4
}

; Function Attrs: noinline
define i32 @seventh(i32 %0, i32 %1, i32 %2, i32 %3, i32 %4, i32 %5, i32 %6) local_unnamed_addr #0 !pc !5 {
  %8 = add i32 %6, %0, !pc !6
  ret i32 %8, !pc !6
}

; Function Attrs: noinline
define double @twice(i32 %0, i32 %1) local_unnamed_addr #0 !pc !7 {
  %3 = zext i32 %1 to i64, !pc !8
  %4 = zext i32 %0 to i64, !pc !8
  %5 = shl nuw i64 %4, 32, !pc !8
  %6 = or disjoint i64 %5, %3, !pc !8
  %.cast = bitcast i64 %6 to double, !pc !8
  %7 = fadd double %.cast, %.cast, !pc !8
  ret double %7, !pc !8
}

; Function Attrs: noinline
define ptr @make_pair(ptr %0, i32 %1, i32 %2) local_unnamed_addr #0 !pc !9 {
  %4 = ptrtoint ptr %0 to i32, !pc !9
  store i32 %1, ptr %0, align 4, !pc !10
  %5 = add i32 %4, 4, !pc !11
  %6 = inttoptr i32 %5 to ptr, !pc !11
  store i32 %2, ptr %6, align 4, !pc !11
  ret ptr %0, !pc !11
}

; Function Attrs: noinline
define i32 @use_pair(i32 %0, i32 %1) local_unnamed_addr #0 !pc !12 {
sleigh_remill_instruction_function_40105c.exit:
  %parameters1 = alloca [12 x i32], align 4, !pc !13
  %2 = getelementptr inbounds i8, ptr %parameters1, i32 3, !pc !13
  %3 = getelementptr inbounds i8, ptr %parameters1, i32 7, !pc !13
  %4 = getelementptr inbounds i8, ptr %parameters1, i32 11, !pc !13
  %5 = getelementptr inbounds i8, ptr %parameters1, i32 15, !pc !13
  %6 = getelementptr inbounds i8, ptr %parameters1, i32 19, !pc !13
  %7 = getelementptr inbounds i8, ptr %parameters1, i32 23, !pc !13
  %8 = getelementptr inbounds i8, ptr %parameters1, i32 27, !pc !13
  %9 = getelementptr inbounds i8, ptr %parameters1, i32 31, !pc !13
  %10 = getelementptr inbounds i8, ptr %parameters1, i32 35, !pc !13
  %11 = getelementptr inbounds i8, ptr %parameters1, i32 39, !pc !13
  %12 = getelementptr inbounds i8, ptr %parameters1, i32 43, !pc !14
  %13 = load i32, ptr @__anvill_stack_minus_44, align 4, !pc !13
  store i32 %13, ptr %2, align 4, !pc !13
  %14 = load i32, ptr @__anvill_stack_minus_40, align 4, !pc !13
  store i32 %14, ptr %3, align 4, !pc !13
  %15 = load i32, ptr @__anvill_stack_minus_36, align 4, !pc !13
  store i32 %15, ptr %4, align 4, !pc !13
  %16 = load i32, ptr @__anvill_stack_minus_32, align 4, !pc !13
  store i32 %16, ptr %5, align 4, !pc !13
  %17 = load i32, ptr @__anvill_stack_minus_28, align 4, !pc !13
  store i32 %17, ptr %6, align 4, !pc !13
  %18 = load i32, ptr @__anvill_stack_minus_24, align 4, !pc !13
  store i32 %18, ptr %7, align 4, !pc !13
  %19 = load i32, ptr @__anvill_stack_minus_20, align 4, !pc !13
  store i32 %19, ptr %8, align 4, !pc !13
  %20 = load i32, ptr @__anvill_stack_minus_16, align 4, !pc !13
  store i32 %20, ptr %9, align 4, !pc !13
  %21 = load i32, ptr @__anvill_stack_minus_12, align 4, !pc !13
  store i32 %21, ptr %10, align 4, !pc !13
  %22 = load i32, ptr @__anvill_stack_minus_8, align 4, !pc !13
  store i32 %22, ptr %11, align 4, !pc !13
  %23 = load i32, ptr @__anvill_stack_minus_4, align 4, !pc !13
  store i32 %23, ptr %12, align 4, !pc !13
  %24 = call ptr @make_pair(ptr nonnull %11, i32 %0, i32 %1) #3, !pc !13
  %25 = load i32, ptr %11, align 4, !pc !15
  %26 = load i32, ptr %12, align 4, !pc !14
  %27 = add i32 %26, %25, !pc !16
  ret i32 %27, !pc !16
}

attributes #0 = { noinline }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #3 = { nounwind }

!0 = !{i32 4198400}
!1 = !{i32 4198424}
!2 = !{i32 4198428}
!3 = !{i32 4198432}
!4 = !{i32 4198436}
!5 = !{i32 4198444}
!6 = !{i32 4198448}
!7 = !{i32 4198456}
!8 = !{i32 4198464}
!9 = !{i32 4198472}
!10 = !{i32 4198476}
!11 = !{i32 4198480}
!12 = !{i32 4198492}
!13 = !{i32 4198508}
!14 = !{i32 4198524}
!15 = !{i32 4198520}
!16 = !{i32 4198528}
