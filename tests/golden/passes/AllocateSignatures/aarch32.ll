; AArch32 (AAPCS, soft-float, Linux).
; RUN: --passes=AllocateSignatures
target datalayout = "e-m:e-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64"
target triple = "armv7-unknown-linux-gnueabi"

declare i32 @ints(i32 %a, i64 %b, i32 %c)
declare double @floats(float %a, double %b)
declare i64 @ret_long_long(i32 %a)
declare { i32, double } @ret_struct(i32 %a)
declare i32 @five_ints(i32, i32, i32, i32, i32)
declare void @split_struct(i32 %a, i32 %b, { i32, i32, i32 } %c, i32 %d)
declare void @no_split_after_stack(i32 %a, i32 %b, i32 %c, i64 %d, i32 %e, i64 %f)
declare { i8, i8 } @small_struct(i8 %a, i16 %b)
declare void @sret(ptr sret({ i32, i32 }) %out, i32 %x)
declare float @float_result(float %a, float %b)
