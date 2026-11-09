; 32-bit x86 (Linux): cdecl, stdcall, fastcall and thiscall. All arguments
; are on the stack starting at [ESP + 4] (the return address is at [ESP]);
; callee-cleanup conventions report the popped bytes in the stack pointer on
; return.
; RUN: --passes=AllocateSignatures
target datalayout = "e-m:e-p:32:32-f64:32:64-f80:32-n8:16:32-S128"
target triple = "i386-pc-linux-gnu-elf"

declare i32 @cdecl_ints(i32 %a, i8 %b, i16 %c)
declare i64 @cdecl_long_long(i64 %a)
declare double @cdecl_double(double %a)
declare { i32, double } @cdecl_ret_struct(i32 %a, float %b, ptr %c)
declare x86_stdcallcc i32 @stdcall_ints(i32 %a, i32 %b)
declare x86_fastcallcc i32 @fastcall_ints(i32 %a, i32 %b, i32 %c)
declare x86_thiscallcc i32 @thiscall_method(ptr %this, i32 %a)
declare i32 @cdecl_variadic(ptr %fmt, ...)
declare x86_fastcallcc i32 @fastcall_mixed(i64 %a, i8 %b, double %c, ptr %d, i32 %e)
declare x86_fastcallcc { i32, double } @fastcall_ret_struct(i32 %a, i32 %b)
declare x86_thiscallcc { i32, double } @thiscall_ret_struct(ptr %this, i16 %a)
declare x86_stdcallcc { i32, double } @stdcall_ret_struct(i32 %a)
declare i32 @cdecl_small_slots(i8 %a, i16 %b, i64 %c, x86_fp80 %d, i8 %e)
