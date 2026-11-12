; SPARC32 (Linux).
; RUN: --passes=AllocateSignatures
target datalayout = "E-m:e-p:32:32-i64:64-f128:64-n32-S64"
target triple = "sparc-unknown-linux-gnu"

declare i32 @ints(i32 %a, float %b, ptr %c)
declare i32 @seven_ints(i32, i32, i32, i32, i32, i32, i32)
declare i64 @ret_long_long(i64 %a)
declare double @doubles(double %a)
declare void @split_double(i32, i32, i32, i32, i32, double %d, i32 %after)
declare { i32, i32 } @struct_result({ i32, i32 } %by_ref, fp128 %q)
declare void @sret(ptr sret({ i32, i32 }) %out, i32 %x)
