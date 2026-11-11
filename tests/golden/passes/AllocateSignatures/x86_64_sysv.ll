; Calling-convention allocation for x86-64 System V (Linux), as computed by
; FunctionDecl::Create for each declared function: the location of every
; parameter and return value, the return address, and the stack pointer
; after the return.
; RUN: --passes=AllocateSignatures
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare i32 @ints(i32 %a, i8 %b, i16 %c, i64 %d, ptr %e, i32 %f, i32 %g, i32 %h)
declare double @floats(float %a, double %b, i32 %c)
declare double @many_doubles(double, double, double, double, double, double, double, double, double, double)
declare { i64, double } @ret_mixed(i32 %a, float %b, ptr %c)
declare { i64, i64 } @ret_two_longs(i64 %a)
declare { i64, i64, i64 } @ret_three_longs()
declare i128 @wide(i128 %a)
declare void @struct_arg({ i32, i32 } %s)
declare x86_fp80 @long_double(x86_fp80 %a)
declare i32 @variadic(ptr %fmt, ...)
declare void @seven_longs({ i64, i64, i64, i64, i64, i64, i64 } %big, i32 %after)
declare void @sret(ptr sret({ i64, i64, i64 }) %out, i32 %x)
declare x86_64_sysvcc void @explicit_cc(i32 %x)
declare void @no_return() noreturn
declare { float, float, float } @ret_three_floats()
declare { double, double } @ret_two_doubles({ double, double } %p)
declare { i8, i8 } @ret_two_bytes({ i8, i8 } %p)
declare { i32, float } @ret_int_float({ i32, float } %p)
declare [2 x i32] @ret_array([2 x i32] %p)
declare { x86_fp80 } @ret_struct_long_double({ x86_fp80 } %p)
declare i256 @ret_i256(i256 %a)
declare void @regs_exhausted(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, { i64, i64 } %pair, i64 %f)
declare void @aligned_stack(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f, i32 %g, i128 %h, x86_fp80 %i, i8 %j)
declare <4 x float> @float_vector(<4 x float> %v, <2 x double> %w)
declare fp128 @quad(fp128 %a, i32 %b, fp128 %c)
declare { <2 x i64> } @vector_struct({ <2 x i64> } %a, { <2 x float>, double } %b)
declare x86_stdcallcc i32 @stdcall_on_amd64(i32 %a, i32 %b)
declare x86_fastcallcc i32 @fastcall_on_amd64(i32 %a, i32 %b)
