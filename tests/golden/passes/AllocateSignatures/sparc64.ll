; SPARC V9 (64-bit, Linux) with remill's Sleigh-based architecture
; (sparc64): 8-byte argument slots; the first six integer slots are in
; O0-O5, floating-point arguments use the FP register of their slot (FS2k+1,
; FD2k, FQ2k), later slots are on the stack at [SP + 2223 + 8 * (k - 6)] with
; small values right-justified, aggregates of at most 16 bytes are passed as
; i64 words and larger ones by reference. Results: O0 (O0, O1 for i128),
; FS0/FD0/FQ0, integer-only aggregates of at most 32 bytes in O0-O3, others in
; memory through a hidden first argument. Return address O7.
; RUN: --passes=AllocateSignatures
target datalayout = "E-m:e-i64:64-n32:64-S128"
target triple = "sparcv9-unknown-linux-gnu"

declare i32 @ints(i32 %a, i64 %b, ptr %c)
declare i64 @seven_ints(i32, i32, i32, i32, i32, i32, i32 %g, i64 %h)
declare double @floats(float %a, double %b, i32 %c, fp128 %q)
declare i128 @wide(i32 %a, i128 %b)
declare { i64, i32 } @small_struct({ i64, i32 } %s, i8 %c)
declare { i64, i64, i64, i64, i64 } @big_struct({ i64, i64, i64 } %by_ref, i32 %x)
declare double @late_double(double, double, double, double, double, double, double, double, double, double, double, double, double, double, double, double, double %on_stack)
declare void @sret(ptr sret({ i64, i64, i64, i64, i64 }) %out, i32 %x)
