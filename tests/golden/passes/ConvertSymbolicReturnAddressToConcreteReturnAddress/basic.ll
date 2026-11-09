; Remaining uses of the symbolic return address (`ptrtoint @__anvill_ra`,
; possibly inside larger constant expressions) are replaced by the real
; return address: one `llvm.returnaddress(0)` call at the top of the entry
; block, `ptrtoint`s of it, and the enclosing constant expressions turned
; into instructions. Functions without such uses are unchanged.
; RUN: --passes=ConvertSymbolicReturnAddressToConcreteReturnAddress
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

@__anvill_ra = external global i64

define void @stores_ra(ptr %slot) {
entry:
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr %slot, !pc !0
  ret void
}

define i64 @adjusted_ra() {
entry:
  br label %next
next:
  ret i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8)
}

define i64 @no_ra(i64 %x) {
  ret i64 %x
}

!0 = !{i64 4096}
