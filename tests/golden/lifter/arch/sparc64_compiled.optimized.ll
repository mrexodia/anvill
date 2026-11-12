source_filename = "lifted_code"
target datalayout = "E-m:e-i64:64-n32:64-S128"
target triple = "sparcv9-pc-linux-gnu-elf"

@__anvill_ra = external global i64
@__anvill_stack_plus_2040 = external local_unnamed_addr global i64

; Function Attrs: noinline
define i32 @shifts_logic(i32 %0, i32 %1) local_unnamed_addr #0 !pc !0 {
  %3 = shl i32 %0, 3, !pc !1
  %4 = ashr i32 %1, 2, !pc !1
  %5 = xor i32 %3, %4, !pc !1
  %6 = xor i32 %1, -1, !pc !1
  %7 = and i32 %6, %0, !pc !1
  %8 = or i32 %7, %5, !pc !1
  ret i32 %8, !pc !1
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) local_unnamed_addr #1

; Function Attrs: noinline
define i32 @shift_right(i32 %0, i32 %1) local_unnamed_addr #0 !pc !2 {
  %3 = and i32 %1, 31
  %4 = lshr i32 %0, %3
  ret i32 %4
}

; Function Attrs: noinline
define i32 @mul_div(i32 %0, i32 %1) local_unnamed_addr #0 !pc !3 {
  %3 = zext i32 %0 to i64, !pc !3
  %4 = zext i32 %1 to i64, !pc !3
  %5 = ashr i32 %0, 31, !pc !3
  %6 = mul nuw i64 %3, %4, !pc !4
  %7 = zext i32 %5 to i64, !pc !5
  %8 = shl nuw i64 %7, 32, !pc !6
  %9 = or disjoint i64 %8, %3, !pc !6
  %10 = sext i32 %1 to i64, !pc !6
  %11 = sdiv i64 %9, %10, !pc !6
  %12 = add i64 %6, %11, !pc !7
  %13 = mul i64 %11, %4, !pc !8
  %14 = sub i64 %3, %13, !pc !9
  %15 = add i64 %14, %12, !pc !10
  %16 = trunc i64 %15 to i32, !pc !11
  ret i32 %16, !pc !11
}

; Function Attrs: noinline
define i32 @udiv(i32 %0, i32 %1) local_unnamed_addr #0 !pc !12 {
  %3 = udiv i32 %0, %1
  ret i32 %3
}

; Function Attrs: noinline
define i32 @load_extend(ptr %0, ptr %1, ptr %2) local_unnamed_addr #0 !pc !13 {
  %4 = ptrtoint ptr %0 to i64, !pc !13
  %5 = ptrtoint ptr %1 to i64, !pc !13
  %6 = ptrtoint ptr %2 to i64, !pc !13
  %7 = add i64 %4, 1, !pc !13
  %8 = inttoptr i64 %7 to ptr, !pc !13
  %9 = load i8, ptr %8, align 1, !pc !13
  %10 = sext i8 %9 to i32, !pc !14
  %11 = add i64 %5, 4, !pc !14
  %12 = inttoptr i64 %11 to ptr, !pc !14
  %13 = load i16, ptr %12, align 2, !pc !14
  %14 = sext i16 %13 to i32, !pc !15
  %15 = add i64 %6, 3, !pc !15
  %16 = inttoptr i64 %15 to ptr, !pc !15
  %17 = load i8, ptr %16, align 1, !pc !15
  %18 = zext i8 %17 to i32, !pc !15
  %19 = add nsw i32 %10, %14, !pc !15
  %20 = add nsw i32 %19, %18, !pc !15
  ret i32 %20, !pc !15
}

; Function Attrs: noinline
define void @store_narrow(ptr %0, ptr %1, i32 %2) local_unnamed_addr #0 !pc !16 {
  %4 = ptrtoint ptr %1 to i64, !pc !16
  %5 = trunc i32 %2 to i8, !pc !16
  store i8 %5, ptr %0, align 1, !pc !16
  %6 = lshr i32 %2, 8, !pc !17
  %7 = add i64 %4, 2, !pc !17
  %8 = trunc i32 %6 to i16, !pc !17
  %9 = inttoptr i64 %7 to ptr, !pc !17
  store i16 %8, ptr %9, align 2, !pc !17
  ret void, !pc !17
}

; Function Attrs: noinline
define i32 @float_to_int(float %0) local_unnamed_addr #0 !pc !18 {
  %2 = fptosi float %0 to i32, !pc !19
  ret i32 %2, !pc !19
}

; Function Attrs: noinline
define double @int_to_double(i32 %0) local_unnamed_addr #0 !pc !20 {
  %2 = sitofp i32 %0 to double, !pc !21
  ret double %2, !pc !21
}

; Function Attrs: noinline
define i32 @float_math(float %0, float %1) local_unnamed_addr #0 !pc !22 {
  %3 = fmul float %0, %1, !pc !23
  %4 = fadd float %3, %0, !pc !24
  %5 = fptosi float %4 to i32, !pc !25
  ret i32 %5, !pc !25
}

; Function Attrs: noinline
define i32 @float_less(float %0, float %1) local_unnamed_addr #0 !pc !26 {
sleigh_remill_instruction_function_4010e8.exit:
  %2 = fcmp olt float %0, %1, !pc !27
  %3 = zext i1 %2 to i8, !pc !27
  %4 = fcmp olt float %1, %0, !pc !27
  %5 = select i1 %4, i8 2, i8 0, !pc !27
  %6 = or disjoint i8 %5, %3, !pc !27
  %7 = fcmp uno float %1, %0, !pc !27
  %8 = select i1 %7, i8 3, i8 0, !pc !27
  %9 = add nuw nsw i8 %6, %8, !pc !27
  %10 = icmp eq i8 %9, 1, !pc !28
  %spec.select = select i1 %10, i32 10, i32 20, !pc !28
  ret i32 %spec.select, !pc !28
}

; Function Attrs: noinline
define i32 @select_max(i32 %0, i32 %1) local_unnamed_addr #0 !pc !29 {
sleigh_remill_instruction_function_4010f4.exit:
  %2 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %0, i32 %1), !pc !29
  %3 = extractvalue { i32, i1 } %2, 1, !pc !29
  %4 = zext i1 %3 to i8, !pc !29
  %5 = sub i32 %0, %1, !pc !29
  %6 = icmp eq i32 %0, %1, !pc !29
  %7 = zext i1 %6 to i8, !pc !29
  %8 = lshr i32 %5, 31, !pc !30
  %9 = trunc nuw nsw i32 %8 to i8, !pc !30
  %10 = xor i8 %4, %9, !pc !30
  %11 = or i8 %10, %7, !pc !30
  %12 = icmp eq i8 %11, 0, !pc !30
  %spec.select = select i1 %12, i32 %0, i32 %1, !pc !30
  ret i32 %spec.select, !pc !30
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32) #2

; Function Attrs: noinline
define i32 @switch_case(i32 %0) local_unnamed_addr #0 !pc !31 {
  %2 = icmp slt i32 %0, -2147483644, !pc !31
  %3 = zext i1 %2 to i8, !pc !31
  %4 = add i32 %0, -4, !pc !31
  %5 = icmp eq i32 %4, 0, !pc !31
  %6 = zext i1 %5 to i8, !pc !31
  %7 = lshr i32 %4, 31, !pc !32
  %8 = trunc nuw nsw i32 %7 to i8, !pc !32
  %9 = xor i8 %3, %8, !pc !32
  %10 = or i8 %9, %6, !pc !32
  %11 = icmp eq i8 %10, 0, !pc !32
  br i1 %11, label %12, label %13, !pc !32

12:                                               ; preds = %1
  switch i32 %0, label %inst_401154.i [
    i32 5, label %16
    i32 9, label %17
  ]

13:                                               ; preds = %1
  switch i32 %0, label %inst_401154.i [
    i32 0, label %14
    i32 1, label %15
  ]

14:                                               ; preds = %13
  br label %sub_401100__AII_B_0.lifted.exit, !pc !31

15:                                               ; preds = %13
  br label %sub_401100__AII_B_0.lifted.exit, !pc !31

inst_401154.i:                                    ; preds = %12, %13
  br label %sub_401100__AII_B_0.lifted.exit, !pc !31

16:                                               ; preds = %12
  br label %sub_401100__AII_B_0.lifted.exit, !pc !31

17:                                               ; preds = %12
  br label %sub_401100__AII_B_0.lifted.exit, !pc !31

sub_401100__AII_B_0.lifted.exit:                  ; preds = %17, %16, %inst_401154.i, %15, %14
  %18 = phi i32 [ 33, %16 ], [ 55, %inst_401154.i ], [ 44, %17 ], [ 11, %14 ], [ 22, %15 ]
  ret i32 %18
}

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!0 = !{i64 4198400}
!1 = !{i64 4198404}
!2 = !{i64 4198428}
!3 = !{i64 4198444}
!4 = !{i64 4198448}
!5 = !{i64 4198452}
!6 = !{i64 4198456}
!7 = !{i64 4198460}
!8 = !{i64 4198464}
!9 = !{i64 4198468}
!10 = !{i64 4198472}
!11 = !{i64 4198476}
!12 = !{i64 4198484}
!13 = !{i64 4198500}
!14 = !{i64 4198504}
!15 = !{i64 4198508}
!16 = !{i64 4198528}
!17 = !{i64 4198536}
!18 = !{i64 4198544}
!19 = !{i64 4198548}
!20 = !{i64 4198568}
!21 = !{i64 4198580}
!22 = !{i64 4198592}
!23 = !{i64 4198596}
!24 = !{i64 4198600}
!25 = !{i64 4198604}
!26 = !{i64 4198624}
!27 = !{i64 4198628}
!28 = !{i64 4198632}
!29 = !{i64 4198640}
!30 = !{i64 4198644}
!31 = !{i64 4198656}
!32 = !{i64 4198660}
