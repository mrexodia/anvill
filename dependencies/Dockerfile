# Development image for anvill.
#
# The base image comes from https://github.com/LLVMParty/remill-template and
# already contains LLVM, gflags, glog, googletest and XED in /dependencies.
# This image adds the anvill-specific dependencies (sleigh, doctest, protobuf
# and Z3) in /anvill-dependencies.
#
# Build (from the `dependencies` folder, with the remill submodule checked out):
#   docker build -t anvill-dependencies .
ARG BASE_IMAGE=ghcr.io/llvmparty/remill-template/dependencies:22.04-llvm19.1.7-remill2026.03.20

FROM ${BASE_IMAGE} AS build
WORKDIR /tmp
COPY \
    CMakeLists.txt \
    superbuild.cmake \
    llvm.cmake \
    llvm-prebuilt.cmake \
    ./
COPY remill/dependencies ./remill/dependencies

RUN \
cmake -G Ninja -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    "-DCMAKE_INSTALL_PREFIX=/anvill-dependencies" \
    "-DCMAKE_PREFIX_PATH=/dependencies" \
    -DUSE_EXTERNAL_LLVM=ON \
    -DBUILD_REMILL_DEPENDENCIES=OFF && \
cmake --build build && \
rm -rf build

FROM ${BASE_IMAGE} AS dependencies
COPY --from=build /anvill-dependencies /anvill-dependencies
ENV CMAKE_PREFIX_PATH="/anvill-dependencies:/dependencies" \
    PATH="/anvill-dependencies/bin:$PATH"
