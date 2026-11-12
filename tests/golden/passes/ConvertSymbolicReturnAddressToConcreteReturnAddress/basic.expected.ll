source_filename = "basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_ra = external global i64

define void @stores_ra(ptr %slot) {
entry:
  %return_address = call ptr @llvm.returnaddress(i32 0)
  %0 = ptrtoint ptr %return_address to i64, !pc !0
  store i64 %0, ptr %slot, align 8, !pc !0
  ret void
}

define i64 @adjusted_ra() {
entry:
  %return_address = call ptr @llvm.returnaddress(i32 0)
  %0 = ptrtoint ptr %return_address to i64
  %1 = add i64 %0, 8
  br label %next

next:                                             ; preds = %entry
  ret i64 %1
}

define i64 @no_ra(i64 %x) {
  ret i64 %x
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare ptr @llvm.returnaddress(i32 immarg) #0

attributes #0 = { nocallback nofree nosync nounwind willreturn memory(none) }

!0 = !{i64 4096}
