/*
 * Copyright (c) 2019-present, Trail of Bits, Inc.
 * All rights reserved.
 *
 * This source code is licensed in accordance with the terms specified in
 * the LICENSE file found in the root directory of this source tree.
 */

#include <anvill/Declarations.h>
#include <anvill/Specification.h>
#include <doctest/doctest.h>
#include <llvm/IR/LLVMContext.h>

namespace anvill {

TEST_SUITE("Specification") {
  TEST_CASE("VariableContaining covers the whole variable") {
    llvm::LLVMContext context;
    auto maybe_spec = Specification::DecodeFromTextPB(context, R"(
      arch: ARCH_AMD64
      operating_system: OS_LINUX
      global_variables { address: 0x1000 type { array { base { base: BT_I32 } size: 4 } } }
      global_variables { address: 0x2000 type { base: BT_I8 } }
    )");
    REQUIRE(maybe_spec.Succeeded());
    auto spec = maybe_spec.TakeValue();

    // Start address, interior addresses, and the last byte.
    for (uint64_t addr : {0x1000u, 0x1001u, 0x1008u, 0x100fu}) {
      auto var = spec.VariableContaining(addr);
      REQUIRE(var);
      CHECK(var->address == 0x1000u);
    }

    // Past the end, before the start, and between variables.
    CHECK(!spec.VariableContaining(0x1010u));
    CHECK(!spec.VariableContaining(0xfffu));
    CHECK(!spec.VariableContaining(0x1fffu));
    CHECK(spec.VariableContaining(0x2000u));
    CHECK(!spec.VariableContaining(0x2001u));

    // VariableAt only matches the start address.
    CHECK(spec.VariableAt(0x1000u));
    CHECK(!spec.VariableAt(0x1004u));
  }

  TEST_CASE("Specification equality") {
    llvm::LLVMContext context;
    const char *text = "arch: ARCH_AMD64 operating_system: OS_LINUX";
    auto a = Specification::DecodeFromTextPB(context, text);
    auto b = Specification::DecodeFromTextPB(context, text);
    REQUIRE(a.Succeeded());
    REQUIRE(b.Succeeded());
    auto spec_a = a.TakeValue();
    auto spec_b = b.TakeValue();
    auto copy_a = spec_a;
    CHECK(spec_a == copy_a);
    CHECK(!(spec_a != copy_a));
    CHECK(spec_a != spec_b);
    CHECK(!(spec_a == spec_b));
  }

  TEST_CASE("Text-format parse errors are reported") {
    llvm::LLVMContext context;
    auto spec = Specification::DecodeFromTextPB(context, "arch: NOT_AN_ARCH");
    REQUIRE(!spec.Succeeded());
  }
}

}  // namespace anvill
