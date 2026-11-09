source_filename = "lifted_code"
target datalayout = "e-m:e-p:32:32-f64:32:64-f80:32-n8:16:32-S128"
target triple = "i386-pc-linux-gnu-elf"

@__anvill_sp = external global i32
@__anvill_ra = external global i32
@llvm.compiler.used = appending global [1 x ptr] [ptr @add], section "llvm.metadata"

; Function Attrs: noinline
define i32 @add(i32 %0, i32 %1) #0 !pc !0 {
  %3 = call ptr @__remill_write_memory_32(ptr null, i32 ptrtoint (ptr @__anvill_sp to i32), i32 ptrtoint (ptr @__anvill_ra to i32)), !pc !0
  %4 = call ptr @__remill_write_memory_32(ptr %3, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 4), i32 %0), !pc !0
  %5 = call ptr @__remill_write_memory_32(ptr %4, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 8), i32 %1), !pc !0
  %6 = call noundef i32 @__remill_read_memory_32(ptr noundef %5, i32 noundef add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 4)) #2, !pc !0
  %7 = call noundef i32 @__remill_read_memory_32(ptr noundef %5, i32 noundef add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 8)) #2, !pc !1
  %8 = add i32 %7, %6, !pc !1
  %9 = icmp ult i32 %8, %6, !pc !1
  %10 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_carry(i1 noundef zeroext %9, i32 noundef %6, i32 noundef %7, i32 noundef %8) #2, !pc !1
  %11 = xor i32 %8, %6, !pc !1
  %12 = icmp eq i32 %8, 0, !pc !1
  %13 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 noundef zeroext %12, i32 noundef %6, i32 noundef %7, i32 noundef %8) #2, !pc !1
  %14 = icmp slt i32 %8, 0, !pc !1
  %15 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 noundef zeroext %14, i32 noundef %6, i32 noundef %7, i32 noundef %8) #2, !pc !1
  %16 = lshr i32 %11, 31, !pc !1
  %17 = xor i32 %8, %7, !pc !1
  %18 = lshr i32 %17, 31, !pc !1
  %19 = add nuw nsw i32 %16, %18, !pc !1
  %20 = icmp eq i32 %19, 2, !pc !1
  %21 = call noundef zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 noundef zeroext %20, i32 noundef %6, i32 noundef %7, i32 noundef %8) #2, !pc !1
  %22 = call noundef i32 @__remill_read_memory_32(ptr noundef %5, i32 noundef ptrtoint (ptr @__anvill_sp to i32)) #2, !pc !2
  %23 = call ptr @__remill_function_return(ptr undef, i32 %22, ptr %5), !pc !2
  call void @__anvill_memory_escape(ptr %23)
  ret i32 %8
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_32(ptr noundef, i32 noundef, i32 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i32 @__remill_read_memory_32(ptr noundef, i32 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_carry(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_zero(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_sign(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_overflow(i1 noundef zeroext, ...) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #2 = { nobuiltin nounwind "no-builtins" }

!0 = !{i32 4198400}
!1 = !{i32 4198404}
!2 = !{i32 4198408}
