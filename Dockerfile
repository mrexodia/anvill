# Builds anvill-decompile-spec on top of the remill-template dependency image
# (https://github.com/LLVMParty/remill-template), which provides LLVM and
# remill's dependencies in /dependencies.
#
#   git submodule update --init --recursive
#   docker build -t anvill .
#   docker run --rm -v "$PWD:/work" anvill --spec /work/spec.pb --ir_out /work/out.ll
ARG BASE_IMAGE=ghcr.io/llvmparty/remill-template/dependencies:22.04-llvm19.1.7-remill2026.03.20

FROM ${BASE_IMAGE} AS build
WORKDIR /anvill
COPY . .

# Build the anvill-specific dependencies (sleigh, doctest, protobuf, Z3) on
# top of /dependencies, then anvill itself (remill is built as part of it).
RUN \
cmake -G Ninja -S dependencies -B dependencies/build -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
    -DUSE_EXTERNAL_LLVM=ON -DBUILD_REMILL_DEPENDENCIES=OFF && \
cmake --build dependencies/build && \
cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
    -DANVILL_ENABLE_INSTALL=ON "-DCMAKE_INSTALL_PREFIX=/opt/anvill" && \
cmake --build build && \
ctest --test-dir build --output-on-failure && \
cmake --install build

FROM ${BASE_IMAGE} AS dist
COPY --from=build /opt/anvill /opt/anvill
ENV PATH="/opt/anvill/bin:${PATH}"
WORKDIR /work
ENTRYPOINT ["anvill-decompile-spec"]
