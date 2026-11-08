#
# Copyright (c) 2019-present, Trail of Bits, Inc.
# All rights reserved.
#
# This source code is licensed in accordance with the terms specified in
# the LICENSE file found in the root directory of this source tree.
#

cmake_minimum_required(VERSION 3.21)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
  message(FATAL_ERROR "In-tree builds are not supported. Run CMake from a separate directory: cmake -B build")
endif()

include("cmake/options.cmake")
include("cmake/ccache.cmake")

# Dependencies come from a local prefix (see dependencies/README.md). The
# default `dependencies/install` prefix is detected automatically; otherwise
# pass -DCMAKE_PREFIX_PATH=...
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include("cmake/SetupDependenciesPrefix.cmake")

project("anvill")

include(GNUInstallDirs)
include("cmake/system.cmake")

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(ANVILL_ENABLE_INSTALL)
  include("cmake/packaging.cmake")
endif(ANVILL_ENABLE_INSTALL)

find_package(LLVM-Wrapper REQUIRED)
find_package(doctest CONFIG REQUIRED)

# Z3 and protobuf come either from the dependencies prefix (CMake config
# packages) or from system packages without CMake configs (e.g. Ubuntu's
# libz3-dev / libprotobuf-dev in the remill-template Docker image).
find_package(Z3 CONFIG QUIET)
if(NOT Z3_FOUND)
  find_path(Z3_INCLUDE_DIR z3++.h REQUIRED)
  find_library(Z3_LIBRARY z3 REQUIRED)
  add_library(z3::libz3 UNKNOWN IMPORTED)
  set_target_properties(z3::libz3 PROPERTIES
    IMPORTED_LOCATION "${Z3_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${Z3_INCLUDE_DIR}"
  )
  set(Z3_VERSION_STRING "${Z3_LIBRARY} (system)")
endif()

# protobuf_MODULE_COMPATIBLE provides protobuf_generate_cpp in config mode
set(protobuf_MODULE_COMPATIBLE ON)
find_package(Protobuf CONFIG QUIET)
if(NOT Protobuf_FOUND)
  find_package(Protobuf MODULE REQUIRED)
endif()

message(STATUS "anvill: LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "anvill: Z3 ${Z3_VERSION_STRING}")
message(STATUS "anvill: Protobuf ${Protobuf_VERSION}")

# Remill is built as part of this project from the dependencies/remill
# submodule (like https://github.com/LLVMParty/remill-template).
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/dependencies/remill/CMakeLists.txt")
  message(FATAL_ERROR "The remill submodule is missing. Run: git submodule update --init --recursive")
endif()
set(GFLAGS_USE_TARGET_NAMESPACE ON)
set(REMILL_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
set(REMILL_ENABLE_INSTALL_TARGET ${ANVILL_ENABLE_INSTALL} CACHE BOOL "" FORCE)
find_package(sleigh CONFIG QUIET COMPONENTS Support Specs)
if(sleigh_FOUND)
  set(REMILL_FETCH_SLEIGH OFF CACHE BOOL "" FORCE)
else()
  message(STATUS "anvill: sleigh not found in the dependency prefix, remill will fetch it")
endif()
add_subdirectory("dependencies/remill")

add_subdirectory("libraries")

if(ANVILL_ENABLE_INSTALL)
  set(cmake_install_dir "lib/cmake/${PROJECT_NAME}")

  include(CMakePackageConfigHelpers)
  configure_package_config_file("${PROJECT_NAME}Config.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
    INSTALL_DESTINATION "${cmake_install_dir}"
  )

  install(
    FILES
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
    DESTINATION "${cmake_install_dir}"
  )
  install(EXPORT "${PROJECT_NAME}Targets"
    DESTINATION "${cmake_install_dir}"
    NAMESPACE "${PROJECT_NAME}::"
  )
endif(ANVILL_ENABLE_INSTALL)

if(ANVILL_ENABLE_TESTS)
  message(STATUS "anvill: Tests have been enabled")
  enable_testing()
else()
  message(STATUS "anvill: Tests are not enabled")
endif(ANVILL_ENABLE_TESTS)

add_subdirectory("lib")
add_subdirectory("bin")

if(ANVILL_ENABLE_TESTS)
  add_subdirectory("tests")
endif()
