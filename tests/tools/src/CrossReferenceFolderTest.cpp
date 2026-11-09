/*
 * Copyright (c) 2019-present, Trail of Bits, Inc.
 * All rights reserved.
 *
 * This source code is licensed in accordance with the terms specified in
 * the LICENSE file found in the root directory of this source tree.
 */

#include <anvill/CrossReferenceFolder.h>
#include <anvill/CrossReferenceResolver.h>
#include <doctest/doctest.h>
#include <llvm/AsmParser/Parser.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/SourceMgr.h>

#include <memory>
#include <string>

namespace anvill {
namespace {

// Each test function returns the value to resolve: `ret` operand of @f.
static std::unique_ptr<llvm::Module> Parse(llvm::LLVMContext &context,
                                           const std::string &body) {
  llvm::SMDiagnostic err;
  auto module = llvm::parseAssemblyString(
      "target datalayout = \"e-m:e-i64:64-f80:128-n8:16:32:64-S128\"\n"
      "@__anvill_sp = external global i8\n"
      "@__anvill_pc = external global i8\n"
      "@__anvill_ra = external global i8\n"
      "@data = external global i32\n" +
          body,
      err, context);
  if (!module) {
    err.print("CrossReferenceFolderTest", llvm::errs());
  }
  return module;
}

static llvm::Value *ReturnedValue(llvm::Module &module) {
  auto &block = module.getFunction("f")->getEntryBlock();
  return llvm::cast<llvm::ReturnInst>(block.getTerminator())
      ->getReturnValue();
}

// Resolves @data to 0x1000.
class DataResolver final : public NullCrossReferenceResolver {
 public:
  std::optional<std::uint64_t> AddressOfEntity(
      llvm::Constant *ent) const override {
    if (ent->getName() == "data") {
      return 0x1000u;
    }
    return std::nullopt;
  }
};

struct Folded {
  std::unique_ptr<llvm::Module> module;
  ResolvedCrossReference xr;
};

static Folded Fold(llvm::LLVMContext &context, const std::string &body) {
  auto module = Parse(context, body);
  REQUIRE(module);
  DataResolver resolver;
  CrossReferenceFolder folder(resolver, module->getDataLayout());
  auto xr = folder.TryResolveReferenceWithClearedCache(ReturnedValue(*module));
  return {std::move(module), xr};
}

}  // namespace

TEST_SUITE("CrossReferenceFolder") {
  TEST_CASE("Compare instructions do not fold") {
    // Only `icmp` constant expressions are folded (with `ule` as `<=`), and
    // LLVM 19 removed those, so compares never produce a cross-reference.
    llvm::LLVMContext context;
    auto f = Fold(context, R"(
      define i1 @f(i64 %x) {
        %a = add i64 ptrtoint (ptr @__anvill_sp to i64), 5
        %b = add i64 ptrtoint (ptr @__anvill_sp to i64), 5
        %c = icmp ule i64 %a, %b
        ret i1 %c
      })");
    CHECK(!f.xr.is_valid);
  }

  TEST_CASE("Stack pointer displacement") {
    llvm::LLVMContext context;
    auto f = Fold(context, R"(
      define i64 @f() {
        ret i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -16)
      })");
    REQUIRE(f.xr.is_valid);
    CHECK(f.xr.references_stack_pointer);
    CHECK(!f.xr.references_program_counter);
    CHECK(f.xr.size == 64u);
    CHECK(f.xr.Displacement(f.module->getDataLayout()) == -16);
  }

  TEST_CASE("Displacement sign-extends any width") {
    llvm::LLVMContext context;
    auto f = Fold(context, R"(
      define i24 @f() {
        ret i24 trunc (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -3) to i24)
      })");
    REQUIRE(f.xr.is_valid);
    CHECK(f.xr.size == 24u);
    CHECK(f.xr.Displacement(f.module->getDataLayout()) == -3);

    auto g = Fold(context, R"(
      define i1 @f() {
        ret i1 trunc (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 1) to i1)
      })");
    REQUIRE(g.xr.is_valid);
    CHECK(g.xr.size == 1u);
    CHECK(g.xr.Displacement(g.module->getDataLayout()) == -1);
  }

  TEST_CASE("Program counter and entities") {
    llvm::LLVMContext context;
    auto f = Fold(context, R"(
      define i64 @f() {
        ret i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198400)
      })");
    REQUIRE(f.xr.is_valid);
    CHECK(f.xr.references_program_counter);
    CHECK(f.xr.u.address == 0x401000u);

    auto g = Fold(context, R"(
      define i64 @f() {
        ret i64 add (i64 ptrtoint (ptr @data to i64), i64 8)
      })");
    REQUIRE(g.xr.is_valid);
    CHECK(g.xr.references_entity);
    CHECK(!g.xr.references_stack_pointer);
    CHECK(!g.xr.references_return_address);
    CHECK(g.xr.u.address == 0x1008u);
  }

  TEST_CASE("Return address") {
    llvm::LLVMContext context;
    auto f = Fold(context, R"(
      define i64 @f() {
        ret i64 ptrtoint (ptr @__anvill_ra to i64)
      })");
    REQUIRE(f.xr.is_valid);
    CHECK(f.xr.references_return_address);
    CHECK(f.xr.u.address == 0x4141414141414141ull);
  }

  TEST_CASE("Bit counting uses the operand width") {
    llvm::LLVMContext context;
    auto clz = Fold(context, R"(
      declare i32 @llvm.ctlz.i32(i32, i1)
      define i32 @f() {
        %v = call i32 @llvm.ctlz.i32(i32 trunc (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 256) to i32), i1 false)
        ret i32 %v
      })");
    REQUIRE(clz.xr.is_valid);
    CHECK(clz.xr.u.address == 23u);  // 0x100 in 32 bits

    auto ctz = Fold(context, R"(
      declare i32 @llvm.cttz.i32(i32, i1)
      define i32 @f() {
        %v = call i32 @llvm.cttz.i32(i32 trunc (i64 ptrtoint (ptr @__anvill_pc to i64) to i32), i1 false)
        ret i32 %v
      })");
    REQUIRE(ctz.xr.is_valid);
    CHECK(ctz.xr.u.address == 32u);  // zero input: the full width

    auto pop = Fold(context, R"(
      declare i16 @llvm.ctpop.i16(i16)
      define i16 @f() {
        %v = call i16 @llvm.ctpop.i16(i16 trunc (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 -1) to i16))
        ret i16 %v
      })");
    REQUIRE(pop.xr.is_valid);
    CHECK(pop.xr.u.address == 16u);  // only the low 16 bits are counted
  }

  TEST_CASE("Shifts by the width or more do not fold") {
    llvm::LLVMContext context;
    auto ok = Fold(context, R"(
      define i64 @f(i64 %x) {
        %a = add i64 ptrtoint (ptr @__anvill_pc to i64), 1
        %s = shl i64 %a, 4
        ret i64 %s
      })");
    REQUIRE(ok.xr.is_valid);
    CHECK(ok.xr.u.address == 16u);

    auto bad = Fold(context, R"(
      define i32 @f(i64 %x) {
        %a = trunc i64 ptrtoint (ptr @__anvill_pc to i64) to i32
        %b = add i32 %a, 1
        %s = shl i32 %b, 40
        ret i32 %s
      })");
    CHECK(!bad.xr.is_valid);
  }

  TEST_CASE("Division by zero does not fold") {
    llvm::LLVMContext context;
    auto f = Fold(context, R"(
      define i64 @f(i64 %x) {
        %a = add i64 ptrtoint (ptr @__anvill_pc to i64), 10
        %b = udiv i64 %a, 0
        ret i64 %b
      })");
    CHECK(!f.xr.is_valid);
  }
}

}  // namespace anvill
