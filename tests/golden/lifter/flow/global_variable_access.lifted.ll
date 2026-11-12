source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_sp = external global i64
@__anvill_ra = external global i64
@__anvill_pc = external global i64
@counter = global i32 0
@llvm.compiler.used = appending global [2 x ptr] [ptr @bump, ptr @counter], section "llvm.metadata"

; Function Attrs: noinline
define i32 @bump(i32 %0) #0 !pc !0 {
  %2 = call ptr @__remill_write_memory_64(ptr null, i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @__anvill_ra to i64)), !pc !0
  %3 = call noundef i32 @__remill_read_memory_32(ptr noundef %2, i64 noundef add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4210688)) #2, !pc !0
  %4 = add i32 %3, %0, !pc !1
  %5 = icmp ult i32 %4, %3, !pc !1
  %6 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_carry(i1 noundef zeroext %5, i32 noundef %3, i32 noundef %0, i32 noundef %4) #2, !pc !1
  %7 = xor i32 %4, %3, !pc !1
  %8 = icmp eq i32 %4, 0, !pc !1
  %9 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %8, i32 noundef %3, i32 noundef %0, i32 noundef %4) #2, !pc !1
  %10 = icmp slt i32 %4, 0, !pc !1
  %11 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %10, i32 noundef %3, i32 noundef %0, i32 noundef %4) #2, !pc !1
  %12 = lshr i32 %7, 31, !pc !1
  %13 = xor i32 %4, %0, !pc !1
  %14 = lshr i32 %13, 31, !pc !1
  %15 = add nuw nsw i32 %12, %14, !pc !1
  %16 = icmp eq i32 %15, 2, !pc !1
  %17 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 noundef zeroext %16, i32 noundef %3, i32 noundef %0, i32 noundef %4) #2, !pc !1
  %18 = call noundef ptr @__remill_write_memory_32(ptr noundef %2, i64 noundef add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4210688), i32 noundef %4) #2, !pc !2
  %19 = call noundef i64 @__remill_read_memory_64(ptr noundef %18, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #2, !pc !3
  %20 = call ptr @__remill_function_return(ptr undef, i64 %19, ptr %18), !pc !3
  call void @__anvill_memory_escape(ptr %20)
  ret i32 %4
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_64(ptr noundef, i64 noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i32 @__remill_read_memory_32(ptr noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_carry(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_zero(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_sign(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_overflow(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_32(ptr noundef, i64 noundef, i32 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i64 @__remill_read_memory_64(ptr noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #2 = { nobuiltin nounwind "no-builtins" }

!0 = !{i64 4198400}
!1 = !{i64 4198406}
!2 = !{i64 4198408}
!3 = !{i64 4198414}
