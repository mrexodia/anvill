# dependencies

Standalone dependencies for anvill based on [LLVMParty/packages](https://github.com/LLVMParty/packages) (superbuild pattern), adapted from [remill-template](https://github.com/LLVMParty/remill-template).

This builds:

- remill's third-party dependencies: gflags, glog, googletest and XED (disable with `-DBUILD_REMILL_DEPENDENCIES=OFF` when they are already available)
- sleigh, with remill's patches from `dependencies/remill/dependencies` (disable with `-DENABLE_SLEIGH=OFF`; remill then fetches it itself)
- anvill's own dependencies: doctest, protobuf (21.12, the last release without abseil) and Z3

By default it also downloads and extracts the LLVMParty LLVM 21.1.6 prebuilt for the current target into the install prefix. Set `USE_EXTERNAL_LLVM=ON` to use an existing LLVM, or `DOWNLOAD_PREBUILT_LLVM=OFF` to compile LLVM 21.1.6 from source instead.

Remill itself is built by the main project via `add_subdirectory(dependencies/remill)`.

## Building

```sh
git submodule update --init --recursive
cmake -G Ninja -S dependencies -B dependencies/build -DCMAKE_BUILD_TYPE=Release
cmake --build dependencies/build
```

This will create a [CMake prefix](https://cmake.org/cmake/help/latest/command/find_package.html#search-procedure) in `dependencies/install`. The main project automatically detects the default `dependencies/install` prefix; for non-default locations, pass it with `-DCMAKE_PREFIX_PATH:PATH=/path/to/dependencies/install`. When `CMAKE_PREFIX_PATH` is already set (for example `/dependencies` in the Docker image), `dependencies/install` is layered on top of it. See [presentation.md](https://github.com/LLVMParty/packages/blob/main/presentation.md) and [dependencies.md](https://github.com/LLVMParty/packages/blob/main/dependencies.md) for more information.

## Docker

The superbuild is not needed with the remill-template Docker image (`ghcr.io/llvmparty/remill-template/dependencies:22.04-llvm19.1.7-remill2026.03.20`): it already provides LLVM and remill's dependencies, and Z3, protobuf and doctest can be installed from the Ubuntu packages. See the main [README](../README.md#using-the-remill-template-docker-image).
