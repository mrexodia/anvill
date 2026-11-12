source_filename = "edge_cases.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_pc = external global i8
@var_404000_I = global i32 7
@var_404010_L = global i64 0

define i32 @phi(i1 %c) {
entry:
  br i1 %c, label %a, label %b

a:                                                ; preds = %entry
  br label %join

b:                                                ; preds = %entry
  br label %join

join:                                             ; preds = %b, %a
  %p = phi ptr [ @var_404000_I, %a ], [ null, %b ]
  %v = load i32, ptr %p, align 4
  ret i32 %v
}

define i32 @instructions() {
  %base = ptrtoint ptr @__anvill_pc to i64
  %v = load i32, ptr @var_404000_I, align 4
  ret i32 %v
}

define i64 @as_integer() {
  ret i64 ptrtoint (ptr @var_404010_L to i64)
}

define i64 @global_relative() {
  %v = load i64, ptr @var_404010_L, align 8
  ret i64 %v
}

define i32 @absolute() {
  %v = load i32, ptr inttoptr (i64 4210688 to ptr), align 4
  ret i32 %v
}

declare i32 @decl(ptr)
