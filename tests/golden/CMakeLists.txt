#
# Copyright (c) 2019-present, Trail of Bits, Inc.
# All rights reserved.
#
# This source code is licensed in accordance with the terms specified in
# the LICENSE file found in the root directory of this source tree.
#

find_package(Python3 COMPONENTS Interpreter)
if(NOT Python3_FOUND)
  message(WARNING "anvill: Python 3 not found, golden tests are disabled")
  return()
endif()

set(golden_args
  "${CMAKE_CURRENT_SOURCE_DIR}/run_golden.py"
  --anvill-opt "$<TARGET_FILE:anvill-opt>"
  --anvill-decompile-spec "$<TARGET_FILE:anvill-decompile-spec>"
)

add_test(
  NAME golden
  COMMAND "${Python3_EXECUTABLE}" ${golden_args} "${CMAKE_CURRENT_SOURCE_DIR}"
)

# Regenerate the expected outputs: cmake --build build --target update-golden
add_custom_target(update-golden
  COMMAND "${Python3_EXECUTABLE}" ${golden_args} --update "${CMAKE_CURRENT_SOURCE_DIR}"
  DEPENDS anvill-opt anvill-decompile-spec
  USES_TERMINAL
)
