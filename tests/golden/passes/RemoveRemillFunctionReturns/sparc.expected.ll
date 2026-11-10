source_filename = "sparc.ll"
target datalayout = "E-m:e-p:32:32-i64:64-f128:64-n32-S64"
target triple = "sparc-unknown-linux-gnu"

@__anvill_ra = external global i8

declare ptr @__remill_function_return(ptr, i32, ptr)

define ptr @returns_normally(ptr %mem) {
  ret ptr %mem
}

define ptr @returns_structure(ptr %mem) {
  ret ptr %mem
}

define ptr @returns_elsewhere(ptr %mem) {
  %m = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 16), ptr %mem), !pc !0
  ret ptr %m
}

!0 = !{i32 12288}
