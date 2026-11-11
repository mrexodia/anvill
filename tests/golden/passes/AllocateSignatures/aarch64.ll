; AArch64 (AAPCS64, Linux).
; RUN: --passes=AllocateSignatures
target datalayout = "e-m:e-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128"
target triple = "aarch64-unknown-linux-gnu"

declare i32 @ints(i32 %a, float %b, ptr %c)
declare i64 @nine_longs(i64, i64, i64, i64, i64, i64, i64, i64, i64)
declare { i64, double } @ret_mixed(i32 %a)
declare i128 @wide(i128 %a)
declare double @doubles(double %a, float %b, half %c)
declare void @sret(ptr sret({ i64, i64, i64 }) %out)
declare { float, float, float } @hfa({ float, float, float } %a, [4 x double] %b, double %c, { float, float } %d)
declare { i64, i64, i64 } @big_struct({ i64, i64, i64 } %a, i32 %b)
declare void @pair_alignment(i32 %a, i128 %b, { i64, i32 } %c, i64 %d, i64 %e, i64 %f, { i64, i64 } %g, i32 %h)
declare <4 x float> @vectors(<4 x float> %a, <2 x float> %b)
declare i256 @huge_int(i256 %a)
declare void @stack_hfa(double, double, double, double, double, double, double, { double, double } %h, float %f)
declare { <2 x i64>, <2 x i64> } @hva({ <2 x i64>, <2 x i64> } %a, <4 x i32> %b)
