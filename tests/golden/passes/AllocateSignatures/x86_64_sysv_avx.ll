; x86-64 System V with AVX (--arch=amd64_avx): each XMM constraint gains a
; YMM variant (ApplyX86Ext), so 256-bit vectors are passed and returned in
; YMM registers while smaller values keep the XMM names.
; RUN: --passes=AllocateSignatures --arch=amd64_avx
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare { i64, double } @ret_mixed(i32 %a, float %b, ptr %c)
declare double @floats(float %a, double %b, i32 %c)
declare <8 x float> @wide_vector(<8 x float> %v, <4 x double> %w, double %d)
