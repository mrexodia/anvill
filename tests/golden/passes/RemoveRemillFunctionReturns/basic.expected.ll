source_filename = "basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_ra = external global i8
@__anvill_sp = external global i8

declare ptr @__remill_function_return(ptr, i64, ptr)

declare i64 @__remill_read_memory_64(ptr, i64)

define ptr @returns_normally(ptr %mem) {
  ret ptr %mem
}

define ptr @returns_to_stack_value(ptr %mem) {
  %ra = call i64 @__remill_read_memory_64(ptr %mem, i64 ptrtoint (ptr @__anvill_sp to i64))
  %m = call ptr @__remill_function_return(ptr undef, i64 %ra, ptr %mem)
  ret ptr %m
}

define ptr @returns_elsewhere(ptr %mem, i64 %target) {
  %1 = call ptr @llvm.addressofreturnaddress.p0(), !pc !0
  store i64 %target, ptr %1, align 8, !pc !0
  ret ptr %mem
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare ptr @llvm.addressofreturnaddress.p0() #0

attributes #0 = { nocallback nofree nosync nounwind willreturn memory(none) }

!0 = !{i64 8192}
