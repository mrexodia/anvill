source_filename = "lifted_code"
target datalayout = "E-m:e-i64:64-n32:64-S128"
target triple = "sparcv9-pc-linux-gnu-elf"

@__anvill_ra = external global i64
@__anvill_sp = external global i64
@llvm.compiler.used = appending global [12 x ptr] [ptr @shifts_logic, ptr @shift_right, ptr @mul_div, ptr @udiv, ptr @load_extend, ptr @store_narrow, ptr @float_to_int, ptr @int_to_double, ptr @float_math, ptr @float_less, ptr @select_max, ptr @switch_case], section "llvm.metadata"

; Function Attrs: noinline
define i32 @shifts_logic(i32 %0, i32 %1) #0 !pc !0 {
  %3 = shl i32 %0, 3
  %4 = ashr i32 %1, 2, !pc !1
  %5 = xor i32 %3, %4
  %6 = xor i32 %1, -1
  %7 = and i32 %6, %0
  %8 = or i32 %7, %5
  %9 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !2
  call void @__anvill_memory_escape(ptr %9)
  ret i32 %8
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

; Function Attrs: noinline
define i32 @shift_right(i32 %0, i32 %1) #0 !pc !3 {
  %3 = and i32 %1, 31
  %4 = lshr i32 %0, %3
  %5 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !4
  call void @__anvill_memory_escape(ptr %5)
  ret i32 %4
}

; Function Attrs: noinline
define i32 @mul_div(i32 %0, i32 %1) #0 !pc !5 {
  %3 = zext i32 %0 to i64, !pc !5
  %4 = zext i32 %1 to i64, !pc !5
  %5 = ashr i32 %0, 31, !pc !5
  %6 = mul nuw i64 %3, %4, !pc !6
  %7 = zext i32 %5 to i64, !pc !7
  %8 = shl nuw i64 %7, 32
  %9 = or disjoint i64 %8, %3
  %10 = sext i32 %1 to i64, !pc !8
  %11 = sdiv i64 %9, %10, !pc !8
  %12 = add i64 %6, %11, !pc !9
  %13 = mul i64 %11, %4, !pc !10
  %14 = sub i64 %3, %13, !pc !11
  %15 = add i64 %14, %12, !pc !12
  %16 = trunc i64 %15 to i32, !pc !13
  %17 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !13
  call void @__anvill_memory_escape(ptr %17)
  ret i32 %16
}

; Function Attrs: noinline
define i32 @udiv(i32 %0, i32 %1) #0 !pc !14 {
  %3 = udiv i32 %0, %1
  %4 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !15
  call void @__anvill_memory_escape(ptr %4)
  ret i32 %3
}

; Function Attrs: noinline
define i32 @load_extend(ptr %0, ptr %1, ptr %2) #0 !pc !16 {
  %4 = ptrtoint ptr %0 to i64, !pc !16
  %5 = ptrtoint ptr %1 to i64, !pc !16
  %6 = ptrtoint ptr %2 to i64, !pc !16
  %7 = add i64 %4, 1, !pc !16
  %8 = call i8 @__remill_read_memory_8(ptr null, i64 %7), !pc !16
  %9 = sext i8 %8 to i32
  %10 = add i64 %5, 4, !pc !17
  %11 = call i16 @__remill_read_memory_16(ptr null, i64 %10), !pc !17
  %12 = sext i16 %11 to i32
  %13 = add i64 %6, 3, !pc !18
  %14 = call i8 @__remill_read_memory_8(ptr null, i64 %13), !pc !18
  %15 = zext i8 %14 to i32
  %16 = add nsw i32 %9, %12
  %17 = add nsw i32 %16, %15
  %18 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !19
  call void @__anvill_memory_escape(ptr %18)
  ret i32 %17
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i8 @__remill_read_memory_8(ptr noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i16 @__remill_read_memory_16(ptr noundef, i64 noundef) #1

; Function Attrs: noinline
define void @store_narrow(ptr %0, ptr %1, i32 %2) #0 !pc !20 {
  %4 = ptrtoint ptr %0 to i64, !pc !20
  %5 = ptrtoint ptr %1 to i64, !pc !20
  %6 = trunc i32 %2 to i8
  %7 = call ptr @__remill_write_memory_8(ptr null, i64 %4, i8 %6), !pc !20
  %8 = lshr i32 %2, 8
  %9 = add i64 %5, 2, !pc !21
  %10 = trunc i32 %8 to i16
  %11 = call ptr @__remill_write_memory_16(ptr %7, i64 %9, i16 %10), !pc !21
  %12 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr %11), !pc !21
  call void @__anvill_memory_escape(ptr %12)
  ret void
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_8(ptr noundef, i64 noundef, i8 noundef zeroext) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_16(ptr noundef, i64 noundef, i16 noundef zeroext) #1

; Function Attrs: noinline
define i32 @float_to_int(float %0) #0 !pc !22 {
  %2 = fptosi float %0 to i32, !pc !23
  %3 = call ptr @__remill_write_memory_32(ptr null, i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 2043), i32 %2), !pc !24
  %4 = call i32 @__remill_read_memory_32(ptr %3, i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 2043)), !pc !25
  %5 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr %3), !pc !26
  call void @__anvill_memory_escape(ptr %5)
  ret i32 %4
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_32(ptr noundef, i64 noundef, i32 noundef zeroext) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i32 @__remill_read_memory_32(ptr noundef, i64 noundef) #1

; Function Attrs: noinline
define double @int_to_double(i32 %0) #0 !pc !27 {
  %2 = call ptr @__remill_write_memory_32(ptr null, i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 2043), i32 %0), !pc !28
  %3 = call i32 @__remill_read_memory_32(ptr %2, i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 2043)), !pc !29
  %4 = sitofp i32 %3 to double, !pc !30
  %5 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr %2), !pc !31
  call void @__anvill_memory_escape(ptr %5)
  ret double %4
}

; Function Attrs: noinline
define i32 @float_math(float %0, float %1) #0 !pc !32 {
  %3 = fmul float %0, %1, !pc !33
  %4 = fadd float %3, %0, !pc !34
  %5 = fptosi float %4 to i32, !pc !35
  %6 = call ptr @__remill_write_memory_32(ptr null, i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 2043), i32 %5), !pc !36
  %7 = call i32 @__remill_read_memory_32(ptr %6, i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 2043)), !pc !37
  %8 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr %6), !pc !38
  call void @__anvill_memory_escape(ptr %8)
  ret i32 %7
}

; Function Attrs: noinline
define i32 @float_less(float %0, float %1) #0 !pc !39 {
  %3 = fcmp olt float %0, %1, !pc !40
  %4 = zext i1 %3 to i8, !pc !40
  %5 = fcmp olt float %1, %0, !pc !40
  %6 = select i1 %5, i8 2, i8 0
  %7 = or disjoint i8 %6, %4
  %8 = fcmp uno float %1, %0
  %9 = select i1 %8, i8 3, i8 0
  %10 = add nuw nsw i8 %7, %9, !pc !40
  %11 = icmp eq i8 %10, 1, !pc !41
  br i1 %11, label %12, label %sleigh_remill_instruction_function_4010e8.exit, !pc !41

12:                                               ; preds = %2
  br label %sleigh_remill_instruction_function_4010e8.exit, !pc !41

sleigh_remill_instruction_function_4010e8.exit:   ; preds = %12, %2
  %13 = phi i32 [ 20, %2 ], [ 10, %12 ]
  %14 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !41
  call void @__anvill_memory_escape(ptr %14)
  ret i32 %13
}

; Function Attrs: noinline
define i32 @select_max(i32 %0, i32 %1) #0 !pc !42 {
  %3 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %0, i32 %1), !pc !42
  %4 = extractvalue { i32, i1 } %3, 1, !pc !42
  %5 = zext i1 %4 to i8, !pc !42
  %6 = sub i32 %0, %1
  %7 = icmp eq i32 %0, %1
  %8 = zext i1 %7 to i8, !pc !42
  %9 = lshr i32 %6, 31
  %10 = trunc nuw nsw i32 %9 to i8
  %11 = xor i8 %5, %10, !pc !43
  %12 = or i8 %11, %8, !pc !43
  %13 = icmp eq i8 %12, 0
  br i1 %13, label %14, label %sleigh_remill_instruction_function_4010f4.exit, !pc !43

14:                                               ; preds = %2
  br label %sleigh_remill_instruction_function_4010f4.exit, !pc !43

sleigh_remill_instruction_function_4010f4.exit:   ; preds = %14, %2
  %15 = phi i32 [ %1, %2 ], [ %0, %14 ]
  %16 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !44
  call void @__anvill_memory_escape(ptr %16)
  ret i32 %15
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32) #2

; Function Attrs: noinline
define i32 @switch_case(i32 %0) #0 !pc !45 {
  %2 = icmp slt i32 %0, -2147483644
  %3 = zext i1 %2 to i8, !pc !45
  %4 = add i32 %0, -4
  %5 = icmp eq i32 %4, 0, !pc !45
  %6 = zext i1 %5 to i8, !pc !45
  %7 = lshr i32 %4, 31
  %8 = trunc nuw nsw i32 %7 to i8
  %9 = xor i8 %3, %8, !pc !46
  %10 = or i8 %9, %6, !pc !46
  %11 = icmp eq i8 %10, 0
  br i1 %11, label %12, label %14, !pc !46

12:                                               ; preds = %1
  %13 = icmp eq i32 %0, 5
  br i1 %13, label %23, label %25, !pc !47

14:                                               ; preds = %1
  %15 = icmp eq i32 %0, 0, !pc !48
  br i1 %15, label %16, label %18, !pc !49

16:                                               ; preds = %14
  %17 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !50
  br label %sub_401100__AII_B_0.lifted.exit, !pc !45

18:                                               ; preds = %14
  %19 = icmp eq i32 %0, 1
  br i1 %19, label %20, label %inst_401154.i, !pc !51

20:                                               ; preds = %18
  %21 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !52
  br label %sub_401100__AII_B_0.lifted.exit, !pc !45

inst_401154.i:                                    ; preds = %25, %18
  %22 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !53
  br label %sub_401100__AII_B_0.lifted.exit, !pc !45

23:                                               ; preds = %12
  %24 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !54
  br label %sub_401100__AII_B_0.lifted.exit, !pc !45

25:                                               ; preds = %12
  %26 = icmp eq i32 %0, 9
  br i1 %26, label %27, label %inst_401154.i, !pc !55

27:                                               ; preds = %25
  %28 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !56
  br label %sub_401100__AII_B_0.lifted.exit, !pc !45

sub_401100__AII_B_0.lifted.exit:                  ; preds = %27, %23, %inst_401154.i, %20, %16
  %29 = phi i32 [ 33, %23 ], [ 55, %inst_401154.i ], [ 44, %27 ], [ 11, %16 ], [ 22, %20 ]
  %30 = phi ptr [ %24, %23 ], [ %22, %inst_401154.i ], [ %28, %27 ], [ %17, %16 ], [ %21, %20 ], !pc !45
  call void @__anvill_memory_escape(ptr %30)
  ret i32 %29
}

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!0 = !{i64 4198400}
!1 = !{i64 4198404}
!2 = !{i64 4198420}
!3 = !{i64 4198428}
!4 = !{i64 4198436}
!5 = !{i64 4198444}
!6 = !{i64 4198448}
!7 = !{i64 4198452}
!8 = !{i64 4198456}
!9 = !{i64 4198460}
!10 = !{i64 4198464}
!11 = !{i64 4198468}
!12 = !{i64 4198472}
!13 = !{i64 4198476}
!14 = !{i64 4198484}
!15 = !{i64 4198492}
!16 = !{i64 4198500}
!17 = !{i64 4198504}
!18 = !{i64 4198508}
!19 = !{i64 4198520}
!20 = !{i64 4198528}
!21 = !{i64 4198536}
!22 = !{i64 4198544}
!23 = !{i64 4198548}
!24 = !{i64 4198552}
!25 = !{i64 4198556}
!26 = !{i64 4198560}
!27 = !{i64 4198568}
!28 = !{i64 4198572}
!29 = !{i64 4198576}
!30 = !{i64 4198580}
!31 = !{i64 4198584}
!32 = !{i64 4198592}
!33 = !{i64 4198596}
!34 = !{i64 4198600}
!35 = !{i64 4198604}
!36 = !{i64 4198608}
!37 = !{i64 4198612}
!38 = !{i64 4198616}
!39 = !{i64 4198624}
!40 = !{i64 4198628}
!41 = !{i64 4198632}
!42 = !{i64 4198640}
!43 = !{i64 4198644}
!44 = !{i64 4198648}
!45 = !{i64 4198656}
!46 = !{i64 4198660}
!47 = !{i64 4198708}
!48 = !{i64 4198668}
!49 = !{i64 4198672}
!50 = !{i64 4198756}
!51 = !{i64 4198684}
!52 = !{i64 4198696}
!53 = !{i64 4198744}
!54 = !{i64 4198768}
!55 = !{i64 4198720}
!56 = !{i64 4198732}
