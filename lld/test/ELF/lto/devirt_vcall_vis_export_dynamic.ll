; REQUIRES: x86
;; Test that dynamically exported symbols prevent devirtualization.

;; First check that we get devirtualization without any export dynamic options.

;; Index based WPD
;; Generate unsplit module with summary for ThinLTO index-based WPD.
; RUN: opt --thinlto-bc -o %t2.o %s
; RUN: ld.lld %t2.o -o %t3 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. 2>&1 | FileCheck %s --check-prefix=REMARK
; RUN: llvm-dis %t2.o.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-IR
;; --export-dynamic without .dynsym does not prevent devirtualization.
; RUN: ld.lld %t2.o -o %t3 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. \
; RUN:   --export-dynamic 2>&1 | FileCheck %s --check-prefix=REMARK

;; Hybrid WPD
;; Generate split module with summary for hybrid Thin/Regular LTO WPD.
; RUN: opt --thinlto-bc --thinlto-split-lto-unit -o %t.o %s
; RUN: ld.lld %t.o -o %t3 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. 2>&1 | FileCheck %s --check-prefix=REMARK
; RUN: llvm-dis %t.o.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-IR

;; Regular LTO WPD
; RUN: opt -o %t4.o %s
; RUN: ld.lld %t4.o -o %t3 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. 2>&1 | FileCheck %s --check-prefix=REMARK
; RUN: llvm-dis %t3.0.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-IR

; REMARK-DAG: single-impl: devirtualized a call to _ZN1A1nEi
; REMARK-DAG: single-impl: devirtualized a call to _ZN1D1mEi

;; Check that all WPD fails with --export-dynamic.

; RUN: echo '.globl foo; foo:' > %ta.s
; RUN: llvm-mc -filetype=obj -triple=x86_64 %ta.s -o %ta.o
; RUN: ld.lld -shared -soname=ta %ta.o -o %ta.so

;; Index based WPD

; RUN: ld.lld %t2.o %ta.so -o %t3 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. \
; RUN:   --export-dynamic 2>&1 | FileCheck /dev/null --implicit-check-not single-impl --allow-empty
; RUN: llvm-dis %t2.o.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-NODEVIRT-IR

;; Hybrid WPD
; RUN: ld.lld %t.o %ta.so -o %t3 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. \
; RUN:   --export-dynamic 2>&1 | FileCheck /dev/null --implicit-check-not single-impl --allow-empty
; RUN: llvm-dis %t.o.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-NODEVIRT-IR

;; Regular LTO WPD
; RUN: ld.lld %t4.o %ta.so -o %t3 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. \
; RUN:   --export-dynamic 2>&1 | FileCheck /dev/null --implicit-check-not single-impl --allow-empty
; RUN: llvm-dis %t3.0.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-NODEVIRT-IR

;; Check that WPD fails for target _ZN1D1mEi with --export-dynamic-symbol=_ZTV1D.

;; Index based WPD
; RUN: ld.lld %t2.o %ta.so -o %t3 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. \
; RUN:   --export-dynamic-symbol=_ZTV1D 2>&1 | FileCheck %s --check-prefix=REMARK-AONLY
; RUN: llvm-dis %t2.o.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-AONLY-IR

;; Hybrid WPD
; RUN: ld.lld %t.o %ta.so -o %t3 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. \
; RUN:   --export-dynamic-symbol=_ZTV1D 2>&1 | FileCheck %s --check-prefix=REMARK-AONLY
; RUN: llvm-dis %t.o.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-AONLY-IR

;; Regular LTO WPD
; RUN: ld.lld %t4.o %ta.so -o %t3 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. \
; RUN:   --export-dynamic-symbol=_ZTV1D 2>&1 | FileCheck %s --check-prefix=REMARK-AONLY
; RUN: llvm-dis %t3.0.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-AONLY-IR

; REMARK-AONLY-NOT: single-impl:
; REMARK-AONLY: single-impl: devirtualized a call to _ZN1A1nEi
; REMARK-AONLY-NOT: single-impl:

;; Check that WPD fails for target _ZN1D1mEi with _ZTV1D in --dynamic-list.
; RUN: echo "{ _ZTV1D; };" > %t.list

;; Index based WPD
; RUN: ld.lld %t2.o %ta.so -o %t3 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. \
; RUN:   --dynamic-list=%t.list 2>&1 | FileCheck %s --check-prefix=REMARK-AONLY
; RUN: llvm-dis %t2.o.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-AONLY-IR

;; Hybrid WPD
; RUN: ld.lld %t.o %ta.so -o %t3 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. \
; RUN:   --dynamic-list=%t.list 2>&1 | FileCheck %s --check-prefix=REMARK-AONLY
; RUN: llvm-dis %t.o.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-AONLY-IR

;; Regular LTO WPD
; RUN: ld.lld %t4.o %ta.so -o %t3 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. \
; RUN:   --dynamic-list=%t.list 2>&1 | FileCheck %s --check-prefix=REMARK-AONLY
; RUN: llvm-dis %t3.0.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-AONLY-IR


;; Check that all WPD fails with when linking against a shared library containing
;; preemptible versions of the vtables. In this case the symbols in the object being
;; linked against the shared library must be exported to .dynsym to allow the runtime
;; preemption, even without any options.

;; Index based WPD
; RUN: opt -relocation-model=pic --thinlto-bc -o %t5.o %s
; RUN: ld.lld %t5.o -o %t5.so -shared
; RUN: ld.lld %t5.o %t5.so -o %t5 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. 2>&1 | FileCheck /dev/null --implicit-check-not single-impl --allow-empty

;; Hybrid WPD
; RUN: opt -relocation-model=pic --thinlto-bc --thinlto-split-lto-unit -o %t5.o %s
; RUN: ld.lld %t5.o -o %t5.so -shared
; RUN: ld.lld %t5.o %t5.so -o %t5 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. 2>&1 | FileCheck /dev/null --implicit-check-not single-impl --allow-empty

;; Regular LTO WPD
; RUN: opt -relocation-model=pic -o %t5.o %s
; RUN: ld.lld %t5.o -o %t5.so -shared
; RUN: ld.lld %t5.o %t5.so -o %t5 -save-temps --lto-whole-program-visibility \
; RUN:   -mllvm -pass-remarks=. 2>&1 | FileCheck /dev/null --implicit-check-not single-impl --allow-empty

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-grtev4-linux-gnu"

%struct.A = type { ptr }
%struct.B = type { %struct.A }
%struct.C = type { %struct.A }
%struct.D = type { ptr }

@_ZTV1B = linkonce_odr unnamed_addr constant { [4 x ptr] } { [4 x ptr] [ptr null, ptr undef, ptr @_ZN1B1fEi, ptr @_ZN1A1nEi] }, !type !0, !type !1, !vcall_visibility !5
@_ZTV1C = linkonce_odr unnamed_addr constant { [4 x ptr] } { [4 x ptr] [ptr null, ptr undef, ptr @_ZN1C1fEi, ptr @_ZN1A1nEi] }, !type !0, !type !2, !vcall_visibility !5
@_ZTV1D = linkonce_odr unnamed_addr constant { [3 x ptr] } { [3 x ptr] [ptr null, ptr undef, ptr @_ZN1D1mEi] }, !type !3, !vcall_visibility !5

;; Prevent the vtables from being dead code eliminated.
@llvm.used = appending global [3 x ptr] [ ptr @_ZTV1B, ptr @_ZTV1C, ptr @_ZTV1D]

; CHECK-IR-LABEL: define dso_local {{(noundef )?}}i32 @_start
define i32 @_start(ptr %obj, ptr %obj2, i32 %a) {
entry:
  %vtable = load ptr, ptr %obj
  %p = call i1 @llvm.type.test(ptr %vtable, metadata !"_ZTS1A")
  call void @llvm.assume(i1 %p)
  %fptrptr = getelementptr ptr, ptr %vtable, i32 1
  %fptr1 = load ptr, ptr %fptrptr, align 8

  ;; Check that the call was devirtualized.
  ; CHECK-IR: %call = tail call i32 @_ZN1A1nEi
  ; CHECK-AONLY-IR: %call = tail call i32 @_ZN1A1nEi
  ; CHECK-NODEVIRT-IR: %call = tail call i32 %fptr1
  %call = tail call i32 %fptr1(ptr nonnull %obj, i32 %a)

  %fptr22 = load ptr, ptr %vtable, align 8

  ;; We still have to call it as virtual.
  ; CHECK-IR: %call3 = tail call i32 %fptr22
  ; CHECK-AONLY-IR: %call3 = tail call i32 %fptr22
  ; CHECK-NODEVIRT-IR: %call3 = tail call i32 %fptr22
  %call3 = tail call i32 %fptr22(ptr nonnull %obj, i32 %call)

  %vtable2 = load ptr, ptr %obj2
  %p2 = call i1 @llvm.type.test(ptr %vtable2, metadata !4)
  call void @llvm.assume(i1 %p2)

  %fptr33 = load ptr, ptr %vtable2, align 8

  ;; Check that the call was devirtualized.
  ; CHECK-IR: %call4 = tail call i32 @_ZN1D1mEi
  ; CHECK-AONLY-IR: %call4 = tail call i32 %fptr33
  ; CHECK-NODEVIRT-IR: %call4 = tail call i32 %fptr33
  %call4 = tail call i32 %fptr33(ptr nonnull %obj2, i32 %call3)
  ret i32 %call4
}
; CHECK-IR-LABEL: ret i32
; CHECK-IR-LABEL: }

declare i1 @llvm.type.test(ptr, metadata)
declare void @llvm.assume(i1)

define i32 @_ZN1B1fEi(ptr %this, i32 %a) #0 {
   ret i32 0;
}

define i32 @_ZN1A1nEi(ptr %this, i32 %a) #0 {
   ret i32 0;
}

define i32 @_ZN1C1fEi(ptr %this, i32 %a) #0 {
   ret i32 0;
}

define i32 @_ZN1D1mEi(ptr %this, i32 %a) #0 {
   ret i32 0;
}

;; Make sure we don't inline or otherwise optimize out the direct calls.
attributes #0 = { noinline optnone }

!0 = !{i64 16, !"_ZTS1A"}
!1 = !{i64 16, !"_ZTS1B"}
!2 = !{i64 16, !"_ZTS1C"}
!3 = !{i64 16, !4}
!4 = distinct !{}
!5 = !{i64 0}
