source_filename = "basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_ra = external global i8

declare ptr @__remill_jump(ptr, i64, ptr)

define ptr @direct(ptr %state, ptr %mem) {
  %m = call ptr @__remill_function_return(ptr undef, i64 ptrtoint (ptr @__anvill_ra to i64), ptr %mem), !pc !0
  ret ptr %m
}

define ptr @reassembled(ptr %state, ptr %mem) {
  %m = call ptr @__remill_function_return(ptr undef, i64 ptrtoint (ptr @__anvill_ra to i64), ptr %mem)
  ret ptr %m
}

define ptr @unknown_target(ptr %state, ptr %mem, i64 %target) {
  %m = call ptr @__remill_jump(ptr %state, i64 %target, ptr %mem)
  ret ptr %m
}

; Function Attrs: noduplicate noinline nounwind optnone
declare ptr @__remill_function_return(ptr, i64, ptr) #0

attributes #0 = { noduplicate noinline nounwind optnone }

!0 = !{i64 4096}
