source_filename = "lifted_code"
target datalayout = "E-m:e-p:32:32-i64:64-f128:64-n32-S64"
target triple = "sparc-pc-linux-gnu-elf"

%struct.State = type { %struct.SPARC32State }
%struct.SPARC32State = type { %struct.ArchState, i64, %struct.FPURegs, i64, %struct.GPR, i64, %struct.FSRReg, i64, %struct.ASR, i32, %struct.CCRFlags, i32, %struct.PSR, i32, %struct.Reg, i32, %struct.Reg, i8, i8, i8, i8 }
%struct.ArchState = type { i32, i32, %union.anon }
%union.anon = type { i64 }
%struct.FPURegs = type { [8 x %union.vec128_t] }
%union.vec128_t = type { %struct.uint64v2_t }
%struct.uint64v2_t = type { [2 x i64] }
%struct.GPR = type { %struct.DoubleReg, i64, %struct.DoubleReg, i64, %struct.DoubleReg, i64, %struct.DoubleReg, i64, i64, %struct.DoubleReg, i64, %struct.DoubleReg, i64, %struct.DoubleReg, i64, %struct.DoubleReg, i64, %struct.DoubleReg, i64, %struct.DoubleReg, i64, %struct.DoubleReg, i64, %struct.DoubleReg, i64, %struct.DoubleReg, i64, %struct.DoubleReg, i64, %struct.DoubleReg, i64, %struct.DoubleReg }
%struct.DoubleReg = type { %union.anon }
%struct.FSRReg = type { i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8, i8 }
%struct.ASR = type { i32, %struct.Reg, i32, %struct.Reg, i32, %struct.Reg, i32, %struct.Reg, i32, %struct.Reg, i32, %struct.Reg, i32, %struct.Reg, i32, %struct.Reg, i32, %struct.Reg, i32, %struct.Reg, i32, %struct.Reg, i32, %struct.Reg, i32 }
%struct.CCRFlags = type { %struct.anon.1, %struct.anon.1 }
%struct.anon.1 = type { i8, i8, i8, i8, i8, i8, i8, i8 }
%struct.PSR = type <{ i64, i64, i64, i64, i64, i8, i8, i8, %union.anon.3, i8, i8, i8, i8, i8, i8, i8, i8, i8, %union.anon.5, i8 }>
%union.anon.3 = type { i16 }
%union.anon.5 = type { i8 }
%struct.Reg = type { i32 }

@__anvill_reg_CWP = external global i32
@__anvill_reg_I0_1 = external global i64
@__anvill_reg_I2_3 = external global i64
@__anvill_reg_I4_5 = external global i64
@__anvill_reg_FP_7 = external global i64
@__anvill_reg_L0_1 = external global i64
@__anvill_reg_L2_3 = external global i64
@__anvill_reg_L4_5 = external global i64
@__anvill_reg_L6_7 = external global i64
@__anvill_reg_O2_3 = external global i64
@__anvill_reg_O4_5 = external global i64
@__anvill_reg_G0_1 = external global i64
@__anvill_reg_G2_3 = external global i64
@__anvill_reg_G4_5 = external global i64
@__anvill_reg_G6_7 = external global i64
@__anvill_reg_Y = external global i32
@__anvill_reg_TICK = external global i32
@__anvill_reg_CCR = external global i32
@__anvill_reg_PCR = external global i32
@__anvill_reg_PIC = external global i32
@__anvill_reg_GSR = external global i32
@__anvill_reg_SOFTINT_SET = external global i32
@__anvill_reg_SOFTINT_CLR = external global i32
@__anvill_reg_SOFTINT = external global i32
@__anvill_reg_TICK_CMPR = external global i32
@__anvill_reg_STICK = external global i32
@__anvill_reg_STICK_CMPR = external global i32
@__anvill_reg_I_CF = external global i8
@__anvill_reg_I_VF = external global i8
@__anvill_reg_I_ZF = external global i8
@__anvill_reg_I_NF = external global i8
@__anvill_reg_X_CF = external global i8
@__anvill_reg_X_VF = external global i8
@__anvill_reg_X_ZF = external global i8
@__anvill_reg_X_NF = external global i8
@__anvill_reg_ccf_fcc0 = external global i8
@__anvill_reg_ccf_fcc1 = external global i8
@__anvill_reg_ccf_fcc2 = external global i8
@__anvill_reg_ccf_fcc3 = external global i8
@__anvill_reg_fsr_aexc = external global i8
@__anvill_reg_fsr_cexc = external global i8
@__anvill_reg_FQ0 = external global i128
@__anvill_reg_FQ4 = external global i128
@__anvill_reg_FQ8 = external global i128
@__anvill_reg_FQ12 = external global i128
@__anvill_reg_FQ16 = external global i128
@__anvill_reg_FQ20 = external global i128
@__anvill_reg_FQ24 = external global i128
@__anvill_reg_FQ28 = external global i128
@__anvill_reg_DECOMPILE_MODE = external global i8
@__anvill_reg_DIDRESTORE = external global i8
@__anvill_sp = external global i64
@__anvill_ra = external global i32
@__anvill_pc = external global i32
@llvm.compiler.used = appending global [1 x ptr] [ptr @add], section "llvm.metadata"

; Function Attrs: noinline
define i32 @add(i32 %0, i32 %1) #0 !pc !0 {
  %3 = alloca %struct.State, align 8, !pc !0
  store i32 0, ptr %3, align 8
  %4 = getelementptr inbounds i8, ptr %3, i32 4
  store i32 0, ptr %4, align 4
  %5 = getelementptr inbounds i8, ptr %3, i32 8
  store i64 0, ptr %5, align 8
  %6 = getelementptr inbounds i8, ptr %3, i32 16
  store i64 0, ptr %6, align 8
  %7 = getelementptr inbounds i8, ptr %3, i32 24
  store i64 0, ptr %7, align 8
  %8 = getelementptr inbounds i8, ptr %3, i32 32
  store i64 0, ptr %8, align 8
  %9 = getelementptr inbounds i8, ptr %3, i32 40
  store i64 0, ptr %9, align 8
  %10 = getelementptr inbounds i8, ptr %3, i32 48
  store i64 0, ptr %10, align 8
  %11 = getelementptr inbounds i8, ptr %3, i32 56
  store i64 0, ptr %11, align 8
  %12 = getelementptr inbounds i8, ptr %3, i32 64
  store i64 0, ptr %12, align 8
  %13 = getelementptr inbounds i8, ptr %3, i32 72
  store i64 0, ptr %13, align 8
  %14 = getelementptr inbounds i8, ptr %3, i32 80
  store i64 0, ptr %14, align 8
  %15 = getelementptr inbounds i8, ptr %3, i32 88
  store i64 0, ptr %15, align 8
  %16 = getelementptr inbounds i8, ptr %3, i32 96
  store i64 0, ptr %16, align 8
  %17 = getelementptr inbounds i8, ptr %3, i32 104
  store i64 0, ptr %17, align 8
  %18 = getelementptr inbounds i8, ptr %3, i32 112
  store i64 0, ptr %18, align 8
  %19 = getelementptr inbounds i8, ptr %3, i32 120
  store i64 0, ptr %19, align 8
  %20 = getelementptr inbounds i8, ptr %3, i32 128
  store i64 0, ptr %20, align 8
  %21 = getelementptr inbounds i8, ptr %3, i32 136
  store i64 0, ptr %21, align 8
  %22 = getelementptr inbounds i8, ptr %3, i32 144
  store i64 0, ptr %22, align 8
  %23 = getelementptr inbounds i8, ptr %3, i32 152
  store i64 0, ptr %23, align 8
  %24 = getelementptr inbounds i8, ptr %3, i32 160
  store i64 0, ptr %24, align 8
  %25 = getelementptr inbounds i8, ptr %3, i32 168
  store i64 0, ptr %25, align 8
  %26 = getelementptr inbounds i8, ptr %3, i32 176
  store i64 0, ptr %26, align 8
  %27 = getelementptr inbounds i8, ptr %3, i32 184
  store i64 0, ptr %27, align 8
  %28 = getelementptr inbounds i8, ptr %3, i32 192
  store i64 0, ptr %28, align 8
  %29 = getelementptr inbounds i8, ptr %3, i32 200
  store i64 0, ptr %29, align 8
  %30 = getelementptr inbounds i8, ptr %3, i32 208
  store i64 0, ptr %30, align 8
  %31 = getelementptr inbounds i8, ptr %3, i32 216
  store i64 0, ptr %31, align 8
  %32 = getelementptr inbounds i8, ptr %3, i32 224
  store i64 0, ptr %32, align 8
  %33 = getelementptr inbounds i8, ptr %3, i32 232
  store i64 0, ptr %33, align 8
  %34 = getelementptr inbounds i8, ptr %3, i32 240
  store i64 0, ptr %34, align 8
  %35 = getelementptr inbounds i8, ptr %3, i32 248
  store i64 0, ptr %35, align 8
  %36 = getelementptr inbounds i8, ptr %3, i32 256
  store i64 0, ptr %36, align 8
  %37 = getelementptr inbounds i8, ptr %3, i32 264
  store i64 0, ptr %37, align 8
  %38 = getelementptr inbounds i8, ptr %3, i32 272
  store i64 0, ptr %38, align 8
  %39 = getelementptr inbounds i8, ptr %3, i32 280
  store i64 0, ptr %39, align 8
  %40 = getelementptr inbounds i8, ptr %3, i32 288
  store i64 0, ptr %40, align 8
  %41 = getelementptr inbounds i8, ptr %3, i32 296
  store i64 0, ptr %41, align 8
  %42 = getelementptr inbounds i8, ptr %3, i32 304
  store i64 0, ptr %42, align 8
  %43 = getelementptr inbounds i8, ptr %3, i32 312
  store i64 0, ptr %43, align 8
  %44 = getelementptr inbounds i8, ptr %3, i32 320
  store i64 0, ptr %44, align 8
  %45 = getelementptr inbounds i8, ptr %3, i32 328
  store i64 0, ptr %45, align 8
  %46 = getelementptr inbounds i8, ptr %3, i32 336
  store i64 0, ptr %46, align 8
  %47 = getelementptr inbounds i8, ptr %3, i32 344
  store i64 0, ptr %47, align 8
  %48 = getelementptr inbounds i8, ptr %3, i32 352
  store i64 0, ptr %48, align 8
  %49 = getelementptr inbounds i8, ptr %3, i32 360
  store i64 0, ptr %49, align 8
  %50 = getelementptr inbounds i8, ptr %3, i32 368
  store i64 0, ptr %50, align 8
  %51 = getelementptr inbounds i8, ptr %3, i32 376
  store i64 0, ptr %51, align 8
  %52 = getelementptr inbounds i8, ptr %3, i32 384
  store i64 0, ptr %52, align 8
  %53 = getelementptr inbounds i8, ptr %3, i32 392
  store i64 0, ptr %53, align 8
  %54 = getelementptr inbounds i8, ptr %3, i32 400
  store i64 0, ptr %54, align 8
  %55 = getelementptr inbounds i8, ptr %3, i32 408
  store i64 0, ptr %55, align 8
  %56 = getelementptr inbounds i8, ptr %3, i32 416
  store i64 0, ptr %56, align 8
  %57 = getelementptr inbounds i8, ptr %3, i32 424
  store i8 0, ptr %57, align 8
  %58 = getelementptr inbounds i8, ptr %3, i32 425
  store i8 0, ptr %58, align 1
  %59 = getelementptr inbounds i8, ptr %3, i32 426
  store i8 0, ptr %59, align 2
  %60 = getelementptr inbounds i8, ptr %3, i32 427
  store i8 0, ptr %60, align 1
  %61 = getelementptr inbounds i8, ptr %3, i32 428
  store i8 0, ptr %61, align 4
  %62 = getelementptr inbounds i8, ptr %3, i32 429
  store i8 0, ptr %62, align 1
  %63 = getelementptr inbounds i8, ptr %3, i32 430
  store i8 0, ptr %63, align 2
  %64 = getelementptr inbounds i8, ptr %3, i32 431
  store i8 0, ptr %64, align 1
  %65 = getelementptr inbounds i8, ptr %3, i32 432
  store i8 0, ptr %65, align 8
  %66 = getelementptr inbounds i8, ptr %3, i32 433
  store i8 0, ptr %66, align 1
  %67 = getelementptr inbounds i8, ptr %3, i32 434
  store i8 0, ptr %67, align 2
  %68 = getelementptr inbounds i8, ptr %3, i32 435
  store i8 0, ptr %68, align 1
  %69 = getelementptr inbounds i8, ptr %3, i32 436
  store i8 0, ptr %69, align 4
  %70 = getelementptr inbounds i8, ptr %3, i32 437
  store i8 0, ptr %70, align 1
  %71 = getelementptr inbounds i8, ptr %3, i32 438
  store i8 0, ptr %71, align 2
  %72 = getelementptr inbounds i8, ptr %3, i32 439
  store i8 0, ptr %72, align 1
  %73 = getelementptr inbounds i8, ptr %3, i32 440
  store i8 0, ptr %73, align 8
  %74 = getelementptr inbounds i8, ptr %3, i32 441
  store i8 0, ptr %74, align 1
  %75 = getelementptr inbounds i8, ptr %3, i32 442
  store i8 0, ptr %75, align 2
  %76 = getelementptr inbounds i8, ptr %3, i32 443
  store i8 0, ptr %76, align 1
  %77 = getelementptr inbounds i8, ptr %3, i32 444
  store i8 0, ptr %77, align 4
  %78 = getelementptr inbounds i8, ptr %3, i32 445
  store i8 0, ptr %78, align 1
  %79 = getelementptr inbounds i8, ptr %3, i32 446
  store i8 0, ptr %79, align 2
  %80 = getelementptr inbounds i8, ptr %3, i32 447
  store i8 0, ptr %80, align 1
  %81 = getelementptr inbounds i8, ptr %3, i32 448
  store i64 0, ptr %81, align 8
  %82 = getelementptr inbounds i8, ptr %3, i32 456
  store i32 0, ptr %82, align 8
  %83 = getelementptr inbounds i8, ptr %3, i32 460
  store i32 0, ptr %83, align 4
  %84 = getelementptr inbounds i8, ptr %3, i32 464
  store i32 0, ptr %84, align 8
  %85 = getelementptr inbounds i8, ptr %3, i32 468
  store i32 0, ptr %85, align 4
  %86 = getelementptr inbounds i8, ptr %3, i32 472
  store i32 0, ptr %86, align 8
  %87 = getelementptr inbounds i8, ptr %3, i32 476
  store i32 0, ptr %87, align 4
  %88 = getelementptr inbounds i8, ptr %3, i32 480
  store i32 0, ptr %88, align 8
  %89 = getelementptr inbounds i8, ptr %3, i32 484
  store i32 0, ptr %89, align 4
  %90 = getelementptr inbounds i8, ptr %3, i32 488
  store i32 0, ptr %90, align 8
  %91 = getelementptr inbounds i8, ptr %3, i32 492
  store i32 0, ptr %91, align 4
  %92 = getelementptr inbounds i8, ptr %3, i32 496
  store i32 0, ptr %92, align 8
  %93 = getelementptr inbounds i8, ptr %3, i32 500
  store i32 0, ptr %93, align 4
  %94 = getelementptr inbounds i8, ptr %3, i32 504
  store i32 0, ptr %94, align 8
  %95 = getelementptr inbounds i8, ptr %3, i32 508
  store i32 0, ptr %95, align 4
  %96 = getelementptr inbounds i8, ptr %3, i32 512
  store i32 0, ptr %96, align 8
  %97 = getelementptr inbounds i8, ptr %3, i32 516
  store i32 0, ptr %97, align 4
  %98 = getelementptr inbounds i8, ptr %3, i32 520
  store i32 0, ptr %98, align 8
  %99 = getelementptr inbounds i8, ptr %3, i32 524
  store i32 0, ptr %99, align 4
  %100 = getelementptr inbounds i8, ptr %3, i32 528
  store i32 0, ptr %100, align 8
  %101 = getelementptr inbounds i8, ptr %3, i32 532
  store i32 0, ptr %101, align 4
  %102 = getelementptr inbounds i8, ptr %3, i32 536
  store i32 0, ptr %102, align 8
  %103 = getelementptr inbounds i8, ptr %3, i32 540
  store i32 0, ptr %103, align 4
  %104 = getelementptr inbounds i8, ptr %3, i32 544
  store i32 0, ptr %104, align 8
  %105 = getelementptr inbounds i8, ptr %3, i32 548
  store i32 0, ptr %105, align 4
  %106 = getelementptr inbounds i8, ptr %3, i32 552
  store i32 0, ptr %106, align 8
  %107 = getelementptr inbounds i8, ptr %3, i32 556
  store i32 0, ptr %107, align 4
  %108 = getelementptr inbounds i8, ptr %3, i32 560
  store i8 0, ptr %108, align 8
  %109 = getelementptr inbounds i8, ptr %3, i32 561
  store i8 0, ptr %109, align 1
  %110 = getelementptr inbounds i8, ptr %3, i32 562
  store i8 0, ptr %110, align 2
  %111 = getelementptr inbounds i8, ptr %3, i32 563
  store i8 0, ptr %111, align 1
  %112 = getelementptr inbounds i8, ptr %3, i32 564
  store i8 0, ptr %112, align 4
  %113 = getelementptr inbounds i8, ptr %3, i32 565
  store i8 0, ptr %113, align 1
  %114 = getelementptr inbounds i8, ptr %3, i32 566
  store i8 0, ptr %114, align 2
  %115 = getelementptr inbounds i8, ptr %3, i32 567
  store i8 0, ptr %115, align 1
  %116 = getelementptr inbounds i8, ptr %3, i32 568
  store i8 0, ptr %116, align 8
  %117 = getelementptr inbounds i8, ptr %3, i32 569
  store i8 0, ptr %117, align 1
  %118 = getelementptr inbounds i8, ptr %3, i32 570
  store i8 0, ptr %118, align 2
  %119 = getelementptr inbounds i8, ptr %3, i32 571
  store i8 0, ptr %119, align 1
  %120 = getelementptr inbounds i8, ptr %3, i32 572
  store i8 0, ptr %120, align 4
  %121 = getelementptr inbounds i8, ptr %3, i32 573
  store i8 0, ptr %121, align 1
  %122 = getelementptr inbounds i8, ptr %3, i32 574
  store i8 0, ptr %122, align 2
  %123 = getelementptr inbounds i8, ptr %3, i32 575
  store i8 0, ptr %123, align 1
  %124 = getelementptr inbounds i8, ptr %3, i32 576
  store i32 0, ptr %124, align 8
  %125 = getelementptr inbounds i8, ptr %3, i32 580
  store i64 0, ptr %125, align 4
  %126 = getelementptr inbounds i8, ptr %3, i32 588
  store i64 0, ptr %126, align 4
  %127 = getelementptr inbounds i8, ptr %3, i32 596
  store i64 0, ptr %127, align 4
  %128 = getelementptr inbounds i8, ptr %3, i32 604
  store i64 0, ptr %128, align 4
  %129 = getelementptr inbounds i8, ptr %3, i32 612
  store i64 0, ptr %129, align 4
  %130 = getelementptr inbounds i8, ptr %3, i32 620
  store i8 0, ptr %130, align 4
  %131 = getelementptr inbounds i8, ptr %3, i32 621
  store i8 0, ptr %131, align 1
  %132 = getelementptr inbounds i8, ptr %3, i32 622
  store i8 0, ptr %132, align 2
  %133 = getelementptr inbounds i8, ptr %3, i32 623
  store i16 0, ptr %133, align 1
  %134 = getelementptr inbounds i8, ptr %3, i32 625
  store i8 0, ptr %134, align 1
  %135 = getelementptr inbounds i8, ptr %3, i32 626
  store i8 0, ptr %135, align 2
  %136 = getelementptr inbounds i8, ptr %3, i32 627
  store i8 0, ptr %136, align 1
  %137 = getelementptr inbounds i8, ptr %3, i32 628
  store i8 0, ptr %137, align 4
  %138 = getelementptr inbounds i8, ptr %3, i32 629
  store i8 0, ptr %138, align 1
  %139 = getelementptr inbounds i8, ptr %3, i32 630
  store i8 0, ptr %139, align 2
  %140 = getelementptr inbounds i8, ptr %3, i32 631
  store i8 0, ptr %140, align 1
  %141 = getelementptr inbounds i8, ptr %3, i32 632
  store i8 0, ptr %141, align 8
  %142 = getelementptr inbounds i8, ptr %3, i32 633
  store i8 0, ptr %142, align 1
  %143 = getelementptr inbounds i8, ptr %3, i32 634
  store i8 0, ptr %143, align 2
  %144 = getelementptr inbounds i8, ptr %3, i32 635
  store i8 0, ptr %144, align 1
  %145 = getelementptr inbounds i8, ptr %3, i32 636
  store i32 0, ptr %145, align 4
  %146 = getelementptr inbounds i8, ptr %3, i32 640
  store i32 0, ptr %146, align 8
  %147 = getelementptr inbounds i8, ptr %3, i32 644
  store i32 0, ptr %147, align 4
  %148 = getelementptr inbounds i8, ptr %3, i32 648
  store i32 0, ptr %148, align 8
  %149 = getelementptr inbounds i8, ptr %3, i32 652
  store i8 0, ptr %149, align 4
  %150 = getelementptr inbounds i8, ptr %3, i32 653
  store i8 0, ptr %150, align 1
  %151 = getelementptr inbounds i8, ptr %3, i32 654
  store i8 0, ptr %151, align 2
  %152 = getelementptr inbounds i8, ptr %3, i32 655
  store i8 0, ptr %152, align 1
  %153 = getelementptr inbounds i8, ptr %3, i32 648
  %154 = load i32, ptr @__anvill_reg_CWP, align 4, !pc !0
  store i32 %154, ptr %153, align 4, !pc !0
  %155 = getelementptr inbounds i8, ptr %3, i32 160
  %156 = load i64, ptr @__anvill_reg_I0_1, align 8, !pc !0
  store i64 %156, ptr %155, align 8, !pc !0
  %157 = getelementptr inbounds i8, ptr %3, i32 176
  %158 = load i64, ptr @__anvill_reg_I2_3, align 8, !pc !0
  store i64 %158, ptr %157, align 8, !pc !0
  %159 = getelementptr inbounds i8, ptr %3, i32 192
  %160 = load i64, ptr @__anvill_reg_I4_5, align 8, !pc !0
  store i64 %160, ptr %159, align 8, !pc !0
  %161 = getelementptr inbounds i8, ptr %3, i32 208
  %162 = load i64, ptr @__anvill_reg_FP_7, align 8, !pc !0
  store i64 %162, ptr %161, align 8, !pc !0
  %163 = getelementptr inbounds i8, ptr %3, i32 232
  %164 = load i64, ptr @__anvill_reg_L0_1, align 8, !pc !0
  store i64 %164, ptr %163, align 8, !pc !0
  %165 = getelementptr inbounds i8, ptr %3, i32 248
  %166 = load i64, ptr @__anvill_reg_L2_3, align 8, !pc !0
  store i64 %166, ptr %165, align 8, !pc !0
  %167 = getelementptr inbounds i8, ptr %3, i32 264
  %168 = load i64, ptr @__anvill_reg_L4_5, align 8, !pc !0
  store i64 %168, ptr %167, align 8, !pc !0
  %169 = getelementptr inbounds i8, ptr %3, i32 280
  %170 = load i64, ptr @__anvill_reg_L6_7, align 8, !pc !0
  store i64 %170, ptr %169, align 8, !pc !0
  %171 = getelementptr inbounds i8, ptr %3, i32 312
  %172 = load i64, ptr @__anvill_reg_O2_3, align 8, !pc !0
  store i64 %172, ptr %171, align 8, !pc !0
  %173 = getelementptr inbounds i8, ptr %3, i32 328
  %174 = load i64, ptr @__anvill_reg_O4_5, align 8, !pc !0
  store i64 %174, ptr %173, align 8, !pc !0
  %175 = getelementptr inbounds i8, ptr %3, i32 360
  %176 = load i64, ptr @__anvill_reg_G0_1, align 8, !pc !0
  store i64 %176, ptr %175, align 8, !pc !0
  %177 = getelementptr inbounds i8, ptr %3, i32 376
  %178 = load i64, ptr @__anvill_reg_G2_3, align 8, !pc !0
  store i64 %178, ptr %177, align 8, !pc !0
  %179 = getelementptr inbounds i8, ptr %3, i32 392
  %180 = load i64, ptr @__anvill_reg_G4_5, align 8, !pc !0
  store i64 %180, ptr %179, align 8, !pc !0
  %181 = getelementptr inbounds i8, ptr %3, i32 408
  %182 = load i64, ptr @__anvill_reg_G6_7, align 8, !pc !0
  store i64 %182, ptr %181, align 8, !pc !0
  %183 = getelementptr inbounds i8, ptr %3, i32 460
  %184 = load i32, ptr @__anvill_reg_Y, align 4, !pc !0
  store i32 %184, ptr %183, align 4, !pc !0
  %185 = getelementptr inbounds i8, ptr %3, i32 476
  %186 = load i32, ptr @__anvill_reg_TICK, align 4, !pc !0
  store i32 %186, ptr %185, align 4, !pc !0
  %187 = getelementptr inbounds i8, ptr %3, i32 468
  %188 = load i32, ptr @__anvill_reg_CCR, align 4, !pc !0
  store i32 %188, ptr %187, align 4, !pc !0
  %189 = getelementptr inbounds i8, ptr %3, i32 484
  %190 = load i32, ptr @__anvill_reg_PCR, align 4, !pc !0
  store i32 %190, ptr %189, align 4, !pc !0
  %191 = getelementptr inbounds i8, ptr %3, i32 492
  %192 = load i32, ptr @__anvill_reg_PIC, align 4, !pc !0
  store i32 %192, ptr %191, align 4, !pc !0
  %193 = getelementptr inbounds i8, ptr %3, i32 500
  %194 = load i32, ptr @__anvill_reg_GSR, align 4, !pc !0
  store i32 %194, ptr %193, align 4, !pc !0
  %195 = getelementptr inbounds i8, ptr %3, i32 508
  %196 = load i32, ptr @__anvill_reg_SOFTINT_SET, align 4, !pc !0
  store i32 %196, ptr %195, align 4, !pc !0
  %197 = getelementptr inbounds i8, ptr %3, i32 516
  %198 = load i32, ptr @__anvill_reg_SOFTINT_CLR, align 4, !pc !0
  store i32 %198, ptr %197, align 4, !pc !0
  %199 = getelementptr inbounds i8, ptr %3, i32 524
  %200 = load i32, ptr @__anvill_reg_SOFTINT, align 4, !pc !0
  store i32 %200, ptr %199, align 4, !pc !0
  %201 = getelementptr inbounds i8, ptr %3, i32 532
  %202 = load i32, ptr @__anvill_reg_TICK_CMPR, align 4, !pc !0
  store i32 %202, ptr %201, align 4, !pc !0
  %203 = getelementptr inbounds i8, ptr %3, i32 540
  %204 = load i32, ptr @__anvill_reg_STICK, align 4, !pc !0
  store i32 %204, ptr %203, align 4, !pc !0
  %205 = getelementptr inbounds i8, ptr %3, i32 548
  %206 = load i32, ptr @__anvill_reg_STICK_CMPR, align 4, !pc !0
  store i32 %206, ptr %205, align 4, !pc !0
  %207 = getelementptr inbounds i8, ptr %3, i32 561
  %208 = load i8, ptr @__anvill_reg_I_CF, align 1, !pc !0
  store i8 %208, ptr %207, align 1, !pc !0
  %209 = getelementptr inbounds i8, ptr %3, i32 563
  %210 = load i8, ptr @__anvill_reg_I_VF, align 1, !pc !0
  store i8 %210, ptr %209, align 1, !pc !0
  %211 = getelementptr inbounds i8, ptr %3, i32 565
  %212 = load i8, ptr @__anvill_reg_I_ZF, align 1, !pc !0
  store i8 %212, ptr %211, align 1, !pc !0
  %213 = getelementptr inbounds i8, ptr %3, i32 567
  %214 = load i8, ptr @__anvill_reg_I_NF, align 1, !pc !0
  store i8 %214, ptr %213, align 1, !pc !0
  %215 = getelementptr inbounds i8, ptr %3, i32 569
  %216 = load i8, ptr @__anvill_reg_X_CF, align 1, !pc !0
  store i8 %216, ptr %215, align 1, !pc !0
  %217 = getelementptr inbounds i8, ptr %3, i32 571
  %218 = load i8, ptr @__anvill_reg_X_VF, align 1, !pc !0
  store i8 %218, ptr %217, align 1, !pc !0
  %219 = getelementptr inbounds i8, ptr %3, i32 573
  %220 = load i8, ptr @__anvill_reg_X_ZF, align 1, !pc !0
  store i8 %220, ptr %219, align 1, !pc !0
  %221 = getelementptr inbounds i8, ptr %3, i32 575
  %222 = load i8, ptr @__anvill_reg_X_NF, align 1, !pc !0
  store i8 %222, ptr %221, align 1, !pc !0
  %223 = getelementptr inbounds i8, ptr %3, i32 429
  %224 = load i8, ptr @__anvill_reg_ccf_fcc0, align 1, !pc !0
  store i8 %224, ptr %223, align 1, !pc !0
  %225 = getelementptr inbounds i8, ptr %3, i32 443
  %226 = load i8, ptr @__anvill_reg_ccf_fcc1, align 1, !pc !0
  store i8 %226, ptr %225, align 1, !pc !0
  %227 = getelementptr inbounds i8, ptr %3, i32 445
  %228 = load i8, ptr @__anvill_reg_ccf_fcc2, align 1, !pc !0
  store i8 %228, ptr %227, align 1, !pc !0
  %229 = getelementptr inbounds i8, ptr %3, i32 447
  %230 = load i8, ptr @__anvill_reg_ccf_fcc3, align 1, !pc !0
  store i8 %230, ptr %229, align 1, !pc !0
  %231 = getelementptr inbounds i8, ptr %3, i32 427
  %232 = load i8, ptr @__anvill_reg_fsr_aexc, align 1, !pc !0
  store i8 %232, ptr %231, align 1, !pc !0
  %233 = getelementptr inbounds i8, ptr %3, i32 425
  %234 = load i8, ptr @__anvill_reg_fsr_cexc, align 1, !pc !0
  store i8 %234, ptr %233, align 1, !pc !0
  %235 = getelementptr inbounds i8, ptr %3, i32 24
  %236 = load i128, ptr @__anvill_reg_FQ0, align 8, !pc !0
  store i128 %236, ptr %235, align 8, !pc !0
  %237 = getelementptr inbounds i8, ptr %3, i32 40
  %238 = load i128, ptr @__anvill_reg_FQ4, align 8, !pc !0
  store i128 %238, ptr %237, align 8, !pc !0
  %239 = getelementptr inbounds i8, ptr %3, i32 56
  %240 = load i128, ptr @__anvill_reg_FQ8, align 8, !pc !0
  store i128 %240, ptr %239, align 8, !pc !0
  %241 = getelementptr inbounds i8, ptr %3, i32 72
  %242 = load i128, ptr @__anvill_reg_FQ12, align 8, !pc !0
  store i128 %242, ptr %241, align 8, !pc !0
  %243 = getelementptr inbounds i8, ptr %3, i32 88
  %244 = load i128, ptr @__anvill_reg_FQ16, align 8, !pc !0
  store i128 %244, ptr %243, align 8, !pc !0
  %245 = getelementptr inbounds i8, ptr %3, i32 104
  %246 = load i128, ptr @__anvill_reg_FQ20, align 8, !pc !0
  store i128 %246, ptr %245, align 8, !pc !0
  %247 = getelementptr inbounds i8, ptr %3, i32 120
  %248 = load i128, ptr @__anvill_reg_FQ24, align 8, !pc !0
  store i128 %248, ptr %247, align 8, !pc !0
  %249 = getelementptr inbounds i8, ptr %3, i32 136
  %250 = load i128, ptr @__anvill_reg_FQ28, align 8, !pc !0
  store i128 %250, ptr %249, align 8, !pc !0
  %251 = getelementptr inbounds i8, ptr %3, i32 652
  %252 = load i8, ptr @__anvill_reg_DECOMPILE_MODE, align 1, !pc !0
  store i8 %252, ptr %251, align 1, !pc !0
  %253 = getelementptr inbounds i8, ptr %3, i32 654
  %254 = load i8, ptr @__anvill_reg_DIDRESTORE, align 1, !pc !0
  store i8 %254, ptr %253, align 1, !pc !0
  %255 = getelementptr inbounds i8, ptr %3, i32 344
  store i64 ptrtoint (ptr @__anvill_sp to i64), ptr %255, align 8, !pc !0
  %256 = getelementptr inbounds i8, ptr %3, i32 348
  store i32 ptrtoint (ptr @__anvill_ra to i32), ptr %256, align 4, !pc !0
  %257 = getelementptr inbounds i8, ptr %3, i32 296
  store i32 %0, ptr %257, align 4, !pc !0
  %258 = getelementptr inbounds i8, ptr %3, i32 300
  store i32 %1, ptr %258, align 4, !pc !0
  %259 = getelementptr inbounds i8, ptr %3, i32 640
  store i32 add (i32 ptrtoint (ptr @__anvill_pc to i32), i32 4198400), ptr %259, align 4, !pc !0
  %260 = call noundef ptr @__remill_sync_hyper_call(ptr noundef nonnull align 16 dereferenceable(656) %3, ptr noundef null, i32 noundef 1024) #3, !pc !0
  %261 = call ptr @__remill_delay_slot_begin(ptr %260), !pc !1
  %262 = call noundef ptr @__remill_sync_hyper_call(ptr noundef nonnull align 16 dereferenceable(656) %3, ptr noundef %261, i32 noundef 1024) #3, !pc !1
  store i32 add (i32 ptrtoint (ptr @__anvill_pc to i32), i32 4198404), ptr %259, align 4, !pc !1
  %263 = call ptr @__remill_delay_slot_end(ptr %262), !pc !1
  store i32 add (i32 ptrtoint (ptr @__anvill_pc to i32), i32 4198404), ptr %259, align 4, !pc !0
  %264 = call ptr @__remill_function_return(ptr undef, i32 add (i32 ptrtoint (ptr @__anvill_pc to i32), i32 4198404), ptr %263), !pc !0
  %265 = getelementptr inbounds i8, ptr %3, i32 296
  %266 = load i32, ptr %265, align 4, !pc !0
  call void @__anvill_memory_escape(ptr %264)
  ret i32 %266
}

; Function Attrs: mustprogress noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_sync_hyper_call(ptr noundef nonnull align 16 dereferenceable(656), ptr noundef, i32 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_delay_slot_begin(ptr noundef) #2

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_delay_slot_end(ptr noundef) #2

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) #2

declare void @__anvill_memory_escape(ptr)

attributes #0 = { noinline }
attributes #1 = { mustprogress noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #3 = { alwaysinline nobuiltin nounwind "no-builtins" }

!0 = !{i32 4198400}
!1 = !{i32 4198404}
