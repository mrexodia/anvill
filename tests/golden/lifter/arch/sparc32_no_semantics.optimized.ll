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

@__anvill_reg_CWP = external local_unnamed_addr global i32
@__anvill_reg_I0_1 = external local_unnamed_addr global i64
@__anvill_reg_I2_3 = external local_unnamed_addr global i64
@__anvill_reg_I4_5 = external local_unnamed_addr global i64
@__anvill_reg_FP_7 = external local_unnamed_addr global i64
@__anvill_reg_L0_1 = external local_unnamed_addr global i64
@__anvill_reg_L2_3 = external local_unnamed_addr global i64
@__anvill_reg_L4_5 = external local_unnamed_addr global i64
@__anvill_reg_L6_7 = external local_unnamed_addr global i64
@__anvill_reg_O2_3 = external local_unnamed_addr global i64
@__anvill_reg_O4_5 = external local_unnamed_addr global i64
@__anvill_reg_G0_1 = external local_unnamed_addr global i64
@__anvill_reg_G2_3 = external local_unnamed_addr global i64
@__anvill_reg_G4_5 = external local_unnamed_addr global i64
@__anvill_reg_G6_7 = external local_unnamed_addr global i64
@__anvill_reg_Y = external local_unnamed_addr global i32
@__anvill_reg_TICK = external local_unnamed_addr global i32
@__anvill_reg_CCR = external local_unnamed_addr global i32
@__anvill_reg_PCR = external local_unnamed_addr global i32
@__anvill_reg_PIC = external local_unnamed_addr global i32
@__anvill_reg_GSR = external local_unnamed_addr global i32
@__anvill_reg_SOFTINT_SET = external local_unnamed_addr global i32
@__anvill_reg_SOFTINT_CLR = external local_unnamed_addr global i32
@__anvill_reg_SOFTINT = external local_unnamed_addr global i32
@__anvill_reg_TICK_CMPR = external local_unnamed_addr global i32
@__anvill_reg_STICK = external local_unnamed_addr global i32
@__anvill_reg_STICK_CMPR = external local_unnamed_addr global i32
@__anvill_reg_I_CF = external local_unnamed_addr global i8
@__anvill_reg_I_VF = external local_unnamed_addr global i8
@__anvill_reg_I_ZF = external local_unnamed_addr global i8
@__anvill_reg_I_NF = external local_unnamed_addr global i8
@__anvill_reg_X_CF = external local_unnamed_addr global i8
@__anvill_reg_X_VF = external local_unnamed_addr global i8
@__anvill_reg_X_ZF = external local_unnamed_addr global i8
@__anvill_reg_X_NF = external local_unnamed_addr global i8
@__anvill_reg_ccf_fcc0 = external local_unnamed_addr global i8
@__anvill_reg_ccf_fcc1 = external local_unnamed_addr global i8
@__anvill_reg_ccf_fcc2 = external local_unnamed_addr global i8
@__anvill_reg_ccf_fcc3 = external local_unnamed_addr global i8
@__anvill_reg_fsr_aexc = external local_unnamed_addr global i8
@__anvill_reg_fsr_cexc = external local_unnamed_addr global i8
@__anvill_reg_FQ0 = external local_unnamed_addr global i128
@__anvill_reg_FQ4 = external local_unnamed_addr global i128
@__anvill_reg_FQ8 = external local_unnamed_addr global i128
@__anvill_reg_FQ12 = external local_unnamed_addr global i128
@__anvill_reg_FQ16 = external local_unnamed_addr global i128
@__anvill_reg_FQ20 = external local_unnamed_addr global i128
@__anvill_reg_FQ24 = external local_unnamed_addr global i128
@__anvill_reg_FQ28 = external local_unnamed_addr global i128
@__anvill_reg_DECOMPILE_MODE = external local_unnamed_addr global i8
@__anvill_reg_DIDRESTORE = external local_unnamed_addr global i8
@__anvill_ra = external global i32
@__anvill_pc = external global i32
@__anvill_stack_0 = external local_unnamed_addr global i32
@__anvill_stack_plus_4 = external local_unnamed_addr global i32

; Function Attrs: noinline
define i32 @add(i32 %0, i32 %1) local_unnamed_addr #0 !pc !0 {
  %return_address = call ptr @llvm.returnaddress(i32 0), !pc !0
  %3 = ptrtoint ptr %return_address to i32, !pc !0
  %return_address_loc = alloca i32, align 4, !pc !0, !stack_offset !1
  %4 = ptrtoint ptr %return_address_loc to i32, !pc !0
  %5 = zext i32 %4 to i64, !pc !0
  %6 = load i32, ptr @__anvill_stack_0, align 4, !pc !0
  store i32 %6, ptr %return_address_loc, align 4, !pc !0
  %7 = alloca %struct.State, align 8, !pc !0
  store i32 0, ptr %7, align 8, !pc !0
  %8 = getelementptr inbounds i8, ptr %7, i32 4, !pc !0
  store i32 0, ptr %8, align 4, !pc !0
  %9 = getelementptr inbounds i8, ptr %7, i32 8, !pc !0
  store i64 0, ptr %9, align 8, !pc !0
  %10 = getelementptr inbounds i8, ptr %7, i32 16, !pc !0
  store i64 0, ptr %10, align 8, !pc !0
  %11 = getelementptr inbounds i8, ptr %7, i32 24, !pc !0
  store i64 0, ptr %11, align 8, !pc !0
  %12 = getelementptr inbounds i8, ptr %7, i32 32, !pc !0
  store i64 0, ptr %12, align 8, !pc !0
  %13 = getelementptr inbounds i8, ptr %7, i32 40, !pc !0
  store i64 0, ptr %13, align 8, !pc !0
  %14 = getelementptr inbounds i8, ptr %7, i32 48, !pc !0
  store i64 0, ptr %14, align 8, !pc !0
  %15 = getelementptr inbounds i8, ptr %7, i32 56, !pc !0
  store i64 0, ptr %15, align 8, !pc !0
  %16 = getelementptr inbounds i8, ptr %7, i32 64, !pc !0
  store i64 0, ptr %16, align 8, !pc !0
  %17 = getelementptr inbounds i8, ptr %7, i32 72, !pc !0
  store i64 0, ptr %17, align 8, !pc !0
  %18 = getelementptr inbounds i8, ptr %7, i32 80, !pc !0
  store i64 0, ptr %18, align 8, !pc !0
  %19 = getelementptr inbounds i8, ptr %7, i32 88, !pc !0
  store i64 0, ptr %19, align 8, !pc !0
  %20 = getelementptr inbounds i8, ptr %7, i32 96, !pc !0
  store i64 0, ptr %20, align 8, !pc !0
  %21 = getelementptr inbounds i8, ptr %7, i32 104, !pc !0
  store i64 0, ptr %21, align 8, !pc !0
  %22 = getelementptr inbounds i8, ptr %7, i32 112, !pc !0
  store i64 0, ptr %22, align 8, !pc !0
  %23 = getelementptr inbounds i8, ptr %7, i32 120, !pc !0
  store i64 0, ptr %23, align 8, !pc !0
  %24 = getelementptr inbounds i8, ptr %7, i32 128, !pc !0
  store i64 0, ptr %24, align 8, !pc !0
  %25 = getelementptr inbounds i8, ptr %7, i32 136, !pc !0
  store i64 0, ptr %25, align 8, !pc !0
  %26 = getelementptr inbounds i8, ptr %7, i32 144, !pc !0
  store i64 0, ptr %26, align 8, !pc !0
  %27 = getelementptr inbounds i8, ptr %7, i32 152, !pc !0
  store i64 0, ptr %27, align 8, !pc !0
  %28 = getelementptr inbounds i8, ptr %7, i32 160, !pc !0
  store i64 0, ptr %28, align 8, !pc !0
  %29 = getelementptr inbounds i8, ptr %7, i32 168, !pc !0
  store i64 0, ptr %29, align 8, !pc !0
  %30 = getelementptr inbounds i8, ptr %7, i32 176, !pc !0
  store i64 0, ptr %30, align 8, !pc !0
  %31 = getelementptr inbounds i8, ptr %7, i32 184, !pc !0
  store i64 0, ptr %31, align 8, !pc !0
  %32 = getelementptr inbounds i8, ptr %7, i32 192, !pc !0
  store i64 0, ptr %32, align 8, !pc !0
  %33 = getelementptr inbounds i8, ptr %7, i32 200, !pc !0
  store i64 0, ptr %33, align 8, !pc !0
  %34 = getelementptr inbounds i8, ptr %7, i32 208, !pc !0
  store i64 0, ptr %34, align 8, !pc !0
  %35 = getelementptr inbounds i8, ptr %7, i32 216, !pc !0
  store i64 0, ptr %35, align 8, !pc !0
  %36 = getelementptr inbounds i8, ptr %7, i32 224, !pc !0
  store i64 0, ptr %36, align 8, !pc !0
  %37 = getelementptr inbounds i8, ptr %7, i32 232, !pc !0
  store i64 0, ptr %37, align 8, !pc !0
  %38 = getelementptr inbounds i8, ptr %7, i32 240, !pc !0
  store i64 0, ptr %38, align 8, !pc !0
  %39 = getelementptr inbounds i8, ptr %7, i32 248, !pc !0
  store i64 0, ptr %39, align 8, !pc !0
  %40 = getelementptr inbounds i8, ptr %7, i32 256, !pc !0
  store i64 0, ptr %40, align 8, !pc !0
  %41 = getelementptr inbounds i8, ptr %7, i32 264, !pc !0
  store i64 0, ptr %41, align 8, !pc !0
  %42 = getelementptr inbounds i8, ptr %7, i32 272, !pc !0
  store i64 0, ptr %42, align 8, !pc !0
  %43 = getelementptr inbounds i8, ptr %7, i32 280, !pc !0
  store i64 0, ptr %43, align 8, !pc !0
  %44 = getelementptr inbounds i8, ptr %7, i32 288, !pc !0
  store i64 0, ptr %44, align 8, !pc !0
  %45 = getelementptr inbounds i8, ptr %7, i32 296, !pc !0
  store i64 0, ptr %45, align 8, !pc !0
  %46 = getelementptr inbounds i8, ptr %7, i32 304, !pc !0
  store i64 0, ptr %46, align 8, !pc !0
  %47 = getelementptr inbounds i8, ptr %7, i32 312, !pc !0
  store i64 0, ptr %47, align 8, !pc !0
  %48 = getelementptr inbounds i8, ptr %7, i32 320, !pc !0
  store i64 0, ptr %48, align 8, !pc !0
  %49 = getelementptr inbounds i8, ptr %7, i32 328, !pc !0
  store i64 0, ptr %49, align 8, !pc !0
  %50 = getelementptr inbounds i8, ptr %7, i32 336, !pc !0
  store i64 0, ptr %50, align 8, !pc !0
  %51 = getelementptr inbounds i8, ptr %7, i32 344, !pc !0
  store i64 0, ptr %51, align 8, !pc !0
  %52 = getelementptr inbounds i8, ptr %7, i32 352, !pc !0
  store i64 0, ptr %52, align 8, !pc !0
  %53 = getelementptr inbounds i8, ptr %7, i32 360, !pc !0
  store i64 0, ptr %53, align 8, !pc !0
  %54 = getelementptr inbounds i8, ptr %7, i32 368, !pc !0
  store i64 0, ptr %54, align 8, !pc !0
  %55 = getelementptr inbounds i8, ptr %7, i32 376, !pc !0
  store i64 0, ptr %55, align 8, !pc !0
  %56 = getelementptr inbounds i8, ptr %7, i32 384, !pc !0
  store i64 0, ptr %56, align 8, !pc !0
  %57 = getelementptr inbounds i8, ptr %7, i32 392, !pc !0
  store i64 0, ptr %57, align 8, !pc !0
  %58 = getelementptr inbounds i8, ptr %7, i32 400, !pc !0
  store i64 0, ptr %58, align 8, !pc !0
  %59 = getelementptr inbounds i8, ptr %7, i32 408, !pc !0
  store i64 0, ptr %59, align 8, !pc !0
  %60 = getelementptr inbounds i8, ptr %7, i32 416, !pc !0
  store i64 0, ptr %60, align 8, !pc !0
  %61 = getelementptr inbounds i8, ptr %7, i32 424, !pc !0
  store i8 0, ptr %61, align 8, !pc !0
  %62 = getelementptr inbounds i8, ptr %7, i32 425, !pc !0
  store i8 0, ptr %62, align 1, !pc !0
  %63 = getelementptr inbounds i8, ptr %7, i32 426, !pc !0
  store i8 0, ptr %63, align 2, !pc !0
  %64 = getelementptr inbounds i8, ptr %7, i32 427, !pc !0
  store i8 0, ptr %64, align 1, !pc !0
  %65 = getelementptr inbounds i8, ptr %7, i32 428, !pc !0
  store i8 0, ptr %65, align 4, !pc !0
  %66 = getelementptr inbounds i8, ptr %7, i32 429, !pc !0
  store i8 0, ptr %66, align 1, !pc !0
  %67 = getelementptr inbounds i8, ptr %7, i32 430, !pc !0
  store i8 0, ptr %67, align 2, !pc !0
  %68 = getelementptr inbounds i8, ptr %7, i32 431, !pc !0
  store i8 0, ptr %68, align 1, !pc !0
  %69 = getelementptr inbounds i8, ptr %7, i32 432, !pc !0
  store i8 0, ptr %69, align 8, !pc !0
  %70 = getelementptr inbounds i8, ptr %7, i32 433, !pc !0
  store i8 0, ptr %70, align 1, !pc !0
  %71 = getelementptr inbounds i8, ptr %7, i32 434, !pc !0
  store i8 0, ptr %71, align 2, !pc !0
  %72 = getelementptr inbounds i8, ptr %7, i32 435, !pc !0
  store i8 0, ptr %72, align 1, !pc !0
  %73 = getelementptr inbounds i8, ptr %7, i32 436, !pc !0
  store i8 0, ptr %73, align 4, !pc !0
  %74 = getelementptr inbounds i8, ptr %7, i32 437, !pc !0
  store i8 0, ptr %74, align 1, !pc !0
  %75 = getelementptr inbounds i8, ptr %7, i32 438, !pc !0
  store i8 0, ptr %75, align 2, !pc !0
  %76 = getelementptr inbounds i8, ptr %7, i32 439, !pc !0
  store i8 0, ptr %76, align 1, !pc !0
  %77 = getelementptr inbounds i8, ptr %7, i32 440, !pc !0
  store i8 0, ptr %77, align 8, !pc !0
  %78 = getelementptr inbounds i8, ptr %7, i32 441, !pc !0
  store i8 0, ptr %78, align 1, !pc !0
  %79 = getelementptr inbounds i8, ptr %7, i32 442, !pc !0
  store i8 0, ptr %79, align 2, !pc !0
  %80 = getelementptr inbounds i8, ptr %7, i32 443, !pc !0
  store i8 0, ptr %80, align 1, !pc !0
  %81 = getelementptr inbounds i8, ptr %7, i32 444, !pc !0
  store i8 0, ptr %81, align 4, !pc !0
  %82 = getelementptr inbounds i8, ptr %7, i32 445, !pc !0
  store i8 0, ptr %82, align 1, !pc !0
  %83 = getelementptr inbounds i8, ptr %7, i32 446, !pc !0
  store i8 0, ptr %83, align 2, !pc !0
  %84 = getelementptr inbounds i8, ptr %7, i32 447, !pc !0
  store i8 0, ptr %84, align 1, !pc !0
  %85 = getelementptr inbounds i8, ptr %7, i32 448, !pc !0
  store i64 0, ptr %85, align 8, !pc !0
  %86 = getelementptr inbounds i8, ptr %7, i32 456, !pc !0
  store i32 0, ptr %86, align 8, !pc !0
  %87 = getelementptr inbounds i8, ptr %7, i32 460, !pc !0
  store i32 0, ptr %87, align 4, !pc !0
  %88 = getelementptr inbounds i8, ptr %7, i32 464, !pc !0
  store i32 0, ptr %88, align 8, !pc !0
  %89 = getelementptr inbounds i8, ptr %7, i32 468, !pc !0
  store i32 0, ptr %89, align 4, !pc !0
  %90 = getelementptr inbounds i8, ptr %7, i32 472, !pc !0
  store i32 0, ptr %90, align 8, !pc !0
  %91 = getelementptr inbounds i8, ptr %7, i32 476, !pc !0
  store i32 0, ptr %91, align 4, !pc !0
  %92 = getelementptr inbounds i8, ptr %7, i32 480, !pc !0
  store i32 0, ptr %92, align 8, !pc !0
  %93 = getelementptr inbounds i8, ptr %7, i32 484, !pc !0
  store i32 0, ptr %93, align 4, !pc !0
  %94 = getelementptr inbounds i8, ptr %7, i32 488, !pc !0
  store i32 0, ptr %94, align 8, !pc !0
  %95 = getelementptr inbounds i8, ptr %7, i32 492, !pc !0
  store i32 0, ptr %95, align 4, !pc !0
  %96 = getelementptr inbounds i8, ptr %7, i32 496, !pc !0
  store i32 0, ptr %96, align 8, !pc !0
  %97 = getelementptr inbounds i8, ptr %7, i32 500, !pc !0
  store i32 0, ptr %97, align 4, !pc !0
  %98 = getelementptr inbounds i8, ptr %7, i32 504, !pc !0
  store i32 0, ptr %98, align 8, !pc !0
  %99 = getelementptr inbounds i8, ptr %7, i32 508, !pc !0
  store i32 0, ptr %99, align 4, !pc !0
  %100 = getelementptr inbounds i8, ptr %7, i32 512, !pc !0
  store i32 0, ptr %100, align 8, !pc !0
  %101 = getelementptr inbounds i8, ptr %7, i32 516, !pc !0
  store i32 0, ptr %101, align 4, !pc !0
  %102 = getelementptr inbounds i8, ptr %7, i32 520, !pc !0
  store i32 0, ptr %102, align 8, !pc !0
  %103 = getelementptr inbounds i8, ptr %7, i32 524, !pc !0
  store i32 0, ptr %103, align 4, !pc !0
  %104 = getelementptr inbounds i8, ptr %7, i32 528, !pc !0
  store i32 0, ptr %104, align 8, !pc !0
  %105 = getelementptr inbounds i8, ptr %7, i32 532, !pc !0
  store i32 0, ptr %105, align 4, !pc !0
  %106 = getelementptr inbounds i8, ptr %7, i32 536, !pc !0
  store i32 0, ptr %106, align 8, !pc !0
  %107 = getelementptr inbounds i8, ptr %7, i32 540, !pc !0
  store i32 0, ptr %107, align 4, !pc !0
  %108 = getelementptr inbounds i8, ptr %7, i32 544, !pc !0
  store i32 0, ptr %108, align 8, !pc !0
  %109 = getelementptr inbounds i8, ptr %7, i32 548, !pc !0
  store i32 0, ptr %109, align 4, !pc !0
  %110 = getelementptr inbounds i8, ptr %7, i32 552, !pc !0
  store i32 0, ptr %110, align 8, !pc !0
  %111 = getelementptr inbounds i8, ptr %7, i32 556, !pc !0
  store i32 0, ptr %111, align 4, !pc !0
  %112 = getelementptr inbounds i8, ptr %7, i32 560, !pc !0
  store i8 0, ptr %112, align 8, !pc !0
  %113 = getelementptr inbounds i8, ptr %7, i32 561, !pc !0
  store i8 0, ptr %113, align 1, !pc !0
  %114 = getelementptr inbounds i8, ptr %7, i32 562, !pc !0
  store i8 0, ptr %114, align 2, !pc !0
  %115 = getelementptr inbounds i8, ptr %7, i32 563, !pc !0
  store i8 0, ptr %115, align 1, !pc !0
  %116 = getelementptr inbounds i8, ptr %7, i32 564, !pc !0
  store i8 0, ptr %116, align 4, !pc !0
  %117 = getelementptr inbounds i8, ptr %7, i32 565, !pc !0
  store i8 0, ptr %117, align 1, !pc !0
  %118 = getelementptr inbounds i8, ptr %7, i32 566, !pc !0
  store i8 0, ptr %118, align 2, !pc !0
  %119 = getelementptr inbounds i8, ptr %7, i32 567, !pc !0
  store i8 0, ptr %119, align 1, !pc !0
  %120 = getelementptr inbounds i8, ptr %7, i32 568, !pc !0
  store i8 0, ptr %120, align 8, !pc !0
  %121 = getelementptr inbounds i8, ptr %7, i32 569, !pc !0
  store i8 0, ptr %121, align 1, !pc !0
  %122 = getelementptr inbounds i8, ptr %7, i32 570, !pc !0
  store i8 0, ptr %122, align 2, !pc !0
  %123 = getelementptr inbounds i8, ptr %7, i32 571, !pc !0
  store i8 0, ptr %123, align 1, !pc !0
  %124 = getelementptr inbounds i8, ptr %7, i32 572, !pc !0
  store i8 0, ptr %124, align 4, !pc !0
  %125 = getelementptr inbounds i8, ptr %7, i32 573, !pc !0
  store i8 0, ptr %125, align 1, !pc !0
  %126 = getelementptr inbounds i8, ptr %7, i32 574, !pc !0
  store i8 0, ptr %126, align 2, !pc !0
  %127 = getelementptr inbounds i8, ptr %7, i32 575, !pc !0
  store i8 0, ptr %127, align 1, !pc !0
  %128 = getelementptr inbounds i8, ptr %7, i32 576, !pc !0
  store i32 0, ptr %128, align 8, !pc !0
  %129 = getelementptr inbounds i8, ptr %7, i32 580, !pc !0
  store i64 0, ptr %129, align 4, !pc !0
  %130 = getelementptr inbounds i8, ptr %7, i32 588, !pc !0
  store i64 0, ptr %130, align 4, !pc !0
  %131 = getelementptr inbounds i8, ptr %7, i32 596, !pc !0
  store i64 0, ptr %131, align 4, !pc !0
  %132 = getelementptr inbounds i8, ptr %7, i32 604, !pc !0
  store i64 0, ptr %132, align 4, !pc !0
  %133 = getelementptr inbounds i8, ptr %7, i32 612, !pc !0
  store i64 0, ptr %133, align 4, !pc !0
  %134 = getelementptr inbounds i8, ptr %7, i32 620, !pc !0
  store i8 0, ptr %134, align 4, !pc !0
  %135 = getelementptr inbounds i8, ptr %7, i32 621, !pc !0
  store i8 0, ptr %135, align 1, !pc !0
  %136 = getelementptr inbounds i8, ptr %7, i32 622, !pc !0
  store i8 0, ptr %136, align 2, !pc !0
  %137 = getelementptr inbounds i8, ptr %7, i32 623, !pc !0
  store i16 0, ptr %137, align 1, !pc !0
  %138 = getelementptr inbounds i8, ptr %7, i32 625, !pc !0
  store i8 0, ptr %138, align 1, !pc !0
  %139 = getelementptr inbounds i8, ptr %7, i32 626, !pc !0
  store i8 0, ptr %139, align 2, !pc !0
  %140 = getelementptr inbounds i8, ptr %7, i32 627, !pc !0
  store i8 0, ptr %140, align 1, !pc !0
  %141 = getelementptr inbounds i8, ptr %7, i32 628, !pc !0
  store i8 0, ptr %141, align 4, !pc !0
  %142 = getelementptr inbounds i8, ptr %7, i32 629, !pc !0
  store i8 0, ptr %142, align 1, !pc !0
  %143 = getelementptr inbounds i8, ptr %7, i32 630, !pc !0
  store i8 0, ptr %143, align 2, !pc !0
  %144 = getelementptr inbounds i8, ptr %7, i32 631, !pc !0
  store i8 0, ptr %144, align 1, !pc !0
  %145 = getelementptr inbounds i8, ptr %7, i32 632, !pc !0
  store i8 0, ptr %145, align 8, !pc !0
  %146 = getelementptr inbounds i8, ptr %7, i32 633, !pc !0
  store i8 0, ptr %146, align 1, !pc !0
  %147 = getelementptr inbounds i8, ptr %7, i32 634, !pc !0
  store i8 0, ptr %147, align 2, !pc !0
  %148 = getelementptr inbounds i8, ptr %7, i32 635, !pc !0
  store i8 0, ptr %148, align 1, !pc !0
  %149 = getelementptr inbounds i8, ptr %7, i32 636, !pc !0
  store i32 0, ptr %149, align 4, !pc !0
  %150 = getelementptr inbounds i8, ptr %7, i32 640, !pc !0
  store i32 0, ptr %150, align 8, !pc !0
  %151 = getelementptr inbounds i8, ptr %7, i32 644, !pc !0
  store i32 0, ptr %151, align 4, !pc !0
  %152 = getelementptr inbounds i8, ptr %7, i32 648, !pc !0
  store i32 0, ptr %152, align 8, !pc !0
  %153 = getelementptr inbounds i8, ptr %7, i32 652, !pc !0
  store i8 0, ptr %153, align 4, !pc !0
  %154 = getelementptr inbounds i8, ptr %7, i32 653, !pc !0
  store i8 0, ptr %154, align 1, !pc !0
  %155 = getelementptr inbounds i8, ptr %7, i32 654, !pc !0
  store i8 0, ptr %155, align 2, !pc !0
  %156 = getelementptr inbounds i8, ptr %7, i32 655, !pc !0
  store i8 0, ptr %156, align 1, !pc !0
  %157 = load i32, ptr @__anvill_reg_CWP, align 4, !pc !0
  store i32 %157, ptr %152, align 4, !pc !0
  %158 = load i64, ptr @__anvill_reg_I0_1, align 8, !pc !0
  store i64 %158, ptr %28, align 8, !pc !0
  %159 = load i64, ptr @__anvill_reg_I2_3, align 8, !pc !0
  store i64 %159, ptr %30, align 8, !pc !0
  %160 = load i64, ptr @__anvill_reg_I4_5, align 8, !pc !0
  store i64 %160, ptr %32, align 8, !pc !0
  %161 = load i64, ptr @__anvill_reg_FP_7, align 8, !pc !0
  store i64 %161, ptr %34, align 8, !pc !0
  %162 = load i64, ptr @__anvill_reg_L0_1, align 8, !pc !0
  store i64 %162, ptr %37, align 8, !pc !0
  %163 = load i64, ptr @__anvill_reg_L2_3, align 8, !pc !0
  store i64 %163, ptr %39, align 8, !pc !0
  %164 = load i64, ptr @__anvill_reg_L4_5, align 8, !pc !0
  store i64 %164, ptr %41, align 8, !pc !0
  %165 = load i64, ptr @__anvill_reg_L6_7, align 8, !pc !0
  store i64 %165, ptr %43, align 8, !pc !0
  %166 = load i64, ptr @__anvill_reg_O2_3, align 8, !pc !0
  store i64 %166, ptr %47, align 8, !pc !0
  %167 = load i64, ptr @__anvill_reg_O4_5, align 8, !pc !0
  store i64 %167, ptr %49, align 8, !pc !0
  %168 = load i64, ptr @__anvill_reg_G0_1, align 8, !pc !0
  store i64 %168, ptr %53, align 8, !pc !0
  %169 = load i64, ptr @__anvill_reg_G2_3, align 8, !pc !0
  store i64 %169, ptr %55, align 8, !pc !0
  %170 = load i64, ptr @__anvill_reg_G4_5, align 8, !pc !0
  store i64 %170, ptr %57, align 8, !pc !0
  %171 = load i64, ptr @__anvill_reg_G6_7, align 8, !pc !0
  store i64 %171, ptr %59, align 8, !pc !0
  %172 = load i32, ptr @__anvill_reg_Y, align 4, !pc !0
  store i32 %172, ptr %87, align 4, !pc !0
  %173 = load i32, ptr @__anvill_reg_TICK, align 4, !pc !0
  store i32 %173, ptr %91, align 4, !pc !0
  %174 = load i32, ptr @__anvill_reg_CCR, align 4, !pc !0
  store i32 %174, ptr %89, align 4, !pc !0
  %175 = load i32, ptr @__anvill_reg_PCR, align 4, !pc !0
  store i32 %175, ptr %93, align 4, !pc !0
  %176 = load i32, ptr @__anvill_reg_PIC, align 4, !pc !0
  store i32 %176, ptr %95, align 4, !pc !0
  %177 = load i32, ptr @__anvill_reg_GSR, align 4, !pc !0
  store i32 %177, ptr %97, align 4, !pc !0
  %178 = load i32, ptr @__anvill_reg_SOFTINT_SET, align 4, !pc !0
  store i32 %178, ptr %99, align 4, !pc !0
  %179 = load i32, ptr @__anvill_reg_SOFTINT_CLR, align 4, !pc !0
  store i32 %179, ptr %101, align 4, !pc !0
  %180 = load i32, ptr @__anvill_reg_SOFTINT, align 4, !pc !0
  store i32 %180, ptr %103, align 4, !pc !0
  %181 = load i32, ptr @__anvill_reg_TICK_CMPR, align 4, !pc !0
  store i32 %181, ptr %105, align 4, !pc !0
  %182 = load i32, ptr @__anvill_reg_STICK, align 4, !pc !0
  store i32 %182, ptr %107, align 4, !pc !0
  %183 = load i32, ptr @__anvill_reg_STICK_CMPR, align 4, !pc !0
  store i32 %183, ptr %109, align 4, !pc !0
  %184 = load i8, ptr @__anvill_reg_I_CF, align 1, !pc !0
  store i8 %184, ptr %113, align 1, !pc !0
  %185 = load i8, ptr @__anvill_reg_I_VF, align 1, !pc !0
  store i8 %185, ptr %115, align 1, !pc !0
  %186 = load i8, ptr @__anvill_reg_I_ZF, align 1, !pc !0
  store i8 %186, ptr %117, align 1, !pc !0
  %187 = load i8, ptr @__anvill_reg_I_NF, align 1, !pc !0
  store i8 %187, ptr %119, align 1, !pc !0
  %188 = load i8, ptr @__anvill_reg_X_CF, align 1, !pc !0
  store i8 %188, ptr %121, align 1, !pc !0
  %189 = load i8, ptr @__anvill_reg_X_VF, align 1, !pc !0
  store i8 %189, ptr %123, align 1, !pc !0
  %190 = load i8, ptr @__anvill_reg_X_ZF, align 1, !pc !0
  store i8 %190, ptr %125, align 1, !pc !0
  %191 = load i8, ptr @__anvill_reg_X_NF, align 1, !pc !0
  store i8 %191, ptr %127, align 1, !pc !0
  %192 = load i8, ptr @__anvill_reg_ccf_fcc0, align 1, !pc !0
  store i8 %192, ptr %66, align 1, !pc !0
  %193 = load i8, ptr @__anvill_reg_ccf_fcc1, align 1, !pc !0
  store i8 %193, ptr %80, align 1, !pc !0
  %194 = load i8, ptr @__anvill_reg_ccf_fcc2, align 1, !pc !0
  store i8 %194, ptr %82, align 1, !pc !0
  %195 = load i8, ptr @__anvill_reg_ccf_fcc3, align 1, !pc !0
  store i8 %195, ptr %84, align 1, !pc !0
  %196 = load i8, ptr @__anvill_reg_fsr_aexc, align 1, !pc !0
  store i8 %196, ptr %64, align 1, !pc !0
  %197 = load i8, ptr @__anvill_reg_fsr_cexc, align 1, !pc !0
  store i8 %197, ptr %62, align 1, !pc !0
  %198 = load i128, ptr @__anvill_reg_FQ0, align 8, !pc !0
  store i128 %198, ptr %11, align 8, !pc !0
  %199 = load i128, ptr @__anvill_reg_FQ4, align 8, !pc !0
  store i128 %199, ptr %13, align 8, !pc !0
  %200 = load i128, ptr @__anvill_reg_FQ8, align 8, !pc !0
  store i128 %200, ptr %15, align 8, !pc !0
  %201 = load i128, ptr @__anvill_reg_FQ12, align 8, !pc !0
  store i128 %201, ptr %17, align 8, !pc !0
  %202 = load i128, ptr @__anvill_reg_FQ16, align 8, !pc !0
  store i128 %202, ptr %19, align 8, !pc !0
  %203 = load i128, ptr @__anvill_reg_FQ20, align 8, !pc !0
  store i128 %203, ptr %21, align 8, !pc !0
  %204 = load i128, ptr @__anvill_reg_FQ24, align 8, !pc !0
  store i128 %204, ptr %23, align 8, !pc !0
  %205 = load i128, ptr @__anvill_reg_FQ28, align 8, !pc !0
  store i128 %205, ptr %25, align 8, !pc !0
  %206 = load i8, ptr @__anvill_reg_DECOMPILE_MODE, align 1, !pc !0
  store i8 %206, ptr %153, align 1, !pc !0
  %207 = load i8, ptr @__anvill_reg_DIDRESTORE, align 1, !pc !0
  store i8 %207, ptr %155, align 1, !pc !0
  store i64 %5, ptr %51, align 8, !pc !0
  %208 = getelementptr inbounds i8, ptr %7, i32 348, !pc !0
  store i32 %3, ptr %208, align 4, !pc !0
  store i32 %0, ptr %45, align 4, !pc !0
  %209 = getelementptr inbounds i8, ptr %7, i32 300, !pc !0
  store i32 %1, ptr %209, align 4, !pc !0
  store i32 ptrtoint (ptr @add to i32), ptr %150, align 4, !pc !0
  %210 = call noundef ptr @__remill_sync_hyper_call(ptr noundef nonnull align 16 dereferenceable(656) %7, ptr noundef null, i32 noundef 1024) #4, !pc !2
  %211 = call noundef ptr @__remill_sync_hyper_call(ptr noundef nonnull align 16 dereferenceable(656) %7, ptr noundef %210, i32 noundef 1024) #4, !pc !2
  store i32 4198404, ptr %150, align 4, !pc !0
  %212 = call ptr @__remill_function_return(ptr undef, i32 4198404, ptr %211), !pc !0
  %213 = load i32, ptr %45, align 4, !pc !0
  ret i32 %213, !pc !0
}

; Function Attrs: mustprogress noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_sync_hyper_call(ptr noundef nonnull align 16 dereferenceable(656), ptr noundef, i32 noundef) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i32 noundef, ptr noundef) local_unnamed_addr #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare ptr @llvm.returnaddress(i32 immarg) #3

attributes #0 = { noinline }
attributes #1 = { mustprogress noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #2 = { noduplicate noinline nounwind optnone "frame-pointer"="all" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(none) }
attributes #4 = { alwaysinline nobuiltin nounwind "no-builtins" }

!0 = !{i32 4198400}
!1 = !{i32 0}
!2 = !{i32 4198404}
