# Builds anvill-decompile-spec on top of the remill-template dependency image
# (https://github.com/LLVMParty/remill-template), which provides LLVM 19 and
# remill's dependencies (gflags, glog, XED) prebuilt in /dependencies. Only
# Z3, protobuf and doctest are added from the Ubuntu packages; remill (and its
# sleigh dependency) are built as part of anvill.
#
#   git submodule update --init --recursive
#   docker build -t anvill .
#   docker run --rm -v "$PWD:/work" anvill --spec /work/spec.pb --ir_out /work/out.ll
ARG BASE_IMAGE=ghcr.io/llvmparty/remill-template/dependencies:22.04-llvm19.1.7-remill2026.03.20

FROM ${BASE_IMAGE} AS build
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libz3-dev libprotobuf-dev protobuf-compiler doctest-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /anvill
COPY . .
RUN \
cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
    -DANVILL_ENABLE_INSTALL=ON "-DCMAKE_INSTALL_PREFIX=/opt/anvill" && \
cmake --build build && \
ctest --test-dir build --output-on-failure && \
cmake --install build

FROM ${BASE_IMAGE} AS dist
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libz3-4 libprotobuf23 && \
    rm -rf /var/lib/apt/lists/*
COPY --from=build /opt/anvill /opt/anvill
ENV PATH="/opt/anvill/bin:${PATH}"
WORKDIR /work
ENTRYPOINT ["anvill-decompile-spec"]
