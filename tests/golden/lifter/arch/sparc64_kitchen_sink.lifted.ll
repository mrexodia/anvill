source_filename = "lifted_code"
target datalayout = "E-m:e-i64:64-n32:64-S128"
target triple = "sparcv9-pc-linux-gnu-elf"

%0 = type { i64, i64 }

@__anvill_ra = external global i64
@__anvill_sp = external global i64
@__anvill_pc = external global i64
@counter = global i32 5
@llvm.compiler.used = appending global [7 x ptr] [ptr @max, ptr @bump, ptr @seventh, ptr @twice, ptr @swap, ptr @use_swap, ptr @counter], section "llvm.metadata"

; Function Attrs: noinline
define i64 @max(i64 %0, i64 %1) #0 !pc !0 {
  %3 = call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %0, i64 %1), !pc !0
  %4 = extractvalue { i64, i1 } %3, 1, !pc !0
  %5 = sub i64 %0, %1, !pc !0
  %6 = icmp sgt i64 %5, -1
  %7 = xor i1 %6, %4
  br i1 %7, label %sub_401000__ALLL_B_0.lifted.exit, label %8, !pc !1

8:                                                ; preds = %2
  br label %sub_401000__ALLL_B_0.lifted.exit, !pc !2

sub_401000__ALLL_B_0.lifted.exit:                 ; preds = %8, %2
  %9 = phi i64 [ %0, %2 ], [ %1, %8 ]
  %10 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !2
  call void @__anvill_memory_escape(ptr %10)
  ret i64 %9
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.ssub.with.overflow.i64(i64, i64) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #2

declare void @__anvill_memory_escape(ptr)

; Function Attrs: noinline
define i32 @bump(i32 %0) #0 !pc !3 {
  %2 = zext i32 %0 to i64, !pc !3
  %3 = call i32 @__remill_read_memory_32(ptr null, i64 4210688), !pc !4
  %4 = zext i32 %3 to i64, !pc !4
  %5 = add nuw nsw i64 %2, %4, !pc !5
  %6 = trunc i64 %5 to i32, !pc !6
  %7 = call ptr @__remill_write_memory_32(ptr null, i64 4210688, i32 %6), !pc !6
  %8 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr %7), !pc !6
  %9 = trunc i64 %5 to i32, !pc !3
  call void @__anvill_memory_escape(ptr %8)
  ret i32 %9
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i32 @__remill_read_memory_32(ptr noundef, i64 noundef) #2

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_32(ptr noundef, i64 noundef, i32 noundef zeroext) #2

; Function Attrs: noinline
define i64 @seventh(i64 %0, i64 %1, i64 %2, i64 %3, i64 %4, i64 %5, i64 %6) #0 !pc !7 {
  %8 = call ptr @__remill_write_memory_64(ptr null, i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 2223), i64 %6), !pc !7
  %9 = call i64 @__remill_read_memory_64(ptr %8, i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 2223)), !pc !7
  %10 = add i64 %9, %0, !pc !8
  %11 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr %8), !pc !8
  call void @__anvill_memory_escape(ptr %11)
  ret i64 %10
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_64(ptr noundef, i64 noundef, i64 noundef) #2

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i64 @__remill_read_memory_64(ptr noundef, i64 noundef) #2

; Function Attrs: noinline
define double @twice(double %0) #0 !pc !9 {
  %2 = fadd double %0, %0, !pc !9
  %3 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !9
  call void @__anvill_memory_escape(ptr %3)
  ret double %2
}

; Function Attrs: noinline
define %0 @swap(i64 %0, i64 %1) #0 !pc !10 {
  %3 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !11
  %4 = insertvalue %0 undef, i64 %1, 0
  %5 = insertvalue %0 %4, i64 %0, 1
  call void @__anvill_memory_escape(ptr %3)
  ret %0 %5
}

; Function Attrs: noinline
define i64 @use_swap(i64 %0, i64 %1) #0 !pc !12 {
  br i1 true, label %3, label %4, !pc !12

3:                                                ; preds = %2
  br label %sleigh_remill_instruction_function_401050.exit, !pc !12

4:                                                ; preds = %2
  br label %sleigh_remill_instruction_function_401050.exit, !pc !12

sleigh_remill_instruction_function_401050.exit:   ; preds = %4, %3
  %5 = call %0 inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198464) to ptr)(i64 %0, i64 %1) #3, !pc !13
  br i1 true, label %6, label %10, !pc !14

6:                                                ; preds = %sleigh_remill_instruction_function_401050.exit
  %7 = extractvalue %0 %5, 1, !pc !13
  %8 = extractvalue %0 %5, 0, !pc !13
  %9 = add i64 %7, %8, !pc !14
  br label %sleigh_remill_instruction_function_401060.exit, !pc !14

10:                                               ; preds = %sleigh_remill_instruction_function_401050.exit
  br label %sleigh_remill_instruction_function_401060.exit, !pc !14

sleigh_remill_instruction_function_401060.exit:   ; preds = %10, %6
  %11 = phi i64 [ %9, %6 ], [ poison, %10 ]
  %12 = call ptr @__remill_function_return(ptr undef, i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8), ptr null), !pc !14
  call void @__anvill_memory_escape(ptr %12)
  ret i64 %11
}

attributes #0 = { noinline }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #3 = { nounwind }

!0 = !{i64 4198400}
!1 = !{i64 4198404}
!2 = !{i64 4198416}
!3 = !{i64 4198424}
!4 = !{i64 4198428}
!5 = !{i64 4198432}
!6 = !{i64 4198436}
!7 = !{i64 4198444}
!8 = !{i64 4198448}
!9 = !{i64 4198456}
!10 = !{i64 4198464}
!11 = !{i64 4198472}
!12 = !{i64 4198480}
!13 = !{i64 4198488}
!14 = !{i64 4198496}
