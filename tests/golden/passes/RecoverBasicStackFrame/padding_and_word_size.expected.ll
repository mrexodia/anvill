source_filename = "padding_and_word_size.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

%sub_401000__AI_B_0.frame_type = type { [5 x i8] }

@__anvill_sp = external global i8
@__anvill_ra = external global i8
@__anvill_stack_minus_20 = external global i8
@__anvill_stack_minus_19 = external global i8
@__anvill_stack_minus_18 = external global i8
@__anvill_stack_minus_17 = external global i8
@__anvill_stack_minus_16 = external global i8
@__anvill_stack_minus_15 = external global i8
@__anvill_stack_minus_14 = external global i8
@__anvill_stack_minus_13 = external global i8
@__anvill_stack_minus_12 = external global i8
@__anvill_stack_minus_11 = external global i8
@__anvill_stack_minus_10 = external global i8
@__anvill_stack_minus_9 = external global i8
@__anvill_stack_minus_8 = external global i8
@__anvill_stack_minus_7 = external global i8
@__anvill_stack_minus_6 = external global i8
@__anvill_stack_minus_5 = external global i8
@__anvill_stack_minus_4 = external global i8
@__anvill_stack_minus_3 = external global i8
@__anvill_stack_minus_2 = external global i8
@__anvill_stack_minus_1 = external global i8
@__anvill_stack_0 = external global i8
@__anvill_stack_plus_1 = external global i8
@__anvill_stack_plus_2 = external global i8
@__anvill_stack_plus_3 = external global i8
@__anvill_stack_plus_4 = external global i8
@__anvill_stack_plus_5 = external global i8
@__anvill_stack_plus_6 = external global i8
@__anvill_stack_plus_7 = external global i8
@__anvill_stack_plus_8 = external global i8
@__anvill_stack_plus_9 = external global i8
@__anvill_stack_plus_10 = external global i8
@__anvill_stack_plus_11 = external global i8
@__anvill_stack_plus_12 = external global i8
@__anvill_stack_plus_13 = external global i8
@__anvill_stack_plus_14 = external global i8
@__anvill_stack_plus_15 = external global i8
@__anvill_stack_plus_16 = external global i8
@__anvill_stack_plus_17 = external global i8
@__anvill_stack_plus_18 = external global i8
@__anvill_stack_plus_19 = external global i8

define i32 @sub_401000__AI_B_0(i32 %x) {
  %1 = alloca %sub_401000__AI_B_0.frame_type, align 8, !__anvill_stack_zero !0
  %2 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  %3 = load i8, ptr @__anvill_stack_minus_20, align 1
  store i8 %3, ptr %2, align 1
  %4 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 1
  %5 = load i8, ptr @__anvill_stack_minus_19, align 1
  store i8 %5, ptr %4, align 1
  %6 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 2
  %7 = load i8, ptr @__anvill_stack_minus_18, align 1
  store i8 %7, ptr %6, align 1
  %8 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 3
  %9 = load i8, ptr @__anvill_stack_minus_17, align 1
  store i8 %9, ptr %8, align 1
  %10 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 4
  %11 = load i8, ptr @__anvill_stack_minus_16, align 1
  store i8 %11, ptr %10, align 1
  %12 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 5
  %13 = load i8, ptr @__anvill_stack_minus_15, align 1
  store i8 %13, ptr %12, align 1
  %14 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 6
  %15 = load i8, ptr @__anvill_stack_minus_14, align 1
  store i8 %15, ptr %14, align 1
  %16 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 7
  %17 = load i8, ptr @__anvill_stack_minus_13, align 1
  store i8 %17, ptr %16, align 1
  %18 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 8
  %19 = load i8, ptr @__anvill_stack_minus_12, align 1
  store i8 %19, ptr %18, align 1
  %20 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 9
  %21 = load i8, ptr @__anvill_stack_minus_11, align 1
  store i8 %21, ptr %20, align 1
  %22 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 10
  %23 = load i8, ptr @__anvill_stack_minus_10, align 1
  store i8 %23, ptr %22, align 1
  %24 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 11
  %25 = load i8, ptr @__anvill_stack_minus_9, align 1
  store i8 %25, ptr %24, align 1
  %26 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 12
  %27 = load i8, ptr @__anvill_stack_minus_8, align 1
  store i8 %27, ptr %26, align 1
  %28 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 13
  %29 = load i8, ptr @__anvill_stack_minus_7, align 1
  store i8 %29, ptr %28, align 1
  %30 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 14
  %31 = load i8, ptr @__anvill_stack_minus_6, align 1
  store i8 %31, ptr %30, align 1
  %32 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 15
  %33 = load i8, ptr @__anvill_stack_minus_5, align 1
  store i8 %33, ptr %32, align 1
  %34 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 16
  %35 = load i8, ptr @__anvill_stack_minus_4, align 1
  store i8 %35, ptr %34, align 1
  %36 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 17
  %37 = load i8, ptr @__anvill_stack_minus_3, align 1
  store i8 %37, ptr %36, align 1
  %38 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 18
  %39 = load i8, ptr @__anvill_stack_minus_2, align 1
  store i8 %39, ptr %38, align 1
  %40 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 19
  %41 = load i8, ptr @__anvill_stack_minus_1, align 1
  store i8 %41, ptr %40, align 1
  %42 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 20
  %43 = load i8, ptr @__anvill_stack_0, align 1
  store i8 %43, ptr %42, align 1
  %44 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 21
  %45 = load i8, ptr @__anvill_stack_plus_1, align 1
  store i8 %45, ptr %44, align 1
  %46 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 22
  %47 = load i8, ptr @__anvill_stack_plus_2, align 1
  store i8 %47, ptr %46, align 1
  %48 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 23
  %49 = load i8, ptr @__anvill_stack_plus_3, align 1
  store i8 %49, ptr %48, align 1
  %50 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 24
  %51 = load i8, ptr @__anvill_stack_plus_4, align 1
  store i8 %51, ptr %50, align 1
  %52 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 25
  %53 = load i8, ptr @__anvill_stack_plus_5, align 1
  store i8 %53, ptr %52, align 1
  %54 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 26
  %55 = load i8, ptr @__anvill_stack_plus_6, align 1
  store i8 %55, ptr %54, align 1
  %56 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 27
  %57 = load i8, ptr @__anvill_stack_plus_7, align 1
  store i8 %57, ptr %56, align 1
  %58 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 28
  %59 = load i8, ptr @__anvill_stack_plus_8, align 1
  store i8 %59, ptr %58, align 1
  %60 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 29
  %61 = load i8, ptr @__anvill_stack_plus_9, align 1
  store i8 %61, ptr %60, align 1
  %62 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 30
  %63 = load i8, ptr @__anvill_stack_plus_10, align 1
  store i8 %63, ptr %62, align 1
  %64 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 31
  %65 = load i8, ptr @__anvill_stack_plus_11, align 1
  store i8 %65, ptr %64, align 1
  %66 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 32
  %67 = load i8, ptr @__anvill_stack_plus_12, align 1
  store i8 %67, ptr %66, align 1
  %68 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 33
  %69 = load i8, ptr @__anvill_stack_plus_13, align 1
  store i8 %69, ptr %68, align 1
  %70 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 34
  %71 = load i8, ptr @__anvill_stack_plus_14, align 1
  store i8 %71, ptr %70, align 1
  %72 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 35
  %73 = load i8, ptr @__anvill_stack_plus_15, align 1
  store i8 %73, ptr %72, align 1
  %74 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 36
  %75 = load i8, ptr @__anvill_stack_plus_16, align 1
  store i8 %75, ptr %74, align 1
  %76 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 37
  %77 = load i8, ptr @__anvill_stack_plus_17, align 1
  store i8 %77, ptr %76, align 1
  %78 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 38
  %79 = load i8, ptr @__anvill_stack_plus_18, align 1
  store i8 %79, ptr %78, align 1
  %80 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 39
  %81 = load i8, ptr @__anvill_stack_plus_19, align 1
  store i8 %81, ptr %80, align 1
  %82 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 20
  %83 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 8
  %84 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 28
  %85 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 8
  %86 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 20
  %87 = ptrtoint ptr %86 to i64
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr %82, align 8, !pc !1
  store i32 %x, ptr %83, align 4
  %arg = load i32, ptr %84, align 4
  %l = load i32, ptr %85, align 4
  %addr = add i64 %87, -4
  %r = add i32 %l, %arg
  ret i32 %r
}

!0 = !{i64 20}
!1 = !{i64 4198400}
