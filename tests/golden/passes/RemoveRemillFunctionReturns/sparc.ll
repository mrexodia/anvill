; On SPARC the return address register holds the address of the call, so
; returns go to the return address plus 8 (past the call and its delay
; slot), or plus 12 for functions that return a structure (also past the
; `unimp <size>` after the delay slot). Both are returns to the real return
; address and are removed. Any other displacement, like 16, means the
; function changed its return address; as SPARC has no return address slot
; (llvm.addressofreturnaddress) to store it into, the call is left alone.
; RUN: --passes=RemoveRemillFunctionReturns
target datalayout = "E-m:e-p:32:32-i64:64-f128:64-n32-S64"
target triple = "sparc-unknown-linux-gnu"

@__anvill_ra = external global i8

declare ptr @__remill_function_return(ptr, i32, ptr)

define ptr @returns_normally(ptr %mem) {
  %m = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 8), ptr %mem), !pc !0
  ret ptr %m
}

define ptr @returns_structure(ptr %mem) {
  %m = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 12), ptr %mem), !pc !1
  ret ptr %m
}

define ptr @returns_elsewhere(ptr %mem) {
  %m = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_ra to i32), i32 16), ptr %mem), !pc !2
  ret ptr %m
}

!0 = !{i32 4096}
!1 = !{i32 8192}
!2 = !{i32 12288}
