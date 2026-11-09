# Patches to dependencies

`remill/*.patch` are applied to the `dependencies/remill` submodule by the
top-level `CMakeLists.txt` when anvill is configured (in name order, skipping
patches that are already applied). They are changes anvill needs that are not
in upstream remill yet; once they are upstream (or in a remill fork that the
submodule points to), delete the patch.

- `0001-Add-Sleigh-based-SPARC64-...patch`
  - Adds `kArchSparc64_SLEIGH` (`sparc64_sleigh`): SPARC V9 with Ghidra's
    `SparcV9_64.sla`. remill's hand-written SPARC64 semantics depend on
    SPARC32 semantics files that were removed when SPARC32 moved to Sleigh
    (remill #681), so the old `sparc64` architecture has no semantics module.
    `Arch.h` already declared `GetSPARC64Sleigh` without defining it.
  - Provides `DECOMPILE_MODE = 1` (the `SparcV9.pspec` default) as a decoding
    context value on SPARC32 and SPARC64, so `save`/`restore` do not spill the
    register window through computed register-space addresses.
  - Makes the Sleigh control-flow analysis accept SPARC `call` (p-code after the
    `CALL` op is unreachable) and instructions that mix intra-instruction
    branches with exits (`ret` with `restore` in its delay slot).
  - Fixes the SPARC32 FP register overlays (`fs0` is the high half of `fd0`).
  - `Arch::IsSPARC32`/`IsSPARC64` also accept the Sleigh variants.

The patch is a `git format-patch` file; to edit it, apply it in the
submodule (`git am`), change and commit, and export it again with
`git format-patch -1 --zero-commit -o ../patches/remill`.
