source_filename = "lifted_code"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_ra = external global i64
@__anvill_stack_0 = external local_unnamed_addr global i64

; Function Attrs: noinline
define i32 @checked(i32 %0) local_unnamed_addr #0 !pc !0 {
sub_401000__AII_B_0.lifted.exit:
  %1 = icmp ne i32 %0, 0, !pc !0
  call void @llvm.assume(i1 %1), !pc !0
  ret i32 %0, !pc !0
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_zero(i1 noundef zeroext, ...) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_flag_computation_sign(i1 noundef zeroext, ...) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i8 @__remill_undefined_8() local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local zeroext i1 @__remill_compare_neq(i1 noundef zeroext) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) local_unnamed_addr #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write)
declare void @llvm.assume(i1 noundef) #2

attributes #0 = { noinline }
attributes #1 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" }
attributes #2 = { nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write) }

!0 = !{i64 4198400}
