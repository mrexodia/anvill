source_filename = "lifted_code"
target datalayout = "E-m:e-p:32:32-i64:64-f128:64-n32-S64"
target triple = "sparc-pc-linux-gnu-elf"

@__anvill_ra = external global i32
@__anvill_stack_minus_8 = external local_unnamed_addr global i32
@__anvill_stack_minus_4 = external local_unnamed_addr global i32
@__anvill_stack_minus_12 = external local_unnamed_addr global i32

; Function Attrs: noinline
define i32 @shifts_logic(i32 %0, i32 %1) local_unnamed_addr #0 !pc !0 {
  %3 = shl i32 %0, 3, !pc !0
  %4 = ashr i32 %1, 2, !pc !1
  %5 = xor i32 %3, %4, !pc !2
  %6 = xor i32 %1, -1, !pc !3
  %7 = and i32 %6, %0, !pc !3
  %8 = or i32 %7, %5, !pc !4
  ret i32 %8, !pc !4
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) local_unnamed_addr #1

; Function Attrs: noinline
define i32 @shift_right(i32 %0, i32 %1) local_unnamed_addr #0 !pc !5 {
  %3 = and i32 %1, 31, !pc !6
  %4 = lshr i32 %0, %3, !pc !6
  ret i32 %4, !pc !6
}

; Function Attrs: noinline
define i32 @mul_div(i32 %0, i32 %1) local_unnamed_addr #0 !pc !7 {
  %3 = mul i32 %0, %1, !pc !8
  %4 = sdiv i32 %0, %1, !pc !9
  %5 = add i32 %3, %4, !pc !8
  %6 = mul i32 %4, %1, !pc !10
  %7 = sub i32 %0, %6, !pc !10
  %8 = add i32 %7, %5, !pc !11
  ret i32 %8, !pc !11
}

; Function Attrs: noinline
define i32 @udiv(i32 %0, i32 %1) local_unnamed_addr #0 !pc !12 {
  %3 = udiv i32 %0, %1, !pc !13
  ret i32 %3, !pc !13
}

; Function Attrs: noinline
define i32 @load_extend(ptr %0, ptr %1, ptr %2) local_unnamed_addr #0 !pc !14 {
  %4 = ptrtoint ptr %0 to i32, !pc !14
  %5 = ptrtoint ptr %1 to i32, !pc !14
  %6 = ptrtoint ptr %2 to i32, !pc !14
  %7 = add i32 %4, 1, !pc !14
  %8 = inttoptr i32 %7 to ptr, !pc !14
  %9 = load i8, ptr %8, align 1, !pc !14
  %10 = sext i8 %9 to i32, !pc !14
  %11 = add i32 %5, 4, !pc !15
  %12 = inttoptr i32 %11 to ptr, !pc !15
  %13 = load i16, ptr %12, align 2, !pc !15
  %14 = sext i16 %13 to i32, !pc !15
  %15 = add i32 %6, 3, !pc !16
  %16 = inttoptr i32 %15 to ptr, !pc !16
  %17 = load i8, ptr %16, align 1, !pc !16
  %18 = zext i8 %17 to i32, !pc !16
  %19 = add nsw i32 %10, %14, !pc !17
  %20 = add nsw i32 %19, %18, !pc !18
  ret i32 %20, !pc !18
}

; Function Attrs: noinline
define void @store_narrow(ptr %0, ptr %1, i32 %2) local_unnamed_addr #0 !pc !19 {
  %4 = ptrtoint ptr %1 to i32, !pc !19
  %5 = trunc i32 %2 to i8, !pc !19
  store i8 %5, ptr %0, align 1, !pc !19
  %6 = lshr i32 %2, 8, !pc !20
  %7 = add i32 %4, 2, !pc !21
  %8 = trunc i32 %6 to i16, !pc !21
  %9 = inttoptr i32 %7 to ptr, !pc !21
  store i16 %8, ptr %9, align 2, !pc !21
  ret void, !pc !21
}

; Function Attrs: noinline
define i32 @float_to_int(float %0) local_unnamed_addr #0 !pc !22 {
  %2 = fptosi float %0 to i32, !pc !23
  ret i32 %2, !pc !23
}

; Function Attrs: noinline
define double @int_to_double(i32 %0) local_unnamed_addr #0 !pc !24 {
  %2 = sitofp i32 %0 to double, !pc !25
  ret double %2, !pc !25
}

; Function Attrs: noinline
define i32 @float_math(float %0, float %1) local_unnamed_addr #0 !pc !26 {
  %3 = fmul float %1, %0, !pc !27
  %4 = fadd float %3, %0, !pc !28
  %5 = fptosi float %4 to i32, !pc !29
  ret i32 %5, !pc !29
}

; Function Attrs: noinline
define i32 @float_less(float %0, float %1) local_unnamed_addr #0 !pc !30 {
  %3 = fcmp ogt float %1, %0, !pc !31
  %4 = zext i1 %3 to i8, !pc !31
  %5 = fcmp olt float %1, %0, !pc !31
  %6 = select i1 %5, i8 2, i8 0, !pc !31
  %7 = or disjoint i8 %6, %4, !pc !31
  %8 = fcmp uno float %1, %0, !pc !31
  %9 = select i1 %8, i8 3, i8 0, !pc !31
  %10 = add nuw nsw i8 %7, %9, !pc !31
  %11 = icmp eq i8 %10, 1, !pc !32
  br i1 %11, label %12, label %13, !pc !32

12:                                               ; preds = %2
  br label %sub_4010e8__AffI_B_0.lifted.exit, !pc !30

13:                                               ; preds = %2
  br label %sub_4010e8__AffI_B_0.lifted.exit, !pc !30

sub_4010e8__AffI_B_0.lifted.exit:                 ; preds = %13, %12
  %14 = phi i32 [ 10, %12 ], [ 20, %13 ]
  ret i32 %14
}

; Function Attrs: noinline
define i32 @select_max(i32 %0, i32 %1) local_unnamed_addr #0 !pc !33 {
sub_401124__AIII_B_0.lifted.exit:
  %2 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %0, i32 %1), !pc !33
  %3 = extractvalue { i32, i1 } %2, 1, !pc !33
  %4 = zext i1 %3 to i8, !pc !33
  %5 = sub i32 %0, %1, !pc !33
  %6 = icmp eq i32 %0, %1, !pc !33
  %7 = zext i1 %6 to i8, !pc !33
  %8 = lshr i32 %5, 31, !pc !34
  %9 = trunc nuw nsw i32 %8 to i8, !pc !34
  %10 = xor i8 %4, %9, !pc !34
  %11 = or i8 %10, %7, !pc !34
  %12 = icmp eq i8 %11, 0, !pc !34
  %spec.select = select i1 %12, i32 %0, i32 %1, !pc !34
  ret i32 %spec.select, !pc !34
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32) #2

; Function Attrs: noinline
define i32 @switch_case(i32 %0) local_unnamed_addr #0 !pc !35 {
  %2 = icmp slt i32 %0, -2147483644, !pc !35
  %3 = zext i1 %2 to i8, !pc !35
  %4 = add i32 %0, -4, !pc !35
  %5 = icmp eq i32 %4, 0, !pc !35
  %6 = zext i1 %5 to i8, !pc !35
  %7 = lshr i32 %4, 31, !pc !36
  %8 = trunc nuw nsw i32 %7 to i8, !pc !36
  %9 = xor i8 %3, %8, !pc !36
  %10 = or i8 %9, %6, !pc !36
  %11 = icmp eq i8 %10, 0, !pc !36
  br i1 %11, label %12, label %13, !pc !36

12:                                               ; preds = %1
  switch i32 %0, label %inst_401188.i [
    i32 5, label %16
    i32 9, label %17
  ]

13:                                               ; preds = %1
  switch i32 %0, label %inst_401188.i [
    i32 0, label %14
    i32 1, label %15
  ]

14:                                               ; preds = %13
  br label %sub_40113c__AII_B_0.lifted.exit, !pc !35

15:                                               ; preds = %13
  br label %sub_40113c__AII_B_0.lifted.exit, !pc !35

inst_401188.i:                                    ; preds = %12, %13
  br label %sub_40113c__AII_B_0.lifted.exit, !pc !35

16:                                               ; preds = %12
  br label %sub_40113c__AII_B_0.lifted.exit, !pc !35

17:                                               ; preds = %12
  br label %sub_40113c__AII_B_0.lifted.exit, !pc !35

sub_40113c__AII_B_0.lifted.exit:                  ; preds = %17, %16, %inst_401188.i, %15, %14
  %18 = phi i32 [ 33, %16 ], [ 55, %inst_401188.i ], [ 44, %17 ], [ 11, %14 ], [ 22, %15 ]
  ret i32 %18
}

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!0 = !{i32 4198400}
!1 = !{i32 4198404}
!2 = !{i32 4198408}
!3 = !{i32 4198412}
!4 = !{i32 4198416}
!5 = !{i32 4198424}
!6 = !{i32 4198428}
!7 = !{i32 4198436}
!8 = !{i32 4198452}
!9 = !{i32 4198448}
!10 = !{i32 4198460}
!11 = !{i32 4198464}
!12 = !{i32 4198472}
!13 = !{i32 4198476}
!14 = !{i32 4198488}
!15 = !{i32 4198492}
!16 = !{i32 4198496}
!17 = !{i32 4198500}
!18 = !{i32 4198504}
!19 = !{i32 4198512}
!20 = !{i32 4198516}
!21 = !{i32 4198520}
!22 = !{i32 4198528}
!23 = !{i32 4198540}
!24 = !{i32 4198560}
!25 = !{i32 4198572}
!26 = !{i32 4198584}
!27 = !{i32 4198604}
!28 = !{i32 4198608}
!29 = !{i32 4198612}
!30 = !{i32 4198632}
!31 = !{i32 4198652}
!32 = !{i32 4198660}
!33 = !{i32 4198692}
!34 = !{i32 4198696}
!35 = !{i32 4198716}
!36 = !{i32 4198720}
