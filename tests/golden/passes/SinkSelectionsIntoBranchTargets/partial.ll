; Uses not dominated by either edge (here, after the join and in the branch
; block itself) keep the select; PHI uses are judged by their incoming edge.
; A branch whose two successors are the same block has no unique edges and
; changes nothing.
; RUN: --passes=SinkSelectionsIntoBranchTargets
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu-elf"

define i32 @join(i1 %c, i32 %a, i32 %b) {
entry:
  %s = select i1 %c, i32 %a, i32 %b
  %before = add i32 %s, 7
  br i1 %c, label %left, label %right
left:
  %l = add i32 %s, 1
  br label %merge
right:
  br label %merge
merge:
  %p = phi i32 [ %l, %left ], [ %s, %right ]
  %after = add i32 %s, %p
  %r = add i32 %after, %before
  ret i32 %r
}

define i32 @same_successor(i1 %c, i32 %a, i32 %b) {
entry:
  %s = select i1 %c, i32 %a, i32 %b
  br i1 %c, label %next, label %next
next:
  ret i32 %s
}
