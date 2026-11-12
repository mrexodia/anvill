source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i64
@__anvill_ra = external global i64
@__anvill_pc = external global i64
@llvm.compiler.used = appending global [2 x ptr] [ptr @f, ptr @g], section "llvm.metadata"

; Function Attrs: noinline
define i32 @f(i32 %0) #0 !pc !0 {
  %2 = call ptr @__remill_write_memory_64(ptr null, i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @__anvill_ra to i64)), !pc !0
  %3 = add i32 %0, 1, !pc !0
  %4 = icmp eq i32 %0, -1
  %5 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_carry(i1 noundef zeroext %4, i32 noundef %0, i32 noundef 1, i32 noundef %3) #2, !pc !0
  %6 = xor i32 %3, %0, !pc !0
  %7 = icmp eq i32 %3, 0, !pc !0
  %8 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %7, i32 noundef %0, i32 noundef 1, i32 noundef %3) #2, !pc !0
  %9 = icmp slt i32 %3, 0, !pc !0
  %10 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %9, i32 noundef %0, i32 noundef 1, i32 noundef %3) #2, !pc !0
  %11 = lshr i32 %6, 31, !pc !0
  %12 = lshr i32 %3, 31, !pc !0
  %13 = add nuw nsw i32 %11, %12, !pc !0
  %14 = icmp eq i32 %13, 2, !pc !0
  %15 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 noundef zeroext %14, i32 noundef %0, i32 noundef 1, i32 noundef %3) #2, !pc !0
  %16 = call i64 @__remill_read_memory_64(ptr %2, i64 ptrtoint (ptr @__anvill_sp to i64)), !pc !1
  %17 = call i32 inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4202496) to ptr)(i32 %3) #3, !pc !1
  %18 = call ptr @__remill_function_return(ptr undef, i64 %16, ptr %2), !pc !1
  call void @__anvill_memory_escape(ptr %18)
  ret i32 %17
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_64(ptr noundef, i64 noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_carry(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_zero(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_sign(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_overflow(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i64 @__remill_read_memory_64(ptr noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

; Function Attrs: noinline
declare !pc !2 i32 @g(i32) #0

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #2 = { nobuiltin nounwind "no-builtins" }
attributes #3 = { nounwind }

!0 = !{i64 4198400}
!1 = !{i64 4198403}
!2 = !{i64 4202496}
