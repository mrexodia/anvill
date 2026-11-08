// Copyright (C) 2020 Trail of Bits
// Based on: https://github.com/andrew-hardin/cmake-git-version-tracking/blob/master/better-example/git.cc.in
// Which is (C) 2020 Andrew Hardin
// 
// MIT License
//  Copyright (c) 2020 Andrew Hardin
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

#include "remill/Version/Version.h"

namespace remill {
namespace version {

bool HasVersionData(void) {
  return true;
}

bool HasUncommittedChanges(void) {
  return true;
}

std::string_view GetAuthorName(void) {
  return "Claude";
}

std::string_view GetAuthorEmail(void) {
  return "noreply@anthropic.com";
}

std::string_view GetCommitHash(void) {
  return "8c81d45cf73c829e93de68ded6dadec1a2171911";
}

std::string_view GetCommitDate(void) {
  return "2026-11-08 17:40:04 +0000";
}

std::string_view GetCommitSubject(void) {
  return "Port to latest remill and LLVM 19 using a local dependencies prefix";
}

std::string_view GetCommitBody(void) {
  return "Follow the LLVMParty/remill-template layout:\n\
- remill is now a submodule in dependencies/remill (latest master,\n\
  918e0bc) and is built with add_subdirectory()\n\
- dependencies/ contains a CMake superbuild for the dependency prefix,\n\
  extended with sleigh, doctest, protobuf 21.12 and Z3 4.13.4, and a\n\
  BUILD_REMILL_DEPENDENCIES option to layer on top of the\n\
  remill-template Docker image (/dependencies)\n\
- cmake/SetupDependenciesPrefix.cmake detects dependencies/install and\n\
  layers it over an existing CMAKE_PREFIX_PATH\n\
- drop the cxx-common/vcpkg presets, scripts and find modules\n\
\n\
Source changes for LLVM 19:\n\
- StringRef starts_with/ends_with/==, std::optional, TypeSize getters,\n\
  APInt::getSignificantBits, ConstantFoldIntegerCast, insertInto,\n\
  TargetParser/Triple.h, SROAPass options\n\
- port the FunctionLifter cleanup pipeline to the new pass manager\n\
- icmp constant expressions no longer exist (LLVM 19)\n\
- GetOrInsertIntrinsicDeclaration helper for LLVM 20+\n\
- missing <utility> include in Result.h, z3 linked explicitly\n\
- lower removed constant expressions in three test fixtures\n\
\n\
CI and the root Dockerfile now build inside\n\
ghcr.io/llvmparty/remill-template/dependencies:22.04-llvm19.1.7-remill2026.03.20.\n\
All tests pass (test_anvill, test_anvill_passes: 47/47 cases).\n\
\n\
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n\
Claude-Session: https://claude.ai/code/session_01Dar7bjgfJRt6c9Aj86Kv4H";
}

std::string_view GetVersionString(void) {
  return "8c81d45";
}

}  // namespace version
}  // namespace remill
