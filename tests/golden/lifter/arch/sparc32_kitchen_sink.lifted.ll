source_filename = "lifted_code"
target datalayout = "E-m:e-p:32:32-i64:64-f128:64-n32-S64"
target triple = "sparc-pc-linux-gnu-elf"

@__anvill_ra = external global i32
@__anvill_sp = external global i32
@__anvill_pc = external global i32
@counter = global i32 5
@llvm.compiler.used = appending global [7 x ptr] [ptr @max, ptr @bump, ptr @seventh, ptr @twice, ptr @make_pair, ptr @use_pair, ptr @counter], section "llvm.metadata"

; Function Attrs: noinline
define i32 @max(i32 %0, i32 %1) #0 !pc !0 {
  %3 = call { i32, i1 } @llvm.ssub.with.overflow.i32(i32 %0, i32 %1), !pc !0
  %4 = extractvalue { i32, i1 } %3, 1, !pc !0
  %5 = sub i32 %0, %1, !pc !0
  %6 = icmp sgt i32 %5, -1
  %7 = xor i1 %6, %4
  br i1 %7, label %sub_401000__AIII_B_0.lifted.exit, label %8, !pc !1

8:                                                ; preds = %2
  br label %sub_401000__AIII_B_0.lifted.exit, !pc !2

sub_401000__AIII_B_0.lifted.exit:                 ; preds = %8, %2
  %9 = phi i32 [ %0, %2 ], [ %1, %8 ]
  %10 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr null), !pc !2
  call void @__anvill_memory_escape(ptr %10)
  ret i32 %9
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) #2

declare void @__anvill_memory_escape(ptr)

; Function Attrs: noinline
define i32 @bump(i32 %0) #0 !pc !3 {
  %2 = call i32 @__remill_read_memory_32(ptr null, i32 4210688), !pc !4
  %3 = add i32 %2, %0, !pc !5
  %4 = call ptr @__remill_write_memory_32(ptr null, i32 4210688, i32 %3), !pc !6
  %5 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr %4), !pc !6
  call void @__anvill_memory_escape(ptr %5)
  ret i32 %3
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i32 @__remill_read_memory_32(ptr noundef, i32 noundef) #2

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_32(ptr noundef, i32 noundef, i32 noundef) #2

; Function Attrs: noinline
define i32 @seventh(i32 %0, i32 %1, i32 %2, i32 %3, i32 %4, i32 %5, i32 %6) #0 !pc !7 {
  %8 = call ptr @__remill_write_memory_32(ptr null, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 92), i32 %6), !pc !7
  %9 = call i32 @__remill_read_memory_32(ptr %8, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 92)), !pc !7
  %10 = add i32 %9, %0, !pc !8
  %11 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr %8), !pc !8
  call void @__anvill_memory_escape(ptr %11)
  ret i32 %10
}

; Function Attrs: noinline
define double @twice(i32 %0, i32 %1) #0 !pc !9 {
  %3 = zext i32 %1 to i64
  %4 = zext i32 %0 to i64
  %5 = shl nuw i64 %4, 32
  %6 = or disjoint i64 %5, %3
  %7 = call ptr @__remill_write_memory_64(ptr null, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 72), i64 %6), !pc !9
  %8 = call i64 @__remill_read_memory_64(ptr %7, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 72)), !pc !10
  %9 = bitcast i64 %8 to double, !pc !11
  %10 = bitcast i64 %8 to double, !pc !11
  %11 = fadd double %9, %10, !pc !11
  %12 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr %7), !pc !11
  call void @__anvill_memory_escape(ptr %12)
  ret double %11
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_64(ptr noundef, i32 noundef, i64 noundef) #2

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i64 @__remill_read_memory_64(ptr noundef, i32 noundef) #2

; Function Attrs: noinline
define ptr @make_pair(ptr %0, i32 %1, i32 %2) #0 !pc !12 {
  %4 = ptrtoint ptr %0 to i32, !pc !12
  %5 = call ptr @__remill_write_memory_32(ptr null, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 64), i32 %4), !pc !12
  %6 = call i32 @__remill_read_memory_32(ptr %5, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 64)), !pc !12
  %7 = call ptr @__remill_write_memory_32(ptr %5, i32 %6, i32 %1), !pc !13
  %8 = add i32 %6, 4, !pc !14
  %9 = call ptr @__remill_write_memory_32(ptr %7, i32 %8, i32 %2), !pc !14
  %10 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 12), ptr %9), !pc !15
  %11 = inttoptr i32 %6 to ptr, !pc !12
  call void @__anvill_memory_escape(ptr %10)
  ret ptr %11
}

; Function Attrs: noinline
define i32 @use_pair(i32 %0, i32 %1) #0 !pc !16 {
  br i1 true, label %3, label %4, !pc !16

3:                                                ; preds = %2
  br label %sleigh_remill_instruction_function_40105c.exit, !pc !16

4:                                                ; preds = %2
  br label %sleigh_remill_instruction_function_40105c.exit, !pc !16

sleigh_remill_instruction_function_40105c.exit:   ; preds = %4, %3
  %5 = call ptr @__remill_write_memory_32(ptr null, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -48), i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -8)), !pc !17
  %6 = call i32 @__remill_read_memory_32(ptr %5, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -48)), !pc !18
  %7 = inttoptr i32 %6 to ptr, !pc !18
  %8 = call ptr inttoptr (i32 add (i32 ptrtoint (ptr @__anvill_pc to i32), i32 4198472) to ptr)(ptr %7, i32 %0, i32 %1) #3, !pc !18
  %9 = call i32 @__remill_read_memory_32(ptr %5, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -8)), !pc !19
  %10 = call i32 @__remill_read_memory_32(ptr %5, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -4)), !pc !20
  br i1 true, label %11, label %13, !pc !21

11:                                               ; preds = %sleigh_remill_instruction_function_40105c.exit
  %12 = add i32 %10, %9, !pc !21
  br label %sleigh_remill_instruction_function_401080.exit, !pc !21

13:                                               ; preds = %sleigh_remill_instruction_function_40105c.exit
  br label %sleigh_remill_instruction_function_401080.exit, !pc !21

sleigh_remill_instruction_function_401080.exit:   ; preds = %13, %11
  %14 = phi i32 [ %12, %11 ], [ poison, %13 ]
  %15 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr %5), !pc !21
  call void @__anvill_memory_escape(ptr %15)
  ret i32 %14
}

attributes #0 = { noinline }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #3 = { nounwind }

!0 = !{i32 4198400}
!1 = !{i32 4198404}
!2 = !{i32 4198416}
!3 = !{i32 4198424}
!4 = !{i32 4198428}
!5 = !{i32 4198432}
!6 = !{i32 4198436}
!7 = !{i32 4198444}
!8 = !{i32 4198448}
!9 = !{i32 4198456}
!10 = !{i32 4198460}
!11 = !{i32 4198464}
!12 = !{i32 4198472}
!13 = !{i32 4198476}
!14 = !{i32 4198480}
!15 = !{i32 4198484}
!16 = !{i32 4198492}
!17 = !{i32 4198500}
!18 = !{i32 4198508}
!19 = !{i32 4198520}
!20 = !{i32 4198524}
!21 = !{i32 4198528}
