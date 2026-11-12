#
# Copyright (c) 2019-present, Trail of Bits, Inc.
# All rights reserved.
#
# This source code is licensed in accordance with the terms specified in
# the LICENSE file found in the root directory of this source tree.
#

include(CMakeDependentOption)

if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  set(default_build_type "Release")
else()
  set(default_build_type "RelWithDebInfo")
endif()

set(CMAKE_BUILD_TYPE "${default_build_type}" CACHE STRING "Build type")

option(ANVILL_ENABLE_INSTALL "Set to ON to enable the install directives (also installs remill)" FALSE)
option(ANVILL_ENABLE_PYTHON3_LIBS "Build the legacy Python 3 spec generator (emits the old JSON format)" FALSE)
cmake_dependent_option(ANVILL_INSTALL_PYTHON3_LIBS "Install Python 3 libraries to the **local machine** at build time. Mostly used for local development, not required for packaging" FALSE
ANVILL_ENABLE_INSTALL FALSE)
option(ANVILL_ENABLE_TESTS "Set to ON to enable the tests" TRUE)
option(ANVILL_ENABLE_SANITIZERS "Set to ON to enable sanitizers. May not work with VCPKG")


