source_filename = "tests/golden/passes/RemoveCompilerBarriers/basic.ll"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

declare void @external()

define internal void @internal() {
  ret void
}

define void @runs() {
  call void asm sideeffect "", ""()
  ret void
}

define void @before_external_call() {
  call void @external()
  ret void
}

define void @before_internal_call() {
  call void asm sideeffect "", ""()
  call void @internal()
  ret void
}

define i32 @separated(i32 %x) {
  call void asm sideeffect "", ""()
  %y = add i32 %x, 1
  call void asm sideeffect "", ""()
  ret i32 %y
}

define void @not_barriers() {
  call void asm sideeffect "nop", ""()
  call void asm "", ""()
  call void asm sideeffect "nop", ""()
  ret void
}
