source_filename = "lifted_code"
target datalayout = "E-m:e-p:32:32-i64:64-f128:64-n32-S64"
target triple = "sparc-pc-linux-gnu-elf"

@__anvill_ra = external global i32
@__anvill_sp = external global i32
@llvm.compiler.used = appending global [12 x ptr] [ptr @shifts_logic, ptr @shift_right, ptr @mul_div, ptr @udiv, ptr @load_extend, ptr @store_narrow, ptr @float_to_int, ptr @int_to_double, ptr @float_math, ptr @float_less, ptr @select_max, ptr @switch_case], section "llvm.metadata"

; Function Attrs: noinline
define i32 @shifts_logic(i32 %0, i32 %1) #0 !pc !0 {
  %3 = shl i32 %0, 3, !pc !0
  %4 = ashr i32 %1, 2, !pc !1
  %5 = xor i32 %3, %4, !pc !2
  %6 = xor i32 %1, -1, !pc !3
  %7 = and i32 %6, %0, !pc !3
  %8 = or i32 %7, %5, !pc !4
  %9 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !4
  call void @__anvill_memory_escape(ptr %9)
  ret i32 %8
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

; Function Attrs: noinline
define i32 @shift_right(i32 %0, i32 %1) #0 !pc !5 {
  %3 = and i32 %1, 31
  %4 = lshr i32 %0, %3, !pc !6
  %5 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !6
  call void @__anvill_memory_escape(ptr %5)
  ret i32 %4
}

; Function Attrs: noinline
define i32 @mul_div(i32 %0, i32 %1) #0 !pc !7 {
  %3 = mul i32 %0, %1
  %4 = sdiv i32 %0, %1, !pc !8
  %5 = add i32 %3, %4, !pc !9
  %6 = mul i32 %4, %1
  %7 = sub i32 %0, %6, !pc !10
  %8 = add i32 %7, %5, !pc !11
  %9 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !11
  call void @__anvill_memory_escape(ptr %9)
  ret i32 %8
}

; Function Attrs: noinline
define i32 @udiv(i32 %0, i32 %1) #0 !pc !12 {
  %3 = udiv i32 %0, %1, !pc !13
  %4 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !14
  call void @__anvill_memory_escape(ptr %4)
  ret i32 %3
}

; Function Attrs: noinline
define i32 @load_extend(ptr %0, ptr %1, ptr %2) #0 !pc !15 {
  %4 = ptrtoint ptr %0 to i32, !pc !15
  %5 = ptrtoint ptr %1 to i32, !pc !15
  %6 = ptrtoint ptr %2 to i32, !pc !15
  %7 = add i32 %4, 1, !pc !15
  %8 = call i8 @__remill_read_memory_8(ptr null, i32 %7), !pc !15
  %9 = sext i8 %8 to i32, !pc !15
  %10 = add i32 %5, 4, !pc !16
  %11 = call i16 @__remill_read_memory_16(ptr null, i32 %10), !pc !16
  %12 = sext i16 %11 to i32, !pc !16
  %13 = add i32 %6, 3, !pc !17
  %14 = call i8 @__remill_read_memory_8(ptr null, i32 %13), !pc !17
  %15 = zext i8 %14 to i32, !pc !17
  %16 = add nsw i32 %9, %12, !pc !18
  %17 = add nsw i32 %16, %15, !pc !19
  %18 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !19
  call void @__anvill_memory_escape(ptr %18)
  ret i32 %17
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i8 @__remill_read_memory_8(ptr noundef, i32 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i16 @__remill_read_memory_16(ptr noundef, i32 noundef) #1

; Function Attrs: noinline
define void @store_narrow(ptr %0, ptr %1, i32 %2) #0 !pc !20 {
  %4 = ptrtoint ptr %0 to i32, !pc !20
  %5 = ptrtoint ptr %1 to i32, !pc !20
  %6 = trunc i32 %2 to i8, !pc !20
  %7 = call ptr @__remill_write_memory_8(ptr null, i32 %4, i8 %6), !pc !20
  %8 = lshr i32 %2, 8, !pc !21
  %9 = add i32 %5, 2, !pc !22
  %10 = trunc i32 %8 to i16, !pc !22
  %11 = call ptr @__remill_write_memory_16(ptr %7, i32 %9, i16 %10), !pc !22
  %12 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr %11), !pc !22
  call void @__anvill_memory_escape(ptr %12)
  ret void
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_8(ptr noundef, i32 noundef, i8 noundef zeroext) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_16(ptr noundef, i32 noundef, i16 noundef zeroext) #1

; Function Attrs: noinline
define i32 @float_to_int(float %0) #0 !pc !23 {
  %2 = bitcast float %0 to i32, !pc !23
  %3 = call ptr @__remill_write_memory_32(ptr null, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -4), i32 %2), !pc !24
  %4 = call i32 @__remill_read_memory_32(ptr %3, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -4)), !pc !25
  %5 = bitcast i32 %4 to float, !pc !26
  %6 = fptosi float %5 to i32, !pc !26
  %7 = call ptr @__remill_write_memory_32(ptr %3, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -8), i32 %6), !pc !27
  %8 = call i32 @__remill_read_memory_32(ptr %7, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -8)), !pc !28
  %9 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr %7), !pc !29
  call void @__anvill_memory_escape(ptr %9)
  ret i32 %8
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_32(ptr noundef, i32 noundef, i32 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i32 @__remill_read_memory_32(ptr noundef, i32 noundef) #1

; Function Attrs: noinline
define double @int_to_double(i32 %0) #0 !pc !30 {
  %2 = call ptr @__remill_write_memory_32(ptr null, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -4), i32 %0), !pc !31
  %3 = call i32 @__remill_read_memory_32(ptr %2, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -4)), !pc !32
  %4 = sitofp i32 %3 to double, !pc !33
  %5 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr %2), !pc !34
  call void @__anvill_memory_escape(ptr %5)
  ret double %4
}

; Function Attrs: noinline
define i32 @float_math(float %0, float %1) #0 !pc !35 {
  %3 = bitcast float %0 to i32, !pc !35
  %4 = bitcast float %1 to i32, !pc !35
  %5 = call ptr @__remill_write_memory_32(ptr null, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -4), i32 %4), !pc !36
  %6 = call ptr @__remill_write_memory_32(ptr %5, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -8), i32 %3), !pc !37
  %7 = call i32 @__remill_read_memory_32(ptr %6, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -4)), !pc !38
  %8 = call i32 @__remill_read_memory_32(ptr %6, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -8)), !pc !39
  %9 = bitcast i32 %8 to float, !pc !40
  %10 = bitcast i32 %7 to float, !pc !40
  %11 = fmul float %9, %10, !pc !40
  %12 = bitcast i32 %8 to float, !pc !41
  %13 = fadd float %11, %12, !pc !41
  %14 = fptosi float %13 to i32, !pc !42
  %15 = call ptr @__remill_write_memory_32(ptr %6, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12), i32 %14), !pc !43
  %16 = call i32 @__remill_read_memory_32(ptr %15, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12)), !pc !44
  %17 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr %15), !pc !45
  call void @__anvill_memory_escape(ptr %17)
  ret i32 %16
}

; Function Attrs: noinline
define i32 @float_less(float %0, float %1) #0 !pc !46 {
  %3 = bitcast float %0 to i32, !pc !46
  %4 = bitcast float %1 to i32, !pc !46
  %5 = call ptr @__remill_write_memory_32(ptr null, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -4), i32 %4), !pc !47
  %6 = call ptr @__remill_write_memory_32(ptr %5, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -8), i32 %3), !pc !48
  %7 = call i32 @__remill_read_memory_32(ptr %6, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -4)), !pc !49
  %8 = call i32 @__remill_read_memory_32(ptr %6, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -8)), !pc !50
  %9 = bitcast i32 %8 to float, !pc !51
  %10 = bitcast i32 %7 to float, !pc !51
  %11 = fcmp olt float %9, %10, !pc !51
  %12 = zext i1 %11 to i8, !pc !51
  %13 = bitcast i32 %7 to float, !pc !51
  %14 = bitcast i32 %8 to float, !pc !51
  %15 = fcmp olt float %13, %14, !pc !51
  %16 = select i1 %15, i8 2, i8 0
  %17 = or disjoint i8 %16, %12
  %18 = bitcast i32 %8 to float, !pc !51
  %19 = bitcast i32 %7 to float, !pc !51
  %20 = fcmp uno float %19, %18
  %21 = select i1 %20, i8 3, i8 0
  %22 = add nuw nsw i8 %17, %21, !pc !51
  %23 = icmp eq i8 %22, 1, !pc !52
  br i1 %23, label %24, label %26, !pc !52

24:                                               ; preds = %2
  %25 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr %6), !pc !53
  br label %sub_4010e8__AffI_B_0.lifted.exit, !pc !46

26:                                               ; preds = %2
  %27 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr %6), !pc !54
  br label %sub_4010e8__AffI_B_0.lifted.exit, !pc !46

sub_4010e8__AffI_B_0.lifted.exit:                 ; preds = %26, %24
  %28 = phi i32 [ 10, %24 ], [ 20, %26 ]
  %29 = phi ptr [ %25, %24 ], [ %27, %26 ], !pc !46
  call void @__anvill_memory_escape(ptr %29)
  ret i32 %28
}

; Function Attrs: noinline
define i32 @select_max(i32 %0, i32 %1) #0 !pc !55 {
  %3 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %0, i32 %1), !pc !55
  %4 = extractvalue { i32, i1 } %3, 1, !pc !55
  %5 = zext i1 %4 to i8, !pc !55
  %6 = sub i32 %0, %1, !pc !55
  %7 = icmp eq i32 %0, %1
  %8 = zext i1 %7 to i8, !pc !55
  %9 = lshr i32 %6, 31
  %10 = trunc nuw nsw i32 %9 to i8
  %11 = xor i8 %5, %10, !pc !56
  %12 = or i8 %11, %8, !pc !56
  %13 = icmp eq i8 %12, 0
  br i1 %13, label %sub_401124__AIII_B_0.lifted.exit, label %14, !pc !56

14:                                               ; preds = %2
  br label %sub_401124__AIII_B_0.lifted.exit, !pc !57

sub_401124__AIII_B_0.lifted.exit:                 ; preds = %14, %2
  %15 = phi i32 [ %0, %2 ], [ %1, %14 ]
  %16 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !57
  call void @__anvill_memory_escape(ptr %16)
  ret i32 %15
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32) #2

; Function Attrs: noinline
define i32 @switch_case(i32 %0) #0 !pc !58 {
  %2 = icmp slt i32 %0, -2147483644
  %3 = zext i1 %2 to i8, !pc !58
  %4 = add i32 %0, -4
  %5 = icmp eq i32 %4, 0, !pc !58
  %6 = zext i1 %5 to i8, !pc !58
  %7 = lshr i32 %4, 31
  %8 = trunc nuw nsw i32 %7 to i8
  %9 = xor i8 %3, %8, !pc !59
  %10 = or i8 %9, %6, !pc !59
  %11 = icmp eq i8 %10, 0
  br i1 %11, label %12, label %14, !pc !59

12:                                               ; preds = %1
  %13 = icmp eq i32 %0, 5
  br i1 %13, label %23, label %25, !pc !60

14:                                               ; preds = %1
  %15 = icmp eq i32 %0, 0, !pc !61
  br i1 %15, label %16, label %18, !pc !62

16:                                               ; preds = %14
  %17 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !63
  br label %sub_40113c__AII_B_0.lifted.exit, !pc !58

18:                                               ; preds = %14
  %19 = icmp eq i32 %0, 1
  br i1 %19, label %20, label %inst_401188.i, !pc !64

20:                                               ; preds = %18
  %21 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !65
  br label %sub_40113c__AII_B_0.lifted.exit, !pc !58

inst_401188.i:                                    ; preds = %25, %18
  %22 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !66
  br label %sub_40113c__AII_B_0.lifted.exit, !pc !58

23:                                               ; preds = %12
  %24 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !67
  br label %sub_40113c__AII_B_0.lifted.exit, !pc !58

25:                                               ; preds = %12
  %26 = icmp eq i32 %0, 9
  br i1 %26, label %27, label %inst_401188.i, !pc !68

27:                                               ; preds = %25
  %28 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !69
  br label %sub_40113c__AII_B_0.lifted.exit, !pc !58

sub_40113c__AII_B_0.lifted.exit:                  ; preds = %27, %23, %inst_401188.i, %20, %16
  %29 = phi i32 [ 33, %23 ], [ 55, %inst_401188.i ], [ 44, %27 ], [ 11, %16 ], [ 22, %20 ]
  %30 = phi ptr [ %24, %23 ], [ %22, %inst_401188.i ], [ %28, %27 ], [ %17, %16 ], [ %21, %20 ], !pc !58
  call void @__anvill_memory_escape(ptr %30)
  ret i32 %29
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
!8 = !{i32 4198448}
!9 = !{i32 4198452}
!10 = !{i32 4198460}
!11 = !{i32 4198464}
!12 = !{i32 4198472}
!13 = !{i32 4198476}
!14 = !{i32 4198480}
!15 = !{i32 4198488}
!16 = !{i32 4198492}
!17 = !{i32 4198496}
!18 = !{i32 4198500}
!19 = !{i32 4198504}
!20 = !{i32 4198512}
!21 = !{i32 4198516}
!22 = !{i32 4198520}
!23 = !{i32 4198528}
!24 = !{i32 4198532}
!25 = !{i32 4198536}
!26 = !{i32 4198540}
!27 = !{i32 4198544}
!28 = !{i32 4198548}
!29 = !{i32 4198552}
!30 = !{i32 4198560}
!31 = !{i32 4198564}
!32 = !{i32 4198568}
!33 = !{i32 4198572}
!34 = !{i32 4198576}
!35 = !{i32 4198584}
!36 = !{i32 4198588}
!37 = !{i32 4198592}
!38 = !{i32 4198596}
!39 = !{i32 4198600}
!40 = !{i32 4198604}
!41 = !{i32 4198608}
!42 = !{i32 4198612}
!43 = !{i32 4198616}
!44 = !{i32 4198620}
!45 = !{i32 4198624}
!46 = !{i32 4198632}
!47 = !{i32 4198636}
!48 = !{i32 4198640}
!49 = !{i32 4198644}
!50 = !{i32 4198648}
!51 = !{i32 4198652}
!52 = !{i32 4198660}
!53 = !{i32 4198684}
!54 = !{i32 4198672}
!55 = !{i32 4198692}
!56 = !{i32 4198696}
!57 = !{i32 4198708}
!58 = !{i32 4198716}
!59 = !{i32 4198720}
!60 = !{i32 4198764}
!61 = !{i32 4198728}
!62 = !{i32 4198732}
!63 = !{i32 4198800}
!64 = !{i32 4198744}
!65 = !{i32 4198752}
!66 = !{i32 4198792}
!67 = !{i32 4198808}
!68 = !{i32 4198776}
!69 = !{i32 4198784}
