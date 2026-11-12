# Anvill: A Reimplementation-Grade Technical Report

This report describes the repository at commit `9948d26` ("update link to empirehacking slack (#383)"). It covers what each component does, how the components fit together, the exact data formats, the algorithms (step by step), the names Anvill generates, and the known quirks. The goal is that someone could build a functionally equivalent tool from this document alone.

Scope and method:

- I read every C++ source and header under `include/`, `lib/` and `bin/`, the protobuf schema, the docs, the tests, the Python package, the build files and the CI scripts.
- **Revision.** The first version of this report described commit `9948d26` as is. Since then, on this branch, anvill was ported to current remill and LLVM 19/21 (§16.6), and **most bugs listed in §17 were fixed**. The text describes the fixed code; each fix is marked **Fixed** with a description of the old behaviour, so a reimplementation can reproduce either. §17 has the full status table.
- **Real IR.** The IR examples are now actual output of the built tools, taken from the golden test suite in `tests/golden` (§16.7). That suite is the executable specification: every pass and lifting situation has input files and the exact expected output, and `ctest` checks them. The only schematic IR left is marked as such (the pre-inlining form of a lifted function in §10.10, which the tools never print).
- **[QUIRK]** marks behaviour that differs from the real ABI or the docs, or that looks like a latent bug, and that is still present. A faithful clone needs to copy these to produce identical output.

---

## Table of contents

1. [What Anvill is](#1-what-anvill-is)
2. [Repository map](#2-repository-map)
3. [Remill concepts you must understand first](#3-remill-concepts-you-must-understand-first)
4. [End-to-end pipeline](#4-end-to-end-pipeline)
5. [The specification format (protobuf)](#5-the-specification-format-protobuf)
6. [Loading a specification](#6-loading-a-specification)
7. [The type system](#7-the-type-system)
8. [Declarations and calling conventions (ABI layer)](#8-declarations-and-calling-conventions-abi-layer)
9. [Providers](#9-providers)
10. [The function lifter](#10-the-function-lifter)
11. [Entity, data and value lifting](#11-entity-data-and-value-lifting)
12. [Cross-reference folding](#12-cross-reference-folding)
13. [The optimization pipeline and every pass](#13-the-optimization-pipeline-and-every-pass)
14. [The `anvill-decompile-spec` driver](#14-the-anvill-decompile-spec-driver)
15. [Python tooling (legacy spec generator)](#15-python-tooling-legacy-spec-generator)
16. [Build, packaging, tests and CI](#16-build-packaging-tests-and-ci)
17. [Consolidated list of quirks and bugs](#17-consolidated-list-of-quirks-and-bugs)
18. [Reimplementation roadmap](#18-reimplementation-roadmap)
- [Appendix A. Generated names and constants](#appendix-a-generated-names-and-constants)
- [Appendix B. IR utility helpers](#appendix-b-ir-utility-helpers-libutilscpp)
- [Appendix C. `Result<V, E>` and the tool tests](#appendix-c-resultv-e-and-the-tool-tests)
- [Appendix D. Short reimplementation checklist](#appendix-d-short-reimplementation-checklist)

---

## 1. What Anvill is

Anvill is a C++17 static library (`libanvill.a`) and a command-line tool (`anvill-decompile-spec`). It turns **machine code plus a description of that machine code** into **"high quality" LLVM bitcode**. The README defines high quality as bitcode similar to what Clang would emit for an equivalent C function. Anvill sits in the middle of the Trail of Bits decompilation stack:

```
 binary ──► disassembler/analyser ──► specification (protobuf) ──► ANVILL ──► LLVM IR ──► Rellic ──► C
            (Ghidra plugin, closed;      functions, types, memory,      │
             legacy: Binary Ninja/IDA     control-flow overrides        └── uses Remill for instruction
             Python scripts in python/)                                     decoding + semantics
```

- **Remill** (`lifting-bits/remill`) decodes a single instruction and gives its semantics as calls into an LLVM "semantics module". Remill's lifted code works on an emulated `State` struct (the register file) and an opaque `Memory *` token threaded through memory intrinsics.
- **Anvill** does everything at the function level and above:
  - It drives Remill over a function's control-flow graph.
  - It wraps the Remill-style function in a native-looking function with real typed parameters and return values, following a calling convention.
  - It recovers stack frames, global variable references, switch tables and so on.
  - It runs custom LLVM passes until the code looks compiler-generated.
- **Rellic** (separate project) turns the result into C.

An important design point: Anvill **does not discover functions or control flow itself**. The specification must give it:

- every function entry and prototype (parameter and return locations),
- every global variable and its type,
- the bytes of memory and their permissions,
- for every control-flow instruction, an "override" record saying what it is (jump, call, return, other) and what its targets are.

Anvill consumes analysis. It does not perform it.

---

## 2. Repository map

| Path | Lines | Contents |
|---|---|---|
| `data_specifications/specification.proto` | 233 | **The input format.** proto3 schema `package specification`. |
| `include/anvill/*.h` | ~2.6k | Public API: `ABI.h` (name constants), `Declarations.h`, `Lifters.h`, `Providers.h`, `Specification.h`, `Type.h`, `Result.h`, `Utils.h`, `CrossReference{Folder,Resolver}.h`, `Optimize.h`, `Transforms.h`, `Passes/*.h` |
| `lib/Specification.{h,cpp}`, `lib/Protobuf.{h,cpp}` | ~1.4k | Parse protobuf → `FunctionDecl`/`VariableDecl`/`CallSiteDecl`/memory/overrides |
| `lib/Type.cpp` | 614 | TypeSpec ⇄ LLVM type, type string encoder |
| `lib/Declarations.cpp`, `lib/ABI.cpp` | 370 | Decl helpers, calling native functions from lifted code, name constants |
| `lib/Arch/*` | ~3.9k | Calling-convention allocators: x86 cdecl/stdcall/fastcall/thiscall, AMD64 SysV, AArch32, AArch64, SPARC32, SPARC64 |
| `lib/Lifters/*` | ~3.3k | `FunctionLifter` (the core, 1.9k lines), `EntityLifter`, `DataLifter`, `ValueLifter`, `Options` |
| `lib/Providers/*` | 380 | Spec-backed Type/Memory/ControlFlow providers |
| `lib/CrossReference*.cpp` | 860 | Constant-expression "address" evaluator |
| `lib/Passes/*` | ~8k | ~30 custom LLVM passes (new pass manager) |
| `lib/Optimize.cpp` | 275 | The pass pipeline |
| `lib/Utils.cpp` | 744 | IR helpers (type adaptation, SP/PC/RA recognisers, load/store of decl values) |
| `bin/Decompile/Main.cpp` | 276 | `anvill-decompile-spec` CLI |
| `tests/anvill_passes/` | ~2k + 44 `.ll` | doctest unit tests per pass |
| `tests/tools/` | ~450 | doctest tests for `Result` and type decoding |
| `python/anvill/` | ~6k | **Legacy** spec generator for Binary Ninja / IDA (emits the *old JSON format*; see §15) |
| `parse_cspec/` | 99 | Ghidra `.cspec` → JSON converter |
| `plugins/ida/anvill.py` | 84 | IDA plugin wrapper around the Python generator |
| `docs/` | | `SpecificationFormat.md` (**describes the old JSON format**), `TypeEncoding.md`, `CodingStyle.md` |
| `cmake/`, `CMakeLists.txt`, `CMakePresets.json`, `Dockerfile`, `packaging/`, `scripts/`, `ci/`, `.github/` | | Build, packaging, CI |
| `remill/`, `libraries/lifting-tools-ci` | | Git submodules (empty here) |

Dependencies, from `CMakeLists.txt`:

- LLVM 14 or 15 (CI builds both) with opaque pointers. `Main.cpp` calls `context.enableOpaquePointers()` on LLVM < 15.
- remill, plus sleigh (optional), XED, gflags, glog, Z3, doctest, Protobuf.
- These usually come from Trail of Bits' `cxx-common` vcpkg bundle.

> **Update:** after this report was written, this branch was ported to the latest remill and LLVM 19+ with a local `dependencies/` prefix, following [remill-template](https://github.com/LLVMParty/remill-template). The rest of this report still describes the original code at `9948d26`; see §16.6 for what changed in the build.

---

## 3. Remill concepts you must understand first

Anvill is written against Remill's API, so a reimplementer needs to know the following Remill concepts. They are described as Anvill uses them.

### 3.1 `remill::Arch`

- Built with `remill::Arch::Build(&context, os_name, arch_name)`.
- Provides:
  - the register table: `RegisterByName`, `ForEachRegister`, `Register::EnclosingRegister()`, `Register::AddressOf(state_ptr, block)` (which emits a GEP into `State`), and `Register::type`;
  - `ProgramCounterRegisterName()` and `StackPointerRegisterName()`;
  - `StateStructType()`, `StatePointerType()` and `MemoryPointerType()`;
  - `address_size` (in bits);
  - `DataLayout()` and `PrepareModule(module)`, which sets the target triple and data layout;
  - `MaxInstructionSize(ctx)`, `DecodeInstruction(addr, bytes, inst&, DecodingContext)` and `DecodeDelayedInstruction(...)`;
  - `MayHaveDelaySlot(inst)` and `NextInstructionIsDelayed(inst, delayed, on_taken_path)`;
  - `CreateInitialContext()`, which returns a `remill::DecodingContext`;
  - `DefineLiftedFunction(name, module)`, which clones `__remill_basic_block`;
  - `DefaultLifter(intrinsics)`, which returns an `OperandLifter` with `LoadRegValue`, `LoadRegAddress` and `ClearCache`.
- `remill::LoadArchSemantics(arch)` loads the per-architecture semantics bitcode module (e.g. `amd64.bc`). Anvill lifts *into that module* and later copies finished functions into the user's module.

### 3.2 The lifted-function ABI

Every Remill-lifted function, and `__remill_basic_block` that they are cloned from, has the signature

```llvm
ptr @lifted(ptr %state, i64 %pc, ptr %memory)     ; returns the new Memory*
```

The argument indices are `remill::kStatePointerArgNum`, `kPCArgNum` and `kMemoryPointerArgNum`, and `kNumBlockArgs == 3`. The entry block of `__remill_basic_block` declares named local "variables" that semantics refer to by name. Anvill uses:

- `remill::kPCVariableName` ("PC")
- `kNextPCVariableName` ("NEXT_PC")
- `kReturnPCVariableName` ("RETURN_PC")
- `MEMORY` (via `remill::LoadMemoryPointerRef`)
- `BRANCH_TAKEN` (via `remill::LoadBranchTaken`)

### 3.3 `remill::Instruction`

- Fields: `pc`, `next_pc`, `delayed_pc`, `branch_taken_pc`, `branch_not_taken_pc`, `bytes`, `arch_name`, `sub_arch_name` and `operands`.
- A `flows` member: a `std::variant` of `NormalInsn`, `NoOp`, `InvalidInsn`, `ErrorInsn`, `DirectJump`, `IndirectJump`, `IndirectFunctionCall`, `DirectFunctionCall`, `FunctionReturn`, `AsyncHyperCall` and `ConditionalInstruction`. A `ConditionalInstruction` holds a `taken_branch`, which is itself one of the other flows, and a `fall_through`.
- Flows carry decoding contexts, for example:
  - `NormalInsn.fallthrough.fallthrough_context`
  - `DirectJump.taken_flow.known_target` and `.static_context`
- `inst.GetLifter()->LiftIntoBlock(inst, block, state_ptr, is_delayed)` emits the semantics call(s) for the instruction into `block`.

### 3.4 `remill::DecodingContext`

A map from context-register name to value, for example the ARM Thumb bit. The spec supplies `context_assignments` (`map<string,uint64>`) at function entry and per jump target. Anvill applies them with `ctx.UpdateContextReg(name, value)`. The old docs use the name `"TMReg"`, and a comment in `Declarations.h` says `"TM"`. The actual name is whatever Remill's ARM decoder uses.

### 3.5 Remill intrinsics Anvill relies on

These are declared in the semantics module and wrapped by `remill::IntrinsicTable`:

| Intrinsic | Meaning |
|---|---|
| `__remill_read_memory_{8,16,32,64,f32,f64,f80,f128}(mem, addr)` | memory read |
| `__remill_write_memory_*(mem, addr, val) → mem` | memory write |
| `__remill_function_call(state, pc, mem)` | call to unknown target |
| `__remill_function_return(state, pc, mem)` | return |
| `__remill_jump(state, pc, mem)` | indirect jump to unknown target |
| `__remill_error(state, pc, mem)` | trap / undecodable / "should not reach" |
| `__remill_async_hyper_call(...)` | syscall / interrupt |
| `__remill_undefined_{8,16,32,64,f32,f64,f80}()` | undefined value (e.g. undefined flags) |
| `__remill_flag_computation_*`, `__remill_compare_*` | flag/compare hints (consumed by branch analysis) |
| `__remill_barrier_*`, `__remill_delay_slot_begin/end`, `__remill_fpu_exception_*`, etc. | removed by Anvill passes |

`remill::AddTerminatingTailCall(block, intrinsic, intrinsics)` emits `%m = call @intrinsic(state, pc, mem); ret %m`. `remill::AddCall` emits a non-terminating call.

---

## 4. End-to-end pipeline

```
anvill-decompile-spec --spec foo.pb --ir_out foo.ll
│
├─ 1. Read file → specification::Specification (protobuf ParseFromString)
├─ 2. Specification::DecodeFromPB
│     ├─ build remill::Arch from (arch, os)
│     ├─ decode type_aliases map → TypeSpec table
│     ├─ decode functions → FunctionDecl (ABI locations + LLVM FunctionType)
│     ├─ decode callsites → CallSiteDecl keyed by (func_addr, call_addr)
│     ├─ decode global_variables → VariableDecl
│     ├─ symbols → multimap<addr,name>
│     ├─ memory_ranges → map<addr, (byte, permission)>   (per byte!)
│     └─ overrides → map<addr, variant<Jump,Call,Return,Misc>>   (REQUIRED)
├─ 3. Build providers: SpecificationTypeProvider (wrapped in Proxy or DefaultCallable),
│     SpecificationControlFlowProvider, SpecificationMemoryProvider
├─ 4. LifterOptions(arch, module, tp, cfp, mp); pc_metadata_name="pc";
│     stack_offset_metadata_name="stack_offset"
├─ 5. EntityLifter lifter(options)
├─ 6. for each FunctionDecl: lifter.LiftEntity(decl)   (or DeclareEntity if not in --lift_list)
│        FunctionLifter: decode+lift CFG into "<name>.lifted" (Remill form)
│                        build native wrapper "<name>" with real params
│                        inline everything, light cleanup, copy into target module
├─ 7. for each VariableDecl: lifter.LiftEntity(decl) → @var_<addr>_<type> with initializer
├─ 8. OptimizeModule(lifter, module): LLVM passes + ~30 Anvill passes, two function pipelines
└─ 9. write .ll / .bc / stats JSON
```

---

## 5. The specification format (protobuf)

### 5.1 Status of the documentation

`docs/SpecificationFormat.md` describes an **older JSON format**: keys such as `"functions"`, `"variables"`, `"memory"` with a hex `"data"` field, type strings like `"**b"`, and `"control_flow_targets"`. The C++ code on `master` reads **only** the protobuf format in `data_specifications/specification.proto`. The semantics in the JSON doc (return address, return stack pointer, parameters as locations) still apply. The *syntax* does not. The README says the protobuf producer is a closed-source Ghidra plugin. The open-source Binary Ninja generator lives on the `binja-final-version` tag. The Python in `python/` on this branch still emits the old JSON (§15).

### 5.2 Schema walk-through (all fields)

```proto
message Specification {
  Arch arch = 1;                         // required, see enum below
  OS operating_system = 2;               // required
  repeated Function functions = 3;
  repeated Callsite callsites = 4;       // per-call-site prototypes (override callee prototype)
  repeated GlobalVariable global_variables = 5;
  repeated Symbol symbols = 6;           // (name, address) pairs; many names per address allowed
  repeated MemoryRange memory_ranges = 7;
  ControlFlowOverrides overrides = 8;    // REQUIRED: absence is a hard error
  map<int64, TypeSpec> type_aliases = 9; // shared/recursive type table referenced by TypeSpec.alias
}
```

**Enums.**

- `Arch`:

  | Value | Arch |
  |---|---|
  | 1 | X86 |
  | 2 | X86_AVX |
  | 3 | X86_AVX512 |
  | 4 | AMD64 |
  | 5 | AMD64_AVX |
  | 6 | `ARCH_ADM64_AVX512` (sic, the typo is in the schema) |
  | 7 | AARCH64 |
  | 8 | AARCH32 |
  | 9 | SPARC32 |
  | 10 | SPARC64 |

  0 = unspecified, which is rejected. These map one-to-one to `remill::kArchX86` … `kArchAArch32LittleEndian`. `AARCH64` maps to `kArchAArch64LittleEndian` and `AARCH32` to `kArchAArch32LittleEndian`. `SPARC32` and `SPARC64` map to `kArchSparc32`/`kArchSparc64`, which in the remill fork anvill uses are both lifted with Sleigh (§16.6). (**Fixed:** in upstream remill the hand-written SPARC32 semantics were removed when SPARC32 moved to Sleigh, so `kArchSparc32` lifted every instruction as a `kSPARC32EmulateInstruction` hyper call, and `kArchSparc64` had no semantics module at all, so building it aborted.)
- `OS`: 1 LINUX, 2 MACOS, 3 WINDOWS, 4 SOLARIS. 0 is rejected.
- `CallingConvention`: the values are **LLVM `CallingConv::ID` numbers**: 0 unspecified/C, 1 CDECL, 64 STDCALL, 65 FASTCALL, 70 THISCALL, 78 AMD64_SYSV, 79 WIN64, 80 VECTORCALL. The value is copied into `llvm::Function::setCallingConv`, except that **CDECL (1) maps to C (0)**: 1 is not an LLVM calling convention ID (LLVM's C is 0 and fastcc is 8). (**Fixed:** the value used to be copied verbatim, declaring functions `cc 1`; `lifter/spec/cdecl_calling_convention`.) WIN64 and VECTORCALL have no allocator (§8).
- `FunctionLinkage`:
  - 0 NORMAL: lift the body.
  - 1 DECL: declare only, `lift_as_decl=true`.
  - 2 EXTERNAL: `lift_as_decl=true` and `is_extern=true`.
- `BaseType`: 25 values, `BT_BOOL=0` … `BT_PADDING=24`. The numbering is identical to `anvill::BaseType`, so decoding is a `static_cast` (§7).

**TypeSpec** (oneof):

```proto
message TypeSpec {
  oneof type {
    BaseType base = 1;
    PointerType pointer = 2;      // { TypeSpec pointee; bool const; }  pointee optional → void
    VectorType vector = 3;        // { TypeSpec base; uint32 size; }
    ArrayType array = 4;          // { TypeSpec base; uint32 size; }
    StructType struct = 5;        // { repeated TypeSpec members; optional uint32 identifier; }  (identifier ignored)
    FunctionType function = 6;    // { TypeSpec return_type; repeated TypeSpec arguments; bool is_variadic; }
    uint32 unknown = 7;           // unknown type of N bytes (0xFFFFFFFF = Ghidra "undefined" → treated as 4 bytes)
    int64 alias = 8;              // reference into Specification.type_aliases
  }
}
```

Structs are **packed**. The producer must insert explicit `BT_PADDING` members.

**Locations.**

```proto
message Register { string register_name = 1; }          // Remill register name, e.g. "RDI", "EDI", "XMM0", "X0", "W0", "o0"
message Memory   { optional string base_reg = 1; int64 offset = 2; }   // [base_reg_on_entry + offset]; no base_reg → absolute address
message Value    { oneof inner_value { Register reg = 1; Memory mem = 2; } }
message Variable { repeated Value values = 1; TypeSpec type = 2; }    // parameters: exactly 1 value supported
message Parameter { optional string name = 1; Variable repr_var = 2; }
```

All locations describe machine state **immediately before the first instruction of the function executes**. For returns, they describe the state immediately after the function returns.

**Callable** (the prototype):

```proto
message Callable {
  Value return_address = 2;               // where the return address is on entry; absent → no return address (e.g. _start)
  repeated Parameter parameters = 3;
  optional Variable return = 4;           // ONE type, possibly several locations (see below)
  bool is_variadic = 5;
  bool is_noreturn = 6;
  CallingConvention calling_convention = 7;
  optional TypeSpec type = 8;             // if present, a FunctionType that overrides params/returns (ABI re-derived!)
  ReturnStackPointer return_stack_pointer = 10;   // { Register reg; optional int64 offset; }  REQUIRED unless `type` given
}
message Function { uint64 entry_address = 1; map<string,uint64> context_assignments = 2;
                   FunctionLinkage func_linkage = 3; Callable callable = 4; }        // callable REQUIRED
message Callsite { uint64 call_address = 1; uint64 inside_function_address = 2; Callable callable = 3; }
message GlobalVariable { TypeSpec type = 1; uint64 address = 2; }
message Symbol { string name = 1; uint64 address = 2; }
message MemoryRange { uint64 address = 1; bool is_writeable = 2; bool is_executable = 3; bytes values = 4; }
```

**Control-flow overrides**, keyed by the address of the instruction:

```proto
message JumpTarget { uint64 address = 1; map<string,uint64> context_assignments = 2; }
message Jump   { uint64 address = 1; repeated JumpTarget targets = 2; bool stop = 3; }
message Call   { uint64 address = 1; optional uint64 return_address = 2; bool is_tailcall = 3; bool stop = 4;
                 optional uint64 target_address = 5; }
message Return { uint64 address = 1; bool stop = 2; }
message Other  { uint64 address = 1; bool stop = 2; }
message ControlFlowOverrides { repeated Jump jumps = 1; repeated Call calls = 2; repeated Return returns = 3;
                               repeated Other others = 4; }
```

### 5.3 What the lifter actually requires (from `FunctionLifter.cpp`)

These requirements are not written down anywhere else.

| Remill flow at instruction `pc` | Overrides used at `pc` | Without an override (or with an override of another kind, which is logged and ignored) |
|---|---|---|
| Normal / NoOp | `Other`. `Other.stop=true` ends the block with `__remill_error` (`lifter/flow/stop_override`) | the instruction falls through |
| DirectJump | `Jump` with exactly 1 target, equal to the decoded target (else `LOG(FATAL)`/`CHECK`), or `Call` (tail call, `lifter/flow/tail_call`) | `br` to the decoded target (`lifter/flow/direct_jump_no_override`) |
| IndirectJump | `Jump` (0 targets → `__remill_jump`; 1 → `br`; N → switch, `lifter/flow/jump_table`), `Call` (tail call), or `Return` | a terminating tail call to `__remill_jump` (`lifter/flow/indirect_jump_unknown`) |
| Direct / indirect call | `Call` (looked up by `CallFunction`; `target_address` redirects) | a call with no redirection; the prototype comes from the callee's declaration or a call site (`lifter/flow/direct_call`, `indirect_call_callsite`), else `__remill_function_call` (`call_without_prototype`) |
| FunctionReturn | not consulted | — |
| Conditional | the taken branch is checked as above | — |

**Fixed:** the three "Otherwise" cases for jumps and calls used to be `LOG(FATAL)` (including "Invalid spec for
call"), so a producer had to emit a `Jump` record for every direct jump and a `Call` record for every call. Overrides
are now only needed where the default is wrong.

`Call.target_address` redirects the call. It is used for thunks: the callee's prototype is looked up at the redirected address and the call goes there. `Call.return_address`, `Call.is_tailcall` and `Call.stop` are parsed but **not read by the lifter** in this revision.

### 5.4 Function prototype decoding rules (`ProtobufTranslator::ParseIntoCallableDecl`)

1. Copy `is_noreturn`, `is_variadic` and `calling_convention`.
2. **If `callable.type` is present:**
   - Decode it to an LLVM `FunctionType`. It must be a function type, and its variadic flag must match `is_variadic`.
   - Create a dummy `llvm::Function` in a scratch module prepared for the arch, with the cc and noreturn set.
   - Call `FunctionDecl::Create(dummy, arch)`. This runs the calling-convention allocator (§8), which *computes* the parameter and return locations from the C-level type.
   - The spec's explicit `parameters`, `return` and `return_stack_pointer` are ignored in this mode.
3. **Else (explicit locations):**
   - Each `Parameter` needs a `repr_var` with **exactly one** `Value` and a `type`. It is decoded to a `ParameterDecl {reg | (mem_reg, mem_offset), type, spec_type, name}`.
   - `return_address`: decoded with type `uint<address_size>`. If absent, `return_address.type = void`, meaning there is no return address.
   - `return_stack_pointer.reg` is **required** (otherwise the error "Non-present or non-object 'return_stack_pointer'"). The offset defaults to 0.
   - `return`: **one** TypeSpec applied to **every** `Value` in `return.values`. With N values, you get N `ValueDecl`s of the same type.
   - **Void returns.** An absent `return`, or a `return` without values, means a void return; `return.type` is only
     decoded when there are values. (**Fixed:** `return.type` used to be decoded unconditionally, so an absent
     `return` failed with "Unknown/invalid data type" and the function or call site was silently skipped; producers
     had to send `return { type { base: BT_VOID } }`. That form is still accepted. `lifter/spec/void_return`.) The
     same applies to `Callsite.callable` and to the `--default_callable_spec` file (§14).
   - The LLVM type is `FunctionType(ret, [param types], is_variadic)`. `ret` is `void` for 0 returns, the single return type for 1, and otherwise a **literal non-packed** `StructType::get(ctx, {types})`.

Example: a protobuf text-format function for `int main(int argc, char **argv)` on amd64 Linux.

```textproto
arch: ARCH_AMD64
operating_system: OS_LINUX
functions {
  entry_address: 0x401130
  callable {
    return_address { mem { base_reg: "RSP" offset: 0 } }
    return_stack_pointer { reg { register_name: "RSP" } offset: 8 }
    parameters { name: "argc" repr_var { values { reg { register_name: "EDI" } } type { base: BT_I32 } } }
    parameters { name: "argv" repr_var { values { reg { register_name: "RSI" } }
                                        type { pointer { pointee { pointer { pointee { base: BT_CHAR } } } } } } }
    return { values { reg { register_name: "EAX" } } type { base: BT_I32 } }
    calling_convention: CALLING_CONVENTION_AMD64_SYSV
  }
}
memory_ranges { address: 0x401130 is_executable: true values: "\x8d\x47\x01\xc3" }   # lea eax,[rdi+1]; ret
overrides { returns { address: 0x401133 } }
symbols { name: "main" address: 0x401130 }
```

You can instead set `callable.type { function { return_type { base: BT_I32 } arguments {...} arguments {...} } }` and let the allocator place the arguments (EDI and RSI here). (**Fixed:** that path used to be broken by the `DecodeType` bug described at the end of §6.) See `tests/golden/lifter/spec/callable_type.textproto` and the multi-architecture cases in `tests/golden/lifter/arch/`.

### 5.5 Type alias table

`type_aliases: map<int64, TypeSpec>` holds named or recursive types, which `TypeSpec.alias = id` refers to. It is decoded once, up front (`DecodeTypeMap`), with memoisation.

To break cycles, the decoder inserts a placeholder `type_map[id]` *before* recursing. A default `TypeSpec` is `BaseType::Bool`. This is harmless because pointer pointees are erased at the LLVM level (opaque `ptr`).

Example: a linked list `struct node { struct node *next; int v; }`.

```textproto
type_aliases { key: 1 value { struct { members { pointer { pointee { alias: 1 } } } members { base: BT_I32 } } } }
global_variables { address: 0x404000 type { alias: 1 } }
```

---

## 6. Loading a specification

`Specification::DecodeFromPB(LLVMContext&, const std::string& | std::istream&)` → `Result<Specification, std::string>` (lib/Specification.cpp). It works as follows:

1. `spec.ParseFromString(pb)`. On failure: "Failed to parse specification".
2. `GetArch`: map `arch`/`operating_system` to Remill names and `remill::Arch::Build`. An unsupported combination is an error.
3. Construct `SpecificationImpl{arch, TypeDictionary(ctx), TypeTranslator(dict, arch)}` and call `ParseSpecification`, which returns either a hard error or a vector of *warnings*. Warnings are `LOG(ERROR)`'d and the item is skipped.
   - `DecodeTypeMap(type_aliases)`. A failure is a warning.
   - **functions**: each is decoded (§5.4). A failure is a warning and the function is skipped. A duplicate `entry_address` is a **hard error**. The result is stored in `functions` (sorted by address) and `address_to_function`.
   - **callsites**: decoded the same way. The key is `(inside_function_address, call_address)`. A duplicate is a hard error. Stored in `call_sites` (sorted) and `loc_to_call_site`.
   - **global_variables**: decoded with `DecodeGlobalVar`. The type must decode, must not be a function type, must not be void, and must be sized. Stored in `variables` (sorted) and `address_to_var`. A variable that fails to decode is skipped with a warning. (**Fixed:** there was no `continue` after a decode failure, so `maybe_var.Value()` was called on a failed `Result` and threw `std::logic_error`; `lifter/spec/global_variables`.) A duplicate variable address is a hard error. (**Fixed:** the duplicate check looked in `address_to_function`, not `address_to_var`.)
   - **symbols**: an empty name is a hard error. Stored in `multimap<uint64, string>`.
   - **memory_ranges**: expanded **byte by byte** into `std::map<uint64, pair<uint8, BytePermission>>`. The permission is `R`, `RW`, `RX` or `RWX` from the two flags. An overlapping byte is a hard error ("was previously mapped").
   - **overrides**: optional (**fixed:** an absent `overrides` used to be the hard error "Spec has no control flow overrides"). Each jump, call, return and other is stored in a sorted vector *and* in `unordered_map<uint64, ControlFlowOverride> control_flow_overrides`. A duplicate address across kinds is the error "Multiple control-flow overrides for address …" (**fixed:** it was a `CHECK` failure that aborted the process; `lifter/spec/duplicate_override`). Jump targets are sorted by address.
4. `Specification` is a cheap handle (`shared_ptr<SpecificationImpl>`).
   - Accessors: `FunctionAt`, `VariableAt`, `VariableContaining` (finds the variable whose `[address, address + size)` contains the address; **fixed:** it used to match exact start addresses only), and `ForEach{Symbol,Function,Variable,CallSite,ControlFlowRedirect,Jump,Call,Return,MiscOverride}`.
   - `operator!=` returns `impl != that.impl` (**fixed:** it returned `impl == that.impl`).
   - `redirections` is never populated.

Protobuf type decoding (`ProtobufTranslator::DecodeType`):

- base → `static_cast<BaseType>`
- unknown → `UnknownType{n}`
- pointer → `PointerType{pointee or void, const}`
- vector/array → `{base, size}`, with an error if base is missing
- struct → members
- alias → `type_map.at(id)`

The one-argument overload builds a `FunctionType` for `has_function()` and returns it. (**Fixed:** it used to fall through without returning, ending in "Unknown/invalid data type", so **every function-typed TypeSpec failed to decode**, directly or via an alias, and every function or call site using `callable.type` was skipped with a warning.) The two-argument (alias-map) overload delegates to the one-argument one for anything it does not handle itself. Both prototype styles now work: `parameters`/`return`, or `callable.type` with the allocator of §8.

---

## 7. The type system

Sources: `include/anvill/Type.h`, `lib/Type.cpp`, `docs/TypeEncoding.md`.


### 7.1 TypeSpec model (language-neutral type AST)

```cpp
enum class BaseType : int { Bool=0, Char=1, SignedChar=2, UnsignedChar=3, Int8=4, UInt8=5, Int16=6, UInt16=7,
  Int24=8, UInt24=9, Int32=10, UInt32=11, Int64=12, UInt64=13, Int128=14, UInt128=15, Float16=16,
  Float32=17, Float64=18, Float80=19, Float96=20, Float128=21, MMX64=22, Void=23, Padding=24 };
struct UnknownType { unsigned size; };                       // size in bytes
struct PointerType { TypeSpec pointee; bool is_const; };
struct VectorType  { TypeSpec base; unsigned size; };
struct ArrayType   { TypeSpec base; unsigned size; };
struct StructType  { std::vector<TypeSpec> members; };
struct FunctionType{ TypeSpec return_type; std::vector<TypeSpec> arguments; bool is_variadic; };
using TypeSpec = std::variant<BaseType, std::shared_ptr<PointerType>, std::shared_ptr<VectorType>,
    std::shared_ptr<ArrayType>, std::shared_ptr<StructType>, std::shared_ptr<FunctionType>, UnknownType>;
enum class TypeKind : unsigned char { kUnknown, kBoolean, kCharacter, kIntegral, kFloatingPoint, kMMX, kVoid, kPadding };  // declared, unused
struct TypeSpecificationError { enum class ErrorCode { InvalidSpecFormat, InvalidState }; ErrorCode error_code; std::string message; };
enum EncodingFormat : bool { kDefault = false, kValidSymbolCharsOnly = true };
```
A default-constructed `TypeSpec` is `BaseType::Bool` (index 0). Protobuf alias decoding relies on this for recursive types: the placeholder inserted before recursing is Bool, which is harmless because pointers ignore their pointee.
The BaseType enum mirrors `specification.proto` `BaseType`; Protobuf decoding does `static_cast<BaseType>(base)`. Proto `TypeSpec` oneof is: base, pointer{pointee,const}, vector{base,size}, array{base,size}, struct{members, optional identifier}, function{return_type, arguments, is_variadic}, unknown(uint32), alias(int64 → shared type table).
(Cross-ref, Protobuf area: in the 1-arg `ProtobufTranslator::DecodeType` the `has_function()` branch builds `res` but never returns it, so it falls through to the error `"Unknown/invalid data type"`. The 2-arg alias-map overload is used only for decoding the `type_aliases` table. Parameters, returns, globals and `callable.type` all use the 1-arg overload, so function types never decode (§6).)

### 7.2 TypeDictionary

```cpp
class TypeDictionary {
 public:
  explicit TypeDictionary(llvm::LLVMContext &);
  union { struct NamedTypes { llvm::Type *bool_, *char_, *schar, *uchar, *int8, *uint8, *int16, *uint16,
           *int24, *uint24, *int32, *uint32, *int64, *uint64, *int128, *uint128, *float16, *float32, *float64,
           *float80_12, *float80_16, *float128, *m64, *void_, *padding; } named;
          llvm::Type *indexed[25]; } u;      // indexed[i] == the field for BaseType i
  llvm::Value *ConvertValueToType(llvm::IRBuilderBase&, llvm::Value*, llvm::Type*) const;
  bool IsPadding(llvm::Type*) const noexcept;
};
```
The field order exactly matches the `BaseType` numbering, so `DecodeFromSpec(BaseType b)` = `u.indexed[(int)b]`.
`ANVILL_USE_WRAPPED_TYPES` is hard-coded to 0, so the plain mapping is:

| BaseType | encoding char | LLVM type |
|---|---|---|
| Bool | `?` | i8 |
| Char / SignedChar / UnsignedChar | `c` / `s` / `S` | i8 |
| Int8 / UInt8 | `b` / `B` | i8 |
| Int16 / UInt16 | `h` / `H` | i16 |
| Int24 / UInt24 | `w` / `W` | i24 |
| Int32 / UInt32 | `i` / `I` | i32 |
| Int64 / UInt64 | `l` / `L` | i64 |
| Int128 / UInt128 | `o` / `O` | i128 |
| Float16 | `e` | half |
| Float32 | `f` | float |
| Float64 | `F` | double |
| Float80 (float80_12) | `d` | x86_fp80 |
| Float96 (float80_16) | `D` | x86_fp80 |
| Float128 | `Q` | fp128 |
| MMX64 | `M` | x86_mmx |
| Void | `v` | void |
| Padding | `p` | i8 |

With wrapped types enabled (dead code), each would be a packed named struct `__anvill_<name>` wrapping the primitive (e.g. `%__anvill_int32 = <{ i32 }>`), and float80 would be `[10 x i8]`/`[12 x i8]`.
- `IsPadding` → always false (non-wrapped build).
- `ConvertValueToType(ir, v, dest)`: if same type, return v. CHECK that neither side is the void type. In the non-wrapped build `FindTypeInList` always returns nullopt, so this reduces to `AdaptToType(ir, v, dest)` (§B.1). The wrapped branches are `LOG(FATAL) "TODO"` or an `extractvalue 0` followed by AdaptToType.

### 7.3 TypeTranslator

```cpp
class TypeTranslator {
  std::unique_ptr<TypeSpecifierImpl> impl;   // {LLVMContext &context; const DataLayout dl; const TypeDictionary type_dict;
                                             //  unordered_map<StructType*,size_t> type_to_id; vector<StructType*> id_to_type;}
 public:
  TypeTranslator(const TypeDictionary&, const llvm::DataLayout&);
  TypeTranslator(const TypeDictionary&, const llvm::Module&);          // module.getDataLayout()
  TypeTranslator(const TypeDictionary&, const remill::Arch*);          // arch->DataLayout()
  TypeTranslator(const TypeDictionary&, const std::unique_ptr<const remill::Arch>&);
  const TypeDictionary &Dictionary() const noexcept;
  const llvm::DataLayout &DataLayout() const noexcept;
  std::string EncodeToString(llvm::Type*, EncodingFormat = kDefault) const;
  Result<llvm::Type*, TypeSpecificationError> DecodeFromSpec(TypeSpec) const;
};
```
The context is taken from `type_dict.u.named.bool_->getContext()`. There is no string-to-type decoder any more: the tests reference a `DecodeFromString` that has been removed, and that test is commented out.

### 7.4 DecodeFromSpec (TypeSpec → llvm::Type)

- BaseType b → `u.indexed[b]`.
- Pointer → `ptr` (address space 0). Pointee and constness are dropped.
- Vector{base,n} → `FixedVectorType::get(decode(base), n)`.
- Array{base,n} → `ArrayType::get(decode(base), n)`.
- Struct{members} → `StructType::get(ctx, elems, /*isPacked=*/true)`, a **packed literal** struct `<{...}>`. Padding must be explicit (`p` members → i8).
- Function{ret,args,variadic} → `FunctionType::get(decode(ret), args, variadic)`. This is a function type, not a pointer.
- UnknownType{size} → `IntegerType::get(ctx, size == UINT32_MAX ? 32 : size*8)`. The UINT32_MAX special case exists because Ghidra reports undefined types that way.
- Errors propagate from children. Falling off the end gives `{InvalidState, "Function fell out of bounds"}`.

Test expectations (tests/tools/src/TypeSpecification.cpp): Int64 → `i64`; Int32 → `i32`; Pointer(Void) → `ptr`; `Function(Void, [Int32, Int8, ptr, Int32])` → `void (i32, i8, ptr, i32)`; Int8 → `i8`; Int16 → `i16`; Float16 → `half`. All use DataLayout `e-m:e-i64:64-f80:128-n8:16:32:64-S128` or the module default.

### 7.5 EncodeToString (llvm::Type → text)

`EncodeToString(type, fmt)`: return "" for null. Otherwise clear `type_to_id`, `RecontextualizeType` into the translator's context, then call `EncodeType`. In the table below the first token is the kDefault form and the one after `|` is kValidSymbolCharsOnly ("alnum").

| LLVM | default | alnum |
|---|---|---|
| void | `v` | `v` |
| half/float/double/fp128 | `e`/`f`/`F`/`Q` | same |
| x86_fp80 | `d` if `allocsize==12`, else `D` **[QUIRK: inverts the docs table, which says d=10 bytes and D=12]** | same |
| x86_mmx | `M` | `M` |
| iN | **always unsigned letters**: N≤8 `B`, ≤16 `H`, ≤32 `I`, ≤64 `L`, ≤128 `O`; else LOG(ERROR) and emit `[Bx<bytes>]` | `_CBx<bytes>_D` |
| ptr | `*` | `_S` |
| function | `(` params… then `&` if vararg, else `v` if 0 params; then ret `)` | `_A` … `_V` … `_B` |
| fixed vector | `<` elem `x` N `>` | `_G` elem `x` N `_H` |
| array | `[` elem `x` N `]` | `_C` elem `x` N `_D` |
| struct = a TypeDictionary named type | its letter (`?`,`c`,…; only reachable when wrapped types are on) | |
| opaque struct | `v` | `v` |
| other struct seen before | `%<id>` | `_M<id>` |
| other struct (new) | `=<id>{` … `}` | `_X<id>_E` … `_F` |
| other (e.g. bfloat, ppc_fp128, scalable vectors) | if allocsize > storesize: `{[Bx<store>][Bx<pad>]}`, else `[Bx<store>]` | `_E_C`…`_D_C`…`_D_F` / `_C`…`_D` |

Struct body algorithm: `id = type_to_id.size()` is assigned *before* recursing (so recursive types emit back-references). Then walk the members using `dl.getStructLayout`: if the member offset > expected, emit padding (`diff<8` → `diff`×`p`, otherwise `[px<diff>]` / `_Cpx<diff>_D`); `offset < expected` → LOG(FATAL) (bitfields?). Emit the member and set `expected = offset + storesize(member)`. Tail padding up to allocsize uses the same rule.

Examples (x86-64 DL):
- `i32` → `I`; `ptr` → `*` / `_S`.
- `{i32, ptr}` (non-packed) → `=0{Ipppp*}` / `_X0_EIpppp_S_F`; `<{i32, ptr}>` → `=0{I*}`.
- `{i16 ×10}` → `=0{HHHHHHHHHH}`. The commented-out test expects `hhhh…`; that expectation is obsolete because signed letters are never emitted.
- `[100 x %S]` → `[=0{…}x100]` / `_C_X0_E…_Fx100_D`.
- `i64 (%S2)` → `(=0{…}L)` / `_A_X0_E…_FL_B`; variadic: `(…&L)` / `_A…_VL_B`.
- `void ()` → `(vv)`; `void (...)` → `(&v)`.
- Global variable names: `var_4010_I` for i32 at 0x4010, `var_4010__S` for a pointer, `var_4010__X0_EIpppp_S_F` for `{i32,ptr}`; aliases `data_4010_…`.

docs/TypeEncoding.md documents the grammar for the *spec* encoding: signed letters exist; `=N{…}` defines identified structs and `%N` references them (ids start at 0 and are sequential); a function needs ≥1 param token (`v` for none, `&` for variadic-only), and `&` must come immediately before the return type; vectors are `<Tx N>`, arrays `[Tx N]`; structs are packed with explicit padding. Examples from the doc: `(vv)`, `(vi)`, `(&v)`, `(i?f)`, `(i&f)`, and the linked list `=0{*%0i}`.

### 7.6 Type → ABI mapping summary
Spec TypeSpec → (DecodeFromSpec) LLVM type → dummy `llvm::Function` → `FunctionDecl::Create` → CallingConvention → ValueDecl locations, and `decl.type` is rewritten to the ABI layout (§8.4). The original spec function type is kept as `decl.spec_type` (`shared_ptr<FunctionType>`), and each ValueDecl/VariableDecl has `spec_type`.

### 7.7 Type-hint intrinsics
- Name: `__anvill_type_hint<alnum-encoding-of-the-hinted-type>`. Test IR shows `declare ptr @__anvill_type_hint_Sb(i64)`, `@__anvill_type_hint_S_X0_Ell_F(i64)`, etc. The form is i64 in, ptr out, with a typed-pointer-era encoding such as `_Sb` = "pointer to int8".
- Nothing in lib/ *creates* them in this revision. Consumers:
  - `LowerTypeHintIntrinsics` pass: for every call whose callee name starts with the prefix, take `arg0->stripPointerCasts()`, emit `CreateBitOrPointerCast(arg0, call->getType())`, copy metadata, RAUW, and erase the call if it is unused.
  - `CrossReferenceFolderImpl::ResolveCall`: looks through the call (resolves `arg0`, size = pointer bits).


---

## 8. Declarations and calling conventions (ABI layer)

Sources: `include/anvill/Declarations.h`, `lib/Declarations.cpp`, `include/anvill/ABI.h`, `lib/ABI.cpp`, `lib/Arch/*`.

A *declaration* says where every input and output of a function lives at the machine level. A *calling convention* object computes such a declaration from a C-level LLVM function type. §8.1–8.5 describe the declaration structures and how they are used. §8.6–8.11 describe the calling-convention allocators.


### 8.1 Structs (every field)

```cpp
struct ValueDecl {                       // a parameter/return location
  const remill::Register *reg{nullptr};       // value lives in this register, OR
  const remill::Register *mem_reg{nullptr};   // value lives at [entry_value(mem_reg) + mem_offset]
  std::int64_t mem_offset{0};                 // (if reg==mem_reg==null && mem_offset!=0 → absolute address)
  TypeSpec spec_type;                         // source-level type
  llvm::Type *type{nullptr};                  // LLVM (ABI) type of the value
};
struct ParameterDecl : ValueDecl { std::string name; };
struct VariableDecl {
  llvm::Type *type{nullptr}; TypeSpec spec_type; std::uint64_t address{0};
  llvm::GlobalVariable *DeclareInModule(const std::string &name, llvm::Module&) const;
};
struct CallableDecl {
  void OverrideFunctionTypeWithABIReturnLayout(); void OverrideFunctionTypeWithABIParamLayout();
  const remill::Arch *arch{nullptr};
  std::shared_ptr<FunctionType> spec_type;          // anvill::FunctionType (TypeSpec)
  llvm::FunctionType *type{nullptr};                 // ABI-level LLVM type
  ValueDecl return_address;                          // where the RA is on entry ([esp], [rsp], x30, lr, o7)
  const remill::Register *return_stack_pointer{nullptr};   // SP on exit = entry(return_stack_pointer) + offset
  std::int64_t return_stack_pointer_offset{0};
  std::vector<ParameterDecl> params;                 // (amd64 variadic: spec should include AL explicitly)
  std::vector<ValueDecl> returns;                    // (amd64 EH: RDX may be an explicit 2nd return)
  bool is_noreturn{false}; bool is_variadic{false};
  llvm::CallingConv::ID calling_convention{0u};
  llvm::Value *CallFromLiftedBlock(llvm::Value *target, const TypeDictionary&, const remill::IntrinsicTable&,
                                   llvm::BasicBlock*, llvm::Value *state_ptr, llvm::Value *mem_ptr) const;
  static Result<CallableDecl, std::string> DecodeFromPB(const remill::Arch*, const std::string &pb);
};
struct FunctionDecl : CallableDecl {
  std::uint64_t address{0};
  std::uint64_t num_bytes_in_redzone{0};
  bool lift_as_decl{false};
  bool is_extern{false};
  std::unordered_map<std::string, std::uint64_t> context_assignments;   // decoding context at entry, e.g. {"TM":1} (Thumb)
  llvm::Function *DeclareInModule(std::string_view name, llvm::Module&) const;
  static Result<FunctionDecl, std::string> Create(llvm::Function&, const remill::Arch*);
  static Result<FunctionDecl, std::string> Create(llvm::Function&, const std::unique_ptr<const remill::Arch>&);
};
struct CallSiteDecl : CallableDecl { std::uint64_t address{0}; std::uint64_t function_address{0}; };
```
In the spec, call sites are keyed by `(function_address, address)` (`loc_to_call_site`).

### 8.2 DeclareInModule
- `VariableDecl::DeclareInModule(name, M)`: `t = RecontextualizeType(type, M.ctx)`. If `M.getGlobalVariable(name)` exists with value type t, return it. Otherwise return `new GlobalVariable(M, t, /*const*/false, ExternalLinkage, /*init*/nullptr, name)`; LLVM auto-renames on collision.
- `FunctionDecl::DeclareInModule(name, M)`: `ft = RecontextualizeType(type)`. If a function with that name and the same type exists, return it. Otherwise (DLOG on a type mismatch) `Function::Create(ft, ExternalLinkage, name, &M)`, add `noinline`, add `noreturn` if `is_noreturn`, `setCallingConv(calling_convention)`, and name each arg `params[i].name`. This assumes `params.size() == #args`, which holds once the ABI param layout is applied.

### 8.3 FunctionDecl::Create / CallableDecl::DecodeFromPB
- `Create`: see §8.8.
- `DecodeFromPB(arch, pb)`: `specification::Function::ParseFromString` (error `"Failed to parse callable decl"`). Builds a local `TypeDictionary(*arch->context)`, a `TypeTranslator(dict, arch)`, an empty `type_map` and a `ProtobufTranslator`, then calls `DecodeDefaultCallableDecl(function)`, which requires `function.has_callable()` and runs `ParseIntoCallableDecl(callable, nullopt, decl)`. Error: `"Failed to decode to default callable decl"`. Used by `anvill-decompile-spec --default_callable_spec` to feed `DefaultCallableTypeProvider::SetDefault`.
- Protobuf path, for context: if the spec function has a `type`, it is decoded to an LLVM FunctionType; a dummy `llvm::Function` is created in a fresh module prepared with `arch->PrepareModule` (cc and noreturn copied) and run through `FunctionDecl::Create`. Otherwise the params/returns/RA/return-SP come straight from the spec, and `decl.type = FunctionType(ret, params, variadic)` with `ret` = void, the single return type, or `StructType::get(ctx, ret_types, false)` (a *literal, non-packed* struct) for several returns.

### 8.4 ABI type override (applied after CC allocation)
- `OverrideFunctionTypeWithABIReturnLayout()`: 0 returns → the return type becomes `void`. (**Fixed:** the type used to be kept unchanged, so a result passed through memory with no return register, e.g. AArch64's X8 buffer, left a non-void native function with nowhere to read its value from.) 1 return → `FunctionType(returns[0].type, old params, vararg)`. N>1 → `StructType::create(elems)`, an *identified, unnamed* struct (prints as `%0`, `%1`, …), used as the return type.
- `OverrideFunctionTypeWithABIParamLayout()`: `FunctionType(old ret, [p.type for p in params], vararg)`. Struct params split across registers therefore become several scalar params, and an injected sret becomes an extra leading param.
- Example (x86 cdecl `long long f(int)`): `returns=[EAX:i32, EDX:i32]` → `decl.type = %0 (i32)`, `%0 = type {i32, i32}`.

### 8.5 CallFromLiftedBlock (the "call native function from lifted code" thunk)

Signature: `Value *CallFromLiftedBlock(Value *target, const TypeDictionary &types, const IntrinsicTable &intrinsics, BasicBlock *block, Value *state_ptr, Value *mem_ptr) const`. It CHECKs that all values share one LLVMContext and uses `IRBuilder ir(block)` at the block end.
1. `sp_reg = arch->RegisterByName(arch->StackPointerRegisterName())`; `ptr_to_sp = sp_reg->AddressOf(state_ptr, block)` (a GEP into the remill `State`).
2. `new_sp_base = return_stack_pointer->AddressOf(state_ptr, block)`; `sp_val_on_exit = add(load(return_stack_pointer->type, new_sp_base), ConstantInt(return_stack_pointer->type, offset, signed))`. **This is computed from the pre-call state.**
3. `ret_addr = LoadLiftedValue(return_address, …)`, CHECKed not null and not undef.
4. For each param: `v = LoadLiftedValue(param)`; if it is an Instruction, `setName(param.name)`; collect.
5. Call: if `target` is an `llvm::Function`, `CreateCall(func, args)` (uses the function's own type); otherwise `CreateCall(RecontextualizeType(this->type), target, args)` (indirect).
6. `is_noreturn` → `call->setDoesNotReturn()`.
7. Returns: exactly 1 → `mem_ptr = StoreNativeValue(call, returns[0], …)`. Otherwise, for each i: `extractvalue call, i` then `StoreNativeValue`. Zero returns do nothing.
8. Store `ret_addr` into the function's `NEXT_PC` variable (`remill::FindVarInFunction(block, remill::kNextPCVariableName).first`), then store `sp_val_on_exit` into `ptr_to_sp`.
9. Return `UndefValue(mem_ptr type)` if noreturn, else `mem_ptr` (it may be updated by memory stores for stack-resident returns).

Callers: `FunctionLifter::TryCallNativeFunction` (direct call to a declared/lifted function; loads mem_ptr from `MEMORY`, calls this, stores the result back) and the call-through-PC path (`dest_func = BitOrPointerCast(pc, ptr)`, indirect).

Real IR: in `tests/golden/lifter/flow/direct_call.lifted.ll` (`int f(int a) { return g(a * 3) + a; }`, with `g`
declared `i32 (i32)` in EDI/EAX), after the lifter's local cleanup has inlined the semantics and promoted the
State, the thunk for `call g` is:

```llvm
  %26 = call noundef ptr @__remill_write_memory_64(ptr noundef %16, i64 noundef add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 -8), i64 noundef add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198419)) #2, !pc !4
  %27 = call i64 @__remill_read_memory_64(ptr %26, i64 add (i64 sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 16), i64 -8)), !pc !4
  %28 = trunc i64 %18 to i32
  %29 = call i32 inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4202496) to ptr)(i32 %28) #3, !pc !4
  %30 = call noundef i32 @__remill_read_memory_32(ptr noundef %26, i64 noundef sub (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8), i64 4)) #2, !pc !5
```

`%26` pushes the return address (`0x401013`, PC-relative), `%27` reloads it from `[RSP]` (the `return_address`
location), `%28` is the argument read from EDI (the low half of the 64-bit product), and `%29` is the native call
(indirect through the PC-tainted address of `g` until `ConvertAddressesToEntityUses` turns it into `@g`). The
`EAX` store of `%29` and the `RSP + 8` update were folded into later uses. The optimized form is in
`direct_call.optimized.ll`.

For an `i32` return in `RAX:i32`: `store i64 0, RAX` then `store (zext i32 %r to i64), RAX`. For `double` in `XMM0` (a vector-ish remill type): store zero to the whole register, then, because AdaptToType returns null, store the double directly through the register pointer.




### 8.6 Constraint vocabulary (lib/Arch/Arch.h)

```cpp
enum SizeConstraint : unsigned {     // one bit per size
  kBit8=1<<0, kBit16=1<<1, kBit32=1<<2, kBit64=1<<3, kBit80=1<<4,
  kBit128=1<<5, kBit256=1<<6, kBit512=1<<7,
  kMaxBitN = all bits <= N   // e.g. kMaxBit64 = 8|16|32|64   ("register can hold up to N bits")
  kMinBitN = all bits >= N   // e.g. kMinBit64 = 64|80|128|256|512 ("value needs at least N bits")
};
enum TypeConstraint : unsigned {
  kTypeInt=1, kTypePtr=2, kTypeFloat=4, kTypeVec=8,
  kTypeIntegral = Int|Ptr, kTypeNumeric = Integral|Float, kTypeFloatOrVec = Float|Vec };

struct VariantConstraint { std::string register_name; TypeConstraint type_constraint; SizeConstraint size_constraint; };
struct RegisterConstraint { std::vector<VariantConstraint> variants;      // sub-register aliases, SMALLEST FIRST, largest LAST
                            bool ContainsVariant(const std::string &name) const; };  // linear name match
struct SizeAndType { SizeConstraint sc; TypeConstraint tc; };
```

A `RegisterConstraint` = one physical register "slot" (e.g. DIL/DI/EDI/RDI). Vector-of-`RegisterConstraint` = ordered allocation pool.

Helper functions:
- `std::vector<std::string> TryRecoverParamNames(const llvm::Function&)`:
  1. for each arg i: `arg.getName()` if it has a name, else `"param" + to_string(i)` (0-based).
  2. scan all instructions for `llvm.dbg.declare` / `llvm.dbg.value`; if the `DILocalVariable` `isParameter()` and `getArg() <= n` and name non-empty: `names[getArg()-1] = name` (getArg is 1-based).
- `ApplyX86Ext(constraints, arch_name)`: for every RegisterConstraint with exactly one variant whose name starts with `"XMM"`: parse N (`XMM0`..`XMM15`) and replace by
  - AVX (`kArchX86_AVX`/`kArchAMD64_AVX`): `{XMMn: kTypeFloatOrVec, kMaxBit128}, {YMMn: kTypeFloatOrVec, kMaxBit256}`
  - AVX512: `{XMMn,128},{YMMn,256},{ZMMn: kTypeFloatOrVec, kMaxBit512}`
  - otherwise unchanged. The replacement always uses `kTypeFloatOrVec`, even if the original XMM entry was `kTypeVec`. (This used to change SysV aggregate returns between plain AMD64 and AVX; aggregates are now classified by `ClassifyEightbytes`, which does not use these entries, so both give the same result. See §8.11.)
- `SelectX86Constraint(arch_name, basic, avx, avx512)`: `kArchX86`/`kArchAMD64` → basic; `*_AVX` → avx; anything else → avx512.

### 8.7 CallingConvention interface

```cpp
class CallingConvention {
 public:
  using Ptr = std::unique_ptr<CallingConvention>;
  CallingConvention(llvm::CallingConv::ID identity, const remill::Arch *arch);
  static Result<Ptr, std::string> CreateCCFromArch(const remill::Arch *arch);
  static Result<Ptr, std::string> CreateCCFromArchAndID(const remill::Arch *arch, llvm::CallingConv::ID cc_id);
  Result<FunctionDecl, std::string> AllocateSignature(llvm::Function &func);          // non-virtual driver
  virtual llvm::Error AllocateSignature(FunctionDecl &fdecl, llvm::Function &func) = 0;  // per-CC
  llvm::CallingConv::ID ID() const;
 protected:
  const remill::Arch *const arch;
  static std::unique_ptr<CallingConvention> CreateX86_C / CreateX86_StdCall / CreateX86_FastCall /
     CreateX86_ThisCall / CreateX86_64_SysV / CreateAArch32_C / CreateAArch64_C / CreateSPARC32_C / CreateSPARC64_C(const remill::Arch*);
 private:
  const llvm::CallingConv::ID identity;
};
```

Identities: X86_C → `CallingConv::C (0)`; X86_StdCall → `X86_StdCall (64)`; X86_FastCall → `X86_FastCall (65)`; X86_ThisCall → `X86_ThisCall (70)`; X86_64_SysV → `X86_64_SysV (78)`; AArch32_C, AArch64_C, SPARC32_C, SPARC64_C → `C (0)`.

Driver `AllocateSignature(llvm::Function &func)`:
```
FunctionDecl decl;
decl.arch = arch; decl.type = func.getFunctionType();
decl.is_variadic = func.isVarArg(); decl.is_noreturn = func.hasFnAttribute(NoReturn);
decl.calling_convention = ID();
err = this->AllocateSignature(decl, func)  -> on error return GetErrorString(err)
decl.OverrideFunctionTypeWithABIReturnLayout();   // §8.4
decl.OverrideFunctionTypeWithABIParamLayout();
return decl;
```
Every concrete `AllocateSignature(fdecl, func)` does: `BindReturnValues(func, injected_sret&, fdecl.returns)` FIRST (it may decide on RVO/injected sret), then `BindParameters(func, injected_sret, fdecl.params)`, then sets `return_stack_pointer`, `return_stack_pointer_offset`, `return_address`.

### 8.8 Choosing a convention

`FunctionDecl::Create(llvm::Function &func, const remill::Arch *arch)` (Declarations.cpp):
- if `func.getCallingConv() != CallingConv::C` → `CreateCCFromArchAndID(arch, cc)`;
- else → `CreateCCFromArch(arch)` (by arch/OS);
- on failure: error `"Calling convention of function '<name>' is not supported: <err>"`;
- then `cc->AllocateSignature(func)`.

`CreateCCFromArch(arch)` (switch on `arch->arch_name`, then `arch->os_name`):
| arch | OS | CC |
|---|---|---|
| kArchInvalid | – | error `"Invalid architecture"` |
| X86, X86_AVX, X86_AVX512 | macOS, Linux, Solaris | X86_C |
| X86* | Windows | X86_StdCall |
| AMD64, AMD64_AVX, AMD64_AVX512 | macOS, Linux, Solaris | X86_64_SysV |
| AMD64* | Windows / other | error (no Win64 CC!) |
| AArch32LittleEndian | any | AArch32_C |
| AArch64LittleEndian | any | AArch64_C |
| Sparc32 | Linux, Solaris | SPARC32_C |
| Sparc64 | Linux, Solaris | SPARC64_C |
| anything else | | error `"Unsupported architecture/OS pair: <arch> and <os>"` |

`CreateCCFromArchAndID(arch, id)`:
| id | IsX86 | IsAMD64 | IsAArch64 | IsSPARC32 | IsSPARC64 |
|---|---|---|---|---|---|
| C | X86_C | X86_64_SysV | AArch64_C | SPARC32_C | SPARC64_C |
| X86_StdCall | X86_StdCall | X86_64_SysV (ignored on AMD64, as by compilers) | – | – | – |
| X86_FastCall | X86_FastCall | X86_64_SysV | | | |
| X86_ThisCall | X86_ThisCall | X86_64_SysV | | | |
| X86_64_SysV | – | X86_64_SysV | | | |
| else / no match | error `"Unsupported calling convention ID: <n>"` |

The `C` row also maps AArch32 to AArch32_C. (**Fixed:** stdcall/fastcall/thiscall on AMD64 used to return the 32-bit
cdecl object, with ESP-relative 4-byte slots; AArch32 was not reachable through the ID path.) There is still no
Win64 or vectorcall allocator, so AMD64 Windows is an error.

### 8.9 AllocationState (lib/Arch/AllocationState.{h,cpp}) — the register allocator

```cpp
struct AllocationConfig {
  bool can_pack_multiple_values_together{false};
  llvm::Type *(*type_splitter)(llvm::Type *) = nullptr;
};
struct AllocationState {
  AllocationState(const std::vector<RegisterConstraint>&, const remill::Arch*, const CallingConvention*);
  SizeAndType AssignSizeAndType(llvm::Type &type);
  llvm::Optional<std::vector<ValueDecl>> TryRegisterAllocate(llvm::Type &type);
  llvm::Optional<std::vector<ValueDecl>> TryCompositeRegisterAllocate(llvm::Type &type);
  llvm::Optional<std::vector<ValueDecl>> TryBasicRegisterAllocate(llvm::Type &type, llvm::Optional<SizeAndType> hint);
  llvm::Optional<std::vector<ValueDecl>> TryVectorRegisterAllocate(llvm::FixedVectorType &type);
  bool IsFilled(size_t i);            // RemainingSpace(i) == 0
  uint64_t RemainingSpace(size_t i);  // MaxSize(variants.back().size_constraint) - fill[i]
  llvm::Optional<std::vector<ValueDecl>> ProcessIntVecX86_64SysV(llvm::Type *elem, unsigned vec_size, unsigned bit_width);
  llvm::Error CoalescePacking(const std::vector<ValueDecl>&, std::vector<ValueDecl> &packed_out);
  const std::vector<RegisterConstraint> &constraints;
  const remill::Arch *arch;
  std::vector<bool> reserved;       // size = constraints.size(), init false
  std::vector<uint64_t> fill;       // bits used per register, init 0
  const CallingConvention *conv;
  AllocationConfig config;
  const SizeConstraint ptr_size_constraint;   // arch->address_size==32 ? kMinBit32 : kMinBit64
};
```

Size helpers:
- `SizeConstraintToMinSize(sc)`: first set bit scanning 8,16,32,64,80,128,256,512 → that size; none → 512.
- `SizeConstraintToMaxSize(sc)`: first set bit scanning 512 down to 8 → that size; none → 0.
- `GetSmallestVariantName(variants, size)`: first variant (in listed order, i.e. smallest first) with `MaxSize(vc.size_constraint) >= size`; else `""`.

`AssignSizeAndType(type)`:
| LLVM type | tc | sc |
|---|---|---|
| iN | kTypeInt | kMinBit8 (N≤8), 16, 32, 64, 80, 128, 256, 512 (first bucket ≥ N); >512 → LOG(FATAL) |
| half | kTypeFloat | kMinBit16 |
| float | kTypeFloat | kMinBit32 |
| double | kTypeFloat | kMinBit64 |
| fp128 | kTypeFloat | kMinBit128 |
| ptr | kTypeIntegral | ptr_size_constraint |
| x86_fp80 | kTypeIntegral **[QUIRK]** | kMinBit80 |
| fixed vector | kTypeFloatOrVec | kMinBit80 (unused in practice; vectors go through composite path) |
| other | LOG(FATAL) |

`TryRegisterAllocate(type)`: struct/array/vector → `TryCompositeRegisterAllocate`, else `TryBasicRegisterAllocate(type, None)`.

`TryCompositeRegisterAllocate(type)`:
- Struct: for each element in order: save `prev_pack`, set `config.can_pack_multiple_values_together = true`, `TryRegisterAllocate(elem)`; restore; on None → return None. Concatenate results. **Element offsets/padding are ignored**.
- Array: same, element type repeated `getNumElements()` times.
- FixedVector: `TryVectorRegisterAllocate(vec)`; if that returns None, so does the composite. (**Fixed:** it returned the empty `ret`, i.e. *success with zero locations*.)
- else LOG(FATAL).
- Rollback: `TryRegisterAllocate` restores `fill`/`reserved` when a composite fails midway. (**Fixed:** the state consumed by earlier members stayed consumed, so a SysV struct of 7×i64 ate RDI..R9, failed on the 7th, went to the stack, and later integer params landed on the stack too.)

`TryBasicRegisterAllocate(type, hint)`:
```
st   = hint ? *hint : AssignSizeAndType(type)
size = SizeConstraintToMinSize(st.sc)        // bits the value needs
has_free_regs = false
for i in 0..constraints.size():
   tc = constraints[i].variants.front().type_constraint   // assumed uniform across variants
   if reserved[i] || IsFilled(i) || !(tc & st.tc): continue
   if !config.can_pack_multiple_values_together && fill[i] != 0: continue
   has_free_regs = true
   if size <= RemainingSpace(i):
       fill[i] += size
       if RemainingSpace(i) == 0: reserved[i] = true
       name = GetSmallestVariantName(constraints[i].variants, fill[i])   // NOTE: uses cumulative fill, not size
       if name empty: return None
       return [ ValueDecl{ reg = arch->RegisterByName(name) (CHECK non-null), type = &type } ]
// nothing fit
if has_free_regs && config.type_splitter:
   split = type_splitter(&type); if split && split != &type: return TryRegisterAllocate(*split)
return None
```
Consequences:
- First-fit in table order. Type classes are filtered by `tc & st.tc`.
- Packing (only inside composites/vectors) stacks values in one register by bit count; the second value's ValueDecl names the *wider* variant (e.g. `{i32,i32}` → `EDI:i32`, then `RDI:i32`) and there is no notion of bit offset inside the register, so loading the 2nd member reads the *low* bits again. Params are not coalesced (only returns call `CoalescePacking`). **This is why the allocators of SysV x86-64, AArch64, AArch32 and SPARC32 no longer use AllocationState for aggregates** (§8.10): they classify aggregates themselves. AllocationState is still used for scalars and vectors on SysV, by the x86-32 return paths and by SPARC64.
- AllocationState itself has no alignment rules (no even-register pairs, no slot skipping); the per-convention code adds them where it bypasses AllocationState.
- **Rollback (fixed).** `TryRegisterAllocate` of a struct, array or vector now saves `reserved`/`fill` and restores them when the composite does not fit. Previously the registers taken by the members that did fit stayed reserved, so later arguments skipped them (a 7-`i64` struct on SysV took RDI–R9 and pushed the next `int` to the stack).

`TryVectorRegisterAllocate(vec)`: for each of the `N` elements:
- floating-point element: the whole vector is allocated as **one** value with `SizeAndType(size of the vector, kTypeFloatOrVec)` (e.g. `<4 x float>` → XMM0, `<8 x float>` → YMM0 with AVX). (**Fixed:** this was `LOG(FATAL) "Unhandled vector type"`.)
- other non-integer element: `LOG(FATAL) "Unhandled vector type"`.
- if `conv->ID() == CallingConv::X86_64_SysV`: `ProcessIntVecX86_64SysV(elem, N, bitwidth)` per element; else pack (`can_pack=true`) `TryRegisterAllocate(elem)`.
- any failure → None; returns None also if the result is empty. (**Fixed:** a failed vector allocation used to "succeed" with zero locations.)

`ProcessIntVecX86_64SysV(elem, vec_size, bw)` — per element (called vec_size times):
- bw 64: size 3 → no-pack `TryRegisterAllocate(elem)` (→ RAX, RDX, RCX); size 2,4 → hint `{AssignSizeAndType(elem).sc, kTypeFloatOrVec}` with packing → XMM regs.
- bw 32: sizes 2,3,4,8,16 → hint FloatOrVec + packing.
- bw 16: 3 → no-pack integral; 2,4,5,6,7,8,16 → FloatOrVec packing.
- bw 8: 3 → no-pack integral; 2,16,32 → FloatOrVec packing.
- other sizes → None (RVO); other bw → LOG(FATAL).
Reference table in source comment (returning int vectors): `<2 x iN>` → xmm0; `<3 x i64>` → rax,rdx,rcx; `<3 x i16>` → ax,dx,cx; `<3 x i8>` → al,dl,cl; `<4 x i64>` → xmm0,xmm1; `<16 x i32>` → xmm0-3, `<32 x i8>` → xmm0,xmm1; larger → RVO; i128 vectors always RVO.

`CoalescePacking(decls, out)` (used only for return values):
1. bucket each decl by the first RegisterConstraint index `i` whose variants contain `decl.reg->name`.
2. for each bucket in constraint order: empty → skip; 1 element → copy as is; ≥2 → `st = llvm::StructType::create(*arch->context, types)` (identified, unnamed, non-packed), `size = DataLayout.getTypeAllocSizeInBits(st)`, reg = `GetSmallestVariantName(variants, size)` (error `"Could not find register variant to fit size %u"`), emit `{reg, st}`.
Note the output order is by register table order, not by member order.

### 8.10 Per-convention rules

Every `BindReturnValues` starts with the explicit-`sret` case: if `func.hasStructRetAttr()` and the IR return type
is not void, error `"Function '%s' with sret-attributed parameter has non-void return type '%s'"`. What the
`sret` pointer becomes is per convention (below).

When a result must go through memory ("RVO", `injected_sret = true`), `BindParameters` adds a hidden first
parameter named `__struct_ret_ptr` **typed `ptr`** (never the aggregate type; **fixed** on every convention, where it
used to be typed as the returned aggregate, and on x86-32 that also shifted every later stack argument by the
aggregate's size).

Stack slots are always rounded: to 8 bytes on x86-64 SysV and AArch64, to 4 bytes on x86-32, AArch32 and SPARC32.
(**Fixed:** every convention used to advance the stack offset by the argument's exact allocation size, so two
stack `int`s on x86-64 were at `[RSP+8]` and `[RSP+12]`.)

The golden cases in §8.11 show the output of every rule below.

#### X86_64_SysV (X86_64_SysV.cpp), id 78

Implements the System V AMD64 psABI, section 3.2.3.

Scalars and vectors use AllocationState with the parameter pool `[DIL/DI/EDI/RDI]`, `[SIL/SI/ESI/RSI]`,
`[DL/DX/EDX/RDX]`, `[CL/CX/ECX/RCX]`, `[R8B/R8W/R8D/R8]`, `[R9B/R9W/R9D/R9]` (kTypeIntegral), then `XMM0..XMM7`
(kTypeFloatOrVec, kMaxBit128; with AVX/AVX512 each gains a YMM/ZMM variant through `ApplyX86Ext`, so 256-bit
vectors use `YMM<n>`). `x86_fp80` arguments are never put in registers (class X87, passed in memory); `fp128`
(`__float128`, class SSE+SSEUP) uses an XMM register like a vector. (**Fixed:** `fp128` arguments were also put
on the stack, and an `fp128` result was an error.)

**Aggregates and 65–128-bit integers** are classified eightbyte by eightbyte (`ClassifyEightbytes`):

1. If the allocation size is > 16 bytes → MEMORY.
2. Flatten to scalar leaves with their byte offsets (structs by `StructLayout`, arrays by element size). An
   `i65..i128` is two `i64` leaves. An 8-byte vector (`__m64`) is one SSE leaf; a 16-byte vector (`__m128`) is
   one leaf covering two eightbytes (SSE and SSEUP), i.e. a whole XMM register. A leaf that is `x86_fp80`,
   `fp128`, another vector, or an integer wider than 128 bits → MEMORY. (**Fixed:** every vector member forced
   the aggregate to memory, so `{ <2 x i64> }` was passed on the stack and returned through a hidden pointer
   instead of in XMM0.)
3. For each eightbyte that contains leaves: INTEGER if any leaf is an integer or pointer, else SSE. Fully padded
   eightbytes are dropped.
4. The transfer type of an INTEGER eightbyte is the pointer itself if it is a single pointer, else the smallest of
   `i8/i16/i32/i64` covering the bytes used (`{i32, i32}` → one `i64`; `{i8, i8}` → `i16`; `{i32, float}` → `i64`).
   An SSE eightbyte is `float` (one float), `<2 x float>` (two floats), the vector type (a vector member; a
   16-byte vector is a single 128-bit register transfer) or `double`.
5. `AssignEightbytes` gives each eightbyte the next free GPR (INTEGER) or XMM register (SSE), in pool order. If any
   eightbyte does not get a register, **none** do and the value goes to memory (the state is unchanged).

Parameters: MEMORY-class or unassigned values go on the stack. Stack offsets start at 8 (`[RSP+8]`; the return
address is at `[RSP]`), each argument takes a multiple of 8 bytes, and an argument whose alignment is 16
(`long double`, `__int128`, 16-byte-aligned types) starts at an offset with `offset % 16 == 8` (16-byte aligned
in the caller's frame). A parameter split over several registers is named `<name>0`, `<name>1`, …

Results:

- void → none. `iN`, N ≤ 64 → `RAX:iN`; N ≤ 128 → `RAX:i64, RDX:i64`; wider → RVO (**changed:** 129–192-bit
  integers used to be split over RAX, RDX, RCX, which is the LLVM-IR-level convention, not the C one).
- `ptr` → `RAX`; `float`/`double`/`fp128` → `XMM0`; `x86_mmx` (LLVM < 20) → `MM0`; `x86_fp80` → `ST0`.
- Aggregates: an aggregate whose only member (through single-member structs/arrays) is `x86_fp80` → `ST0`
  (class X87). Otherwise classify as above and assign INTEGER eightbytes to RAX then RDX, SSE eightbytes to XMM0
  then XMM1 (`{i64, double}` → `RAX:i64, XMM0:double`). MEMORY → RVO.
- Vectors: AllocationState on the return pool (`RAX`, `RDX`, `RCX`, `XMM0`, `XMM1`, `ST0`, `ST1`) with the integer
  vector table of §8.9, then `CoalescePacking`; failure → RVO.
- RVO: `returns = [RAX:ptr]`, hidden parameter `__struct_ret_ptr: RDI : ptr` and RDI reserved. (**Fixed:** the
  hidden parameter was put in RAX and typed as the aggregate while RDI was still reserved; aggregates up to the
  register count were returned in RAX/RDX/RCX instead of going to memory above 16 bytes; and `{i64, double}`
  went to RVO on plain AMD64 because XMM0/XMM1 in the return pool only accepted `kTypeVec`.)
- An explicit `sret` parameter: `returns = [RAX:ptr]`; the parameter itself is allocated like any pointer (RDI).

Epilogue: `return_stack_pointer = RSP + 8`; `return_address = [RSP + 0]` typed as RSP's type.

#### X86_C (cdecl, X86_C.cpp), id 0; X86_StdCall (id 64), X86_FastCall (id 65), X86_ThisCall (id 70)

Results (all four): `iN` N ≤ 32 → `EAX:iN`; ≤ 64 → `EAX:i32, EDX:i32`; ≤ 96 → `EAX, EDX, ECX` each i32; else the
return pool. `ptr` → `EAX`; `float`/`double`/`x86_fp80` → `ST0`; `x86_mmx` → `MM0`. Aggregates and vectors use
AllocationState on the return pool (`[AL/AX/EAX]`, `[DL/DX/EDX]`, `[CL/CX/ECX]`, `ST0`, `ST1`) with
`CoalescePacking`; failure → RVO with `returns = [EAX:ptr]`. (So small aggregates are returned in registers, the
MSVC convention; the i386 System V ABI returns every aggregate in memory. Not changed.)

Parameters: stack offsets start at 4 (`[ESP+4]`); each argument takes a multiple of 4 bytes. A hidden RVO pointer
is the first stack argument (`[ESP+4] : ptr`, 4 bytes).

- **fastcall**: the first two arguments that are integers of at most 32 bits or pointers, left to right, go in ECX
  then EDX (`CL`/`CX`/`ECX` by size); all others, including `i64`, go on the stack, and a later small integer
  can still take a free register. A result pointer, hidden or an explicit `sret` parameter, is passed on the
  stack (the first stack argument, `[ESP+4]`) and does not use a register. (**Fixed:** a hidden result pointer
  took ECX and pushed the first argument to EDX.)
- **thiscall**: `this`, the first argument that is not an explicit `sret` parameter, goes in ECX if it is an
  integer of at most 32 bits or a pointer. A hidden or explicit `sret` result pointer is passed on the stack
  (first stack argument). (**Fixed:** with an explicit `sret` before `this`, the result pointer took ECX and
  `this` went on the stack.)
- (**Fixed:** the fastcall and thiscall register pools existed but were never consulted, so every argument was
  taken from the stack.)

Epilogue: `return_stack_pointer = ESP + n`, `return_address = [ESP + 0]`, where n is 4 for cdecl (8 with a
hidden or explicit sret pointer: the i386 System V callee pops it with `ret 4`), and for stdcall, fastcall and
thiscall 4 plus the bytes of all stack arguments (the callee pops them).

#### AArch64_C (AArch64_C.cpp), id 0

Implements the AAPCS64 directly, without AllocationState (`AssignAAPCS64`), tracking NGRN (next X register) and
NSRN (next V register), both 0..8:

- `half`/`bfloat`/`float`/`double`/`fp128` and 64- or 128-bit vectors → the next V register, named by size: `H<n>`
  (16 bits), `S<n>` (32), `D<n>` (64), `Q<n>` (128).
- A homogeneous floating-point aggregate (1–4 leaves, all the same floating-point type) or homogeneous
  short-vector aggregate (1–4 leaves, all the same 64- or 128-bit vector type) → consecutive V registers, one per
  member, if they all fit; otherwise it goes on the stack and NSRN becomes 8. (**Fixed:** short-vector aggregates
  were not recognized, so `{ <2 x i64>, <2 x i64> }` was passed by reference and returned through X8 instead of
  in Q0, Q1.)
- Integers of at most 64 bits and pointers → the next X register: `W<n>` for integers of at most 32 bits, `X<n>`
  otherwise.
- Other aggregates (and `i65..i128`) of at most 16 bytes → one or two X registers as `i64` chunks (the last chunk
  narrowed to `i8/i16/i32` if shorter), starting at an even register when the type's alignment is 16 or it is a
  wide integer. If they do not all fit, it goes on the stack and NGRN becomes 8.
- Non-HFA aggregates larger than 16 bytes and integers wider than 128 bits are passed by reference (`ptr`).
- An explicit `sret` parameter → X8.
- Stack: offsets from `[SP]` (no return address on the stack), 8-byte slots, 16-byte aligned for 16-byte
  aligned values.

Results use the same assignment as the first argument (`i32` → `W0`, `i128` → `X0:i64, X1:i64`,
`{i64, double}` → `X0:i64, X1:i64` since it is not an HFA, HFAs → `S0..S3`/`D0..D3`). Anything else (a larger
aggregate, an integer wider than 128 bits) is returned through the buffer whose address the caller passes in
X8: hidden parameter `__struct_ret_ptr: X8 : ptr` and **no** return value (the callee need not preserve X8), so
the ABI function type returns `void`. An explicit `sret` likewise has no return value. `x86_fp80` is an error.

(**Fixed:** the old pool listed V0–V7 as *integer* registers, so a ninth integer argument went to `V0`; `i128`
went to `V0`; split integer results were typed `i32`; `sret` pointers went to X0 and X8 was declared as the return
value; HFAs were not recognized; and aggregates that did not fit were an error.)

Epilogue: `return_stack_pointer = SP + 0`; `return_address = X30`.

#### AArch32_C (AArch32_C.cpp), id 0

Implements the base (soft-float) AAPCS, as used by `arm-linux-gnueabi`, without AllocationState:

- Every argument is a sequence of 4-byte words: a value of at most 4 bytes keeps its type (`float` stays
  `float`, in a core register); each word of a larger value or of an aggregate is `i32`.
- Words go in R0–R3 (NCRN), then on the stack (NSAA, offsets from `[SP]`). Values with 8-byte alignment (`i64`,
  `double`, aggregates containing them) start at an even register and at an 8-byte aligned stack offset.
- An argument that does not fit in the remaining registers is split between the last registers and the stack,
  as long as nothing is on the stack yet; otherwise it goes entirely on the stack (kept whole, one declaration)
  and NCRN becomes 4.
- Results: aggregates of at most 4 bytes → `R0:i32`; non-aggregates of at most 8 bytes → `R0` or `R0:i32, R1:i32`
  (`double` too); 128-bit short vectors → `R0..R3` as `i32` words (**fixed:** they were returned in memory);
  everything else → memory, with the address as the first argument (`__struct_ret_ptr: R0`,
  shifting every argument by one register) and no return value. An explicit `sret` parameter is R0 and has no
  return value. `x86_fp80`/`fp128` results are an error.

(**Fixed:** `i64` arguments were not aligned to even registers; `float`/`double` arguments always went to the
stack; a `double` result was `R0:double, R1:double`; and an aggregate result declared `R0:ptr` as the return value
without a hidden parameter, so the first argument also claimed R0.)

Epilogue: `return_stack_pointer = SP + 0`; `return_address = LR`.

#### SPARC32_C (SPARC32_C.cpp), id 0

Register names follow current remill: `O0`–`O7`, `SP`, `FS<n>`, `FD<n>` (they used to be lowercase `o0`, `f0`,
`d0`, which no longer exist).

Parameters follow the SPARC V8 ABI, without AllocationState: every argument is a sequence of 4-byte words, and the
words of all arguments go in O0–O5, then on the stack at `[SP + 92]`, `[SP + 96]`, … (word k ≥ 6 is at
`SP + 92 + 4·(k − 6)`). Floating-point arguments use the integer registers, and a `double` or `long long` may be
split between O5 and the stack. Aggregates and `fp128` are passed by reference (`ptr`). A single-word value keeps
its type; each word of a multi-word value is `i32`. An argument that starts on the stack is kept whole.

Results: `iN` N ≤ 32 → `O0`; ≤ 192 → `O0..O5` as `i32` words; `ptr` → `O0`; `half`/`float` → `FS0`; `double` → `FD0`.
Aggregates and `fp128` are returned in memory: the caller stores the address at `[SP + 64]` in its frame, the
hidden parameter is `__struct_ret_ptr: [SP + 64] : ptr`, and the callee returns that address in `O0`. An explicit
`sret` parameter is also `[SP + 64]`. Vectors still use AllocationState on the return pool.

Such callees return to `O7 + 12`, skipping the `unimp <size>` word that follows the delay slot of the call. The
remill fork categorizes `jmp %o7 + 12` / `jmp %i7 + 12` as returns, and `RemoveRemillFunctionReturns` accepts a
return address displacement of 12 on SPARC (as well as 0, 4 and 8). (**Fixed:** this return was an indirect jump
to `O7 + 12`, which left the whole `State` and a `__remill_jump` in the lifted function;
`lifter/arch/sparc32_kitchen_sink` (`make_pair`), `passes/RemoveRemillFunctionReturns/sparc.ll`.)

(**Fixed:** `double` arguments went to the stack because no register accepted 64-bit floats; stack offsets used
exact sizes; aggregate results were an error; and an injected sret hit `CHECK(!injected_sret)`.)

Epilogue: `return_stack_pointer = SP + 0`; `return_address = O7`.

#### SPARC64_C (SPARC64_C.cpp), id 0

Implements the SPARC V9 (64-bit) ABI without AllocationState, with the register names of remill's Sleigh-based
SPARC64 (`O0`–`O5`, `SP`, `O7`, `FS<n>`, `FD<n>`, `FQ<n>`; Ghidra's names, upper-cased):

- Arguments occupy 8-byte slots k = 0, 1, …. Integers of at most 64 bits and pointers keep their type: slots 0–5
  are `O0`–`O5`, later slots are on the stack at `[SP + 2047 + 176 + 8·(k − 6)]` (2047 is the stack bias, 176 the
  register save area plus six reserved argument words), right-justified (big-endian), so an `int` in slot 6 is at
  `[SP + 2227]` and an `i64` in slot 7 at `[SP + 2231]`.
- `float`/`double`/`fp128` in slot k < 16 are in `FS(2k+1)`/`FD(2k)`/`FQ(2k)` and do not use the integer register
  of their slot; `fp128` starts at an even slot. Later ones are on the stack.
- `i65..i128` and aggregates of at most 16 bytes are `i64` words in consecutive slots (16-byte values start at an
  even slot); larger aggregates are passed by reference.
- Results: integers in `O0` (`i128` → `O0, O1` as `i64`), `float` → `FS0`, `double` → `FD0`, `fp128` → `FQ0`,
  integer-only aggregates of at most 32 bytes → `O0..O3` as `i64` words. Anything else is returned in memory: the
  hidden parameter `__struct_ret_ptr` is the first argument (`O0`), and the callee returns it in `O0`. An explicit
  `sret` parameter is likewise `O0`.
- Simplifications: floating-point members of small aggregates are treated as integer words (the ABI puts them in
  FP registers), and variadic floating-point arguments are not moved to integer registers.

Epilogue: `return_stack_pointer = SP + 0`; `return_address = O7` (the callee returns to `O7 + 8`).

(**Fixed:** this used AllocationState with the register names of remill's old SPARC64 architecture (`o0`, `f1`,
`d0`, …) and could not be tested, because that architecture aborted; floating-point arguments were not
slot-based; the stack offset was a fixed 2227 "found experimentally"; split integer results were typed `i32`;
and an injected sret hit `CHECK(!injected_sret)`.)

### 8.11 Worked examples (real allocator output)

`anvill-opt --passes=AllocateSignatures` runs `FunctionDecl::Create` on every function of a module and prints,
per function: the IR type and calling convention, the ABI function type (`abi type`, after §8.4's overrides), the
convention ID chosen, each parameter and return location with its type, the return address and the stack
pointer after the return. The printer writes unnamed identified structs by body, so output is deterministic.

#### x86-64 System V

`tests/golden/passes/AllocateSignatures/x86_64_sysv.ll` (`anvill-opt --passes=AllocateSignatures`):

```llvm
declare i32 @ints(i32 %a, i8 %b, i16 %c, i64 %d, ptr %e, i32 %f, i32 %g, i32 %h)
declare double @floats(float %a, double %b, i32 %c)
declare double @many_doubles(double, double, double, double, double, double, double, double, double, double)
declare { i64, double } @ret_mixed(i32 %a, float %b, ptr %c)
declare { i64, i64 } @ret_two_longs(i64 %a)
declare { i64, i64, i64 } @ret_three_longs()
declare i128 @wide(i128 %a)
declare void @struct_arg({ i32, i32 } %s)
declare x86_fp80 @long_double(x86_fp80 %a)
declare i32 @variadic(ptr %fmt, ...)
declare void @seven_longs({ i64, i64, i64, i64, i64, i64, i64 } %big, i32 %after)
declare void @sret(ptr sret({ i64, i64, i64 }) %out, i32 %x)
declare x86_64_sysvcc void @explicit_cc(i32 %x)
declare void @no_return() noreturn
declare { float, float, float } @ret_three_floats()
declare { double, double } @ret_two_doubles({ double, double } %p)
declare { i8, i8 } @ret_two_bytes({ i8, i8 } %p)
declare { i32, float } @ret_int_float({ i32, float } %p)
declare [2 x i32] @ret_array([2 x i32] %p)
declare { x86_fp80 } @ret_struct_long_double({ x86_fp80 } %p)
declare i256 @ret_i256(i256 %a)
declare void @regs_exhausted(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, { i64, i64 } %pair, i64 %f)
declare void @aligned_stack(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f, i32 %g, i128 %h, x86_fp80 %i, i8 %j)
declare <4 x float> @float_vector(<4 x float> %v, <2 x double> %w)
declare fp128 @quad(fp128 %a, i32 %b, fp128 %c)
declare { <2 x i64> } @vector_struct({ <2 x i64> } %a, { <2 x float>, double } %b)
declare x86_stdcallcc i32 @stdcall_on_amd64(i32 %a, i32 %b)
declare x86_fastcallcc i32 @fastcall_on_amd64(i32 %a, i32 %b)
```

Output (`x86_64_sysv.expected.txt`):

```
@ints i32 (i32, i8, i16, i64, ptr, i32, i32, i32) cc 0
  abi type: i32 (i32, i8, i16, i64, ptr, i32, i32, i32)
  calling convention: 78
  param a: EDI : i32
  param b: SIL : i8
  param c: DX : i16
  param d: RCX : i64
  param e: R8 : ptr
  param f: R9D : i32
  param g: [RSP + 8] : i32
  param h: [RSP + 16] : i32
  return: RAX : i32
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@floats double (float, double, i32) cc 0
  abi type: double (float, double, i32)
  calling convention: 78
  param a: XMM0 : float
  param b: XMM1 : double
  param c: EDI : i32
  return: XMM0 : double
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@many_doubles double (double, double, double, double, double, double, double, double, double, double) cc 0
  abi type: double (double, double, double, double, double, double, double, double, double, double)
  calling convention: 78
  param param0: XMM0 : double
  param param1: XMM1 : double
  param param2: XMM2 : double
  param param3: XMM3 : double
  param param4: XMM4 : double
  param param5: XMM5 : double
  param param6: XMM6 : double
  param param7: XMM7 : double
  param param8: [RSP + 8] : double
  param param9: [RSP + 16] : double
  return: XMM0 : double
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@ret_mixed { i64, double } (i32, float, ptr) cc 0
  abi type: { i64, double } (i32, float, ptr)
  calling convention: 78
  param a: EDI : i32
  param b: XMM0 : float
  param c: RSI : ptr
  return: RAX : i64
  return: XMM0 : double
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@ret_two_longs { i64, i64 } (i64) cc 0
  abi type: { i64, i64 } (i64)
  calling convention: 78
  param a: RDI : i64
  return: RAX : i64
  return: RDX : i64
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@ret_three_longs { i64, i64, i64 } () cc 0
  abi type: ptr (ptr)
  calling convention: 78
  param __struct_ret_ptr: RDI : ptr
  return: RAX : ptr
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@wide i128 (i128) cc 0
  abi type: { i64, i64 } (i64, i64)
  calling convention: 78
  param a0: RDI : i64
  param a1: RSI : i64
  return: RAX : i64
  return: RDX : i64
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@struct_arg void ({ i32, i32 }) cc 0
  abi type: void (i64)
  calling convention: 78
  param s: RDI : i64
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@long_double x86_fp80 (x86_fp80) cc 0
  abi type: x86_fp80 (x86_fp80)
  calling convention: 78
  param a: [RSP + 8] : x86_fp80
  return: ST0 : x86_fp80
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@variadic i32 (ptr, ...) cc 0
  abi type: i32 (ptr, ...)
  calling convention: 78
  param fmt: RDI : ptr
  return: RAX : i32
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@seven_longs void ({ i64, i64, i64, i64, i64, i64, i64 }, i32) cc 0
  abi type: void ({ i64, i64, i64, i64, i64, i64, i64 }, i32)
  calling convention: 78
  param big: [RSP + 8] : { i64, i64, i64, i64, i64, i64, i64 }
  param after: EDI : i32
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@sret void (ptr, i32) cc 0
  abi type: ptr (ptr, i32)
  calling convention: 78
  param out: RDI : ptr
  param x: ESI : i32
  return: RAX : ptr
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@explicit_cc void (i32) cc 78
  abi type: void (i32)
  calling convention: 78
  param x: EDI : i32
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@no_return void () cc 0
  abi type: void ()
  calling convention: 78
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@ret_three_floats { float, float, float } () cc 0
  abi type: { <2 x float>, float } ()
  calling convention: 78
  return: XMM0 : <2 x float>
  return: XMM1 : float
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@ret_two_doubles { double, double } ({ double, double }) cc 0
  abi type: { double, double } (double, double)
  calling convention: 78
  param p0: XMM0 : double
  param p1: XMM1 : double
  return: XMM0 : double
  return: XMM1 : double
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@ret_two_bytes { i8, i8 } ({ i8, i8 }) cc 0
  abi type: i16 (i16)
  calling convention: 78
  param p: DI : i16
  return: AX : i16
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@ret_int_float { i32, float } ({ i32, float }) cc 0
  abi type: i64 (i64)
  calling convention: 78
  param p: RDI : i64
  return: RAX : i64
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@ret_array [2 x i32] ([2 x i32]) cc 0
  abi type: i64 (i64)
  calling convention: 78
  param p: RDI : i64
  return: RAX : i64
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@ret_struct_long_double { x86_fp80 } ({ x86_fp80 }) cc 0
  abi type: x86_fp80 ({ x86_fp80 })
  calling convention: 78
  param p: [RSP + 8] : { x86_fp80 }
  return: ST0 : x86_fp80
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@ret_i256 i256 (i256) cc 0
  abi type: ptr (ptr, i256)
  calling convention: 78
  param __struct_ret_ptr: RDI : ptr
  param a: [RSP + 8] : i256
  return: RAX : ptr
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@regs_exhausted void (i64, i64, i64, i64, i64, { i64, i64 }, i64) cc 0
  abi type: void (i64, i64, i64, i64, i64, { i64, i64 }, i64)
  calling convention: 78
  param a: RDI : i64
  param b: RSI : i64
  param c: RDX : i64
  param d: RCX : i64
  param e: R8 : i64
  param pair: [RSP + 8] : { i64, i64 }
  param f: R9 : i64
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@aligned_stack void (i64, i64, i64, i64, i64, i64, i32, i128, x86_fp80, i8) cc 0
  abi type: void (i64, i64, i64, i64, i64, i64, i32, i128, x86_fp80, i8)
  calling convention: 78
  param a: RDI : i64
  param b: RSI : i64
  param c: RDX : i64
  param d: RCX : i64
  param e: R8 : i64
  param f: R9 : i64
  param g: [RSP + 8] : i32
  param h: [RSP + 24] : i128
  param i: [RSP + 40] : x86_fp80
  param j: [RSP + 56] : i8
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@float_vector <4 x float> (<4 x float>, <2 x double>) cc 0
  abi type: <4 x float> (<4 x float>, <2 x double>)
  calling convention: 78
  param v: XMM0 : <4 x float>
  param w: XMM1 : <2 x double>
  return: XMM0 : <4 x float>
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@quad fp128 (fp128, i32, fp128) cc 0
  abi type: fp128 (fp128, i32, fp128)
  calling convention: 78
  param a: XMM0 : fp128
  param b: EDI : i32
  param c: XMM1 : fp128
  return: XMM0 : fp128
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@vector_struct { <2 x i64> } ({ <2 x i64> }, { <2 x float>, double }) cc 0
  abi type: <2 x i64> (<2 x i64>, <2 x float>, double)
  calling convention: 78
  param a: XMM0 : <2 x i64>
  param b0: XMM1 : <2 x float>
  param b1: XMM2 : double
  return: XMM0 : <2 x i64>
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@stdcall_on_amd64 i32 (i32, i32) cc 64
  abi type: i32 (i32, i32)
  calling convention: 78
  param a: EDI : i32
  param b: ESI : i32
  return: RAX : i32
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@fastcall_on_amd64 i32 (i32, i32) cc 65
  abi type: i32 (i32, i32)
  calling convention: 78
  param a: EDI : i32
  param b: ESI : i32
  return: RAX : i32
  return address: [RSP] : i64
  stack pointer on return: RSP + 8
```

#### x86-64 System V with AVX

`tests/golden/passes/AllocateSignatures/x86_64_sysv_avx.ll` (`anvill-opt --passes=AllocateSignatures --arch=amd64_avx`):

```llvm
declare { i64, double } @ret_mixed(i32 %a, float %b, ptr %c)
declare double @floats(float %a, double %b, i32 %c)
declare <8 x float> @wide_vector(<8 x float> %v, <4 x double> %w, double %d)
```

Output (`x86_64_sysv_avx.expected.txt`):

```
@ret_mixed { i64, double } (i32, float, ptr) cc 0
  abi type: { i64, double } (i32, float, ptr)
  calling convention: 78
  param a: EDI : i32
  param b: XMM0 : float
  param c: RSI : ptr
  return: RAX : i64
  return: XMM0 : double
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@floats double (float, double, i32) cc 0
  abi type: double (float, double, i32)
  calling convention: 78
  param a: XMM0 : float
  param b: XMM1 : double
  param c: EDI : i32
  return: XMM0 : double
  return address: [RSP] : i64
  stack pointer on return: RSP + 8

@wide_vector <8 x float> (<8 x float>, <4 x double>, double) cc 0
  abi type: <8 x float> (<8 x float>, <4 x double>, double)
  calling convention: 78
  param v: YMM0 : <8 x float>
  param w: YMM1 : <4 x double>
  param d: XMM2 : double
  return: YMM0 : <8 x float>
  return address: [RSP] : i64
  stack pointer on return: RSP + 8
```

#### x86-32 cdecl, stdcall, fastcall and thiscall

`tests/golden/passes/AllocateSignatures/x86_32.ll` (`anvill-opt --passes=AllocateSignatures`):

```llvm
declare i32 @cdecl_ints(i32 %a, i8 %b, i16 %c)
declare i64 @cdecl_long_long(i64 %a)
declare double @cdecl_double(double %a)
declare { i32, double } @cdecl_ret_struct(i32 %a, float %b, ptr %c)
declare x86_stdcallcc i32 @stdcall_ints(i32 %a, i32 %b)
declare x86_fastcallcc i32 @fastcall_ints(i32 %a, i32 %b, i32 %c)
declare x86_thiscallcc i32 @thiscall_method(ptr %this, i32 %a)
declare i32 @cdecl_variadic(ptr %fmt, ...)
declare x86_fastcallcc i32 @fastcall_mixed(i64 %a, i8 %b, double %c, ptr %d, i32 %e)
declare x86_fastcallcc { i32, double } @fastcall_ret_struct(i32 %a, i32 %b)
declare x86_thiscallcc { i32, double } @thiscall_ret_struct(ptr %this, i16 %a)
declare x86_stdcallcc { i32, double } @stdcall_ret_struct(i32 %a)
declare x86_fastcallcc void @fastcall_explicit_sret(ptr sret({ i32, i32, i32 }) %out, i32 %a, i32 %b)
declare x86_thiscallcc void @thiscall_explicit_sret(ptr sret({ i32, i32, i32 }) %out, ptr %this, i32 %a)
declare i32 @cdecl_small_slots(i8 %a, i16 %b, i64 %c, x86_fp80 %d, i8 %e)
```

Output (`x86_32.expected.txt`):

```
@cdecl_ints i32 (i32, i8, i16) cc 0
  abi type: i32 (i32, i8, i16)
  calling convention: 0
  param a: [ESP + 4] : i32
  param b: [ESP + 8] : i8
  param c: [ESP + 12] : i16
  return: EAX : i32
  return address: [ESP] : i32
  stack pointer on return: ESP + 4

@cdecl_long_long i64 (i64) cc 0
  abi type: { i32, i32 } (i64)
  calling convention: 0
  param a: [ESP + 4] : i64
  return: EAX : i32
  return: EDX : i32
  return address: [ESP] : i32
  stack pointer on return: ESP + 4

@cdecl_double double (double) cc 0
  abi type: double (double)
  calling convention: 0
  param a: [ESP + 4] : double
  return: ST0 : double
  return address: [ESP] : i32
  stack pointer on return: ESP + 4

@cdecl_ret_struct { i32, double } (i32, float, ptr) cc 0
  abi type: ptr (ptr, i32, float, ptr)
  calling convention: 0
  param __struct_ret_ptr: [ESP + 4] : ptr
  param a: [ESP + 8] : i32
  param b: [ESP + 12] : float
  param c: [ESP + 16] : ptr
  return: EAX : ptr
  return address: [ESP] : i32
  stack pointer on return: ESP + 8

@stdcall_ints i32 (i32, i32) cc 64
  abi type: i32 (i32, i32)
  calling convention: 64
  param a: [ESP + 4] : i32
  param b: [ESP + 8] : i32
  return: EAX : i32
  return address: [ESP] : i32
  stack pointer on return: ESP + 12

@fastcall_ints i32 (i32, i32, i32) cc 65
  abi type: i32 (i32, i32, i32)
  calling convention: 65
  param a: ECX : i32
  param b: EDX : i32
  param c: [ESP + 4] : i32
  return: EAX : i32
  return address: [ESP] : i32
  stack pointer on return: ESP + 8

@thiscall_method i32 (ptr, i32) cc 70
  abi type: i32 (ptr, i32)
  calling convention: 70
  param this: ECX : ptr
  param a: [ESP + 4] : i32
  return: EAX : i32
  return address: [ESP] : i32
  stack pointer on return: ESP + 8

@cdecl_variadic i32 (ptr, ...) cc 0
  abi type: i32 (ptr, ...)
  calling convention: 0
  param fmt: [ESP + 4] : ptr
  return: EAX : i32
  return address: [ESP] : i32
  stack pointer on return: ESP + 4

@fastcall_mixed i32 (i64, i8, double, ptr, i32) cc 65
  abi type: i32 (i64, i8, double, ptr, i32)
  calling convention: 65
  param a: [ESP + 4] : i64
  param b: CL : i8
  param c: [ESP + 12] : double
  param d: EDX : ptr
  param e: [ESP + 20] : i32
  return: EAX : i32
  return address: [ESP] : i32
  stack pointer on return: ESP + 24

@fastcall_ret_struct { i32, double } (i32, i32) cc 65
  abi type: ptr (ptr, i32, i32)
  calling convention: 65
  param __struct_ret_ptr: [ESP + 4] : ptr
  param a: ECX : i32
  param b: EDX : i32
  return: EAX : ptr
  return address: [ESP] : i32
  stack pointer on return: ESP + 8

@thiscall_ret_struct { i32, double } (ptr, i16) cc 70
  abi type: ptr (ptr, ptr, i16)
  calling convention: 70
  param __struct_ret_ptr: [ESP + 4] : ptr
  param this: ECX : ptr
  param a: [ESP + 8] : i16
  return: EAX : ptr
  return address: [ESP] : i32
  stack pointer on return: ESP + 12

@stdcall_ret_struct { i32, double } (i32) cc 64
  abi type: ptr (ptr, i32)
  calling convention: 64
  param __struct_ret_ptr: [ESP + 4] : ptr
  param a: [ESP + 8] : i32
  return: EAX : ptr
  return address: [ESP] : i32
  stack pointer on return: ESP + 12

@fastcall_explicit_sret void (ptr, i32, i32) cc 65
  abi type: ptr (ptr, i32, i32)
  calling convention: 65
  param out: [ESP + 4] : ptr
  param a: ECX : i32
  param b: EDX : i32
  return: EAX : ptr
  return address: [ESP] : i32
  stack pointer on return: ESP + 8

@thiscall_explicit_sret void (ptr, ptr, i32) cc 70
  abi type: ptr (ptr, ptr, i32)
  calling convention: 70
  param out: [ESP + 4] : ptr
  param this: ECX : ptr
  param a: [ESP + 8] : i32
  return: EAX : ptr
  return address: [ESP] : i32
  stack pointer on return: ESP + 12

@cdecl_small_slots i32 (i8, i16, i64, x86_fp80, i8) cc 0
  abi type: i32 (i8, i16, i64, x86_fp80, i8)
  calling convention: 0
  param a: [ESP + 4] : i8
  param b: [ESP + 8] : i16
  param c: [ESP + 12] : i64
  param d: [ESP + 20] : x86_fp80
  param e: [ESP + 32] : i8
  return: EAX : i32
  return address: [ESP] : i32
  stack pointer on return: ESP + 4
```

#### AArch64

`tests/golden/passes/AllocateSignatures/aarch64.ll` (`anvill-opt --passes=AllocateSignatures`):

```llvm
declare i32 @ints(i32 %a, float %b, ptr %c)
declare i64 @nine_longs(i64, i64, i64, i64, i64, i64, i64, i64, i64)
declare { i64, double } @ret_mixed(i32 %a)
declare i128 @wide(i128 %a)
declare double @doubles(double %a, float %b, half %c)
declare void @sret(ptr sret({ i64, i64, i64 }) %out)
declare { float, float, float } @hfa({ float, float, float } %a, [4 x double] %b, double %c, { float, float } %d)
declare { i64, i64, i64 } @big_struct({ i64, i64, i64 } %a, i32 %b)
declare void @pair_alignment(i32 %a, i128 %b, { i64, i32 } %c, i64 %d, i64 %e, i64 %f, { i64, i64 } %g, i32 %h)
declare <4 x float> @vectors(<4 x float> %a, <2 x float> %b)
declare i256 @huge_int(i256 %a)
declare void @stack_hfa(double, double, double, double, double, double, double, { double, double } %h, float %f)
declare { <2 x i64>, <2 x i64> } @hva({ <2 x i64>, <2 x i64> } %a, <4 x i32> %b)
```

Output (`aarch64.expected.txt`):

```
@ints i32 (i32, float, ptr) cc 0
  abi type: i32 (i32, float, ptr)
  calling convention: 0
  param a: W0 : i32
  param b: S0 : float
  param c: X1 : ptr
  return: W0 : i32
  return address: X30 : i64
  stack pointer on return: SP + 0

@nine_longs i64 (i64, i64, i64, i64, i64, i64, i64, i64, i64) cc 0
  abi type: i64 (i64, i64, i64, i64, i64, i64, i64, i64, i64)
  calling convention: 0
  param param0: X0 : i64
  param param1: X1 : i64
  param param2: X2 : i64
  param param3: X3 : i64
  param param4: X4 : i64
  param param5: X5 : i64
  param param6: X6 : i64
  param param7: X7 : i64
  param param8: [SP] : i64
  return: X0 : i64
  return address: X30 : i64
  stack pointer on return: SP + 0

@ret_mixed { i64, double } (i32) cc 0
  abi type: { i64, i64 } (i32)
  calling convention: 0
  param a: W0 : i32
  return: X0 : i64
  return: X1 : i64
  return address: X30 : i64
  stack pointer on return: SP + 0

@wide i128 (i128) cc 0
  abi type: { i64, i64 } (i64, i64)
  calling convention: 0
  param a0: X0 : i64
  param a1: X1 : i64
  return: X0 : i64
  return: X1 : i64
  return address: X30 : i64
  stack pointer on return: SP + 0

@doubles double (double, float, half) cc 0
  abi type: double (double, float, half)
  calling convention: 0
  param a: D0 : double
  param b: S1 : float
  param c: H2 : half
  return: D0 : double
  return address: X30 : i64
  stack pointer on return: SP + 0

@sret void (ptr) cc 0
  abi type: void (ptr)
  calling convention: 0
  param out: X8 : ptr
  return address: X30 : i64
  stack pointer on return: SP + 0

@hfa { float, float, float } ({ float, float, float }, [4 x double], double, { float, float }) cc 0
  abi type: { float, float, float } (float, float, float, double, double, double, double, double, { float, float })
  calling convention: 0
  param a0: S0 : float
  param a1: S1 : float
  param a2: S2 : float
  param b0: D3 : double
  param b1: D4 : double
  param b2: D5 : double
  param b3: D6 : double
  param c: D7 : double
  param d: [SP] : { float, float }
  return: S0 : float
  return: S1 : float
  return: S2 : float
  return address: X30 : i64
  stack pointer on return: SP + 0

@big_struct { i64, i64, i64 } ({ i64, i64, i64 }, i32) cc 0
  abi type: void (ptr, ptr, i32)
  calling convention: 0
  param __struct_ret_ptr: X8 : ptr
  param a: X0 : ptr
  param b: W1 : i32
  return address: X30 : i64
  stack pointer on return: SP + 0

@pair_alignment void (i32, i128, { i64, i32 }, i64, i64, i64, { i64, i64 }, i32) cc 0
  abi type: void (i32, i64, i64, i64, i64, i64, i64, i64, { i64, i64 }, i32)
  calling convention: 0
  param a: W0 : i32
  param b0: X2 : i64
  param b1: X3 : i64
  param c0: X4 : i64
  param c1: X5 : i64
  param d: X6 : i64
  param e: X7 : i64
  param f: [SP] : i64
  param g: [SP + 8] : { i64, i64 }
  param h: [SP + 24] : i32
  return address: X30 : i64
  stack pointer on return: SP + 0

@vectors <4 x float> (<4 x float>, <2 x float>) cc 0
  abi type: <4 x float> (<4 x float>, <2 x float>)
  calling convention: 0
  param a: Q0 : <4 x float>
  param b: D1 : <2 x float>
  return: Q0 : <4 x float>
  return address: X30 : i64
  stack pointer on return: SP + 0

@huge_int i256 (i256) cc 0
  abi type: void (ptr, ptr)
  calling convention: 0
  param __struct_ret_ptr: X8 : ptr
  param a: X0 : ptr
  return address: X30 : i64
  stack pointer on return: SP + 0

@stack_hfa void (double, double, double, double, double, double, double, { double, double }, float) cc 0
  abi type: void (double, double, double, double, double, double, double, { double, double }, float)
  calling convention: 0
  param param0: D0 : double
  param param1: D1 : double
  param param2: D2 : double
  param param3: D3 : double
  param param4: D4 : double
  param param5: D5 : double
  param param6: D6 : double
  param h: [SP] : { double, double }
  param f: [SP + 16] : float
  return address: X30 : i64
  stack pointer on return: SP + 0

@hva { <2 x i64>, <2 x i64> } ({ <2 x i64>, <2 x i64> }, <4 x i32>) cc 0
  abi type: { <2 x i64>, <2 x i64> } (<2 x i64>, <2 x i64>, <4 x i32>)
  calling convention: 0
  param a0: Q0 : <2 x i64>
  param a1: Q1 : <2 x i64>
  param b: Q2 : <4 x i32>
  return: Q0 : <2 x i64>
  return: Q1 : <2 x i64>
  return address: X30 : i64
  stack pointer on return: SP + 0
```

#### AArch32 (base AAPCS)

`tests/golden/passes/AllocateSignatures/aarch32.ll` (`anvill-opt --passes=AllocateSignatures`):

```llvm
declare i32 @ints(i32 %a, i64 %b, i32 %c)
declare double @floats(float %a, double %b)
declare i64 @ret_long_long(i32 %a)
declare { i32, double } @ret_struct(i32 %a)
declare i32 @five_ints(i32, i32, i32, i32, i32)
declare void @split_struct(i32 %a, i32 %b, { i32, i32, i32 } %c, i32 %d)
declare void @no_split_after_stack(i32 %a, i32 %b, i32 %c, i64 %d, i32 %e, i64 %f)
declare { i8, i8 } @small_struct(i8 %a, i16 %b)
declare void @sret(ptr sret({ i32, i32 }) %out, i32 %x)
declare float @float_result(float %a, float %b)
declare <4 x i32> @vector128_ret(i32 %a)
```

Output (`aarch32.expected.txt`):

```
@ints i32 (i32, i64, i32) cc 0
  abi type: i32 (i32, i32, i32, i32)
  calling convention: 0
  param a: R0 : i32
  param b0: R2 : i32
  param b1: R3 : i32
  param c: [SP] : i32
  return: R0 : i32
  return address: LR : i32
  stack pointer on return: SP + 0

@floats double (float, double) cc 0
  abi type: { i32, i32 } (float, i32, i32)
  calling convention: 0
  param a: R0 : float
  param b0: R2 : i32
  param b1: R3 : i32
  return: R0 : i32
  return: R1 : i32
  return address: LR : i32
  stack pointer on return: SP + 0

@ret_long_long i64 (i32) cc 0
  abi type: { i32, i32 } (i32)
  calling convention: 0
  param a: R0 : i32
  return: R0 : i32
  return: R1 : i32
  return address: LR : i32
  stack pointer on return: SP + 0

@ret_struct { i32, double } (i32) cc 0
  abi type: void (ptr, i32)
  calling convention: 0
  param __struct_ret_ptr: R0 : ptr
  param a: R1 : i32
  return address: LR : i32
  stack pointer on return: SP + 0

@five_ints i32 (i32, i32, i32, i32, i32) cc 0
  abi type: i32 (i32, i32, i32, i32, i32)
  calling convention: 0
  param param0: R0 : i32
  param param1: R1 : i32
  param param2: R2 : i32
  param param3: R3 : i32
  param param4: [SP] : i32
  return: R0 : i32
  return address: LR : i32
  stack pointer on return: SP + 0

@split_struct void (i32, i32, { i32, i32, i32 }, i32) cc 0
  abi type: void (i32, i32, i32, i32, i32, i32)
  calling convention: 0
  param a: R0 : i32
  param b: R1 : i32
  param c0: R2 : i32
  param c1: R3 : i32
  param c2: [SP] : i32
  param d: [SP + 4] : i32
  return address: LR : i32
  stack pointer on return: SP + 0

@no_split_after_stack void (i32, i32, i32, i64, i32, i64) cc 0
  abi type: void (i32, i32, i32, i64, i32, i64)
  calling convention: 0
  param a: R0 : i32
  param b: R1 : i32
  param c: R2 : i32
  param d: [SP] : i64
  param e: [SP + 8] : i32
  param f: [SP + 16] : i64
  return address: LR : i32
  stack pointer on return: SP + 0

@small_struct { i8, i8 } (i8, i16) cc 0
  abi type: i32 (i8, i16)
  calling convention: 0
  param a: R0 : i8
  param b: R1 : i16
  return: R0 : i32
  return address: LR : i32
  stack pointer on return: SP + 0

@sret void (ptr, i32) cc 0
  abi type: void (ptr, i32)
  calling convention: 0
  param out: R0 : ptr
  param x: R1 : i32
  return address: LR : i32
  stack pointer on return: SP + 0

@float_result float (float, float) cc 0
  abi type: float (float, float)
  calling convention: 0
  param a: R0 : float
  param b: R1 : float
  return: R0 : float
  return address: LR : i32
  stack pointer on return: SP + 0

@vector128_ret <4 x i32> (i32) cc 0
  abi type: { i32, i32, i32, i32 } (i32)
  calling convention: 0
  param a: R0 : i32
  return: R0 : i32
  return: R1 : i32
  return: R2 : i32
  return: R3 : i32
  return address: LR : i32
  stack pointer on return: SP + 0
```

#### SPARC32

`tests/golden/passes/AllocateSignatures/sparc.ll` (`anvill-opt --passes=AllocateSignatures`):

```llvm
declare i32 @ints(i32 %a, float %b, ptr %c)
declare i32 @seven_ints(i32, i32, i32, i32, i32, i32, i32)
declare i64 @ret_long_long(i64 %a)
declare double @doubles(double %a)
declare void @split_double(i32, i32, i32, i32, i32, double %d, i32 %after)
declare { i32, i32 } @struct_result({ i32, i32 } %by_ref, fp128 %q)
declare void @sret(ptr sret({ i32, i32 }) %out, i32 %x)
```

Output (`sparc.expected.txt`):

```
@ints i32 (i32, float, ptr) cc 0
  abi type: i32 (i32, float, ptr)
  calling convention: 0
  param a: O0 : i32
  param b: O1 : float
  param c: O2 : ptr
  return: O0 : i32
  return address: O7 : i32
  stack pointer on return: SP + 0

@seven_ints i32 (i32, i32, i32, i32, i32, i32, i32) cc 0
  abi type: i32 (i32, i32, i32, i32, i32, i32, i32)
  calling convention: 0
  param param0: O0 : i32
  param param1: O1 : i32
  param param2: O2 : i32
  param param3: O3 : i32
  param param4: O4 : i32
  param param5: O5 : i32
  param param6: [SP + 92] : i32
  return: O0 : i32
  return address: O7 : i32
  stack pointer on return: SP + 0

@ret_long_long i64 (i64) cc 0
  abi type: { i32, i32 } (i32, i32)
  calling convention: 0
  param a0: O0 : i32
  param a1: O1 : i32
  return: O0 : i32
  return: O1 : i32
  return address: O7 : i32
  stack pointer on return: SP + 0

@doubles double (double) cc 0
  abi type: double (i32, i32)
  calling convention: 0
  param a0: O0 : i32
  param a1: O1 : i32
  return: FD0 : double
  return address: O7 : i32
  stack pointer on return: SP + 0

@split_double void (i32, i32, i32, i32, i32, double, i32) cc 0
  abi type: void (i32, i32, i32, i32, i32, i32, i32, i32)
  calling convention: 0
  param param0: O0 : i32
  param param1: O1 : i32
  param param2: O2 : i32
  param param3: O3 : i32
  param param4: O4 : i32
  param d0: O5 : i32
  param d1: [SP + 92] : i32
  param after: [SP + 96] : i32
  return address: O7 : i32
  stack pointer on return: SP + 0

@struct_result { i32, i32 } ({ i32, i32 }, fp128) cc 0
  abi type: ptr (ptr, ptr, ptr)
  calling convention: 0
  param __struct_ret_ptr: [SP + 64] : ptr
  param by_ref: O0 : ptr
  param q: O1 : ptr
  return: O0 : ptr
  return address: O7 : i32
  stack pointer on return: SP + 0

@sret void (ptr, i32) cc 0
  abi type: ptr (ptr, i32)
  calling convention: 0
  param out: [SP + 64] : ptr
  param x: O0 : i32
  return: O0 : ptr
  return address: O7 : i32
  stack pointer on return: SP + 0
```


#### SPARC64

`tests/golden/passes/AllocateSignatures/sparc64.ll` (`anvill-opt --passes=AllocateSignatures`):

```llvm
declare i32 @ints(i32 %a, i64 %b, ptr %c)
declare i64 @seven_ints(i32, i32, i32, i32, i32, i32, i32 %g, i64 %h)
declare double @floats(float %a, double %b, i32 %c, fp128 %q)
declare i128 @wide(i32 %a, i128 %b)
declare { i64, i32 } @small_struct({ i64, i32 } %s, i8 %c)
declare { i64, i64, i64, i64, i64 } @big_struct({ i64, i64, i64 } %by_ref, i32 %x)
declare double @late_double(double, double, double, double, double, double, double, double, double, double, double, double, double, double, double, double, double %on_stack)
declare void @sret(ptr sret({ i64, i64, i64, i64, i64 }) %out, i32 %x)
```

Output (`sparc64.expected.txt`):

```
@ints i32 (i32, i64, ptr) cc 0
  abi type: i32 (i32, i64, ptr)
  calling convention: 0
  param a: O0 : i32
  param b: O1 : i64
  param c: O2 : ptr
  return: O0 : i32
  return address: O7 : i64
  stack pointer on return: SP + 0

@seven_ints i64 (i32, i32, i32, i32, i32, i32, i32, i64) cc 0
  abi type: i64 (i32, i32, i32, i32, i32, i32, i32, i64)
  calling convention: 0
  param param0: O0 : i32
  param param1: O1 : i32
  param param2: O2 : i32
  param param3: O3 : i32
  param param4: O4 : i32
  param param5: O5 : i32
  param g: [SP + 2227] : i32
  param h: [SP + 2231] : i64
  return: O0 : i64
  return address: O7 : i64
  stack pointer on return: SP + 0

@floats double (float, double, i32, fp128) cc 0
  abi type: double (float, double, i32, fp128)
  calling convention: 0
  param a: FS1 : float
  param b: FD2 : double
  param c: O2 : i32
  param q: FQ8 : fp128
  return: FD0 : double
  return address: O7 : i64
  stack pointer on return: SP + 0

@wide i128 (i32, i128) cc 0
  abi type: { i64, i64 } (i32, i64, i64)
  calling convention: 0
  param a: O0 : i32
  param b0: O2 : i64
  param b1: O3 : i64
  return: O0 : i64
  return: O1 : i64
  return address: O7 : i64
  stack pointer on return: SP + 0

@small_struct { i64, i32 } ({ i64, i32 }, i8) cc 0
  abi type: { i64, i64 } (i64, i64, i8)
  calling convention: 0
  param s0: O0 : i64
  param s1: O1 : i64
  param c: O2 : i8
  return: O0 : i64
  return: O1 : i64
  return address: O7 : i64
  stack pointer on return: SP + 0

@big_struct { i64, i64, i64, i64, i64 } ({ i64, i64, i64 }, i32) cc 0
  abi type: ptr (ptr, ptr, i32)
  calling convention: 0
  param __struct_ret_ptr: O0 : ptr
  param by_ref: O1 : ptr
  param x: O2 : i32
  return: O0 : ptr
  return address: O7 : i64
  stack pointer on return: SP + 0

@late_double double (double, double, double, double, double, double, double, double, double, double, double, double, double, double, double, double, double) cc 0
  abi type: double (double, double, double, double, double, double, double, double, double, double, double, double, double, double, double, double, double)
  calling convention: 0
  param param0: FD0 : double
  param param1: FD2 : double
  param param2: FD4 : double
  param param3: FD6 : double
  param param4: FD8 : double
  param param5: FD10 : double
  param param6: FD12 : double
  param param7: FD14 : double
  param param8: FD16 : double
  param param9: FD18 : double
  param param10: FD20 : double
  param param11: FD22 : double
  param param12: FD24 : double
  param param13: FD26 : double
  param param14: FD28 : double
  param param15: FD30 : double
  param on_stack: [SP + 2303] : double
  return: FD0 : double
  return address: O7 : i64
  stack pointer on return: SP + 0

@sret void (ptr, i32) cc 0
  abi type: ptr (ptr, i32)
  calling convention: 0
  param out: O0 : ptr
  param x: O1 : i32
  return: O0 : ptr
  return address: O7 : i64
  stack pointer on return: SP + 0
```

---

## 9. Providers

Sources: `include/anvill/Providers.h`, `lib/Providers/*`. The lifter never reads the specification directly. It asks three provider interfaces, so other front-ends (e.g. an interactive decompiler) can supply data lazily.


### 9.1 TypeProvider
```cpp
class TypeProvider {
 public:
  virtual std::optional<FunctionDecl> GetDefaultFunctionType(uint64_t) const;   // base: nullopt
  virtual std::optional<VariableDecl> GetDefaultVariableDecl(uint64_t) const;   // base: nullopt
  std::optional<FunctionDecl> TryGetFunctionTypeOrDefault(uint64_t a) const;    // TryGetFunctionType(a) ?: GetDefaultFunctionType(a)
  std::optional<CallableDecl> TryGetCalledFunctionTypeOrDefault(uint64_t fn, const remill::Instruction&, uint64_t to) const;
                                    // TryGetCalledFunctionType(fn, inst, to) ?: GetDefaultFunctionType(to)
  std::optional<VariableDecl> TryGetVariableTypeOrDefault(uint64_t a, llvm::Type *hint=nullptr) const;
  virtual std::optional<FunctionDecl> TryGetFunctionType(uint64_t address) const = 0;
  virtual std::optional<CallableDecl> TryGetCalledFunctionType(uint64_t function_address, const remill::Instruction &from_inst) const; // base: nullopt
  virtual std::optional<CallableDecl> TryGetCalledFunctionType(uint64_t function_address, const remill::Instruction &from_inst, uint64_t to_address) const;
        // base: 2-arg version ?: (CallableDecl&)TryGetFunctionType(to_address) (sliced)
  virtual std::optional<VariableDecl> TryGetVariableType(uint64_t, llvm::Type *hint=nullptr) const = 0;
  virtual void QueryRegisterStateAtInstruction(uint64_t func_addr, uint64_t inst_addr,
      std::function<void(const std::string &reg, llvm::Type*, std::optional<uint64_t> value)>) const = 0;
  virtual const TypeDictionary &Dictionary() const = 0;
};
```
Implementations:
- `BaseTypeProvider(const TypeDictionary&)` / `(const TypeTranslator&)`: holds `context` (from `dict.bool_`) and a copy of the dictionary. `Dictionary()` returns it, and `QueryRegisterStateAtInstruction` is a no-op.
- `NullTypeProvider : BaseTypeProvider`: both Try* methods return nullopt.
- `ProxyTypeProvider(const TypeProvider &deleg)`: forwards every pure/virtual method, including `Dictionary()`. Use it as a base for stacking providers.
- `DefaultCallableTypeProvider(remill::ArchName default_arch, const TypeProvider &deleg) : ProxyTypeProvider`. Its impl is a `SmallDenseMap<ArchName underlying, CallableDecl, 16>`.
  - `SetDefault(arch, CallableDecl)`.
  - `TryGetCalledFunctionType(fn_addr, inst)`: (1) the delegate's call-site decl; (step removed: it used to return the delegate's `TryGetFunctionType(fn_addr)`, i.e. the *containing* function's type, not the callee's; **fixed**. The callee's own declaration is looked up by the lifter itself, §10); (3) the default for `inst.arch_name`; (4) if `inst.arch_name != inst.sub_arch_name`, the default for `sub_arch_name`; else nullopt.
  - `TryGetFunctionType(addr)`: the delegate's, else a FunctionDecl built from the default for `default_arch` with `address = addr`. That makes *every* address look like a function.
- `SpecificationTypeProvider(const Specification&) : BaseTypeProvider(spec.impl->type_translator)`, sharing `spec.impl`.
  - `TryGetCalledFunctionType(fn, inst)` → `impl->loc_to_call_site[{fn, inst.pc}]` (a CallSiteDecl sliced to CallableDecl).
  - `TryGetFunctionType(a)` → `*impl->address_to_function[a]` (exact start address).
  - `TryGetVariableType(a, hint)` → `impl->VariableContaining(a)`: the variable whose `[address, address + size)` contains `a`, so pointers into the middle of a variable are lifted as GEPs into it (§11, `lifter/data/pointers`). The hint is ignored. (**Fixed:** it was an exact start-address lookup.)

### 9.2 MemoryProvider
```cpp
enum class BytePermission : uint8_t { kUnknown, kReadable, kReadableWritable, kReadableWritableExecutable, kReadableExecutable };
enum class ByteAvailability : uint8_t { kUnknown /*valid addr, value unknown*/, kUnavailable /*unmapped*/, kAvailable };
class MemoryProvider {   // non-copyable, protected default ctor
  static bool HasByte(ByteAvailability a)        { return a == kAvailable; }
  static bool IsValidAddress(ByteAvailability a) { return a == kUnknown || a == kAvailable; }
  static bool IsExecutable(BytePermission p)     { return p ∈ {kUnknown, kReadableWritableExecutable, kReadableExecutable}; }
  virtual std::tuple<uint8_t, ByteAvailability, BytePermission> Query(uint64_t address) const = 0;
};
```
- `NullMemoryProvider::Query` → `{0, kUnknown, kUnknown}`.
- `SpecificationMemoryProvider(spec)`: looks the address up in `impl->memory` (`std::map<uint64_t, pair<uint8_t, BytePermission>>`). Found → `{byte, kAvailable, perm}`; else `{0, kUnknown, kUnknown}`. Unmapped addresses are never reported as kUnavailable.

### 9.3 ControlFlowProvider
```cpp
// include/anvill/Specification.h
struct ControlFlowOverrideSpec { uint64_t address; bool stop; };
struct JumpTarget { uint64_t address; std::unordered_map<std::string, uint64_t> context_assignments; };
struct Jump : ControlFlowOverrideSpec { std::vector<JumpTarget> targets; };
struct Call : ControlFlowOverrideSpec { std::optional<uint64_t> return_address; bool is_tailcall; std::optional<uint64_t> target_address; };
struct Return : ControlFlowOverrideSpec {};
struct Misc : ControlFlowOverrideSpec {};
using ControlFlowOverride = std::variant<std::monostate, Jump, Call, Return, Misc>;

class ControlFlowProvider { virtual ControlFlowOverride GetControlFlowOverride(uint64_t addr) const = 0; };  // non-copyable
```
- `NullControlFlowProvider` → `{}` (monostate).
- `SpecificationControlFlowProvider(spec)` → `impl->control_flow_overrides.find(addr)`, monostate on a miss. (**Fixed:** it used `operator[]` through the shared impl, so a lookup miss inserted a monostate entry, mutating shared state through a const method.)


---

## 10. The function lifter

Source: `lib/Lifters/FunctionLifter.{h,cpp}` (≈2.4k lines). This is the heart of Anvill.

### 10.1 The two-function model

For each `FunctionDecl` Anvill builds **two** LLVM functions, both inside the Remill *semantics module*:

1. **The native function** `sub_<hex addr>_<alnum-encoded function type>_<cc number>`, for example `sub_401130__AII_B_0` for `i32 (i32)` with cc 0.
   - Its type is `decl.type`, the ABI-level C-like prototype.
   - Its calling convention is `decl.calling_convention`. It has `noinline`, plus `noreturn` if `decl.is_noreturn`.
   - It is created by `GetOrDeclareFunction`, which caches in `addr_to_func[decl.address]` and in the semantics module by name, and records `func_name_to_address[name] = address`.
2. **The lifted function** `<native name>.lifted`.
   - A clone of `__remill_basic_block` (`arch->DefineLiftedFunction`) with Remill's three-argument signature `ptr (ptr state, i64 pc, ptr mem)`.
   - `InternalLinkage` and `alwaysinline`.
   - Instruction semantics are lifted into it.

The native function body allocates a `State` on its own stack and marshals its arguments *into* `State` and memory according to the declared parameter locations. It then calls the lifted function and marshals the return values back *out*. Everything is then recursively inlined into the native function, so the lifted function disappears.

The name encoding uses `TypeTranslator::EncodeToString(type, kValidSymbolCharsOnly)` (§7.5). For example `i32 (i32)` → `_AII_B`, `i64 (i64, i64, ptr)` → `_ALLL_S_B`… The test data shows older names with signed letters, such as `sub_4003b4__All_Svl_B_0`. The current encoder emits unsigned letters only.

### 10.2 `LiftFunction(const FunctionDecl &decl)`, step by step

```
reset per-function state: addr_to_func, edge_work_list, edge_to_dest_block, addr_to_block, op_lifter->ClearCache()
func_address = decl.address
native_func  = DeclareFunction(decl)                       // sub_...
pc_annotation = !{i64 decl.address}                        // if pc_metadata_name set

(byte0, avail, perm) = memory_provider.Query(func_address)
if !IsValidAddress(avail) || !IsExecutable(perm): LOG(ERROR); return nullptr
if native_func already has a body: return it              // already lifted
if decl.lift_as_decl: return native_func (declaration)    // DECL / EXTERNAL linkage
if !HasByte(avail): return native_func (declaration)      // address valid but bytes unknown

lifted_func = arch->DefineLiftedFunction(name + ".lifted", semantics_module)
   → remove noinline; add inlinehint + alwaysinline; internal linkage
state_ptr    = arg 0
pc_reg_ref   = address of PC register var  (op_lifter->LoadRegAddress(entry, state, pc_reg->name))
next_pc_reg_ref = address of "NEXT_PC"
sp_reg_ref   = address of SP register
mem_ptr_ref  = address of "MEMORY"
entry: store %pc → NEXT_PC ; store %pc → PC
ctx = arch->CreateInitialContext(); for (k,v) in decl.context_assignments: ctx.UpdateContextReg(k,v)
entry: br GetOrCreateBlock(from=0, to=func_address, ctx)   // seeds the work list
annotate entry block with !pc func_address

VisitInstructions()                         // §10.3
CallLiftedFunctionFromNativeFunction(decl)  // §10.6
RecursivelyInlineLiftedFunctionIntoNativeFunction()  // §10.7
return native_func
```

### 10.3 The work list (`GetOrCreateBlock` / `VisitInstructions`)

The lifter works on **edges**, not addresses:

- `edge_work_list : std::set<tuple<to_addr, from_addr>>`. This is ordered by destination, so instructions are lifted in roughly address order.
- `edge_to_dest_block : map<pair<from,to>, BasicBlock*>`. Each edge gets its own block, named `inst_<hex to>`.
- `decoding_contexts : map<pair<to,from>, DecodingContext>`. This records the context *along that edge*. The assumption is that the context is constant per edge.
- `addr_to_block : unordered_map<addr, BasicBlock*>`. This is the block that holds the *actual* lifted code for an address.

`GetOrCreateBlock(from, to, ctx)` returns the edge block if it exists. Otherwise it creates it, pushes `(to, from)` onto the work list, and records `ctx`. Every edge is pushed without consulting `addr_to_block`. The source comment says this is so that self-tail-calls remain observable.

`VisitInstructions` loop:

```
while work list not empty:
   (addr, from) = pop smallest
   ctx   = decoding_contexts[(addr, from)]
   block = edge_to_dest_block[(from, addr)];  if !block->empty(): continue
   if addr_to_block[addr] exists: block: br addr_to_block[addr]; continue     // edge to already-lifted inst
   addr_to_block[addr] = block
   ok = DecodeInstructionInto(addr, /*delayed*/false, &inst, ctx)
   if !ok:        LOG(ERROR "Could not decode instruction at ..."); block: tail-call __remill_error (state muted); continue
   if !inst.IsValid() || inst.IsError(): tail-call __remill_error (state muted); continue
   VisitInstruction(inst, block, ctx)
```

There is dead code: an `if (inst_addr == func_address) { … if (inst_addr != func_address) … }` block for redirection recovery.

`DecodeInstructionInto(addr, is_delayed, inst*, ctx)`:

- Read up to `arch->MaxInstructionSize(ctx)` bytes, which is 15 on x86 and 4 on the fixed-width architectures. The size is computed for the current context. (**Fixed:** it was a function-local `static`, computed once for the first context.)
- Stop at the first byte that is unknown or unavailable, or whose permission is `kReadable` or `kReadableWritable`. A byte with `kUnknown` permission is accepted.
- Then call `arch->DecodeInstruction` or `DecodeDelayedInstruction`.

### 10.4 `VisitInstruction` and the flow visitor

```
curr_inst = &inst
if options.track_provenance: InstrumentDataflowProvenance(block)
       // mem = __anvill_data_provenance(mem, pc, <every top-level reg except PC,SP>...)   (variadic, ptr(ptr,i64,...))
if options.add_breakpoints: InstrumentCallBreakpointFunction(block)
       // call ptr @breakpoint_<hex pc>(mem, PC, NEXT_PC); the function is defined as `ret arg0`,
       //   optnone + noinline + readnone, so it survives optimization
inst.GetLifter()->LiftIntoBlock(inst, block, state_ptr, /*is_delayed=*/false)   // remill semantics call(s)
if arch->MayHaveDelaySlot(inst): decode inst.delayed_pc as a delayed instruction into `delayed_inst`
annotate every instruction in block (not yet annotated) with !pc = inst.pc
std::visit(FlowVisitor{...}, inst.flows)        // control-flow orchestration, table below
annotate again (catches the branch instructions just added)
```

Control-flow orchestration per Remill flow kind. "Override" means `control_flow_provider.GetControlFlowOverride(inst.pc)`.

| Flow | Behaviour |
|---|---|
| `NormalInsn` / `NoOp` | If the override is `Misc` with `stop` → `InsertError` (tail-call `__remill_error`). Otherwise `br` to `GetOrCreateBlock(pc, next_pc, fallthrough_context)`. Any other override kind → LOG(ERROR), then fallthrough. |
| `InvalidInsn` | tail-call `__remill_error`, with the state argument replaced by `undef` (`MuteStateEscape`) |
| `ErrorInsn` | lift the delayed instruction (taken path), then the same as Invalid |
| `DirectJump` | Override `Jump`: CHECK exactly 1 target, CHECK it equals the Remill-decoded target, lift the delay slot, `br` to the target block (static context). Override `Call` (tail call): delay slot, `CallFunction(inst, block, branch_taken_pc)`, then `InsertError`. Else (no override; another kind is logged and ignored): delay slot, `br` to the decoded target. (**Fixed:** was FATAL.) |
| `IndirectJump` | Override `Jump`: delay slot; then (a) if `type_provider.TryGetCalledFunctionType(func_address, inst)` gives a call-site prototype, treat it as a typed tail call: `CallCallableDecl(block, load PC, decl)` + `ret mem`; (b) else if there are targets → `DoSwitchBasedIndirectJump`; (c) else tail-call `__remill_jump`. Override `Call`: delay slot, `CallFunction(..., nullopt)`, `InsertError`. Override `Return`: `VisitFunctionReturn`. Else: delay slot, terminating tail call to `__remill_jump`. (**Fixed:** was FATAL.) |
| `DirectFunctionCall` | delay slot; `can_return = CallFunction(inst, block, branch_taken_pc)`; `VisitAfterFunctionCall` |
| `IndirectFunctionCall` | delay slot; `CallFunction(inst, block, nullopt)`; `VisitAfterFunctionCall` |
| `FunctionReturn` | delay slot; tail-call `__remill_function_return` with the state muted (so the PC operand stays observable for later passes) |
| `AsyncHyperCall` | delay slot; tail-call `__remill_async_hyper_call` |
| `ConditionalInstruction` | `cond = load BRANCH_TAKEN`; `br cond, taken, not_taken`. The taken block runs the visitor on `taken_branch` recursively. The not-taken block lifts the delay slot (not-taken path) and branches to `next_pc` with the fallthrough context. |

`VisitDelayedInstruction(inst, delayed, block, on_taken_path)`: if `delayed && arch->NextInstructionIsDelayed(inst, *delayed, on_taken_path)`, call `LiftIntoBlock(*delayed, block, state, /*is_delayed=*/true)` and annotate with the delayed instruction's PC. This applies to SPARC and MIPS-style delay slots.

### 10.5 Calls

`CallFunction(inst, block, optional target_pc) → bool can_return`:

1. The override **must** be a `Call` (otherwise FATAL).
2. Pick the prototype:
   - If `call.target_address` is set (a redirection, e.g. a PLT thunk): `TryGetCalledFunctionTypeOrDefault(func_address, inst, redirected)`, and `target_pc = redirected`.
   - Else if `target_pc` is set: `TryGetCalledFunctionType(func_address, inst, target_pc)`. This first tries the call-site decl, then the callee's FunctionDecl.
   - Else: `TryGetCalledFunctionType(func_address, inst)`, which tries the call-site decl only.
3. If there is no prototype: LOG(ERROR) "Missing type information…". Emit a non-terminating `__remill_function_call(state, pc, mem)` and return `true`.
4. Otherwise `dest = target_pc ? program_counter_init_procedure(ir, pc_reg, target)` (i.e. `add(ptrtoint @__anvill_pc, target)`) `: load PC`. Then `CallCallableDecl(block, dest, decl)` and return `!decl.is_noreturn`.

`CallCallableDecl(block, pc, decl)`:

- `dest_func = bitorpointercast pc to ptr`
- `mem = load MEMORY`
- `new_mem = decl.CallFromLiftedBlock(dest_func, dict, intrinsics, block, state, mem)`
- `store new_mem → MEMORY`

`CallFromLiftedBlock` (§8.5) loads each parameter from its declared location in `State`/memory and calls `dest_func` *indirectly* through the symbolic PC value. It then writes the return values back to their declared locations, writes the return address into `NEXT_PC`, and sets SP to `return_stack_pointer + offset`. Later, `ConvertAddressesToEntityUses` (§13) turns `inttoptr(add(ptrtoint @__anvill_pc, 0x401000))` into a direct reference to `@sub_401000…`.

`VisitAfterFunctionCall`:

- `(ret_pc, ret_pc_val) = LoadFunctionReturnAddress(inst, block)`. Normally this is `(branch_not_taken_pc, load RETURN_PC)`.
  - **SPARC special case**: read the 4 bytes at the return address. If they decode as format-0 `unimp imm22` (op=0, op2=0), the call returns a struct of size `imm22`, and execution resumes 4 bytes later: `ret_pc+4`, `RETURN_PC+4`.
- If `can_return`: `store ret_pc_val → PC`, `store ret_pc_val → NEXT_PC`, `br GetOrCreateBlock(inst.pc, ret_pc, prev_context)`.
- Else: tail-call `__remill_error`.

### 10.6 Jump tables / multi-target indirect jumps (`DoSwitchBasedIndirectJump`)

Cases (from the source comment):

1. No target → `__remill_jump` (handled by the caller).
2. One target → plain `br`, with the target's `context_assignments` applied to the context.
3. Several targets → an *index* switch through an opaque intrinsic:

Real IR, from `tests/golden/lifter/flow/jump_table.textproto` (`switch (x)` over 4 cases compiled to a
`movslq`-relative jump table; the `Jump` override lists the 4 targets). `%28` is the computed jump target:

```llvm
  %42 = call i64 (i64, ...) @__anvill_complete_switch(i64 %28, i64 4198423, i64 4198429, i64 4198435, i64 4198441) #6, !pc !6
  switch i64 %42, label %43 [
    i64 0, label %inst_401017.i
    i64 1, label %inst_40101d.i
    i64 2, label %inst_401023.i
    i64 3, label %inst_401029.i
  ], !pc !6

43:                                               ; preds = %22
  unreachable, !pc !0
```

`__anvill_complete_switch` is declared `iADDR (iADDR, ...)` with `readnone`. Each target block gets the context `ApplyTargetList(target.context_assignments, prev_context)`.

Later, `JumpTableAnalysis` and `LowerSwitchIntrinsics` (§13) slice the target back to the jump-table index
computation, bound it with Z3, read the table through the `MemoryProvider`, and replace the whole construct with a
native `switch` on the *original index variable*. That is what makes decompiled `switch` statements look natural.
The optimized result (`jump_table.optimized.ll`):

```llvm
define i32 @table_switch(i32 %0) local_unnamed_addr #0 !pc !0 {
  %2 = icmp ugt i32 %0, 3, !pc !1
  br i1 %2, label %3, label %4, !pc !1

3:                                                ; preds = %4, %1
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

4:                                                ; preds = %1
  switch i32 %0, label %3 [
    i32 0, label %inst_401017.i
    i32 1, label %inst_40101d.i
    i32 2, label %inst_401023.i
    i32 3, label %inst_401029.i
  ], !pc !2

inst_401017.i:                                    ; preds = %4
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

inst_40101d.i:                                    ; preds = %4
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

inst_401023.i:                                    ; preds = %4
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

inst_401029.i:                                    ; preds = %4
  br label %sub_401000__AII_B_0.lifted.exit, !pc !0

sub_401000__AII_B_0.lifted.exit:                  ; preds = %inst_401029.i, %inst_401023.i, %inst_40101d.i, %inst_401017.i, %3
  %5 = phi i32 [ -1, %3 ], [ 400, %inst_401029.i ], [ 300, %inst_401023.i ], [ 200, %inst_40101d.i ], [ 100, %inst_401017.i ]
  ret i32 %5
}
```

(**Fixed:** this never happened before: the slice contained `ptrtoint @__anvill_pc`, which the interpreter could
not evaluate, and the old RAUW-based workaround mutated the module; see §13.3.2.)

The `default` case is always `unreachable`. The proto's `Jump.stop` flag is not used here, and there is no "incomplete" form any more, although `__anvill_incomplete_switch` is still named in ABI.h.

### 10.7 Building the native wrapper (`CallLiftedFunctionFromNativeFunction`)

This runs only if `native_func` is still a declaration.

```
block = new entry block in native_func
mem   = null (Memory*)
AllocateAndInitializeStateStructure(block):
     state = alloca %struct.State
     per options.state_struct_init_procedure (default kGlobalRegisterVariablesAndZeroes):
        kNone | kZeroes (store zeroinitializer) | kUndef (store undef)
        | kGlobalRegisterVariables*: for every top-level register except PC and SP:
              store (load @__anvill_reg_<NAME>) → &state->NAME      (global: external, no initializer)
     x86/amd64 only: GSBASE = ptrtoint(addrspacecast (ptr addrspace(256) null) to ptr)
                     FSBASE = same with addrspace(257);  SSBASE/DSBASE/ESBASE/CSBASE = 0
store program_counter_init_procedure(func_address) → &state->PC      ; add(ptrtoint @__anvill_pc, addr)
store stack_pointer_init_procedure()               → &state->SP      ; ptrtoint @__anvill_sp
if return_address.type is not void:
     mem = StoreNativeValue(return_address_init_procedure() /*ptrtoint @__anvill_ra*/, decl.return_address, ...)
for each native arg i:  mem = StoreNativeValue(arg_i, decl.params[i], ...)
mem = call lifted_func(state, pc, mem)            ; setDoesNotReturn if noreturn
annotate everything so far with !pc func_address
ret_val = (1 return) LoadLiftedValue(returns[0]) | (N returns) insertvalue chain into undef | none
call void @__anvill_memory_escape(ptr mem)         ; keeps memory writes alive until Optimize removes it
ret ret_val / ret void
```

"PC" is the enclosing register of `ProgramCounterRegisterName()`. "SP" is the enclosing register of
`StackPointerRegisterName()` when that is the same register under another name (e.g. `R13` for AArch32 `SP`),
otherwise the named register itself. On SPARC32, `SP` is the high half of the
64-bit `SP_7` pair (the other half is `O7`), so `SP_7` is initialized from `@__anvill_reg_SP_7` like any other
register, and `SP` is then overwritten with `__anvill_sp`. (**Fixed:** anvill always used the enclosing register,
so it stored a zero-extended 64-bit `__anvill_sp` into `SP_7`: `SP` became 0 and `O7` the stack address.)

`StoreNativeValue` and `LoadLiftedValue` (Appendix B) implement "value ↔ register or `[base+off]`". Register stores first zero the full register when the types differ, then store the zero-extended value. Memory stores go through `__remill_write_memory_N`.

### 10.8 Inlining and cleanup (`RecursivelyInlineLiftedFunctionIntoNativeFunction`)

1. `CHECK(!verifyModule(semantics module))`.
2. If PC metadata is on, record the set of instructions that had **no** `!pc` before inlining.
3. Repeat until nothing changes: collect every `CallInst` whose callee is defined and not `noinline`. Inline each one with `llvm::InlineFunction` (CHECK success). After each inline, propagate the call site's `!pc` to every newly inlined, unannotated instruction. If the call site had no `!pc`, the new instructions are added to the "no provenance" set so they never pick up a wrong PC later.
   - This emulates `__attribute__((flatten))`. The lifted function and all Remill semantics functions disappear. What remains is calls to the Remill *intrinsics* (declarations), to `noinline` native functions, and to the escape function.
4. `verifyFunction` (FATAL on failure).
5. Run a legacy FunctionPassManager: CFGSimplification, PromoteMemoryToRegister, Reassociate, DeadStoreElimination, DCE, SROA, DCE, InstructionCombining.
6. `ClearVariableNames` drops the names of all instructions.

### 10.9 Moving the result into the user's module (`AddFunctionToContext`)

The lifting happens in the semantics module. `EntityLifter::LiftEntity(FunctionDecl)` then:

- looks for an existing function at the same address with the same type (`found_by_type`) or another type (LOG(ERROR) "Ignoring existing version…");
- lifts;
- calls `AddFunctionToContext`:
  - Find or create a function of the same name and type in `options.module`. If it already has a body, erase it (keeping referential identity). If no function has that name, look for an entity at the address with the same type, to handle a user rename.
  - `remill::CloneFunctionInto(func, new_version)`, then `EraseFunctionBody(func)` in the semantics module. The declaration stays for future lifts.
  - Set `!pc` metadata on the function itself.
  - `lifter_context.AddEntity(new_version, address)`. This appends it to `@llvm.compiler.used` and records it in the address↔entity maps.
  - For every direct call in the new body whose callee name maps back to an address via `func_name_to_address`, `AddEntity(callee, addr)`.
- If the name changed, restore the user's old name.

`DeclareEntity(FunctionDecl)` does the same without lifting, giving a declaration only. The driver uses it for functions not in `--lift_list`.

### 10.10 End-to-end example

Input: amd64 Linux, function at `0x401130`, bytes `8d 47 01 c3` (`lea eax,[rdi+1]; ret`), with a prototype `i32 (i32)` where the parameter is in `EDI`, the return is in `EAX`, RA = `[RSP]`, return SP = `RSP+8`, and a `Return` override at `0x401133`.

The input is `tests/golden/lifter/basic/increment.textproto`. After §10.2–10.7, before inlining, the IR has this
shape (schematic; the golden files capture the IR after the lifter's local cleanup and after `OptimizeModule`):

```llvm
define internal ptr @sub_401130__AII_B_0.lifted(ptr %state, i64 %pc, ptr %memory) alwaysinline {
entry:                                   ; cloned __remill_basic_block locals: BRANCH_TAKEN, RETURN_PC, MEMORY, NEXT_PC, ...
  store i64 %pc, ptr %NEXT_PC, !pc !0
  store i64 %pc, ptr %RIP, !pc !0
  br label %inst_401130, !pc !0
inst_401130:                              ; lea eax, [rdi+1]
  ; ... remill operand lifting + call to the LEA semantic function ...      !pc !0
  br label %inst_401133, !pc !0
inst_401133:                              ; ret
  ; ... RET semantic: pops [RSP] into PC/NEXT_PC, RSP += 8 ...             !pc !1
  %npc = load i64, ptr %NEXT_PC
  %m = call ptr @__remill_function_return(ptr undef, i64 %npc, ptr %mem), !pc !1   ; state muted
  ret ptr %m
}

define i32 @sub_401130__AII_B_0(i32 %0) noinline {
  %state = alloca %struct.State
  store %struct.State zeroinitializer, ptr %state
  store i64 (load @__anvill_reg_RAX), ...  ; one per top-level register except RIP/RSP
  store i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198704), ptr %RIP
  store i64 ptrtoint (ptr @__anvill_sp to i64), ptr %RSP
  %m0 = call ptr @__remill_write_memory_64(ptr null, i64 <RSP>, i64 ptrtoint (ptr @__anvill_ra to i64))
  store i64 0, ptr %RDI                    ; StoreNativeValue: clear, then zext
  store i64 (zext i32 %0 to i64), ptr %RDI
  %m1 = call ptr @sub_401130__AII_B_0.lifted(ptr %state, i64 <pc>, ptr %m0)
  %rax = load i64, ptr %RAX
  %r = trunc i64 %rax to i32
  call void @__anvill_memory_escape(ptr %m1)
  ret i32 %r
}
!0 = !{i64 4198704}   !1 = !{i64 4198707}
```

After inlining and the local cleanup (`anvill-decompile-spec --ir_pre_opt`; real output,
`increment.lifted.ll`, with `--add_names` so the function is named `inc`):

```llvm
@__anvill_sp = external global i64
@__anvill_ra = external global i64
@llvm.compiler.used = appending global [1 x ptr] [ptr @inc], section "llvm.metadata"

; Function Attrs: noinline
define i32 @inc(i32 %0) #0 !pc !0 {
  %2 = call ptr @__remill_write_memory_64(ptr null, i64 ptrtoint (ptr @__anvill_sp to i64), i64 ptrtoint (ptr @__anvill_ra to i64)), !pc !0
  %3 = add i32 %0, 1
  %4 = call noundef i64 @__remill_read_memory_64(ptr noundef %2, i64 noundef ptrtoint (ptr @__anvill_sp to i64)) #2, !pc !1
  %5 = call ptr @__remill_function_return(ptr undef, i64 %4, ptr %2), !pc !1
  call void @__anvill_memory_escape(ptr %5)
  ret i32 %3
}

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_write_memory_64(ptr noundef, i64 noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local i64 @__remill_read_memory_64(ptr noundef, i64 noundef) #1

; Function Attrs: noduplicate noinline nounwind optnone
declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) #1

declare void @__anvill_memory_escape(ptr)


!0 = !{i64 4198704}
!1 = !{i64 4198707}
```

After `OptimizeModule` (§13) (`increment.optimized.ll`):

```llvm
@__anvill_ra = external global i64
@__anvill_stack_0 = external local_unnamed_addr global i64

define i32 @inc(i32 %0) local_unnamed_addr #0 !pc !0 {
  %2 = add i32 %0, 1
  ret i32 %2
}

declare dso_local ptr @__remill_function_return(ptr noundef nonnull align 1, i64 noundef, ptr noundef) local_unnamed_addr #1

!0 = !{i64 4198704}
```

How the `ret` disappears:

- `__remill_function_return(undef, <RA loaded from [sp]>, mem)` has a PC operand that `RemoveRemillFunctionReturns` folds (via the cross-reference folder) to `__anvill_ra`, i.e. "returns to the caller". So the call is deleted.
- The RA store to the stack frame becomes dead once `RecoverBasicStackFrame` and SROA have turned stack memory into an `alloca`.
- The `__anvill_reg_*` loads die because nothing reads those registers.

A real lift of the same shape is in `tests/anvill_passes/data/test_ret0_rt.ll`:

```llvm
define i64 @f() #0 { ret i64 1 }
define i32 @main(i32 %0, ptr %1, ptr %2) #0 {
  %4 = call i64 @f()
  %5 = trunc i64 %4 to i32
  ret i32 %5
}
```

This also shows the `__anvill_stack_minus_32 … __anvill_stack_plus_7` symbolic stack-slot globals (§13 RecoverBasicStackFrame, kSymbolic) and `@llvm.compiler.used` listing the lifted entities.

### 10.11 Other FunctionLifter details worth replicating

- `MuteStateEscape(call)` replaces the State argument of `__remill_error` and `__remill_function_return` with `undef`. The State no longer escapes, so SROA can scalarise it. The PC argument still shows what was being returned to.
- `InsertError(block)` is `AddTerminatingTailCall(__remill_error)`. It is used for `stop` overrides, for after a tail-call `Call` on a jump, and for after a noreturn call.
- PC annotation (`!pc`) is applied to *every* instruction created while lifting an instruction, if it is not already annotated. Delayed instructions get their own PC. The native wrapper's setup code gets the function address.
- `TryCallNativeFunction` exists, for calling a known `llvm::Function` directly through `CallFromLiftedBlock`, but it is unused in the current flow. All calls go through the symbolic-PC indirect form.

---

## 11. Entity, data and value lifting

Sources: `include/anvill/Lifters.h`, `lib/Lifters/{Options,EntityLifter,ValueLifter,DataLifter}.cpp`.


### 11.1 Options (Lifters.h / Options.cpp)

```cpp
enum class StateStructureInitializationProcedure : char {
  kNone,                        // just `alloca %State`
  kZeroes,                      // store zeroinitializer
  kUndef,                       // store undef
  kGlobalRegisterVariables,     // state->REG = load @__anvill_reg_REG (per register)
  kGlobalRegisterVariablesAndZeroes,   // zero first, then the global loads   ← DEFAULT
  kGlobalRegisterVariablesAndUndef };
enum class StackFrameStructureInitializationProcedure : char { kNone, kZeroes, kUndef, kSymbolic /* default */ };

class StackFrameRecoveryOptions {
  StackFrameStructureInitializationProcedure stack_frame_struct_init_procedure{kSymbolic};
  std::uint64_t stack_frame_lower_padding{0};    // bytes after the frame (redzone when the stack grows down)
  std::uint64_t stack_frame_higher_padding{0};   // bytes before the frame (caller's frame)
  std::uint64_t max_stack_frame_size{8192};
  unsigned stack_frame_word_size{0};             // 0 → pointer size
  const char *stack_offset_metadata_name{nullptr};   // metadata kind for "offset from entry SP" annotations
  bool stack_grows_down{true};
  bool stack_pointer_is_negative{false};
};

class LifterOptions {
  LifterOptions(const remill::Arch*, llvm::Module&, const TypeProvider&, const ControlFlowProvider&, const MemoryProvider&);
  // CHECKs module context == arch->context.
  const remill::Arch *const arch; llvm::Module *const module;
  const TypeProvider &type_provider; const ControlFlowProvider &control_flow_provider; const MemoryProvider &memory_provider;
  const llvm::DataLayout &DataLayout() const;               // module->getDataLayout()
  const ::anvill::TypeDictionary &TypeDictionary() const;   // type_provider.Dictionary()
  StateStructureInitializationProcedure state_struct_init_procedure = kGlobalRegisterVariablesAndZeroes;
  const char *pc_metadata_name{nullptr};   // metadata kind tying IR to original PCs (decompiler uses "pc")
  std::function<Value*(IRBuilderBase&, const remill::Register *pc_reg, uint64_t func_addr)> program_counter_init_procedure = SymbolicProgramCounterInit;
  std::function<Value*(IRBuilderBase&, const remill::Register *sp_reg, uint64_t func_addr)> stack_pointer_init_procedure = SymbolicStackPointerInit;
  std::function<Value*(IRBuilderBase&, llvm::IntegerType*, uint64_t func_addr)> return_address_init_procedure = SymbolicReturnAddressInit;
  StackFrameRecoveryOptions stack_frame_recovery_options;
  bool add_breakpoints : 1 = false;     // emit breakpoint_<addr> calls per instruction
  bool track_provenance : 1 = false;    // calls to __anvill_data_provenance
  bool stack_pointer_is_signed : 1 = false;   // used by SimplifyStackArithFlags (SIGN flag constant)
  bool should_remove_anvill_pc : 1 = true;    // Optimize: remove the __anvill_pc symbolic base
};
```
Static init procedures:
- `SymbolicStackPointerInit(ir, sp_reg, addr)`: get or create `@__anvill_sp` (type = SP register type, e.g. i64; ExternalLinkage; *initialiser = zero*, so it is a definition, not a declaration). Return the CE `ptrtoint (ptr @__anvill_sp to i64)`.
- `SymbolicProgramCounterInit(ir, pc_reg, addr)`: get or create `@__anvill_pc` the same way. Return `add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 <func_addr>)`.
- `SymbolicReturnAddressInit(ir, int_ty, addr)`: `@__anvill_ra : int_ty = 0`. Return `ptrtoint @__anvill_ra`.
- `ConcreteReturnAddressInit(ir, int_ty, addr)`: `ptrtoint (call ptr @llvm.returnaddress(i32 0)) to int_ty`.

The decompiler (bin/Decompile/Main.cpp) sets `pc_metadata_name = "pc"` and `stack_offset_metadata_name = "stack_offset"`, and wraps the spec type provider in a `ProxyTypeProvider` (or a `DefaultCallableTypeProvider` when `--default_callable_spec` is given).

### 11.2 EntityLifter / EntityLifterImpl
```cpp
class EntityLifter {   // pimpl: std::shared_ptr<EntityLifterImpl> (copyable; copies share state)
  explicit EntityLifter(const LifterOptions&);
  std::optional<uint64_t> AddressOfEntity(llvm::Constant*) const;
  const LifterOptions &Options() const; const llvm::DataLayout &DataLayout() const;
  const MemoryProvider &MemoryProvider() const; const TypeProvider &TypeProvider() const;
  llvm::Function *LiftEntity(const FunctionDecl&) const;     // in FunctionLifter.cpp
  llvm::Function *DeclareEntity(const FunctionDecl&) const;  // in FunctionLifter.cpp
  llvm::Constant *LiftEntity(const VariableDecl&) const;     // DataLifter.cpp
  llvm::Constant *DeclareEntity(const VariableDecl&) const;  // DataLifter.cpp
};
class EntityLifterImpl {
  const LifterOptions options;              // copy
  const MemoryProvider *const memory_provider; const TypeProvider *const type_provider;
  ValueLifterImpl value_lifter; FunctionLifter function_lifter; DataLifter data_lifter;   // constructed in that order
  std::unordered_map<uint64_t, llvm::SmallSet<llvm::WeakTrackingVH, 10>> address_to_entity;
  llvm::ValueMap<llvm::Constant*, uint64_t> entity_to_address;       // weak: auto-removes deleted constants
  void AddEntity(llvm::Constant*, uint64_t);
  void ForEachEntityAtAddress(uint64_t, std::function<void(llvm::Constant*)>) const;  // skips nulled VHs
  std::optional<uint64_t> AddressOfEntity(llvm::Constant*) const;
};
```
- Constructor: CHECK that the contexts match, then `options.arch->PrepareModule(options.module)` (sets triple and DL).
- `AddEntity(e, a)`: `address_to_entity[a].insert(e)`. If `entity_to_address.insert({e,a})` is new and `e` is a GlobalValue, call `llvm::appendToCompilerUsed(module, {gv})`, which keeps it alive via `@llvm.compiler.used`.
- `LiftEntity(FunctionDecl)` (FunctionLifter.cpp, for completeness): scan the entities at `decl.address` for a Function with the same type (`found_by_type`) or any other function (`found_by_address`, LOG(ERROR) "Ignoring existing version…"). Then `func = function_lifter.LiftFunction(decl)`; on null return `found_by_type`. Name-sync with `found_by_type`, then `AddFunctionToContext(func, addr, impl)`, and restore the old name if it differed.

### 11.3 ValueLifter / ValueLifterImpl (constant initialisers and pointers)
```cpp
class ValueLifter { ValueLifter(const EntityLifter&);   // shares impl
  llvm::Constant *Lift(std::string_view data, llvm::Type *type) const;   // = impl->value_lifter.Lift(data, type, *impl, /*loc_ea=*/0)
  llvm::Constant *Lift(std::uint64_t ea, llvm::Type *value_type, unsigned address_space = 0) const;
       // = impl->value_lifter.GetPointer(ea, value_type, *impl, address_space)
       // passes address_space as the address space (fixed: it used to be passed as `loc_ea`, leaving the address space 0)
};
class ValueLifterImpl { const LifterOptions &options; const llvm::DataLayout &dl; llvm::LLVMContext &context; TypeTranslator type_specifier; … };
```
`ConsumeBytesAsInt(data&, n)`:
```
APInt r(n*8, 0); for i<n: r <<= 8; r |= data[i];  data = data.substr(n)
return (dl.isLittleEndian() && n > 1) ? r.byteSwap() : r
```
Each byte is read as `uint8_t`. (**Fixed:** `data[i]` was a (signed) `char` passed to `APInt::operator|=(uint64_t)`, so a byte ≥ 0x80 sign-extended and set all the low 64 bits: `0x8001` (bytes `01 80`) became `0x80ff`. `lifter/data/integer_bytes`.)

`Lift(data, type, ent, loc_ea)`:
- iN: read `allocsize(type)` bytes and truncate to N bits if needed. So i24 reads 4 bytes, and i1 reads 1 byte.
- ptr: read `allocsize(ptr)` bytes as `address`. If `address == loc_ea` (self-reference, e.g. `__dso_handle`) → `Constant::getIntegerValue(ptr, value)` (an inttoptr constant). Else `GetPointer(address, nullptr, ent, loc_ea, addrspace)`; if that is null, fall back to the inttoptr constant.
- struct: for each element, recurse on `data.substr(layout.offset(i))` with `loc_ea + offset` and build a `ConstantStruct`. Padding bytes are skipped implicitly.
- array / fixed vector: elements at `i * allocsize(elem)` → `ConstantArray` / `ConstantVector`.
- float / double: read allocsize bytes, then `bitsToFloat` / `bitsToDouble`.
- other (half, x86_fp80, fp128, …): LOG(FATAL).

`GetPointer(ea, value_type, ent, loc_ea, as)`: `value_type` defaults to i8. `ret = TryGetPointerForAddress(ea, ent, value_type)`. If null: `ea == 0` → `null` ptr; otherwise LOG(WARNING) "Failed to lift address …" and return nullptr. If `ret`'s address space differs from `as` → `addrspacecast`, followed by `AddEntity(ret, ea)`.

`TryGetPointerForAddress(ea, ent, hinted_type)`:
1. Check existing entities at `ea`. A GlobalVariable or Function always wins (the last one seen). Otherwise keep the first one, letting a GlobalValue replace a non-GlobalValue. Return `UnwrapZeroIndices(found)`, which peels all-zero GEPs and pointer casts/aliases while the type stays the same; with opaque pointers that usually reaches the base global.
2. `type_provider->TryGetFunctionTypeOrDefault(ea)` → `GetFunctionPointer(decl)` = `function_lifter.DeclareFunction(decl)` + `AddFunctionToContext(func, decl.address, ent)`.
3. If `hinted_type` is an `llvm::FunctionType`: create a temporary `.anvill.value_lifter.temp` function (PrivateLinkage) in `options.module`, run `FunctionDecl::Create(tmp, arch)`, erase the temp, force `decl.address = ea`, then `GetFunctionPointer`. Log an error on failure.
4. `GetVarPointer(ea, ea, ent, hinted_type)`, then `GetVarPointer(ea, ea-1, …)` for one-past-the-end symbols such as `__text_end`.
5. Apply `UnwrapZeroIndices` to the result, or return nullptr.

`GetVarPointer(var_ea, search_ea, ent, elem_ty)`: `v = type_provider->TryGetVariableType(search_ea, elem_ty)`; none → nullptr. If `v.address == var_ea` → `data_lifter.GetOrDeclareData(v, ent)`. Otherwise use `remill::BuildPointerToOffset(builder, GetOrDeclareData(v), var_ea - v.address, ptr)`, which yields a constant GEP into the enclosing variable.

Example: VariableDecl `{i32, ptr}` @0x4000 with LE bytes `2a 00 00 00 | 00×4 | 10 40 00 00 00 00 00 00`. The result is `{ i32 42, ptr X }`, where X is `@sub_4010`-like if the TypeProvider knows a function at 0x4010, `@var_4010_…` if a variable starts there, `getelementptr(i8, @var_4000_…, 16)` style for interior pointers, and otherwise `inttoptr (i64 16400 to ptr)`.

### 11.4 DataLifter
```cpp
class DataLifter { DataLifter(const LifterOptions&);
  llvm::Constant *LiftData(const VariableDecl&, EntityLifterImpl&);          // creates the GlobalVariable
  llvm::Constant *GetOrDeclareData(const VariableDecl&, EntityLifterImpl&);  // never null
  const LifterOptions &options; const MemoryProvider &memory_provider; const TypeProvider &type_provider;
  const TypeTranslator type_specifier; llvm::LLVMContext &context; };
```
`GetOrDeclareData(decl)`:
1. `type = RecontextualizeType(decl.type)`. For each entity at `decl.address`, while `found_by_type` is not yet a GlobalValue:
   - GlobalAlias: if its value type == type → `found_by_type`; always `found_by_address = ga`.
   - ConstantExpr: CHECK pointer type, then `found_by_address = ce`. (**Fixed:** it assigned `ga`, which is null in that scope, so CE entities were ignored.)
   - GlobalVariables are ignored here; LiftData dedups them by name instead.
2. If `found_by_type` → return it.
3. `wrap_with_alias(val)`: if `CanBeAliased(val)` (backed by a definition, §B.4) → create `GlobalAlias::create(type, 0, External, "data_<hex>_<alnum enc>", module)` with aliasee `val`, `AddEntity(val)`, `AddEntity(ga)`, and return `ga`. Otherwise return `val`.
4. If `found_by_address` (an alias of a different type): `[base, off] = remill::StripAndAccumulateConstantOffsets(dl, found)`. If base is set and `off > 0` → `wrap_with_alias(BuildPointerToOffset(ir, base, off, type))`. Otherwise (LOG(ERROR) if off<0): `ce = bitcast(found, type->getPointerTo(as))`, `AddEntity(ce, addr)`, `wrap_with_alias(ce)`.
5. Otherwise `gv = LiftData(decl)`, `AddEntity(gv, addr)`, return gv.

`LiftData(decl)`:
1. Name `var_<hex addr>_<EncodeToString(type, kValidSymbolCharsOnly)>`. If the module already has a global with that name → return it.
2. `size = allocsize(type)`. Query the first byte; if `HasByte` (kAvailable) push it. For i in `1..size`: stop (LOG(ERROR)) when a byte is not available ("crosses into inaccessible bytes (Byte offset i)") or has a different permission ("crosses permission"). Either case marks the bytes as not accessible.
3. If accessible → `value = value_lifter.Lift(bytes, type, ent, decl.address)`.
4. `is_constant = first_perm ∈ {kReadable, kReadableExecutable}`.
5. `new GlobalVariable(module, type, is_constant, ExternalLinkage, value_or_null, name)`. A null initialiser gives an external declaration. No alignment is set.

`EntityLifter::DeclareEntity(VariableDecl)`: if the first byte's availability is not `IsValidAddress` (kUnknown or kAvailable) → nullptr; else `GetOrDeclareData`. `LiftEntity(VariableDecl)` = `GetOrDeclareData` with no check.

Example: `VariableDecl{type=i32, address=0x601040}` with available RW bytes `01 00 00 00` → `@var_601040_I = global i32 1`. The same in read-only memory → `@var_601040_I = constant i32 1`. With unknown bytes → `@var_601040_I = external global i32`.


---

## 12. Cross-reference folding

Sources: `include/anvill/CrossReference{Folder,Resolver}.h`, `lib/CrossReference{Folder,Resolver}.cpp`. Many passes need to ask "what address does this constant expression or instruction compute, and is it relative to the stack pointer, the program counter or the return address?" This component answers that question.


### 12.1 Resolver interface
```cpp
class CrossReferenceResolver {
  virtual std::optional<std::uint64_t> AddressOfEntity(llvm::Constant *ent) const = 0;
  virtual llvm::Constant *EntityAtAddress(std::uint64_t addr, llvm::Type *value_type=nullptr, unsigned addr_space=0) const = 0;
};
class NullCrossReferenceResolver   // AddressOfEntity → nullopt; EntityAtAddress → nullptr
class EntityCrossReferenceResolver(const EntityLifter&)   // impl holds a copy of the EntityLifter + a ValueLifter
```
- `EntityCrossReferenceResolver::AddressOfEntity(c)` = `entity_lifter.AddressOfEntity(c)`, a lookup in the `entity_to_address` ValueMap.
- `EntityAtAddress(addr, T, as)`: `ret = value_lifter.Lift(addr, T, as)` (§11.2). If both `ret` and `T` are set and `ret`'s pointer type differs from `ptr addrspace(as)`: when the address spaces differ, return `addrspacecast(bitcast(ret → ptr addrspace(ret_as)), ptr as)`; otherwise return `bitcast(ret, ptr)` (a no-op with opaque pointers). There is a large commented-out legacy implementation.

### 12.2 ResolvedCrossReference
```cpp
struct ResolvedCrossReference {
  union { std::uint64_t address; std::int64_t displacement; } u;
  unsigned size{0};                         // bits of the operand
  bool references_entity : 1;               // AddressOfEntity succeeded somewhere
  bool references_global_value : 1;         // a GlobalValue that was NOT resolvable → needs relocation
  bool references_stack_pointer : 1;        // __anvill_sp / __anvill_reg_<sp> / read_register(sp) / sponentry
  bool references_program_counter : 1;      // __anvill_pc / __anvill_reg_<pc>
  bool references_return_address : 1;       // __anvill_ra / llvm.returnaddress / addressofreturnaddress-load …
  bool is_valid : 1;
  operator bool() const { return is_valid; }
  std::int64_t Displacement(const llvm::DataLayout&) const;
};
```
`Displacement(dl)`: CHECK `size != 0`. Let `w = min(size, ptr_bits)`: sign-extend from the low `w` bits of `u.displacement` (any width, e.g. 1 for an `icmp` result). (**Fixed:** only 8/16/32/64 were handled and any other width gave 0, which made every SP comparison fold to `false` in RemoveStackPointerCExprs.)
`{}` value-initialises everything to zero/false.

### 12.3 CrossReferenceFolder API
```cpp
CrossReferenceFolder(const CrossReferenceResolver&, const llvm::DataLayout&);   // impl is shared_ptr → copies share cache
const llvm::DataLayout &DataLayout() const;
void ClearCache() const;
ResolvedCrossReference TryResolveReferenceWithCaching(llvm::Value*) const;       // entities.clear(); ResolveValue
ResolvedCrossReference TryResolveReferenceWithClearedCache(llvm::Value*) const;  // entities.clear(); cache.clear(); ResolveValue
uint64_t MagicReturnAddressValue() const;   // 0x4141414141414141 truncated to pointer width (16→0x4141, 32→0x41414141)
```
Impl state: `xref_resolver`, a `DataLayout dl` copy, `unordered_map<Value*, ResolvedCrossReference> xref_cache` (keyed by instruction or constant; it can go stale if IR is deleted, hence the cleared-cache variant), and `vector<Value*> entities` (collected, never read).

### 12.4 Algorithm

Helper: `Signed(val, size)`: size 1 → -1/0; 8/16/32/64 → C casts; other → `((val ^ m) - m)` with `m = 1 << (size-1)`.

Binary folders, generated by `MAKE_BINOP_FOLDER(name, op, merge, wrap, allow_rhs_zero)`:
```
Fold<name>(lhs, rhs, mask, size):
  if (allow_rhs_zero || (rhs.u.address & mask)) return merge(lhs, rhs, (a,b) -> (uint64)(wrap(a,size) op wrap(b,size)) & mask)
  else return {}                                   // division/remainder by zero → invalid
```
| op | merge | wrap | rhs zero allowed |
|---|---|---|---|
| Add, Sub, Mul | Merge | Signed | yes |
| And, Or, Xor | Merge | none | yes |
| Shl, LShr | MergeLeft | none | yes |
| AShr | MergeLeft | Signed | yes |
| UDiv, URem | MergeLeft | none | no |
| SDiv, SRem | MergeLeft | Signed | no |
| ICmp eq/ne/ugt/uge/ult | Merge | none | yes |
| ICmp ule uses `<=` (**fixed:** it used `<`) | Merge | none | yes |
| ICmp sgt/sge/slt/sle | Merge | Signed | yes |

- `Merge`: `is_valid = lhs.valid & rhs.valid`, and each references_* flag is the OR of both sides.
- `MergeLeft`: `is_valid` is the AND of both sides, but the flags come from lhs only.
- The result `size` is reset to the output size by the caller.

`ResolveValue(v)`: Constant → `ResolveConstant`; Instruction → `ResolveInstruction`; anything else (Argument, …) → `{}` (invalid).

`ResolveConstant(c)` (memoised):
- GlobalValue → `ResolveGlobalValue(gv)`, then `size = ptr bits`.
- ConstantExpr → `ResolveConstantExpr`.
- ConstantInt → `size = bitwidth`. Negative values with ≤64 significant bits → `address = sext value`, valid. Non-negative values with ≤64 active bits → zext value, valid. Otherwise invalid.
- ConstantPointerNull → valid, address 0, size = ptr bits.
- anything else → invalid.

`ResolveGlobalValue(gv)` (not memoised itself; reached via ResolveConstant):
1. If gv is a GlobalVariable named `__anvill_pc` → references_program_counter, valid (address 0). If `__anvill_sp` → references_stack_pointer, valid. If `__anvill_ra` → `address = MagicRA`, references_return_address, valid.
2. Regardless of step 1: if `xref_resolver.AddressOfEntity(gv)` yields a value → `address = it`, references_entity, valid. This lets a resolver give the special globals concrete values.
3. If valid by now → return.
4. Otherwise set `references_global_value = true`. If gv is a GlobalAlias with an aliasee → `xr = ResolveConstant(aliasee)`; note this overwrites the flag. Return.

`ResolveConstantExpr(ce)`:
- If `AddressOfEntity(ce)` resolves → `{address, size=ptr, references_entity, valid}`, with all other flags clear. (**Fixed:** that `xr` was default-initialised, not `{}`, so the other bitfields were indeterminate.)
- `size` = primitive bits of operand 0's type (pointer → ptr bits) and `mask = size<64 ? (1<<size)-1 : ~0`. `out_size`/`out_mask` are computed the same way from the CE's own type.
- Add, Sub, Mul, And, Or, Xor, Shl, LShr, AShr, SDiv, UDiv, SRem, URem → `Fold<op>(RC(op0), RC(op1), mask, size)`, `size = out_size`.
- ZExt → `address &= mask` (input mask); size = out.
- SExt → `displacement = Signed(address, in_size)`; `address &= out_mask`; size = out.
- Trunc → `address &= out_mask`.
- IntToPtr, PtrToInt, BitCast → pass-through; size = out.
- ICmp → `FoldICmp(pred)`.
- GetElementPtr → `base = RC(op0)`. `accumulateConstantOffset(dl, ap(ptr_bits), visit)`, where `visit` resolves non-constant indices via ResolveValue and adds `Signed(idx.address, ptr_bits)`. On failure `base.is_valid = false`. Otherwise `base.address += Signed(ap, ptr_bits)`; size = out.
- Select → resolve the condition; pick op1 if `cond.address != 0`, else op2; `is_valid &= cond.is_valid`. Only the chosen side is evaluated.
- other → `{}`.

`ResolveInstruction(inst)` (memoised; the cache entry is created up front, which breaks cycles because a re-entrant lookup sees the zero, invalid entry):
- `IsProgramCounter(inst)` (a load of `__anvill_reg_<pc>`) → PC flag, size = ptr, valid.
- `IsStackPointer(inst)` (a load of `__anvill_reg_<sp>`, `llvm.read_register(sp)`, or `llvm.sponentry`) → SP flag.
- `IsReturnAddress(inst)` → address = MagicRA, RA flag.
- Otherwise the same masking rules as for CEs: Add…URem (no ICmp, Select or GEP *instructions*); Load → `ResolveLoad` (a load from a *constant* GlobalVariable with an initializer resolves to that initializer, else `{}`); ZExt/SExt/Trunc/IntToPtr/PtrToInt/BitCast as above; Call → `ResolveCall`; others → `{}`.

`ResolveCall(call)`:
- `llvm.ctlz` / `llvm.cttz` / `llvm.ctpop` → resolve arg0, truncate it to the call's width W (≤ 64, else invalid) and count on W bits; a zero input counts as W. size = W. (**Fixed:** these used `__builtin_clzl`/`ctzl`/`popcountl` on the 64-bit address regardless of width, and clz/ctz of 0 was UB.) Shifts by at least the width give an invalid result (also fixed).
- other intrinsics → `{}`.
- Non-intrinsic call whose callee name starts with `__anvill_type_hint` → resolve arg0, size = ptr bits. Anything else → `{}`.

### 12.5 Examples (64-bit DL, resolver = entity lifter)

1. `add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -16)` → `{address=0xFFFFFFFFFFFFFFF0, size=64, references_stack_pointer, valid}`; `Displacement() = -16`.
2. `add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4198400)` → `{address=0x401000, references_program_counter, valid}`.
3. `ptrtoint (ptr getelementptr inbounds (i8, ptr @var_404000_I, i64 4) to i64)`, where `@var_404000_I` is registered at 0x404000 → `{address=0x404004, references_entity, valid, size=64}`.
4. `trunc (i64 add (ptrtoint @__anvill_sp, -8) to i32)` → `address=0xFFFFFFF8, size=32` → `Displacement = -8`.
5. `udiv (i64 ptrtoint @x, 0)` → invalid `{}`.
6. `ptrtoint (ptr @unknown_external to i64)`, not an entity → `references_global_value=1, is_valid=0`.
7. `ptrtoint (ptr @__anvill_ra)` → `address = 0x4141414141414141, references_return_address`.
8. Instruction chain: `%a = load i64, ptr @__anvill_reg_RSP` (SP flag) → `%b = add i64 %a, 32` → `{address=32, SP flag}`.
9. Select CE: `select (i1 icmp eq (i64 ptrtoint @__anvill_pc, 0), i64 1, i64 2)` → icmp eq 0==0 → 1 → picks `i64 1`.


---

## 13. The optimization pipeline and every pass


Scope: `lib/Passes/*`, `include/anvill/Passes/*`, `include/anvill/Transforms.h`,
`lib/Transforms.cpp`, the test harness in `tests/anvill_passes/`, and the scheduling
in `lib/Optimize.cpp`. Repo HEAD: `9948d26`. The remill submodule is not checked out.
The Remill constants below are inferred from usage. Remill "three-argument form" functions
have the signature `Memory *f(State *, addr_t pc, Memory *)`, which gives
`remill::kStatePointerArgNum = 0`, `remill::kPCArgNum = 1`, `remill::kMemoryPointerArgNum = 2`.
The test IR confirms this, e.g. `__remill_function_return(ptr undef, i32 %11, ptr null)`.

Conventions in this document:

* All passes are **new-PM function passes**: `llvm::PassInfoMixin<T>` with
  `PreservedAnalyses run(llvm::Function &, llvm::FunctionAnalysisManager &)`.
  Two are **function analyses** instead: `llvm::AnalysisInfoMixin<T>`, `BranchAnalysis` and `JumpTableAnalysis`.
  None of them is a module pass or uses the legacy PM.
* Each pass has a `static llvm::StringRef name()`. In `Transforms.h`, each pass also has an
  `AddXxx(llvm::FunctionPassManager &fpm, ...)` helper that does `fpm.addPass(Xxx(...))`.
* "Illustrative" marks IR examples that were constructed by hand. All other examples come from the
  test data or from code comments.
* "Gotcha" marks behaviour that the code really has (bugs and quirks included). A faithful
  reimplementation should either reproduce it or make a deliberate choice to fix it.


### 13.0 Shared names, constants, metadata kinds


From `lib/ABI.cpp` (`include/anvill/ABI.h`):

| Constant | Value |
|---|---|
| `kAnvillNamePrefix` | `"__anvill_"` |
| `kSymbolicPCName` | `"__anvill_pc"` (global used to taint PC-derived constants) |
| `kSymbolicSPName` | `"__anvill_sp"` |
| `kSymbolicRAName` | `"__anvill_ra"` |
| `kUnmodelledRegisterPrefix` | `"__anvill_reg_"` (e.g. `@__anvill_reg_RSP`) |
| `kTypeHintFunctionPrefix` | `"__anvill_type_hint"` |
| `kMemoryPointerEscapeFunction` | `"__anvill_memory_escape"` |
| `kStackFrameTypeNameSuffix` | `".frame_type"` |
| `kSymbolicStackFrameValuePrefix` | `"__anvill_stack_"` |
| `kAnvillSwitchCompleteFunc` | `"__anvill_complete_switch"` (declared `T (T, ...)`, `readnone`; arg0 = computed PC, args 1..N = constant target PCs) |
| `kAnvillSwitchIncompleteFunc` | `"__anvill_incomplete_switch"` |
| `kAnvillDataProvenanceFunc` | `"__anvill_data_provenance"` |
| `kAnvillStackZero` | `"__anvill_stack_zero"` (**metadata kind name** on the frame alloca) |
| `kGlobalVariableNamePrefix` / `kGlobalAliasNamePrefix` | `"var_"` / `"data_"` |

Defined in pass headers:

* `BranchHintPass.h`: `kFlagIntrinsicPrefix = "__remill_flag_computation"`,
  `kCompareInstrinsicPrefix = "__remill_compare"` (sic, "Instrinsic"),
  `kCompareExchangePrefix = "__remill_compare_exchange"`.
* `TransformRemillJumpIntrinsics.cpp`: `kRemillJumpIntrinsicName = "__remill_jump"`,
  `kRemillFunctionReturnIntrinsicName = "__remill_function_return"`.
* `JumpTableAnalysis.cpp`: `IndexVarName = "index"` (the Z3 variable name).
* `BranchAnalysis.cpp`: Z3 symbol names `"value0"`/`"value1"`, and
  `EnvironmentBuilder::FlagIDPrefix = "flag"` (unused in practice).
* `SliceManager`: slice functions are named `"sliceFunc." + id`. Basic blocks are
  `"slicebasicblock." + id`. The module is `"slicemodule"`.

Intrinsic and function names that passes match on:

* `__remill_read_memory_*`, `__remill_write_memory_*` (suffixes `8/16/32/64/f32/f64/f80/f128`)
* `__remill_undefined_*`
* `__remill_delay_slot_begin`, `__remill_delay_slot_end`
* `__remill_error`
* `__remill_function_return`, `__remill_jump`
* `__remill_flag_computation_{zero,overflow,sign,carry}`. Signature
  `i1 (i1 flag_val, ...)`. The varargs are `lhs, rhs, result`.
* `__remill_compare_{eq,neq,sle,slt,sge,sgt,ule,ult,uge,ugt}`, declared `i1 (i1)`
* `fpclassify`, `__fpclassifyd`, `__fpclassifyf`, `__fpclassifyld`
* `llvm.returnaddress`, `llvm.addressofreturnaddress.p0` (on Windows ARM: `_AddressOfReturnAddress`),
  `llvm.sponentry`, `llvm.read_register`
* `__anvill_type_hint*`, `__anvill_complete_switch`, `__anvill_incomplete_switch`

Metadata kinds:

* PC metadata: name comes from `LifterOptions::pc_metadata_name` (`const char *`, default nullptr).
  `Optimize.cpp` resolves it with `context.getMDKindID(options.pc_metadata_name)` into
  `std::optional<unsigned> pc_metadata_id`. The node format is `!{iN <pc>}`,
  i.e. `MDNode::get(ctx, ValueAsMetadata::get(ConstantInt(addr_type, pc)))`.
* `__anvill_stack_zero` (`kAnvillStackZero`): on the stack-frame `alloca`. Format
  `!{iN <base>}`.
* Stack-offset metadata: name from `StackFrameRecoveryOptions::stack_offset_metadata_name`
  (default nullptr). Format `!{iN <disp>}`.
* `CopyMetadataTo` (lib/Utils.cpp) copies **all** non-debug-loc metadata from src instruction to
  dst instruction except `tbaa`, `tbaa_struct`, `noalias`, `alias_scope`. It is a no-op if either side is not an
  Instruction or `src == dst`. Practically every rewrite calls it, so the PC metadata follows
  the rewritten code.

`StackFrameRecoveryOptions` (include/anvill/Lifters.h), with defaults:

```
StackFrameStructureInitializationProcedure stack_frame_struct_init_procedure{kSymbolic}; // kNone,kZeroes,kUndef,kSymbolic
uint64_t stack_frame_lower_padding{0};
uint64_t stack_frame_higher_padding{0};
uint64_t max_stack_frame_size{8192};
unsigned stack_frame_word_size{0};          // 0 => pointer size
const char *stack_offset_metadata_name{nullptr};
bool stack_grows_down{true};
bool stack_pointer_is_negative{false};
```

The relevant `LifterOptions` fields are `pc_metadata_name`, `stack_frame_recovery_options`,
`should_remove_anvill_pc` (default true) and `stack_pointer_is_signed`.

Helpers from `lib/Utils.cpp` that the passes rely on (core library):

* `IsStackPointer(M, v)`: true for the GV named `__anvill_sp`, for a load of `@__anvill_reg_<SP>` where the
  SP name depends on the arch (x86 `esp`; x86_64 `rsp|esp`; aarch64 `sp|xsp|wsp`; arm `r13|sp|wsp`; sparc `o6|sp`),
  for `llvm.sponentry`, and for `llvm.read_register` naming the SP.
* `IsProgramCounter(M, v)`: true for the GV named `__anvill_pc`, or a load of `@__anvill_reg_<PC>`.
* `IsReturnAddress(M, v)` returns true for:
  * the GV `__anvill_ra`;
  * a call to `llvm.returnaddress` or `llvm.sponentry`;
  * `__remill_read_memory_*(mem, llvm.addressofreturnaddress())`;
  * a load from `llvm.addressofreturnaddress()`;
  * a recursion through ptrtoint, inttoptr or bitcast;
  * a CE `add(RA, disp)` with `disp == 0`, or with `disp` in {0,4,8} on SPARC.
* `IsRelatedToStackPointer(M, v)` / `StackPointerResolver`: a cached recursive walk through ptrtoint,
  CEs (casts, gep, shifts, div, add/sub/mul/and/or/xor/icmp, select), binary ops, unary ops,
  selects, `stripPointerCastsAndAliases` and `stripAndAccumulateConstantOffsets`, bottoming out in
  `IsStackPointer`.
* `AdaptToType(ir, src, dest_type)` converts integers and pointers:
  * int to int: zext; trunc; or `icmp ne 0` when the destination is i1;
  * int to ptr: unwraps a `ptrtoint` CE if present, otherwise uses inttoptr, plus an addrspacecast if needed;
  * ptr to ptr: bitcast or addrspacecast;
  * ptr to int: ptrtoint to pointer width, then adapts again.
* `CrossReferenceFolder` / `ResolvedCrossReference`. Fields: `u.address`/`u.displacement`, `size`
  (bits), `references_entity`, `references_global_value`, `references_stack_pointer`,
  `references_program_counter`, `references_return_address`, `is_valid`.
  * `__anvill_pc` and `__anvill_sp` resolve to address 0 with the matching flag set.
  * `__anvill_ra` resolves to `MagicReturnAddressValue()`, which is `0x4141414141414141`
    truncated to pointer width.
  * `Displacement(dl)` sign-extends `u.displacement` from `min(size, ptr_bits)`. **Only 8, 16, 32 and 64
    are handled. Any other size (e.g. 1) yields 0.**

`lib/Transforms.cpp` only defines `TransformationErrorManager::~TransformationErrorManager()`,
which does `CHECK(error_list.empty())`. The `TransformationError`, `SeverityType` and
`TransformationErrorManager` types in `Transforms.h` are not used by any current pass. They are a vestige.


### 13.1 Shared pass infrastructure


#### 13.1.1 `lib/Passes/Utils.{h,cpp}`

```cpp
template <class... Types>                     // in anonymous namespace in the header
static std::vector<llvm::Instruction*> SelectInstructions(llvm::Function&);
    // all instructions where dyn_cast<T> succeeds for any T in Types, in function order

bool BasicBlockIsSane(llvm::BasicBlock *block);          // PHIs only at the top of the block
inline bool BasicBlockIsSane(llvm::Instruction *inst);   // = BasicBlockIsSane(inst->getParent())

std::vector<llvm::CallBase*> FindFunctionCalls(llvm::Function&, std::function<bool(llvm::CallBase*)> pred);
     // collect first, so callers can mutate safely

llvm::Value *ConvertToPointer(llvm::Instruction *usage_site, llvm::Value *val, llvm::PointerType *dest);
     // IRBuilder at usage_site. Constant: ptr->ptr via addrspacecast + remill::BuildPointerToOffset(...,0,...);
     // int->ptr: zext to ptr width if narrower, then inttoptr CE; otherwise bitcast CE (with LOG(ERROR)).
     // Non-constant: same logic using instructions (CreateAddrSpaceCast/CreateZExt/CreateIntToPtr/
     // CreateBitOrPointerCast), copying metadata at every step.   (Currently unused by the passes.)

std::string GetFunctionIR(llvm::Function&);   std::string GetModuleIR(llvm::Module&);
llvm::PreservedAnalyses ConvertBoolToPreserved(bool modified);   // none() if modified else all()

llvm::Function *AddressOfReturnAddressFunction(llvm::Module*);
     // x86, x86_64, aarch64, aarch64_be -> "llvm.addressofreturnaddress.p0"
     // arm, armeb, aarch64_32 on Windows -> "_AddressOfReturnAddress"
     // otherwise nullptr. Declares `ptr ()` (i8* ptr in AS 0) with ExternalLinkage if absent.
```

#### 13.1.2 CRTP drivers (headers only)

**`IntrinsicPass<UserFunctionPass, Result>`** (`IntrinsicPass.h`):

```cpp
Result run(Function &F, FunctionAnalysisManager &am) {
  Result total = UserFunctionPass::INIT_RES;                 // static member of the user
  for (CallInst *c : all CallInsts in F where UserFunctionPass::isTargetInstrinsic(c))  // collected first
    total = user.runOnIntrinsic(c, am, std::move(total));
  return total;
}
```

**`BranchHintPass<U,R> : IntrinsicPass<U,R>`** (`BranchHintPass.h`) supplies
`isTargetInstrinsic(call)`: the callee name starts with `"__remill_compare"` **and does not** start with
`"__remill_compare_exchange"`.

**`IndirectJumpPass<U,R>`** (`IndirectJumpPass.h`). The target is a `CallInst` whose callee name **equals**
`__anvill_complete_switch`. Incomplete switches are deliberately excluded (see the NOTE(ian) comment).
`run` starts from `U::BuildInitialResult()` and folds `runOnIndirectJump(call, am, total)` over the targets.


### 13.2 Constraint / SMT machinery (Z3 IS used)


The top-level `CMakeLists.txt` has `find_package(Z3 CONFIG REQUIRED)`. Headers include
`<z3++.h>`. Users: `Constraints`, `ConstraintExtractor`, `BranchAnalysis` and `JumpTableAnalysis`.

#### 13.2.1 `Constraints.h/.cpp`: an expression AST lowered to Z3

```cpp
class Environment { std::unordered_map<std::string, z3::expr> bindings;
  z3::expr lookup(const std::string&) const;   // throws std::invalid_argument("Unbound variable: "+name)
  void insert(std::string, z3::expr); };       // unordered_map::insert, so the first binding wins

class Expr { virtual z3::expr BuildExpression(z3::context&, const Environment&) const = 0; };
class Cast : Expr { unique_ptr<Expr> target; virtual z3::expr BuildExpressionFromEvaluated(z3::expr) const = 0; }
class Sext  : Cast { unsigned target_size; }   // z3::sext(e, target_size)  (target_size = #bits ADDED)
class Zext  : Cast { unsigned target_size; }   // z3::zext(e, target_size)
class Trunc : Cast { unsigned hi, lo; }        // e.extract(hi, lo)
class AtomVariable : Expr { std::string name; }    // env.lookup(name)
class AtomIntExpr  : Expr { llvm::APInt atom_value; } // c.bv_val(width, bits[]) with bit i = api[i]
enum Z3Binop { ADD, SUB, ULE, ULT, UGT, UGE, MUL, AND, OR, EQ, SGT, SGE, SLE, SLT, XOR, NEQ, LShr, AShr, Shl };
class BinopExpr : Expr { Z3Binop opcode; unique_ptr<Expr> lhs, rhs; }
enum Z3Unop { LOGNOT };   class UnopExpr : Expr { Z3Unop opcode; unique_ptr<Expr> lhs; }
```

Each class has a `static std::unique_ptr<Expr> Create(...)` factory.

`Cast::BuildExpression`: evaluates the target. If the result is Bool, it upcasts with
`ite(e, bv1(1), bv1(0))` before applying the cast. A cast always operates on a bitvector.

`BinopExpr::ExpressionFromLhsRhs(op, e1, e2)` maps ops to Z3 as follows:

| Ops | Z3 lowering |
|---|---|
| ADD/SUB/MUL | `+ - *` |
| ULE/ULT/UGT/UGE | `z3::ule` etc. |
| SGT/SGE/SLT/SLE | `z3::sgt` etc. (bv signed) |
| EQ/NEQ | `== / !=` |
| AND/OR | `& / |` if `e1.is_bv()`, else `&& / ||` |
| XOR | `^` |
| AShr/LShr/Shl | `z3::ashr`, `z3::lshr`, `z3::shl` |

Any other op throws.

`BinopExpr::BuildExpression` builds both sides. If exactly one side is Bool and the other is a bv,
the bv side must be 1 bit (asserted) and is converted with `bv != bv1(0)`. Otherwise the widths
must match (asserted).

`UnopExpr` LOGNOT: `!e` on Bool, `e == 0` on a bv.

Translation tables (static methods on `BinopExpr`):

* `TranslateOpcodeToConnective(BinaryOps)`: And→AND, Or→OR, Add→ADD, Sub→SUB, Xor→XOR,
  LShr, AShr, Shl. Anything else (including Mul, Div) gives `nullopt`.
* `TranslateIcmpOpToZ3(Predicate)`: maps all 10 integer predicates (EQ, NE→NEQ, U*/S*).

#### 13.2.2 `ConstraintExtractor<UserVisitor>` (header-only CRTP `llvm::InstVisitor<UserVisitor, optional<unique_ptr<Expr>>>`)

It builds an `Expr` for an LLVM value by walking its def chain.

```cpp
optional<unique_ptr<Expr>> ExpectInsnOrStopCondition(Value *v) {
  if (auto s = user->attemptStop(v)) return s;              // client-defined leaves
  if (ConstantInt *ci = v) return AtomIntExpr(ci->getValue());
  if (Instruction *i = v)  return visit(*i);
  return nullopt;                                            // args, non-int constants, CEs => fail
}
visitInstruction         -> nullopt (anything unhandled aborts the whole expression)
visitSExt(I)  -> Sext(expr(op0),  dstBits - srcBits)
visitZExt(I)  -> Zext(expr(op0),  dstBits - srcBits)
visitTrunc(I) -> Trunc(expr(op0), hi = dstBits-1, lo = 0)
visitICmpInst -> BinopExpr(TranslateIcmpOpToZ3(pred), expr(op0), expr(op1))
visitBinaryOperator -> BinopExpr(TranslateOpcodeToConnective(opc), expr(op0), expr(op1))
```

There is also a public, unused `std::optional<llvm::Instruction*> substituded_index;`.

Gotcha: the extractor expects InstCombine-canonical IR. PHIs, selects, loads, calls and
mul/div all fail unless `attemptStop` catches them.

#### 13.2.3 `BranchAnalysis` (function analysis). File `lib/Passes/BranchAnalysis.cpp`

Kind: `BranchHintPass<BranchAnalysis, DenseMap<CallInst*, BranchResult>>` plus
`llvm::AnalysisInfoMixin<BranchAnalysis>`. It has `static AnalysisKey Key`, `INIT_RES` (an empty map), and
`name() = "BranchAnalysis"`. It is registered in `Optimize.cpp` with `fam.registerPass([&]{ return BranchAnalysis(); })`.

```cpp
typedef std::pair<llvm::Value*, llvm::Value*> ComparedValues;
struct BranchResult { ComparedValues compared; llvm::CmpInst::Predicate compare; };
struct RemillComparison { llvm::CmpInst::Predicate pred; };
enum ArithFlags { OF, ZF, SIGN, CARRY };
struct RemillFlag { ArithFlags flg; Value *flag_val, *lhs, *rhs, *over; };
class Guess { Predicate op; Z3Binop z3_op; bool flip_symbols;
  bool AttemptToProve(z3::expr flagRes, z3::solver&, z3::context&, const Environment&);
  BranchResult ConstructSimplifiedCondition(ComparedValues); };
RemillComparison ParseComparisonIntrinsic(StringRef name);
std::optional<RemillFlag> ParseFlagIntrinsic(const Value*);
```

Purpose: prove that a `__remill_compare_<pred>(i1 %flagexpr)` hint is equivalent to a plain
`icmp <pred'> a, b` over the two operands of the underlying arithmetic. Then `BranchRecovery`
replaces the hint call with that icmp.

`ParseComparisonIntrinsic(name)`:

* takes `name.rsplit('_').second` and looks it up in
  `{sle,slt,ult,ule,sge,sgt,ugt,uge,eq,neq}`, mapped to `ICMP_*`;
* `neq` maps to `ICMP_NE`;
* an unknown suffix **throws `std::runtime_error`**.

`ParseFlagIntrinsic(v)`:

* `v` must be a `CallInst` to a function whose name starts with `__remill_flag_computation`;
* the suffix after the last `_` must be in `{zero→ZF, overflow→OF, sign→SIGN, carry→CARRY}`;
* returns `{flg, flag_val=arg0, lhs=arg1, rhs=arg2, over=arg3}`. "over" is the arithmetic
  result. It is unused by BranchAnalysis and used by SimplifyStackArithFlags.

Algorithm, `analyzeComparison(call)`:

1. `pred = ParseComparisonIntrinsic(callee name)`.
2. Create an `EnvironmentBuilder` (state: `optional<ComparedValues> symbols`) and a
   `LocalConstraintExtractor`. The extractor's `attemptStop(v)` works as follows:
   * If `v` is `symbols->first`, return `AtomVariable("value0")`. If it is `symbols->second`, return
     `AtomVariable("value1")`.
   * Else, if `ParseFlagIntrinsic(v)` succeeds, call `envBuilder.addFlag(flag)`. It accepts the flag only if
     (a) no symbols are fixed yet, or the flag's `{lhs, rhs}` set equals the fixed pair (in either order),
     and (b) both lhs and rhs are integer typed. The first accepted flag **fixes**
     `symbols = (lhs, rhs)`. When accepted, the walk continues **into `flag_val` (arg0)**,
     i.e. into the inlined semantic computation of the flag. The opaque call is not treated as a leaf.
   * Otherwise `nullopt`, and normal visiting continues.
3. `expr = extractor.ExpectInsnOrStopCondition(call->getArgOperand(0))`. On failure there is no result.
4. Create a Z3 context and solver. `BuildEnvironment` creates two bv consts `value0` and `value1`, both
   with the **bit width of `symbols->first`**, and inserts them into the Environment.
5. `exp = expr->BuildExpression(c, env)`. If it is a bv (it must be 1 bit), set `exp = (exp == 1)`.
6. Try the guess strategies in order. The defaults are installed by the constructor:
   1. `Guess(hint, false)`
   2. `Guess(inverse(hint), false)`
   3. `Guess(hint, true)` (flipped operands)
   4. `Guess(inverse(hint), true)`

   A second constructor accepts a custom `vector<function<Guess(Predicate)>>`.
7. `Guess::AttemptToProve(flagRes, s, c, env)`:
   * `push()`
   * `g = op(v0', v1')`, where (v0', v1') = (value0, value1), or swapped if `flip_symbols`
   * `s.add((g && !flagRes) || (flagRes && !g))`
   * `proven = (s.check() == unsat)`
   * `pop()`

   This is an equivalence check.
8. The first proven guess gives `BranchResult{compared = (symbols.first, symbols.second)` (swapped if
   flipped)`, compare = guess.op}`.

`runOnIntrinsic` inserts `{call, result}` into the map when a proof succeeds.

`data/maybe_proof.smt` and `data/proof_result.smt` are dumps of such queries; no test uses them.
A large comment block in the .cpp shows an SMT-LIB example proving `sle` via add.

The golden case below is the function `@slice` from `tests/anvill_passes/data/BranchRecoveryAarch64.ll`. The pass
manager runs InstCombine first, as the unit test does, so the flag computations are in canonical form:

Real IR: `tests/golden/passes/BranchRecovery/aarch64.ll`, run as `anvill-opt --passes=instcombine<no-verify-fixpoint>,BranchRecovery`. Input:

```llvm
; AArch64 flag computations (NZCV) behind a compare hint.
source_filename = "lifted_code"

; Function Attrs: noduplicate noinline nounwind optnone readnone willreturn
declare zeroext i1 @__remill_flag_computation_sign(i1 zeroext, ...) local_unnamed_addr #0

; Function Attrs: noduplicate noinline nounwind optnone readnone willreturn
declare zeroext i1 @__remill_flag_computation_overflow(i1 zeroext, ...) local_unnamed_addr #0

; Function Attrs: nounwind readnone willreturn
declare zeroext i1 @__remill_compare_sge(i1 zeroext) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare ptr @__remill_function_return(ptr nonnull align 1, i64, ptr) local_unnamed_addr #2

; Function Attrs: noduplicate noinline nounwind optnone
declare ptr @__remill_missing_block(ptr nonnull align 1, i64, ptr) local_unnamed_addr #2

; Function Attrs: nounwind ssp
define ptr @slice(ptr %0, i32 %W10, i32 %W9, ptr nocapture %PC_output) local_unnamed_addr #3 {
  %.sroa.0.688.insert.ext = zext i32 %W9 to i64
  %2 = xor i32 %W10, -1
  %3 = zext i32 %2 to i64
  %4 = add nuw nsw i64 %3, 1
  %5 = add nuw nsw i64 %4, %.sroa.0.688.insert.ext
  %6 = sext i32 %W9 to i64
  %7 = sext i32 %2 to i64
  %8 = add nsw i64 %7, 1
  %9 = add nsw i64 %8, %6
  %10 = trunc i64 %5 to i32
  %11 = icmp slt i32 %10, 0
  %12 = tail call zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 zeroext %11, i32 %W9, i32 %W10, i32 %10) #4
  %13 = shl i64 %5, 32
  %14 = ashr exact i64 %13, 32
  %15 = icmp ne i64 %14, %9
  %16 = tail call zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 zeroext %15, i32 %W9, i32 %W10, i32 %10) #4
  %17 = xor i1 %12, %16
  %18 = xor i1 %17, true
  %19 = tail call zeroext i1 @__remill_compare_sge(i1 zeroext %18) #4
  br i1 %19, label %20, label %22

20:                                               ; preds = %1
  %21 = tail call ptr @__remill_function_return(ptr undef, i64 undef, ptr %0) #5, !noalias !0
  br label %sub_0.exit

22:                                               ; preds = %1
  %23 = tail call ptr @__remill_missing_block(ptr undef, i64 16, ptr %0) #5, !noalias !0
  br label %sub_0.exit

sub_0.exit:                                       ; preds = %22, %20
  %24 = phi ptr [ %21, %20 ], [ %23, %22 ]
  store i64 16, ptr %PC_output, align 8
  ret ptr %24
}

attributes #0 = { noduplicate noinline nounwind optnone readnone willreturn "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "no-builtins" "no-infs-fp-math"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { nounwind readnone willreturn "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "no-builtins" "no-infs-fp-math"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #2 = { noduplicate noinline nounwind optnone "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "no-builtins" "no-infs-fp-math"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #3 = { nounwind ssp }
attributes #4 = { nobuiltin nounwind readnone willreturn "no-builtins" }
attributes #5 = { nounwind }

!0 = !{!1}
!1 = distinct !{!1, !2, !"sub_0: %state"}
!2 = distinct !{!2, !"sub_0"}
```

Output (`aarch64.expected.ll`):

```llvm
declare zeroext i1 @__remill_flag_computation_sign(i1 zeroext, ...) local_unnamed_addr #0

declare zeroext i1 @__remill_flag_computation_overflow(i1 zeroext, ...) local_unnamed_addr #0

declare zeroext i1 @__remill_compare_sge(i1 zeroext) local_unnamed_addr #1

declare ptr @__remill_function_return(ptr nonnull align 1, i64, ptr) local_unnamed_addr #2

declare ptr @__remill_missing_block(ptr nonnull align 1, i64, ptr) local_unnamed_addr #2

define ptr @slice(ptr %0, i32 %W10, i32 %W9, ptr nocapture %PC_output) local_unnamed_addr #3 {
  %.sroa.0.688.insert.ext = zext i32 %W9 to i64
  %2 = xor i32 %W10, -1
  %3 = zext i32 %2 to i64
  %4 = add nuw nsw i64 %3, 1
  %5 = add nuw nsw i64 %4, %.sroa.0.688.insert.ext
  %6 = sext i32 %W9 to i64
  %7 = sext i32 %2 to i64
  %8 = add nsw i64 %7, 1
  %9 = add nsw i64 %8, %6
  %10 = trunc i64 %5 to i32
  %11 = icmp slt i32 %10, 0
  %12 = tail call zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 zeroext %11, i32 %W9, i32 %W10, i32 %10) #4
  %13 = shl i64 %5, 32
  %14 = ashr exact i64 %13, 32
  %15 = icmp ne i64 %14, %9
  %16 = tail call zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 zeroext %15, i32 %W9, i32 %W10, i32 %10) #4
  %17 = xor i1 %12, %16
  %18 = xor i1 %17, true
  %19 = icmp sge i32 %W9, %W10
  br i1 %19, label %20, label %22

20:                                               ; preds = %1
  %21 = tail call ptr @__remill_function_return(ptr undef, i64 undef, ptr %0) #5, !noalias !0
  br label %sub_0.exit

22:                                               ; preds = %1
  %23 = tail call ptr @__remill_missing_block(ptr undef, i64 16, ptr %0) #5, !noalias !0
  br label %sub_0.exit

sub_0.exit:                                       ; preds = %22, %20
  %24 = phi ptr [ %21, %20 ], [ %23, %22 ]
  store i64 16, ptr %PC_output, align 8
  ret ptr %24
}

!0 = !{!1}
!1 = distinct !{!1, !2, !"sub_0: %state"}
!2 = distinct !{!2, !"sub_0"}
```

More cases in `tests/golden/passes/BranchRecovery/`: `unrecoverable.ll`, `x86_sub_sle.ll`.

The test runs InstCombine first. Expected analysis result: `compare == ICMP_SGE`,
`compared == (%W9 /*arg 2*/, %W10 /*arg 1*/)`.

In `RecoverSubBranch.ll` (an x86 `sub RDX, RAX` with ZF | (SF ^ OF) feeding `__remill_compare_sle`), the
result is `ICMP_SLE (%RDX, %RAX)`. In `UnrecoverableBranch.ll` (an **add** with the same flags feeding
`compare_sle`), the result map is empty.

#### 13.2.4 `BranchRecovery` (transform). File `lib/Passes/BranchRecovery.cpp`

Kind: `BranchHintPass<BranchRecovery, PreservedAnalyses>` plus `PassInfoMixin`. `INIT_RES = all()`.
Added by `AddBranchRecovery(fpm)`.

`runOnIntrinsic(call)`:

* `res = am.getResult<BranchAnalysis>(F)`;
* if `call` is in the map, call `llvm::ReplaceInstWithInst(call, new ICmpInst(ba.compare, ba.compared.first, ba.compared.second))`
  and intersect `agg` with `none()`.

The x86 counterpart (`data/RecoverSubBranch.ll`, a `sub RDX, RAX` with ZF | (SF ^ OF) feeding `__remill_compare_sle`):

Real IR: `tests/golden/passes/BranchRecovery/x86_sub_sle.ll`, run as `anvill-opt --passes=instcombine<no-verify-fixpoint>,BranchRecovery`. Input:

```llvm
; A signed less-or-equal (x86 jle after sub): the __remill_compare_sle hint 
; over the ZF/SF/OF flag computations is proven (with Z3) equal to icmp sle 
; RDX, RAX and replaced by it.
source_filename = "lifted_code"

; Function Attrs: noduplicate noinline nounwind optnone readnone willreturn
declare zeroext i1 @__remill_flag_computation_zero(i1 zeroext, ...) local_unnamed_addr #0

; Function Attrs: noduplicate noinline nounwind optnone readnone willreturn
declare zeroext i1 @__remill_flag_computation_sign(i1 zeroext, ...) local_unnamed_addr #0

; Function Attrs: noduplicate noinline nounwind optnone readnone willreturn
declare zeroext i1 @__remill_flag_computation_overflow(i1 zeroext, ...) local_unnamed_addr #0

; Function Attrs: noduplicate noinline nounwind optnone readnone willreturn
declare zeroext i1 @__remill_compare_sle(i1 zeroext) local_unnamed_addr #0

; Function Attrs: noduplicate noinline nounwind optnone readnone willreturn
declare i64 @__remill_read_memory_64(ptr, i64) local_unnamed_addr #0

; Function Attrs: noduplicate noinline nounwind optnone
declare ptr @__remill_function_return(ptr nonnull align 1, i64, ptr) local_unnamed_addr #1

; Function Attrs: noduplicate noinline nounwind optnone
declare ptr @__remill_missing_block(ptr nonnull align 1, i64, ptr) local_unnamed_addr #1

; Function Attrs: nounwind ssp
define ptr @slice(ptr %0, i64 %RAX, i64 %RDX, ptr nocapture %RIP_output) local_unnamed_addr #2 {
  %2 = sub i64 %RDX, %RAX
  %3 = icmp eq i64 %2, 0
  %4 = tail call zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 zeroext %3, i64 %RDX, i64 %RAX, i64 %2) #3
  %5 = icmp slt i64 %2, 0
  %6 = tail call zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 zeroext %5, i64 %RDX, i64 %RAX, i64 %2) #3
  %7 = lshr i64 %RDX, 63
  %8 = lshr i64 %RAX, 63
  %9 = lshr i64 %2, 63
  %10 = xor i64 %7, %8
  %11 = xor i64 %9, %7
  %12 = add nuw nsw i64 %11, %10
  %13 = icmp eq i64 %12, 2
  %14 = tail call zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 zeroext %13, i64 %RDX, i64 %RAX, i64 %2) #3
  %15 = xor i1 %6, %14
  %16 = or i1 %4, %15
  %17 = tail call zeroext i1 @__remill_compare_sle(i1 zeroext %16) #4
  br i1 %17, label %18, label %21

18:                                               ; preds = %1
  %19 = tail call i64 @__remill_read_memory_64(ptr %0, i64 undef) #3
  %20 = tail call ptr @__remill_function_return(ptr undef, i64 %19, ptr %0) #5, !noalias !0
  br label %sub_0.exit

21:                                               ; preds = %1
  %22 = tail call ptr @__remill_missing_block(ptr undef, i64 8, ptr %0) #5, !noalias !0
  br label %sub_0.exit

sub_0.exit:                                       ; preds = %21, %18
  %.sroa.13.0 = phi i64 [ %19, %18 ], [ 8, %21 ]
  %23 = phi ptr [ %20, %18 ], [ %22, %21 ]
  store i64 %.sroa.13.0, ptr %RIP_output, align 8
  ret ptr %23
}

attributes #0 = { noduplicate noinline nounwind optnone readnone willreturn "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "no-builtins" "no-infs-fp-math"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { noduplicate noinline nounwind optnone "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "no-builtins" "no-infs-fp-math"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "tune-cpu"="generic" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #2 = { nounwind ssp }
attributes #3 = { nobuiltin nounwind readnone willreturn "no-builtins" }
attributes #4 = { alwaysinline nobuiltin nounwind readnone willreturn "no-builtins" }
attributes #5 = { nounwind }

!0 = !{!1}
!1 = distinct !{!1, !2, !"sub_0: %state"}
!2 = distinct !{!2, !"sub_0"}
```

Output (`x86_sub_sle.expected.ll`):

```llvm
declare zeroext i1 @__remill_flag_computation_zero(i1 zeroext, ...) local_unnamed_addr #0

declare zeroext i1 @__remill_flag_computation_sign(i1 zeroext, ...) local_unnamed_addr #0

declare zeroext i1 @__remill_flag_computation_overflow(i1 zeroext, ...) local_unnamed_addr #0

declare zeroext i1 @__remill_compare_sle(i1 zeroext) local_unnamed_addr #0

declare i64 @__remill_read_memory_64(ptr, i64) local_unnamed_addr #0

declare ptr @__remill_function_return(ptr nonnull align 1, i64, ptr) local_unnamed_addr #1

declare ptr @__remill_missing_block(ptr nonnull align 1, i64, ptr) local_unnamed_addr #1

define ptr @slice(ptr %0, i64 %RAX, i64 %RDX, ptr nocapture %RIP_output) local_unnamed_addr #2 {
  %2 = sub i64 %RDX, %RAX
  %3 = icmp eq i64 %RDX, %RAX
  %4 = tail call zeroext i1 (i1, ...) @__remill_flag_computation_zero(i1 zeroext %3, i64 %RDX, i64 %RAX, i64 %2) #3
  %5 = icmp slt i64 %2, 0
  %6 = tail call zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 zeroext %5, i64 %RDX, i64 %RAX, i64 %2) #3
  %7 = xor i64 %RDX, %RAX
  %8 = lshr i64 %7, 63
  %9 = xor i64 %2, %RDX
  %10 = lshr i64 %9, 63
  %11 = add nuw nsw i64 %10, %8
  %12 = icmp eq i64 %11, 2
  %13 = tail call zeroext i1 (i1, ...) @__remill_flag_computation_overflow(i1 zeroext %12, i64 %RDX, i64 %RAX, i64 %2) #3
  %14 = xor i1 %6, %13
  %15 = or i1 %4, %14
  %16 = icmp sle i64 %RDX, %RAX
  br i1 %16, label %17, label %20

17:                                               ; preds = %1
  %18 = tail call i64 @__remill_read_memory_64(ptr %0, i64 undef) #3
  %19 = tail call ptr @__remill_function_return(ptr undef, i64 %18, ptr %0) #4, !noalias !0
  br label %sub_0.exit

20:                                               ; preds = %1
  %21 = tail call ptr @__remill_missing_block(ptr undef, i64 8, ptr %0) #4, !noalias !0
  br label %sub_0.exit

sub_0.exit:                                       ; preds = %20, %17
  %.sroa.13.0 = phi i64 [ %18, %17 ], [ 8, %20 ]
  %22 = phi ptr [ %19, %17 ], [ %21, %20 ]
  store i64 %.sroa.13.0, ptr %RIP_output, align 8
  ret ptr %22
}

!0 = !{!1}
!1 = distinct !{!1, !2, !"sub_0: %state"}
!2 = distinct !{!2, !"sub_0"}
```

More cases in `tests/golden/passes/BranchRecovery/`: `aarch64.ll`, `unrecoverable.ll`.

The flag computations become dead. DCE or InstCombine removes them, and `RemoveUnusedBranchHints` handles the rest.

Interaction: the analysis is computed once per function per pass invocation and cached in the FAM.
Keys are `CallInst*`. Replaced calls are erased, but the result is only consulted for calls that still exist.

#### 13.2.5 `RemoveUnusedBranchHints`. File `lib/Passes/RemoveUnusedBranchHints.cpp`

Kind: `IntrinsicPass<RemoveUnusedBranchHints, PreservedAnalyses>` plus PassInfoMixin. `INIT_RES = all()`.
Added by **`AddRemoveFailedBranchHints(fpm)`** (note the name mismatch).

`isTargetInstrinsic`: the callee name starts with `"__remill_compare"` **or** `"__remill_flag_computation"`.

`runOnIntrinsic`: `call->replaceAllUsesWith(call->getArgOperand(0)); call->eraseFromParent();` and returns
`none()`. The `agg` argument is ignored, so the result is `none()` whenever any target existed.

Real IR: `tests/golden/passes/RemoveUnusedBranchHints/basic.ll`, run as `anvill-opt --passes=RemoveUnusedBranchHints`. Input:

```llvm
; Branch hints that BranchRecovery did not use are removed: calls to
; __remill_compare_* and __remill_flag_computation_* are replaced by their
; first argument (the computed i1). __remill_compare_exchange_* calls are
; atomic memory operations and must be kept (previously they were replaced by
; their memory pointer, deleting the atomic store).

declare i1 @__remill_compare_eq(i1)
declare i1 @__remill_compare_sle(i1)
declare i1 @__remill_flag_computation_zero(i1, ...)
declare ptr @__remill_compare_exchange_memory_32(ptr, i64, ptr, i32)

define i1 @f(ptr %mem, i32 %a, i32 %b, ptr %expected) {
  %eq = icmp eq i32 %a, %b
  %h1 = call i1 @__remill_compare_eq(i1 %eq)
  %sle = icmp sle i32 %a, %b
  %h2 = call i1 @__remill_compare_sle(i1 %sle)
  %z = icmp eq i32 %a, 0
  %f = call i1 (i1, ...) @__remill_flag_computation_zero(i1 %z, i32 %a, i32 0, i32 %a)
  %m = call ptr @__remill_compare_exchange_memory_32(ptr %mem, i64 16, ptr %expected, i32 %b)
  %x = and i1 %h1, %h2
  %y = and i1 %x, %f
  ret i1 %y
}
```

Output (`basic.expected.ll`):

```llvm
declare i1 @__remill_compare_eq(i1)

declare i1 @__remill_compare_sle(i1)

declare i1 @__remill_flag_computation_zero(i1, ...)

declare ptr @__remill_compare_exchange_memory_32(ptr, i64, ptr, i32)

define i1 @f(ptr %mem, i32 %a, i32 %b, ptr %expected) {
  %eq = icmp eq i32 %a, %b
  %sle = icmp sle i32 %a, %b
  %z = icmp eq i32 %a, 0
  %m = call ptr @__remill_compare_exchange_memory_32(ptr %mem, i64 16, ptr %expected, i32 %b)
  %x = and i1 %eq, %sle
  %y = and i1 %x, %z
  ret i1 %y
}
```

**Fixed.** Like BranchHintPass, this pass now excludes `__remill_compare_exchange*` (the `%m` call
above is kept). Previously a surviving Remill CAS intrinsic was replaced by its arg0 (the memory pointer, which the
call also returns), so the atomic operation was silently erased.

#### 13.2.6 `SimplifyStackArithFlags` (removed)

**Removed.** The files `lib/Passes/SimplifyStackArithFlags.{h,cpp}` were never built: they were not in the
`anvill_passes` list in `lib/CMakeLists.txt`, they included non-existent headers (`anvill/Analysis/Utils.h`,
`anvill/BranchAnalysis.h`), and `AddSimplifyStackArithFlags(fpm, bool)` was declared in Transforms.h but never
defined. The files and the declaration have been deleted. A reimplementation does not need this pass.

What it was meant to do: an IntrinsicPass over calls where `ParseFlagIntrinsic` succeeds. If `flag.over` is a
Constant and `IsRelatedToStackPointer`, the call is replaced by a constant from
`constant_flags = {OF:false, ZF:false, SIGN:true}`. Because `std::map::insert` does not overwrite, the
constructor's attempt to set `SIGN` to `stack_pointer_is_signed` has no effect. Flags missing from the map
(CARRY) are replaced by `undef`.


### 13.3 Jump-table recovery: JumpTableAnalysis + Slicer + SliceManager + SliceInterpreter + LowerSwitchIntrinsics


#### 13.3.1 `Slicer` (`lib/Passes/SlicerVisitor.{h,cpp}`, private, `llvm::InstVisitor<Slicer, llvm::Value*>`)

It produces a "linear" defining slice of a value and stops at the first non-linear value.

```cpp
Value *checkInstruction(Value *v)  // if Instruction -> visit(*v); else return v (constants/args are stop values)
SmallVector<Instruction*> getSlice()  // returns resultingSlice REVERSED (def order: operands first)
visitInstruction(I)   -> return &I                        // default: stop here (loads, calls, phis, ...)
visitCastInst(I)      -> push I; return checkInstruction(I.op0)
visitUnaryOperator(I) -> push I; return checkInstruction(I.op0)
visitBinaryOperator(I):
    if op1 is a PtrToIntInst whose operand is a Constant:   push I, push that ptrtoint; continue on op0
    else if op1 is not a Constant: return &I              // non-linear: this binop is the stop value
    else: push I; continue on op0
```

Only operand 1 may be constant; it relies on InstCombine canonicalization. The returned value is the
"stop value".

#### 13.3.2 `SliceManager` / `InterpreterBuilder` / `SliceInterpreter`

```cpp
class SliceID { uint64_t id; SliceID(); SliceID operator++(int); friend class SliceManager; };
class InterpreterBuilder {
  class Slice { Function *repr_function; SliceID id; Function *getRepr(); };
  InterpreterBuilder(unique_ptr<Module>);
  SliceInterpreter getInterp() const;       // new SliceInterpreter(*mod)
  Slice getSlice(SliceID) const;            // mod->getFunction("sliceFunc."+id)
};
class SliceManager {
  unique_ptr<Module> mod;                   // "slicemodule", same LLVMContext as the lifted code
  optional<reference_wrapper<const EntityLifter>> lifter;
  SliceID next_id;
 public:
  SliceManager(const EntityLifter&, LLVMContext&);  SliceManager(LLVMContext&);
  static std::string getFunctionName(SliceID) { return "sliceFunc." + to_string(id); }
  std::optional<SliceID> addSlice(ArrayRef<Instruction*> slice, Value *returnValue);
  static InterpreterBuilder IntoInterpreterBuilder(SliceManager&&);  // moves mod out
};
class SliceInterpreter {
  unique_ptr<ExecutionEngine> execEngine;
  explicit SliceInterpreter(const Module&);  // EngineBuilder(CloneModule(m)).setEngineKind(Interpreter).create()
  GenericValue executeSlice(SliceID, ArrayRef<GenericValue>);  // FindFunctionNamed("sliceFunc.N") + runFunction
};
```

The LLVM **interpreter** (`llvm/ExecutionEngine/Interpreter.h`) evaluates slices concretely.
`addSlice(slice, ret)`:

1. `id = next_id++`.
2. `defined = set(slice)`. `lifted_args` = every operand of a slice instruction that is not in `defined` and
   not a Constant, plus `ret` if `ret` is not in `defined`. The arguments are ordered by `SmallDenseSet`
   iteration order. For the jump table use there is exactly one argument, so order is irrelevant.
3. Create `Function "sliceFunc.<id>"` with type `ret->getType() (argTypes...)` and ExternalLinkage in the slice module.
4. Clone every slice instruction and build a `ValueToValueMapTy`. Map each lifted argument to its function `Argument`,
   then run `RemapInstruction` on each clone.
5. Create block `"slicebasicblock.<id>"`. Append the clones in slice order, then `ret mapper[ret]`.
6. "Remove anvill pc": if the *slice module* has a GV named `__anvill_pc`, replace its uses with null. In practice
   this is a no-op, because the clones still reference the original module's GVs.
7. `replaceAllGVConstantsWithInterpretableValue(clones)` walks the operands recursively through ConstantExprs. For each
   `GlobalVariable` operand:
   * with an initializer: ok;
   * without an initializer, used via a `PtrToIntOperator` (CE), and with a lifter where
     `lifter.AddressOfEntity(gv)` succeeds: schedule `ptrtoint-CE → ConstantInt(addr)`;
   * otherwise: fail. The function is erased and the call returns `nullopt`.

   **Fixed.** This step used to schedule pairs and run `ce->replaceAllUsesWith(ci); ce->destroyConstant()`.
   That was RAUW on a uniqued ConstantExpr, so it also rewrote uses in the *original* lifted module, and for
   the external `@__anvill_pc` the slice could never be made interpretable at all (jump tables were never
   lowered). Now `SliceManager::makeInterpretable` rebuilds each constant operand of the copied slice
   locally, recursively and with a cache: `ptrtoint @__anvill_pc` becomes 0, `ptrtoint` of a lifted entity
   becomes its address (via `EntityLifter::AddressOfEntity`), other initialized globals stay, and a
   global without an initializer makes the slice uninterpretable. Only the operands of the copied slice are
   replaced (`op.set(new_constant)`); nothing outside the slice changes.
8. `assert(remill::VerifyModule(mod))`, then return `id`.

#### 13.3.3 `JumpTableAnalysis` (function analysis). File `lib/Passes/JumpTableAnalysis.cpp`

Kind: `IndirectJumpPass<JumpTableAnalysis, DenseMap<CallInst*, JumpTableResult>>` plus
`AnalysisInfoMixin`. The constructor is `JumpTableAnalysis(const EntityLifter&)`. Registered in Optimize.cpp with
`fam.registerPass([&]{ return JumpTableAnalysis(lifter); })`. `name() = "JumpTableAnalysis"`.

```cpp
class PcRel  { SliceID slice;  APInt apply(SliceInterpreter&, APInt loadedVal) const;
               IntegerType *getExpectedType(const InterpreterBuilder&) const; /* slice fn param[0] type */ };
class IndexRel { SliceID slice; Value *index;  Value *getIndex() const;
                 APInt apply(SliceInterpreter&, APInt indexValue) const; };
struct Bound { APInt lower, upper; bool isSigned;
               bool lessThanOrEqual(APInt a, APInt b) const { return isSigned ? a.sle(b) : a.ule(b); } };
struct JumpTableResult { PcRel pcRel; IndexRel indexRel; Bound bounds; BasicBlock *defaultOut; InterpreterBuilder interp; };
```

Both `apply`s go through `RunSingleIntFunc`, which builds a `GenericValue` with `.IntVal = arg`, calls
`executeSlice`, and returns `.IntVal`.

The pattern conditions are documented at length in the file's header comment:

1. The PC depends on only one non-constant value, and that value is a load.
2. The load address depends on only one non-constant value, the index.
3. The idom of the block containing the jump ends in a conditional branch. One successor can reach the jump
   without passing back through the check; the other cannot.
4. The check depends only on the index.
5. Bounds are derived for the index (with Z3).

`runOnIndirectJump(call)` gets the `DominatorTreeAnalysis` result, creates
`JumpTableDiscovery(dt, lifter)`, and calls `RunPattern(call)`. On success it inserts the result.

`JumpTableDiscovery::RunPattern(pcCall)`:

* `SliceManager slices(lifter, ctx)` and `computed_pc = pcCall->getArgOperand(0)`.
* **RunIndexPattern(computed_pc)**, which needs `computed_pc` to be an Instruction:
  * `stop = Slicer().visit(pc)` and `pc_rel_slice = slice`.
  * Require `match(stop, m_Load(m_IntToPtr(m_Value(int_addr))))`. The inttoptr can be an instruction or a CE.
  * Set `loaded_expression = int_addr`. Run `index = Slicer().checkInstruction(int_addr)` and take
    `index_rel_slice` from that slicer. The slice runs from the **integer** address. The comment mentions
    %28, but the code uses %27.
  * Call `attemptForwardIndexPastCast()`, which repeats the following while it succeeds:
    * Applies only if `index` has exactly one use and that user is a `CastInst`.
    * `ReplaceIndexWith(cast)`: find the cast in `index_rel_slice`. If it is absent, stop. Otherwise the new
      slice is the part strictly after the cast, and `index = cast`.

    This handles patterns like `trunc(atoi())`, where the high bits are garbage.
* **RunBoundsCheckPattern(pcCall)**:
  * `idom = dt.getNode(callBB)->getIDom()`. If there is none, LOG(WARNING) and fail.
  * Call `TranslateTerminatorToBoundsCheck(idom->getTerminator(), callBB)`. It must be a `BranchInst`
    with 2 successors. Let `s0r = isPotentiallyReachable(succ0->getFirstNonPHI(), callBB->getFirstNonPHI(), exclusion={branch's block}, &dt)`
    and `s1r` the same for succ1.
    * If `s0r && !s1r`: `{branch, passes_check_on_true=true, fail=succ1}`.
    * If `!s0r && s1r`: `{branch, false, fail=succ0}`.
    * Otherwise fail.
  * `default_out = fail_direction`.
  * Run `JTAConstraintExtractor(index).ExpectInsnOrStopCondition(branch->getCondition())`. Its `attemptStop`
    returns `AtomVariable("index")` iff `value == index`. The rest goes through the generic extractor;
    constants become atoms.
  * If `!passes_check_on_true`: `cons = UnopExpr(LOGNOT, cons)`, so the constraint describes reaching the jump.
  * `bounds = ExprSolve().SolveForBounds(cons, index)`.
* Then `pc_id = slices.addSlice(pc_rel_slice, computed_pc)` and
  `idx_id = slices.addSlice(index_rel_slice, loaded_expression)`. Either failing means no result.
* `ib = SliceManager::IntoInterpreterBuilder(move(slices))`.
* Both slice functions must satisfy `IsValidRelType`: exactly one integer param and an integer return.
* Return `{PcRel(pc_id), IndexRel(idx_id, index), bounds, default_out, move(ib)}`.

`ExprSolve::SolveForBounds(exp, index)`:

* `OptimizeExpr(exp, index, isSigned)`, run once with `isSigned = false` and once with `true`:
  * Create a fresh `z3::context` and `index_bv = bv_const("index", width(index))`, and set `env{"index"}`.
  * `constraints = exp->BuildExpression`.
  * `GetBound(maximize)` and `GetBound(minimize)` each:
    * use a `z3::optimize` with param `priority = pareto`;
    * add the constraints;
    * set the objective to `index_bv`, or for signed to `index_bv + 2^(n-1)` (a bias into the unsigned domain);
    * `check() == sat` gives `lower(h).as_uint64()` as an APInt; for signed, subtract `2^(n-1)`.

    Either one failing means `nullopt`.
  * Verify with a plain solver: `constraints && (index >u ub || index <u lb)`, using `>s / <s` for
    signed. It must be `unsat`, otherwise `nullopt`.
  * Return `Bound{lb, ub, isSigned}`.
* If only one variant succeeds, return it. If both succeed, return the one with the smaller `upper - lower`
  (compared with `ule`). Ties go to unsigned.

The golden case below is a small x86-64 jump table: `cmp`/`ja` bounds check, then `movslq` of a
table-relative offset and an indirect jump. The `!anvill.memory` metadata gives `anvill-opt`'s memory provider
the table bytes.

Real IR: `tests/golden/passes/LowerSwitchIntrinsics/jump_table.ll`, run as `anvill-opt --passes=LowerSwitchIntrinsics`. Input:

```llvm
; A lifted jump table: a bounds check (x > 3 goes to %default), a load of a
; 32-bit table entry at 0x401038 + 4*x, the target 0x401038 + entry, and
; __anvill_complete_switch mapping the target to the case index of the
; lifted targets. JumpTableAnalysis (Z3) finds the index %x and its bounds
; [0, 3] from the dominating branch; LowerSwitchIntrinsics reads the table
; from memory and replaces the dispatch with `switch i32 %x` whose default
; is the bounds check's failure block. The default block's PHIs get an
; incoming value for the new edge (the value from the bounds-check block).

declare i64 @__anvill_complete_switch(i64, ...)

define i32 @sub_401000__AII_B_0(i32 %x) {
entry:
  %oob = icmp ugt i32 %x, 3
  br i1 %oob, label %default, label %dispatch

dispatch:
  %idx = zext i32 %x to i64
  %off = shl nuw nsw i64 %idx, 2
  %addr = add i64 %off, 4198456
  %p = inttoptr i64 %addr to ptr
  %entry_val = load i32, ptr %p, align 4
  %rel = sext i32 %entry_val to i64
  %target = add i64 %rel, 4198456
  %sel = call i64 (i64, ...) @__anvill_complete_switch(i64 %target, i64 4198423, i64 4198429, i64 4198435, i64 4198441), !pc !0
  switch i64 %sel, label %unreachable [ i64 0, label %case0
                                        i64 1, label %case1
                                        i64 2, label %case2
                                        i64 3, label %case3 ], !pc !0

unreachable:
  unreachable

case0:
  br label %exit
case1:
  br label %exit
case2:
  br label %exit
case3:
  br label %exit

default:
  %d = phi i32 [ -1, %entry ]
  br label %exit

exit:
  %r = phi i32 [ 100, %case0 ], [ 200, %case1 ], [ 300, %case2 ], [ 400, %case3 ], [ %d, %default ]
  ret i32 %r
}

; Table entries are relative to the table at 0x401038:
; 0x401017 0x40101d 0x401023 0x401029
!anvill.memory = !{!1}
!0 = !{i64 4198421}
!1 = !{i64 4198456, !"dfffffffe5ffffffebfffffff1ffffff", !"r"}
```

Output (`jump_table.expected.ll`):

```llvm
declare i64 @__anvill_complete_switch(i64, ...)

define i32 @sub_401000__AII_B_0(i32 %x) {
entry:
  %oob = icmp ugt i32 %x, 3
  br i1 %oob, label %default, label %dispatch

dispatch:                                         ; preds = %entry
  %idx = zext i32 %x to i64
  %off = shl nuw nsw i64 %idx, 2
  %addr = add i64 %off, 4198456
  %p = inttoptr i64 %addr to ptr
  %entry_val = load i32, ptr %p, align 4
  %rel = sext i32 %entry_val to i64
  %target = add i64 %rel, 4198456
  switch i32 %x, label %default [
    i32 0, label %case0
    i32 1, label %case1
    i32 2, label %case2
    i32 3, label %case3
  ]

unreachable:                                      ; No predecessors!
  unreachable

case0:                                            ; preds = %dispatch
  br label %exit

case1:                                            ; preds = %dispatch
  br label %exit

case2:                                            ; preds = %dispatch
  br label %exit

case3:                                            ; preds = %dispatch
  br label %exit

default:                                          ; preds = %dispatch, %entry
  %d = phi i32 [ -1, %entry ], [ -1, %dispatch ]
  br label %exit

exit:                                             ; preds = %default, %case3, %case2, %case1, %case0
  %r = phi i32 [ 100, %case0 ], [ 200, %case1 ], [ 300, %case2 ], [ 400, %case3 ], [ %d, %default ]
  ret i32 %r
}

!anvill.memory = !{!0}

!0 = !{i64 4198456, !"dfffffffe5ffffffebfffffff1ffffff", !"r"}
```

More cases in `tests/golden/passes/LowerSwitchIntrinsics/`: `missing_memory.ll`, `shared_target.ll`.

For the unit-test data `data/SwitchLoweringNeg.ll` (function `@_start`, aarch64-ish, 64-bit addresses; not
reproduced here), the analysis gives:

* pc slice `[%30, %31]`, stop value `%29` (a load) → `sliceFunc.0: i64 (i32)`;
* index slice from `%27`, stopping at `%19`; then forwarded past the trunc, so index = `%20` (i32)
  and the slice is `[%21, %22, %26, %27]` → `sliceFunc.1: i64 (i32)`;
* default out = `%33`; check = `not (ugt (add index 4) 7)`;
* bounds: unsigned `[0, 0xFFFFFFFF]` and signed `[-4, 3]`, so signed is chosen.

The test asserts `lower == -4`, `upper == 3`, `isSigned`, and `indexRel.apply(-3) == 4294983524`.

`SwitchLoweringLarge.ll` has 3 switches. The expected unsigned bounds are [3, 241], [6, 35] and [26, 46].

#### 13.3.4 `LowerSwitchIntrinsics` (transform). File `lib/Passes/LowerSwitchIntrinsics.cpp`

Kind: `IndirectJumpPass<LowerSwitchIntrinsics, PreservedAnalyses>` plus PassInfoMixin. The constructor is
`LowerSwitchIntrinsics(const MemoryProvider &)`. `BuildInitialResult() = all()`.
Added by `AddLowerSwitchIntrinsics(fpm, memprov)`.

`runOnIndirectJump(targetCall)` (each `__anvill_complete_switch` CallInst):

1. `jt = am.getResult<JumpTableAnalysis>(F)`. If the call has no entry, return unchanged.
2. `follower = targetCall->getParent()->getTerminator()`. It must be a `SwitchInst` with
   `getCondition() == targetCall`. Otherwise return unchanged.
3. `PcBinding::Build(call, follower)`:
   * asserts `call->arg_size() - 1 == follower->getNumCases()`;
   * for each case `(k → BB)`, maps `cast<ConstantInt>(call->getArgOperand(k + 1))->getValue()` to `BB`,
     in a `DenseMap<APInt, BasicBlock*>`.

   This relies on the lifter's convention that switch case `k` corresponds to vararg `k+1` of the complete-switch call.
4. `SwitchBuilder::CreateNativeSwitch(jt, binding)`:
   * If `lower > upper` (per the bounds' signedness), fail. The case count is `(upper - lower) + 1`,
     computed without wrapping; if `upper - lower >= 4096` (`kMaxSwitchCases`), fail.
   * `new_switch = SwitchInst::Create(jt.indexRel.getIndex(), jt.defaultOut, count)`.
     It is not inserted into a block.
   * For `count` iterations, `i` starting at `lower` and incremented each time:
     * `addr = indexRel.apply(interp, i)`;
     * `off = ReadIntFrom(pcRel.getExpectedType(interp), addr)`. This reads `bitwidth/8` bytes via
       `MemoryProvider::Query(addr + k)`, which returns `tuple<uint8_t, ByteAvailability, BytePermission>`.
       Any byte that is not `kAvailable` fails the switch. Then `llvm::LoadIntFromMemory` (host order),
       and `byteSwap()` if `dl.isLittleEndian() != sys::IsLittleEndianHost`;
     * `pc = pcRel.apply(interp, off)` and `bb = binding.Lookup(pc)`. A missing `bb` fails the switch;
     * if `bb != defaultOut`, `new_switch->addCase(ConstantInt(i), bb)`.
   * On any failure: `delete new_switch` and return nullopt.
5. On success, fix the PHIs of the successors before replacing the terminator. Count, per successor block,
   how many edges from this block the old and the new switch have:
   * a successor that gains edges (e.g. the new default, or a block that the table reaches more often)
     gets an incoming value for this block in each PHI: the existing value for this block, else the value
     from a predecessor that dominates this block, else `undef`;
   * a successor that loses edges gets `succ->removePredecessor(block)` once per lost edge (with the default
     `KeepOneInputPHIs = false`), while this block is still a predecessor.

   Then `ReplaceInstWithInst(follower, new_switch)`. If `targetCall` has no uses, erase it. Return `none()`.

Real IR: `tests/golden/passes/LowerSwitchIntrinsics/shared_target.ll`, run as `anvill-opt --passes=LowerSwitchIntrinsics`. Input:

```llvm
; Table entries 1 and 2 both point to 0x40101d (case1), so case2 is no
; longer a successor after lowering: its PHI drops the incoming value from
; the dispatch block (previously left behind, which made the IR invalid).

declare i64 @__anvill_complete_switch(i64, ...)

define i32 @sub_401000__AII_B_0(i32 %x) {
entry:
  %oob = icmp ugt i32 %x, 3
  br i1 %oob, label %default, label %dispatch

dispatch:
  %idx = zext i32 %x to i64
  %off = shl nuw nsw i64 %idx, 2
  %addr = add i64 %off, 4198456
  %p = inttoptr i64 %addr to ptr
  %entry_val = load i32, ptr %p, align 4
  %rel = sext i32 %entry_val to i64
  %target = add i64 %rel, 4198456
  %sel = call i64 (i64, ...) @__anvill_complete_switch(i64 %target, i64 4198423, i64 4198429, i64 4198435, i64 4198441), !pc !0
  switch i64 %sel, label %unreachable [ i64 0, label %case0
                                        i64 1, label %case1
                                        i64 2, label %case2
                                        i64 3, label %case3 ], !pc !0

unreachable:
  unreachable

case0:
  br label %exit
case1:
  br label %exit
case2:
  %only_from_dispatch = phi i32 [ 300, %dispatch ]
  br label %exit
case3:
  br label %exit

default:
  br label %exit

exit:
  %r = phi i32 [ 100, %case0 ], [ 200, %case1 ], [ %only_from_dispatch, %case2 ], [ 400, %case3 ], [ -1, %default ]
  ret i32 %r
}

!anvill.memory = !{!1}
!0 = !{i64 4198421}
!1 = !{i64 4198456, !"dfffffffe5ffffffe5fffffff1ffffff", !"r"}
```

Output (`shared_target.expected.ll`):

```llvm
declare i64 @__anvill_complete_switch(i64, ...)

define i32 @sub_401000__AII_B_0(i32 %x) {
entry:
  %oob = icmp ugt i32 %x, 3
  br i1 %oob, label %default, label %dispatch

dispatch:                                         ; preds = %entry
  %idx = zext i32 %x to i64
  %off = shl nuw nsw i64 %idx, 2
  %addr = add i64 %off, 4198456
  %p = inttoptr i64 %addr to ptr
  %entry_val = load i32, ptr %p, align 4
  %rel = sext i32 %entry_val to i64
  %target = add i64 %rel, 4198456
  switch i32 %x, label %default [
    i32 0, label %case0
    i32 1, label %case1
    i32 2, label %case1
    i32 3, label %case3
  ]

unreachable:                                      ; No predecessors!
  unreachable

case0:                                            ; preds = %dispatch
  br label %exit

case1:                                            ; preds = %dispatch, %dispatch
  br label %exit

case2:                                            ; No predecessors!
  br label %exit

case3:                                            ; preds = %dispatch
  br label %exit

default:                                          ; preds = %dispatch, %entry
  br label %exit

exit:                                             ; preds = %default, %case3, %case2, %case1, %case0
  %r = phi i32 [ 100, %case0 ], [ 200, %case1 ], [ poison, %case2 ], [ 400, %case3 ], [ -1, %default ]
  ret i32 %r
}

!anvill.memory = !{!0}

!0 = !{i64 4198456, !"dfffffffe5ffffffe5fffffff1ffffff", !"r"}
```

More cases in `tests/golden/passes/LowerSwitchIntrinsics/`: `jump_table.ll`, `missing_memory.ll`.

In the unit test `SwitchLoweringNeg` (mock memory at 4294983520 holding the i32 offsets
`[0x10, 0x3c, 0x3c, 0x1c, 0x28, 0x3c, 0x3c, 0x30]`), the result has 4 cases on indices {-4, -1, 0, 3}. Entries
that resolve to the default-out PC (0x3c → 4294983496 → arg 5 → case 4 → `%33`) are omitted.

`missing_memory.ll` has no `!anvill.memory`: a table read fails, so the switch is left as it was.

Notes:

* **Fixed.** The loop used to run `for (i = lower; lessThanOrEqual(i, upper); ++i)`, which never terminates
  when `upper` is the maximum value for its width and signedness (unless a memory read fails first). It is now
  a counted loop with the 4096-case cap above.
* **Fixed.** `ReplaceInstWithInst` does not update PHIs. Blocks that stopped being successors (like `case2`
  above) kept an incoming entry for the dispatch block, and blocks reached by new edges lacked one, which
  produced invalid IR (and an assertion in `removePredecessor` when it was called after the replacement).
* The index value must dominate the switch. It does, because it dominates the check.


### 13.4 Per-pass reference, in pipeline order


#### 13.4.1 `SinkSelectionsIntoBranchTargets`. File `lib/Passes/SinkSelectionsIntoBranchTargets.cpp`

Kind: function pass. It uses `DominatorTreeAnalysis`. It also exposes the public static helper
`static FunctionAnalysis AnalyzeFunction(const DominatorTreeAnalysis::Result&, Function&)` (used by tests):

```cpp
struct FunctionAnalysis {
  struct Replacement { llvm::Use *use_to_replace; llvm::Value *replace_with; };
  std::vector<Replacement> replacement_list;
  std::unordered_set<llvm::SelectInst*> disposable_instruction_list;
};
```

Algorithm:

1. Skip declarations.
2. For each `SelectInst S` in function order, look at every use of `S.getCondition()`. Each user that is a
   **conditional** `BranchInst` whose condition is that same value goes into `map[S]`.
3. For each `(S, branches)` and each branch `B`:
   * `taken = BasicBlockEdge(B.parent, B.succ0)` and `not_taken = (B.parent, B.succ1)`;
   * for every use `U` of `S`: if `dt.dominates(taken, U)`, replace it with `S.true`; else if
     `dt.dominates(not_taken, U)`, replace it with `S.false`;
   * record each replacement and add `S` to the disposable set.

   The Use-based `dominates` handles PHI uses correctly: they are attributed to the incoming edge.
4. Apply: for each replacement, `CopyMetadataTo(S, replace_with)` (only if `replace_with` is an instruction), then
   `use->set(replace_with)`. Erase each disposable select that has become `use_empty()`.

Example, from the code comment and the `SimpleCase` test data:

Real IR: `tests/golden/passes/SinkSelectionsIntoBranchTargets/basic.ll`, run as `anvill-opt --passes=SinkSelectionsIntoBranchTargets`. Input:

```llvm
; A select whose condition is also the condition of a branch: uses of the
; select dominated by the taken edge use the true value, uses dominated by the
; not-taken edge use the false value. The select is erased once unused.

define i32 @f(i1 %c, i32 %a, i32 %b) {
entry:
  %s = select i1 %c, i32 %a, i32 %b, !pc !0
  br i1 %c, label %taken, label %not_taken
taken:
  %t = add i32 %s, 1
  ret i32 %t
not_taken:
  %n = mul i32 %s, 2
  ret i32 %n
}

!0 = !{i64 4096}
```

Output (`basic.expected.ll`):

```llvm
define i32 @f(i1 %c, i32 %a, i32 %b) {
entry:
  br i1 %c, label %taken, label %not_taken

taken:                                            ; preds = %entry
  %t = add i32 %a, 1
  ret i32 %t

not_taken:                                        ; preds = %entry
  %n = mul i32 %b, 2
  ret i32 %n
}
```

More cases in `tests/golden/passes/SinkSelectionsIntoBranchTargets/`: `partial.ll`.

The unit test (`tests/anvill_passes`) expects `SimpleCase`: 2 replacements and 1 disposable. `MultipleSelects` (3 selects, same
condition): 6 and 3. `MultipleSelectUsages`: 6 and 1.

Interaction: this is scheduled twice (§13.6). It feeds RemoveTrivialPhisAndSelects and cross-reference folding at
branch targets.

#### 13.4.2 `RemoveUnusedFPClassificationCalls`. File `lib/Passes/RemoveUnusedFPClassificationCalls.cpp`

Kind: function pass. It erases every call whose direct callee is named exactly `fpclassify`, `__fpclassifyd`,
`__fpclassifyf` or `__fpclassifyld`, provided the call is `use_empty()`. The NOTE says it must run before
lifted functions are renamed. Real IR: `tests/golden/passes/RemoveUnusedFPClassificationCalls/basic.ll` (all four
names unused → erased; a used `__fpclassifyd` and an unused call to another function are kept).

#### 13.4.3 `RemoveDelaySlotIntrinsics`. File `lib/Passes/RemoveDelaySlotIntrinsics.cpp`

Kind: function pass. It looks up `__remill_delay_slot_begin` and `__remill_delay_slot_end` in the module, and
returns `all()` if neither exists. For each call to either:

```
mem = arg0; CopyMetadataTo(call, mem); call->RAUW(mem); erase.
```

Real IR: `tests/golden/passes/RemoveDelaySlotIntrinsics/basic.ll`, run as `anvill-opt --passes=RemoveDelaySlotIntrinsics`. Input:

```llvm
; Calls to __remill_delay_slot_begin/__remill_delay_slot_end are replaced by
; their memory-pointer argument; their metadata is copied onto the memory
; pointer when it is an instruction.

declare ptr @__remill_delay_slot_begin(ptr)
declare ptr @__remill_delay_slot_end(ptr)
declare ptr @__remill_write_memory_32(ptr, i64, i32)

define ptr @f(ptr %mem) {
  %m0 = call ptr @__remill_delay_slot_begin(ptr %mem), !pc !0
  %m1 = call ptr @__remill_write_memory_32(ptr %m0, i64 16, i32 1)
  %m2 = call ptr @__remill_delay_slot_end(ptr %m1), !pc !1
  ret ptr %m2
}

!0 = !{i64 4096}
!1 = !{i64 4100}
```

Output (`basic.expected.ll`):

```llvm
declare ptr @__remill_delay_slot_begin(ptr)

declare ptr @__remill_delay_slot_end(ptr)

declare ptr @__remill_write_memory_32(ptr, i64, i32)

define ptr @f(ptr %mem) {
  %m1 = call ptr @__remill_write_memory_32(ptr %mem, i64 16, i32 1), !pc !0
  ret ptr %m1
}

!0 = !{i64 4100}
```

More cases in `tests/golden/passes/RemoveDelaySlotIntrinsics/`: `absent.ll`.

#### 13.4.4 `RemoveErrorIntrinsics`. File `lib/Passes/RemoveErrorIntrinsics.cpp`

Kind: function pass. It returns `all()` if the module has no `__remill_error`. Steps:

1. For each call to `__remill_error` (skipping ones already removed):
   * Walk backward from the block **terminator** down to and including the call. For each instruction,
     RAUW non-void results with `undef`, then `dropAllReferences()`, `removeFromParent()`, and add it to the
     `to_remove` set. Note that the walk goes from the terminator to the call; instructions *before* the call
     are kept.
   * Append `unreachable` and copy the call's metadata onto it.
   * Mark the block as affected.
2. Repeat until there is no change:
   * Collect the PHIs (only the leading PHIs of each block) that have an incoming block in `affected_blocks`.
   * Rebuild each: drop incoming entries whose block is affected or whose value was removed.
     * 0 entries left: the PHI is replaced by `undef`, and its block is marked affected (it is unreachable now)
       and added to `unreachable_blocks` (which is otherwise unused).
     * 1 entry left: forward it.
     * Otherwise: build a new PHI (with metadata copied) before the old one.

     Then RAUW, drop and remove the old PHI.
3. `deleteValue()` everything in `to_remove`. The result is `none()` if anything was removed.

Real IR: `tests/golden/passes/RemoveErrorIntrinsics/basic.ll`, run as `anvill-opt --passes=RemoveErrorIntrinsics`. Input:

```llvm
; A call to __remill_error and everything after it in its block is replaced by
; `unreachable` (the call's metadata moves to the `unreachable`). Values
; defined in the removed tail are replaced by undef.

declare ptr @__remill_error(ptr, i64, ptr)

define i32 @f(ptr %state, ptr %mem, i1 %c) {
entry:
  br i1 %c, label %bad, label %good

bad:
  %x = add i32 1, 2
  %m = call ptr @__remill_error(ptr %state, i64 4096, ptr %mem), !pc !0
  %after = add i32 %x, 3
  ret i32 %after

good:
  ret i32 0
}

!0 = !{i64 4096}
```

Output (`basic.expected.ll`):

```llvm
declare ptr @__remill_error(ptr, i64, ptr)

define i32 @f(ptr %state, ptr %mem, i1 %c) {
entry:
  br i1 %c, label %bad, label %good

bad:                                              ; preds = %entry
  %x = add i32 1, 2
  unreachable, !pc !0

good:                                             ; preds = %entry
  ret i32 0
}

!0 = !{i64 4096}
```

More cases in `tests/golden/passes/RemoveErrorIntrinsics/`: `absent.ll`, `phi_incoming.ll`.

Note: the successor's PHIs are fixed (see `phi_incoming.ll`), but the CFG edge removal does not update any
analyses beyond returning `none()`.

#### 13.4.5 `LowerRemillMemoryAccessIntrinsics`. File `lib/Passes/LowerRemillMemoryAccessIntrinsics.cpp`

Kind: function pass. Targets are calls whose direct callee name starts with `__remill_read_memory_` or
`__remill_write_memory_`. Atomics (`__remill_compare_exchange_*`, `__remill_fetch_and_*`) are **not**
handled; there is a TODO.

`adjust_val_type(t)`: if the callee name ends with `f80`, use `x86_fp80`. If it ends with `f128`, use `fp128`.
Otherwise keep `t`. Remill models f80/f128 memory values as `double` in registers.

Dispatch:

| Callee and shape | Rewrite |
|---|---|
| `read`, 2 args: `val = __remill_read_memory_NN(mem, addr)` | `vt = adjust(call type)`. `p = inttoptr addr to ptr` (AS 0). `v = load vt, p`. If vt is fp80/fp128, `v = fptrunc v to call type`. RAUW call with v. |
| `read`, 3 args: `mem' = __remill_read_memory_fNN(mem, addr, T *out)` | `vt = adjust(type of arg2)`. In practice the name ends with f80/f128, so vt is an fp type. `p = inttoptr addr`. `v = load vt, p`. `q = bitcast arg2 to ptr`. `store v, q`. RAUW call with `mem`. |
| `read`, other arg counts | LOG(ERROR), no change. |
| `write` with pointer arg2 (by reference): `mem' = __remill_write_memory_fNN(mem, addr, T *val)` | `vt = adjust(ptr type)`. `v = load vt, arg2`. FPExt if fp80/fp128; when the source is already that type this is a no-op. `store v, inttoptr addr`. RAUW call with `mem`. |
| `write` by value: `mem' = __remill_write_memory_NN(mem, addr, val)` | `vt = adjust(type of val)`. `p = inttoptr addr`. If vt is fp80/fp128, `val = fpext val to vt`. `store val, p`. RAUW call with `mem`. |

Every created instruction gets `CopyMetadataTo(call, ...)`. Loads and stores use default alignment and are
non-volatile.

Gotcha: in the by-reference write path, if the name did not end with f80/f128, `vt` would be a pointer type,
so the code would load a pointer. That does not happen with real Remill names.

Real IR: `tests/golden/passes/LowerRemillMemoryAccessIntrinsics/basic.ll`, run as `anvill-opt --passes=LowerRemillMemoryAccessIntrinsics`. Input:

```llvm
; Remill memory intrinsics become plain loads and stores through
; `inttoptr` of the address; the memory pointer result of a write is
; replaced by its memory-pointer argument. Metadata of the call is copied to
; every new instruction.

declare i8 @__remill_read_memory_8(ptr, i64)
declare i16 @__remill_read_memory_16(ptr, i64)
declare i32 @__remill_read_memory_32(ptr, i64)
declare i64 @__remill_read_memory_64(ptr, i64)
declare float @__remill_read_memory_f32(ptr, i64)
declare double @__remill_read_memory_f64(ptr, i64)
declare ptr @__remill_write_memory_8(ptr, i64, i8)
declare ptr @__remill_write_memory_16(ptr, i64, i16)
declare ptr @__remill_write_memory_32(ptr, i64, i32)
declare ptr @__remill_write_memory_64(ptr, i64, i64)
declare ptr @__remill_write_memory_f32(ptr, i64, float)
declare ptr @__remill_write_memory_f64(ptr, i64, double)

define ptr @f(ptr %mem, i64 %addr) {
  %b = call i8 @__remill_read_memory_8(ptr %mem, i64 %addr), !pc !0
  %h = call i16 @__remill_read_memory_16(ptr %mem, i64 %addr)
  %w = call i32 @__remill_read_memory_32(ptr %mem, i64 %addr)
  %q = call i64 @__remill_read_memory_64(ptr %mem, i64 %addr)
  %fs = call float @__remill_read_memory_f32(ptr %mem, i64 %addr)
  %fd = call double @__remill_read_memory_f64(ptr %mem, i64 %addr)
  %m1 = call ptr @__remill_write_memory_8(ptr %mem, i64 16, i8 %b), !pc !1
  %m2 = call ptr @__remill_write_memory_16(ptr %m1, i64 32, i16 %h)
  %m3 = call ptr @__remill_write_memory_32(ptr %m2, i64 48, i32 %w)
  %m4 = call ptr @__remill_write_memory_64(ptr %m3, i64 64, i64 %q)
  %m5 = call ptr @__remill_write_memory_f32(ptr %m4, i64 80, float %fs)
  %m6 = call ptr @__remill_write_memory_f64(ptr %m5, i64 96, double %fd)
  ret ptr %m6
}

!0 = !{i64 4096}
!1 = !{i64 4100}
```

Output (`basic.expected.ll`):

```llvm
declare i8 @__remill_read_memory_8(ptr, i64)

declare i16 @__remill_read_memory_16(ptr, i64)

declare i32 @__remill_read_memory_32(ptr, i64)

declare i64 @__remill_read_memory_64(ptr, i64)

declare float @__remill_read_memory_f32(ptr, i64)

declare double @__remill_read_memory_f64(ptr, i64)

declare ptr @__remill_write_memory_8(ptr, i64, i8)

declare ptr @__remill_write_memory_16(ptr, i64, i16)

declare ptr @__remill_write_memory_32(ptr, i64, i32)

declare ptr @__remill_write_memory_64(ptr, i64, i64)

declare ptr @__remill_write_memory_f32(ptr, i64, float)

declare ptr @__remill_write_memory_f64(ptr, i64, double)

define ptr @f(ptr %mem, i64 %addr) {
  %1 = inttoptr i64 %addr to ptr, !pc !0
  %2 = load i8, ptr %1, align 1, !pc !0
  %3 = inttoptr i64 %addr to ptr
  %4 = load i16, ptr %3, align 2
  %5 = inttoptr i64 %addr to ptr
  %6 = load i32, ptr %5, align 4
  %7 = inttoptr i64 %addr to ptr
  %8 = load i64, ptr %7, align 8
  %9 = inttoptr i64 %addr to ptr
  %10 = load float, ptr %9, align 4
  %11 = inttoptr i64 %addr to ptr
  %12 = load double, ptr %11, align 8
  store i8 %2, ptr inttoptr (i64 16 to ptr), align 1, !pc !1
  store i16 %4, ptr inttoptr (i64 32 to ptr), align 2
  store i32 %6, ptr inttoptr (i64 48 to ptr), align 4
  store i64 %8, ptr inttoptr (i64 64 to ptr), align 8
  store float %10, ptr inttoptr (i64 80 to ptr), align 4
  store double %12, ptr inttoptr (i64 96 to ptr), align 8
  ret ptr %mem
}

!0 = !{i64 4096}
!1 = !{i64 4100}
```

More cases in `tests/golden/passes/LowerRemillMemoryAccessIntrinsics/`: `extended_float.ll`.

Interaction: this exposes `inttoptr(CE over __anvill_sp)` loads and stores, which is exactly what
RemoveStackPointerCExprs and RecoverBasicStackFrame consume (see `RecoverStackFrameInformation.ll`).
Because the memory-pointer chain is replaced by the incoming mem, ordering becomes ordinary LLVM memory semantics.

#### 13.4.6 `RemoveCompilerBarriers`. File `lib/Passes/RemoveCompilerBarriers.cpp`

Kind: function pass. A "barrier" is a `CallBase` whose called operand is an `InlineAsm` with
`hasSideEffects()`, a void return type, and an **empty** asm string. Per block, scanning forward with state
`(prev_is_compiler_barrier, prev_barrier)`:

* Barrier call: if `prev_is_compiler_barrier` is already set, schedule this barrier for removal. Otherwise
  remember it as `prev_barrier`. Then set `prev = true`.
* Other inline asm: reset both.
* Direct call to a function with **external linkage**: if `prev` is set and `prev_barrier != null`,
  schedule `prev_barrier` for removal. Then set `prev = true` and `prev_barrier = null`.
* Direct call to a non-external function: `prev = false`, `prev_barrier = null`.
* Indirect call, or any non-call instruction: reset both.

So a barrier is removed when it is adjacent to another barrier, or immediately followed by an external call.
A barrier that follows an external call is also removed, because `prev` stays true. Scheduled calls are erased if
`use_empty()`.

Real IR: `tests/golden/passes/RemoveCompilerBarriers/basic.ll`, run as `anvill-opt --passes=RemoveCompilerBarriers`. Input:

```llvm
; Compiler barriers are empty side-effecting inline asm calls. Runs of
; consecutive barriers collapse to the first one, and a barrier directly
; followed by a call to an external function is removed (the call already is
; a barrier). A barrier followed by a non-call instruction is kept.

declare void @external()
define internal void @internal() {
  ret void
}

define void @runs() {
  call void asm sideeffect "", ""()
  call void asm sideeffect "", ""()
  call void asm sideeffect "", ""()
  ret void
}

define void @before_external_call() {
  call void asm sideeffect "", ""()
  call void @external()
  ret void
}

define void @before_internal_call() {
  call void asm sideeffect "", ""()
  call void @internal()
  ret void
}

define i32 @separated(i32 %x) {
  call void asm sideeffect "", ""()
  %y = add i32 %x, 1
  call void asm sideeffect "", ""()
  ret i32 %y
}

define void @not_barriers() {
  call void asm sideeffect "nop", ""()
  call void asm "", ""()
  call void asm sideeffect "nop", ""()
  ret void
}
```

Output (`basic.expected.ll`):

```llvm
declare void @external()

define internal void @internal() {
  ret void
}

define void @runs() {
  call void asm sideeffect "", ""()
  ret void
}

define void @before_external_call() {
  call void @external()
  ret void
}

define void @before_internal_call() {
  call void asm sideeffect "", ""()
  call void @internal()
  ret void
}

define i32 @separated(i32 %x) {
  call void asm sideeffect "", ""()
  %y = add i32 %x, 1
  call void asm sideeffect "", ""()
  ret i32 %y
}

define void @not_barriers() {
  call void asm sideeffect "nop", ""()
  call void asm "", ""()
  call void asm sideeffect "nop", ""()
  ret void
}
```

#### 13.4.7 `LowerTypeHintIntrinsics`. File `lib/Passes/LowerTypeHintIntrinsics.cpp`

Kind: function pass. For every CallInst whose direct callee name starts with `__anvill_type_hint`:

```
v = arg0->stripPointerCasts(); cast = IRBuilder(call).CreateBitOrPointerCast(v, call->getType());
CopyMetadataTo(call, cast); call->RAUW(cast);
```

Real IR: `tests/golden/passes/LowerTypeHintIntrinsics/basic.ll`, run as `anvill-opt --passes=LowerTypeHintIntrinsics`. Input:

```llvm
; Calls to __anvill_type_hint* functions are replaced by a bit/pointer cast of
; their (pointer-cast-stripped) argument to the call's type.

declare ptr @__anvill_type_hint_Sb(i64)
declare i64 @__anvill_type_hint_L(ptr)
declare ptr @__anvill_type_hint_S(ptr)

define i32 @f(i64 %addr, ptr %p) {
  %hinted = call ptr @__anvill_type_hint_Sb(i64 %addr), !pc !0
  %v = load i32, ptr %hinted
  %as_int = call i64 @__anvill_type_hint_L(ptr %p)
  %same = call ptr @__anvill_type_hint_S(ptr %p)
  store i64 %as_int, ptr %same
  %unused = call ptr @__anvill_type_hint_Sb(i64 %addr)
  ret i32 %v
}

!0 = !{i64 4096}
```

Output (`basic.expected.ll`):

```llvm
declare ptr @__anvill_type_hint_Sb(i64)

declare i64 @__anvill_type_hint_L(ptr)

declare ptr @__anvill_type_hint_S(ptr)

define i32 @f(i64 %addr, ptr %p) {
  %1 = inttoptr i64 %addr to ptr, !pc !0
  %v = load i32, ptr %1, align 4
  %2 = ptrtoint ptr %p to i64
  store i64 %2, ptr %p, align 8
  %3 = inttoptr i64 %addr to ptr
  ret i32 %v
}

!0 = !{i64 4096}
```

#### 13.4.8 `ConvertMasksToCasts`. File `lib/Passes/ConvertMasksToCasts.cpp`

Kind: function pass. Collection uses PatternMatch in one forward scan. The first matching pattern wins per instruction:

1. `and V, C` or `and C, V` with `C` a ConstantInt. The mask must be exactly the **low half all-ones**:
   `activeBits(C) * 2 == width` and `countTrailingZeros(~C) == activeBits`. This means 0xFF on i16, 0xFFFF on i32,
   0xFFFFFFFF on i64, and so on. Record `(inst, operand index of V, iN/2)`. The header comment shows
   `and i64 %v, 0xff → trunc i8`, but the code only accepts the half-width mask.
2. `ashr (shl V, S), S` (equal shift amounts; the check compares `ConstantInt*` identity, which is value
   equality for the same type) with `0 < S < N`, where N is the width. This sign-extends the low `N - S` bits of
   `V`, so record `(inst, i(N - S))`. **Fixed:** this used to record `i(N/2)` whatever `S` was (only for
   N ∈ {8, …, 128}), so `ashr(shl x, 48), 48` on i64 became `sext(trunc to i32)` instead of
   `sext(trunc to i16)`. See `sign_extend.ll`.
3. `add (shl V, N), C`, where N ∈ {8, 16, 32, 64, 128} and `C` has at least N trailing zeros. Record
   `(inst, C >> N)`.

Rewrites, applied in this order: trunc_zexts, then shl_adds, then shl_ashrs. Each re-matches to tolerate RAUW
from earlier rewrites.

* mask: `t = trunc inst.op[k] to iN/2` and `z = zext t to iN`. Copy metadata to both. RAUW and erase.
* shl_add: re-match `add(Instruction shl, ConstantInt)` and `shl(V, ConstantInt n)`. Build
  `a = add V, (C >> N)` and `s = shl a, n`. RAUW the add with `s`, and schedule the old `shl` for erasure.
  (**Fixed:** this rewrite now sets `changed`; it used to return `all()` when it was the only one that fired.)
* shl_ashr: re-match. `t = trunc V to i(N - S)` and `s = sext t to iN`. RAUW and erase. Schedule the old `shl`.
* Scheduled `shl`s with no remaining uses are erased.

Real IR: `tests/golden/passes/ConvertMasksToCasts/masks.ll`, run as `anvill-opt --passes=ConvertMasksToCasts`. Input:

```llvm
; (and V, M) where M keeps exactly the low half of the bits becomes
; (zext (trunc V)). Other masks are unchanged.

define i32 @low_half_i32(i32 %v) {
  %r = and i32 %v, 65535, !pc !0
  ret i32 %r
}

define i64 @low_half_i64_commuted(i64 %v) {
  %r = and i64 4294967295, %v
  ret i64 %r
}

define i64 @not_half(i64 %v) {
  %r = and i64 %v, 65535
  ret i64 %r
}

define i32 @not_low_bits(i32 %v) {
  %r = and i32 %v, 65520
  ret i32 %r
}

!0 = !{i64 4096}
```

Output (`masks.expected.ll`):

```llvm
define i32 @low_half_i32(i32 %v) {
  %1 = trunc i32 %v to i16, !pc !0
  %2 = zext i16 %1 to i32, !pc !0
  ret i32 %2
}

define i64 @low_half_i64_commuted(i64 %v) {
  %1 = trunc i64 %v to i32
  %2 = zext i32 %1 to i64
  ret i64 %2
}

define i64 @not_half(i64 %v) {
  %r = and i64 %v, 65535
  ret i64 %r
}

define i32 @not_low_bits(i32 %v) {
  %r = and i32 %v, 65520
  ret i32 %r
}

!0 = !{i64 4096}
```

More cases in `tests/golden/passes/ConvertMasksToCasts/`: `shifted_add.ll`, `sign_extend.ll`.

Purpose: fix truncated PC and SP displacements before stack analysis (see Optimize.cpp's comment).

#### 13.4.9 `RemoveTrivialPhisAndSelects`. File `lib/Passes/RemoveTrivialPhisAndSelects.cpp`

Kind: function pass. Worklist algorithm:

1. The initial worklist is every instruction.
2. For each PHI: if all incoming values are pointer-equal to incoming value 0, schedule every use of the PHI to be
   set to that value, and add the PHI to `remove`. For each select: if `true == false`, do the same.
3. Apply the replacements with `use->set(val)`, pushing each user Instruction into the next worklist.
   This handles cascades.
4. Loop until the worklist is empty.
5. Erase the `remove` instructions that are `use_empty()`.

Real IR: `tests/golden/passes/RemoveTrivialPhisAndSelects/basic.ll`, run as `anvill-opt --passes=RemoveTrivialPhisAndSelects`. Input:

```llvm
; PHIs whose incoming values are all the same value, and selects whose two
; values are the same, are replaced by that value. Replacements are repeated
; on the users (a worklist), so chains collapse.

define i32 @f(i1 %c, i32 %x, i32 %y) {
entry:
  br i1 %c, label %a, label %b
a:
  br label %join
b:
  br label %join
join:
  %p = phi i32 [ %x, %a ], [ %x, %b ]
  %s = select i1 %c, i32 %p, i32 %x
  %q = phi i32 [ %y, %a ], [ %x, %b ]
  %t = select i1 %c, i32 %q, i32 %q
  %r = add i32 %s, %t
  ret i32 %r
}

define i32 @loop(i32 %x, i32 %n) {
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %next, %loop ]
  %self = phi i32 [ %x, %entry ], [ %self, %loop ]
  %next = add i32 %i, 1
  %done = icmp eq i32 %next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret i32 %self
}
```

Output (`basic.expected.ll`):

```llvm
define i32 @f(i1 %c, i32 %x, i32 %y) {
entry:
  br i1 %c, label %a, label %b

a:                                                ; preds = %entry
  br label %join

b:                                                ; preds = %entry
  br label %join

join:                                             ; preds = %b, %a
  %q = phi i32 [ %y, %a ], [ %x, %b ]
  %r = add i32 %x, %q
  ret i32 %r
}

define i32 @loop(i32 %x, i32 %n) {
entry:
  br label %loop

loop:                                             ; preds = %loop, %entry
  %i = phi i32 [ 0, %entry ], [ %next, %loop ]
  %self = phi i32 [ %x, %entry ], [ %self, %loop ]
  %next = add i32 %i, 1
  %done = icmp eq i32 %next, %n
  br i1 %done, label %exit, label %loop

exit:                                             ; preds = %loop
  ret i32 %self
}
```

There is no special handling for self-referential PHIs (`phi [%x, ...], [%p, loop]`): those are not trivial,
because the values differ.

#### 13.4.10 `RemoveStackPointerCExprs`. File `lib/Passes/RemoveStackPointerCExprs.cpp`

Kind: function pass. The constructor is `RemoveStackPointerCExprs(const StackFrameRecoveryOptions&)`.

(A stale duplicate header, `lib/Passes/RemoveStackPointerCExprs.h`, with a default constructor and no options,
has been removed; the real one is in `include/anvill/Passes/`.)

Private class `ConcreteStackPointerResolver : NullCrossReferenceResolver`. Its `AddressOfEntity(c)` returns a fake
concrete SP if `IsStackPointer(module, c)`, chosen by pointer size:

| Pointer size | Positive (default) | `stack_pointer_is_negative` |
|---|---|---|
| 64 | `0x00007ffc07000000` | `0xffff7ffc07000000` |
| 32 | `0x00860000` | `0xff860000` |
| 16 | `0x0800` | `0xf800` |

Other sizes LOG(ERROR) and return nullopt.

Algorithm:

1. Skip declarations.
2. `folder = CrossReferenceFolder(ConcreteStackPointerResolver, dl)` and `StackPointerResolver sp(module)`.
3. The worklist is all instructions. `ce_insert_loc` starts as the entry block's first insertion point.
4. Pop an instruction and look at each operand that is a `ConstantExpr` with `sp.IsRelatedToStackPointer(ce)`:
   * Compute `xr = folder.TryResolveReferenceWithCaching(ce)`.
   * If `xr.is_valid`, `xr.size < pointer bits`, and the CE type is an integer: replace the operand with
     `ConstantInt(ity, xr.Displacement(dl), signed)`. This folds narrow SP-derived values, such as comparisons
     and truncations, into constants computed using the fake concrete SP.
     **Fixed:** `Displacement()` used to handle only sizes 8/16/32/64 and returned 0 otherwise, so every `i1`
     (icmp) result folded to `false`. It now truncates to any width, so a comparison folds to its real value
     under the fake concrete SP (`x86_flags.ll`: `sp - 12 < 0` is `false` with the positive fake SP).
   * If `xr.is_valid` but the value is full width or not an integer: leave it. RecoverBasicStackFrame handles these.
   * If it is not valid: `newi = ce->getAsInstruction()`, inserted **before** `ce_insert_loc`. Then
     `ce_insert_loc = newi`, so successive unfolded CEs stack upward and nested operands come first.
     `use.set(newi)` and push `newi` onto the worklist (its operands may be CEs too).
5. The result is `none()` if anything changed.

The golden case is the header comment's example (test `RegressionRecoverStack.ll`): x86 flag computations over
the stack pointer.

Real IR: `tests/golden/passes/RemoveStackPointerCExprs/x86_flags.ll`, run as `anvill-opt --passes=RemoveStackPointerCExprs`. Input:

```llvm
; 32-bit x86 (concrete ESP 0x00860000): a sign-flag computation on ESP - 12.
; The comparison is an instruction (icmp constant expressions no longer
; exist in LLVM 19), and the pointer-sized operands are left alone.

@__anvill_sp = external global i8

declare zeroext i1 @__remill_flag_computation_sign(i1 zeroext, ...)

define i1 @slice() {
  %c = icmp slt i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12), 0
  %1 = call zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 zeroext %c, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12))
  %low = trunc i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12) to i8
  %lowi = trunc i8 trunc (i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12) to i8) to i1
  %r = and i1 %1, %lowi
  ret i1 %r
}
```

Output (`x86_flags.expected.ll`):

```llvm
@__anvill_sp = external global i8

declare zeroext i1 @__remill_flag_computation_sign(i1 zeroext, ...)

define i1 @slice() {
  %c = icmp slt i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12), 0
  %1 = call zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 zeroext %c, i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12))
  %low = trunc i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12) to i8
  %lowi = trunc i8 -12 to i1
  %r = and i1 %1, %lowi
  ret i1 %r
}
```

More cases in `tests/golden/passes/RemoveStackPointerCExprs/`: `narrow.ll`, `unresolvable.ll`.

`narrow.ll` covers `trunc` and other narrow values; `unresolvable.ll` covers the unfold path (a CE the folder
cannot resolve becomes instructions in the entry block).

#### 13.4.11 `RecoverBasicStackFrame`. File `lib/Passes/RecoverBasicStackFrame.cpp`

Kind: function pass. The constructor is `RecoverBasicStackFrame(const StackFrameRecoveryOptions&)`.

Data structures:

```cpp
struct StackPointerUse { llvm::Use *use; uint64_t type_size; int64_t stack_offset; };
struct StackFrameAnalysis { std::vector<StackPointerUse> instruction_uses;
                            int64_t lowest_offset, highest_offset; size_t size; };
static constexpr uint64_t kMax16 = UINT16_MAX, kMax32 = UINT32_MAX;
```

Algorithm:

1. **EnumerateStackPointerUsages(F)**: every operand Use (in every instruction) whose value is a `Constant` and
   `StackPointerResolver::IsRelatedToStackPointer`. A store with SP-derived CEs on both operands yields 2 uses.
2. **AnalyzeStackFrame(F, opts)** uses a `CrossReferenceFolder(NullCrossReferenceResolver, dl)`. For each use:
   * `xr = folder.TryResolveReferenceWithCaching(val)`. Skip it unless `is_valid && references_stack_pointer`.
   * `off = xr.Displacement(dl)`. Then truncate-and-sign-extend: to int16 if `max_stack_frame_size <= 0xFFFF`
     (the default 8192 hits this case), or to int32 if `<= 0xFFFFFFFF`.
   * `type_size = allocSize(val type)`. If the user is a store and the use is the pointer operand
     (operandNo 1), use `allocSize(stored type)`. If the user is a load, use `allocSize(load type)`.
   * Update `highest = max(highest, off + type_size)` and `lowest = min(lowest, off)`, and record
     `{use, type_size, off}`.
   * Finally `size = highest - lowest`.
3. If there are no uses, return `all()`.
4. **UpdateFunction**:
   * `word = opts.stack_frame_word_size`, or the pointer size if it is 0. `word_ty = iN(word * 8)`.
     `padding = lower_pad + higher_pad`.
   * **GenerateStackFrameType**:
     * The name is `F.getName() + ".frame_type"`. If a StructType with that name already exists, return it.
     * `frame_size = max(1, min(max_stack_frame_size, padding + size))`.
     * `slot = lcm(ptr_size, word)` and `num_slots = ceil(frame_size / slot)`.
     * The type is `StructType::create({ [num_slots * slot / word x word_ty] }, name)`, a non-packed struct with
       one array of words. **Fixed:** the element count used to be `num_slots`, which is only right when
       `word == ptr_size`; with `--stack_word_size=1` a 40-byte frame was `[5 x i8]` and every access past byte
       5 was out of bounds (`padding_and_word_size.ll`).
   * **Fixed (alignment).** Before the type is built, `lowest` is rounded down and `highest` rounded up to a
     multiple of `word`, relative to the SP on entry. The frame then starts and ends on word boundaries of the
     real stack, so a pointer-sized value such as the return address occupies exactly one frame word.
     Previously the frame started at the exact lowest accessed offset (e.g. -12 on a 64-bit target), frame
     words straddled the return-address slot, and SplitStackFrameAtReturnAddress produced out-of-bounds
     accesses.
   * `base_stack_offset = lowest - lower_pad`. This is the same for both growth directions.
   * In the entry block, at the first insertion point: `frame = alloca <frame_type>`. All the instructions created
     below are inserted right after it, in the entry block, with the same IRBuilder.
   * If `stack_offset_metadata_name` is set, attach metadata `"__anvill_stack_zero"` = `!{iPTR -base_stack_offset}`:
     the offset, from the start of the frame alloca, of the SP on entry (where `__anvill_stack_0` lands).
     **Fixed:** it used to be `highest + higher_pad - word` (grows down) or `lowest - lower_pad + word` (grows
     up), which mixed stack-relative and frame-relative offsets and made every `stack_offset` that
     SplitStackFrameAtReturnAddress derives from it off by a few bytes.
   * Initialization, according to `stack_frame_struct_init_procedure`. Let `n = min(padding + size, alloc size of
     the frame type)`; the minimum matters when the frame was clamped to `max_stack_frame_size`.
     * `kZeroes` / `kUndef`: for `i` in `0, word, 2·word, …` up to `< n`: `store iW 0` (or `undef`) to
       `gep frame, 0, 0, i/word`. **Fixed:** this used to be one `store zeroinitializer/undef, frame` of the
       whole frame; after SplitStackFrameAtReturnAddress splits the frame, that store was redirected into the
       first piece and wrote past its end. And the per-word loop must stop at the allocated size
       (`clamped_frame.ll`).
     * `kNone`: nothing.
     * `kSymbolic`: for `i` in `0, word, 2·word, …` up to `< n`:
       * `gep frame, 0, 0, i/word`;
       * load the GV named `__anvill_stack_<sfx><abs(off)>` (type `word_ty`) and store it there;
       * `off` starts at `base_stack_offset` and increases by `word`.

       The suffix is `minus_` / `plus_`, chosen by sign; it is swapped when `!stack_grows_down`. `off == 0`
       gives `__anvill_stack_0`. Missing GVs are created as `ExternalLinkage`, non-constant, with no
       initializer. An existing GV must have value type `word_ty` (`CHECK_EQ`).
   * For each recorded use:
     * `z = (off - lowest) + lower_pad`;
     * `ptr = gep frame_type, frame, 0, 0, z / word`. Metadata is copied from the old value, which only has
       effect if it is an instruction.
     * `missing = z % word`. If it is nonzero, pick the element type: 1/3/5/7 → i8 (scale 1); 2/6 → i16
       (scale 2); 4 → i32 (scale 4). Then `ptr = bitorptrcast ptr to ptr` and `ptr = gep el, ptr, missing/scale`.
     * `ptr = CreateBitOrPointerCast(ptr, original operand type)`. If the original was an integer, such as
       `ptrtoint(sp) + k`, this creates a `ptrtoint`.
     * `use->set(ptr)`. The code uses `use->set`, not RAUW, because the constant may be shared with other functions.
5. `assert(EnumerateStackPointerUsages(F).empty())` and return `none()`.

The golden cases use one small x86-64 function: the return address at [sp+0], a local at [sp-12] and a stack
argument at [sp+8]. After word alignment the frame spans [-16, +16) (4 words).

Real IR: `tests/golden/passes/RecoverBasicStackFrame/init_none.ll`, run as `anvill-opt --passes=RecoverBasicStackFrame --stack_init=none`. Input:

```llvm
; Every use of a constant expression derived from `__anvill_sp` becomes a
; GEP into a new frame alloca (`%<function>.frame_type` = { [N x iW] },
; W = word size). The frame spans the lowest to the highest accessed offset
; (here -12 .. +12, rounded up to words). With --stack_offset_metadata, the
; alloca carries `__anvill_stack_zero` = the frame index of offset 0.
; Initialization (--stack_init=none):
;   symbolic: each word is loaded from @__anvill_stack_{minus,plus}_<off>
;   zeroes / undef: one store of zeroinitializer / undef
;   none: nothing

@__anvill_sp = external global i8
@__anvill_ra = external global i8

; RA at [sp+0], a local at [sp-12], a stack argument at [sp+8].
define i32 @sub_401000__AI_B_0(i32 %x) {
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr inttoptr (i64 ptrtoint (ptr @__anvill_sp to i64) to ptr), !pc !0
  store i32 %x, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -12) to ptr)
  %arg = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 8) to ptr)
  %l = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -12) to ptr)
  %addr = add i64 ptrtoint (ptr @__anvill_sp to i64), -4
  %r = add i32 %l, %arg
  ret i32 %r
}

!0 = !{i64 4198400}
```

Output (`init_none.expected.ll`):

```llvm
%sub_401000__AI_B_0.frame_type = type { [4 x i64] }

@__anvill_sp = external global i8
@__anvill_ra = external global i8

define i32 @sub_401000__AI_B_0(i32 %x) {
  %1 = alloca %sub_401000__AI_B_0.frame_type, align 8, !__anvill_stack_zero !0
  %2 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 2
  %3 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  %4 = getelementptr i32, ptr %3, i32 1
  %5 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 3
  %6 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  %7 = getelementptr i32, ptr %6, i32 1
  %8 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 2
  %9 = ptrtoint ptr %8 to i64
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr %2, align 8, !pc !1
  store i32 %x, ptr %4, align 4
  %arg = load i32, ptr %5, align 4
  %l = load i32, ptr %7, align 4
  %addr = add i64 %9, -4
  %r = add i32 %l, %arg
  ret i32 %r
}

!0 = !{i64 16}
!1 = !{i64 4198400}
```

More cases in `tests/golden/passes/RecoverBasicStackFrame/`: `clamped_frame.ll`, `init_symbolic.ll`, `init_undef.ll`, `init_zeroes.ll`, `no_stack_uses.ll`, `padding_and_word_size.ll`.

For the unit-test data `data/RecoverStackFrameInformation.ll` (i386; 12 instructions with 14 SP uses), the
analysis gives lowest = -28, highest = 16 (12 + sizeof(i32)), size = 44. With word 4 the frame is 48 bytes
(12 words), or 176 with 128 bytes of padding.

Real IR: `tests/golden/passes/RecoverBasicStackFrame/init_zeroes.ll`, run as `anvill-opt --passes=RecoverBasicStackFrame --stack_init=zeroes`. Input:

```llvm
; Every use of a constant expression derived from `__anvill_sp` becomes a
; GEP into a new frame alloca (`%<function>.frame_type` = { [N x iW] },
; W = word size). The frame spans the lowest to the highest accessed offset
; (here -12 .. +12, rounded up to words). With --stack_offset_metadata, the
; alloca carries `__anvill_stack_zero` = the frame index of offset 0.
; Initialization (--stack_init=zeroes):
;   symbolic: each word is loaded from @__anvill_stack_{minus,plus}_<off>
;   zeroes / undef: one store of zeroinitializer / undef
;   none: nothing

@__anvill_sp = external global i8
@__anvill_ra = external global i8

; RA at [sp+0], a local at [sp-12], a stack argument at [sp+8].
define i32 @sub_401000__AI_B_0(i32 %x) {
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr inttoptr (i64 ptrtoint (ptr @__anvill_sp to i64) to ptr), !pc !0
  store i32 %x, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -12) to ptr)
  %arg = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 8) to ptr)
  %l = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -12) to ptr)
  %addr = add i64 ptrtoint (ptr @__anvill_sp to i64), -4
  %r = add i32 %l, %arg
  ret i32 %r
}

!0 = !{i64 4198400}
```

Output (`init_zeroes.expected.ll`):

```llvm
%sub_401000__AI_B_0.frame_type = type { [4 x i64] }

@__anvill_sp = external global i8
@__anvill_ra = external global i8

define i32 @sub_401000__AI_B_0(i32 %x) {
  %1 = alloca %sub_401000__AI_B_0.frame_type, align 8, !__anvill_stack_zero !0
  %2 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  store i64 0, ptr %2, align 8
  %3 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 1
  store i64 0, ptr %3, align 8
  %4 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 2
  store i64 0, ptr %4, align 8
  %5 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 3
  store i64 0, ptr %5, align 8
  %6 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 2
  %7 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  %8 = getelementptr i32, ptr %7, i32 1
  %9 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 3
  %10 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 0
  %11 = getelementptr i32, ptr %10, i32 1
  %12 = getelementptr %sub_401000__AI_B_0.frame_type, ptr %1, i32 0, i32 0, i32 2
  %13 = ptrtoint ptr %12 to i64
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr %6, align 8, !pc !1
  store i32 %x, ptr %8, align 4
  %arg = load i32, ptr %9, align 4
  %l = load i32, ptr %11, align 4
  %addr = add i64 %13, -4
  %r = add i32 %l, %arg
  ret i32 %r
}

!0 = !{i64 16}
!1 = !{i64 4198400}
```

More cases in `tests/golden/passes/RecoverBasicStackFrame/`: `clamped_frame.ll`, `init_none.ll`, `init_symbolic.ll`, `init_undef.ll`, `no_stack_uses.ll`, `padding_and_word_size.ll`.

The test also checks that the alloca is the first instruction and that there are 14 GEPs in the entry block.

`data/SplitStackFrameAtReturnAddress.ll` shows the kSymbolic output on the same function. It has 44
`__anvill_stack_minus_28 … plus_15` i8 globals (`word = 1`), so the frame is `<{ [44 x i8] }>`. The golden
`init_symbolic.ll` shows the kSymbolic output for the x86-64 function.

Interaction: SROA runs afterward. Then SplitStackFrameAtReturnAddress looks the alloca up by the frame type name.

#### 13.4.12 `SplitStackFrameAtReturnAddress`. File `lib/Passes/SplitStackFrameAtReturnAddress.cpp`

Kind: function pass. The constructor is `SplitStackFrameAtReturnAddress(const StackFrameRecoveryOptions&)`.

Algorithm:

1. **FindStackFrameAlloca**: the first `alloca` in the entry block whose allocated type is a *named*
   (non-literal) StructType whose name starts with `F.getName()` and ends with `".frame_type"`. If there is none,
   return `all()`.
2. **FindFixedOffsetUses(alloca)** returns a `vector<FixedOffsetUse{Use*, APInt offset}>`. It walks a worklist of
   `(inst, offset)` starting at `(alloca, 0)`, with APInt width = index size of AS 0, signed. For every use of `inst`:
   * Record `(use, offset)`. **Every** use is recorded, including uses whose users are casts or GEPs.
   * If the user is a `BitCast`, `PtrToInt` or `IntToPtr`, push `(user, offset)`.
   * If the user is a `GetElementPtr` and `accumulateConstantOffset` succeeds, push `(gep, offset + gepoff)`.

   **Fixed:** the `seen` set (of Uses) was never inserted into, so a user that consumes the same value twice was
   walked twice and its uses recorded twice. Each Use is now visited once.
3. If there are no uses, return `all()`.
4. If `stack_offset_metadata_name` is set, run **AnnotateStackUses**:
   * Read the `__anvill_stack_zero` metadata on the alloca. If it is not `!{ConstantInt Z}`, return.
   * For each recorded use whose **used value** (`use->get()`) is an instruction that lacks the offset metadata, set
     `<stack_offset_metadata_name> = !{iN disp}`, with `disp = Z - off` if the stack grows down, otherwise
     `off - Z`.
   * Then remove `__anvill_stack_zero` from the alloca.
5. **SplitStackFrameAround(alloca, uses, opts)**:
   * **FindReturnAddressStore**: among the uses whose user is a `StoreInst` with `IsReturnAddress(value operand)`,
     pick the first. If several exist, pick the **lowest offset** when the stack grows down, or the highest when it
     grows up, with LOG(ERROR) when offsets differ.
   * If found: `ra_off = offset` and `ra_end = ra_off + ptr_size`, with LOG(INFO) if `ra_off != 0`.
     If not found: `ra_off = 0` and `ra_end = 1`.
   * Partition the uses:
     * `above`: `off < ra_off`, keeping `off`;
     * `at`: `ra_off <= off < ra_end`, using `off - ra_off`;
     * `below`: the rest, using `off - ra_end`.
   * `IRBuilder ir(frame_alloca)`. **All** new instructions are inserted immediately before the old alloca, in the
     entry block.
   * `make_subframe(uses, down_name, up_name, num_slots)`:
     * `sub = alloca iPTR, iPTR num_slots`, i.e. an **array alloca of pointer-sized ints** named `down_name` if the
       stack grows down, else `up_name`;
     * reset the per-subframe maps: `pointers = {ptr_size: sub}` and `computed_offsets = {0: sub}`;
     * `CopyMetadataTo(old alloca, sub)`;
     * call `SubstituteUse` for each use.

     The subframes are created as:
     * `above` (frame offsets below the RA, i.e. lower addresses) → `("locals", "parameters", ceil(ra_off / ptr))`;
     * `below` (frame offsets past the RA, i.e. higher addresses) → `("parameters", "locals",
       ceil((allocSize(frame) - ra_end) / ptr))`;
     * `at` → `("return_address_loc", "return_address_loc", 1)`.

     So when the stack grows down, the part below the return address is `%locals` and the part above it (the
     caller's outgoing arguments) is `%parameters`. **Fixed:** the two names used to be swapped.
   * Then for each `to_replace (old → new)`: `old->dropAllReferences(); old->RAUW(new); old->eraseFromParent()`.
     The original frame alloca is left in place for DCE or SROA.
6. Return `none()`.

`DemandedOffset(ir, old_inst, pointers, computed_offsets, off, ptr_size)`:

* Memoized by `computed_offsets[off]`.
* `missing = off % ptr_size` picks the element type:
  * 1/3/5/7: i8, scale 1;
  * 2/6: i16, scale 2;
  * 4: i32, scale 4;
  * 0: `iPTR`, scale `ptr_size`.
* For a nonzero `missing`, the base is `pointers[scale]`, created as a `BitOrPointerCast(pointers[ptr_size], ptr)`
  if needed.
* Result: `gep el, base, i32 (off / scale)`, with `CopyMetadataTo(old_inst, gep)`.

`SubstituteUse(ir, use, off, ...)`: `use_inst = use->get()` (must be an Instruction), `user_inst = user`,
`ret = DemandedOffset(off)`. By the user's opcode:

* `PtrToInt`: schedule `to_replace[user] = ptrtoint ret to user type`.
* `Add, Sub, Mul, SDiv, UDiv, ZExt, SExt, Trunc, Or, Xor, And`: `use->set(ptrtoint ret to use_inst type)`.
* `IntToPtr`, `BitCast`: schedule `to_replace[user] = bitorptrcast ret to user type`.
* `Load`: `use->set(bitorptrcast ret to ptr(AS))`.
* `Store`: if this is the value operand (operand 0), use `ptrtoint` or `bitorptrcast` to the value type.
  Otherwise, `bitorptrcast` to `ptr(AS)`.
* `GetElementPtr`:
  * all indices constant: schedule `to_replace[user] = bitorptrcast ret to gep type`. This is safe because the
    GEP's own uses were also recorded, at their accumulated offsets, and are rewritten separately.
  * otherwise, split the indices into a constant prefix and the rest:
    * if the prefix is empty: `use->set(bitorptrcast ret)`;
    * else compute `sub_off` for the prefix and `sub_ret = DemandedOffset(off + sub_off)`, then build, **at the
      old GEP's position**, `new_gep = gep indexedType(prefix), bitcast(sub_ret), [0, rest...]` and schedule
      `to_replace[user] = new_gep`. The leading zero index is needed because `indexedType(prefix)` is the type
      that the variable indices index into. **Fixed:** the base used to be `ret` (losing the prefix offset), the
      leading zero was missing, and the GEP was inserted before the alloca in the entry block, where the variable
      indices may not be defined yet. See `variable_index.ll`.
* `ICmp`, `PHI`, `Select` and the default case: `ptrtoint` if `use_inst` has an integer type, otherwise
  `bitorptrcast` to `use_inst`'s type; then `use->set(...)`.

The golden case runs RecoverBasicStackFrame first (as the pipeline does) on the x86-64 function from §13.4.11,
so the frame has a return address store at frame offset 16:

Real IR: `tests/golden/passes/SplitStackFrameAtReturnAddress/after_recovery.ll`, run as `anvill-opt --passes=RecoverBasicStackFrame,SplitStackFrameAtReturnAddress --stack_init=zeroes`. Input:

```llvm
; After RecoverBasicStackFrame, the frame is split at the slot that holds the
; return address into three allocas: the callee's locals (lower addresses),
; `return_address_loc`, and the caller's stack `parameters` (higher
; addresses). Uses are rewritten to point into the matching part and get
; `stack_offset` metadata (the displacement from the stack pointer at
; function entry). Previously the locals/parameters names were swapped.

@__anvill_sp = external global i8
@__anvill_ra = external global i8

; RA at [sp+0], a local at [sp-12], a stack argument at [sp+8].
define i32 @sub_401000__AI_B_0(i32 %x) {
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr inttoptr (i64 ptrtoint (ptr @__anvill_sp to i64) to ptr), !pc !0
  store i32 %x, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -12) to ptr)
  %arg = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 8) to ptr)
  %l = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -12) to ptr)
  %addr = add i64 ptrtoint (ptr @__anvill_sp to i64), -4
  %r = add i32 %l, %arg
  ret i32 %r
}

!0 = !{i64 4198400}
```

Output (`after_recovery.expected.ll`):

```llvm
%sub_401000__AI_B_0.frame_type = type { [4 x i64] }

@__anvill_sp = external global i8
@__anvill_ra = external global i8

define i32 @sub_401000__AI_B_0(i32 %x) {
  %locals = alloca i64, i64 2, align 8, !stack_offset !0
  %1 = getelementptr i64, ptr %locals, i32 1, !stack_offset !1
  %2 = getelementptr i32, ptr %locals, i32 1, !stack_offset !0
  %parameters = alloca i64, i64 1, align 8, !stack_offset !2
  %return_address_loc = alloca i64, i64 1, align 8, !stack_offset !3
  %3 = ptrtoint ptr %return_address_loc to i64, !stack_offset !3
  %4 = ptrtoint ptr %return_address_loc to i64, !stack_offset !3
  %5 = alloca %sub_401000__AI_B_0.frame_type, align 8, !stack_offset !4
  store i64 0, ptr %locals, align 8
  store i64 0, ptr %1, align 8
  store i64 0, ptr %return_address_loc, align 8
  store i64 0, ptr %parameters, align 8
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr %return_address_loc, align 8, !pc !5
  store i32 %x, ptr %2, align 4
  %arg = load i32, ptr %parameters, align 4
  %l = load i32, ptr %2, align 4
  %addr = add i64 %4, -4
  %r = add i32 %l, %arg
  ret i32 %r
}

!0 = !{i64 12}
!1 = !{i64 8}
!2 = !{i64 -8}
!3 = !{i64 0}
!4 = !{i64 16}
!5 = !{i64 4198400}
```

More cases in `tests/golden/passes/SplitStackFrameAtReturnAddress/`: `full_cleanup.ll`, `variable_index.ll`.

The `stack_offset` values follow this convention for a downward-growing stack: a positive value is the depth
below the SP on entry. Here the local at `[sp-12]` is `!{i64 12}`, the stack argument at `[sp+8]` is
`!{i64 -8}`, the return address at `[sp+0]` is `!{i64 0}`, and the (now dead) whole-frame alloca, which starts
at `sp-16`, is `!{i64 16}`.

#### 13.4.13 `CombineAdjacentShifts`. File `lib/Passes/CombineAdjacentShifts.cpp`

Kind: function pass. Matcher:

```
m_AShr(m_Shl(m_Value(V), m_ConstantInt(shift_left /* = shl amount A */)), m_ConstantInt(shift_right /* = ashr amount B */))
```

The condition is that V is an integer type of width W, `A * 2 == W` and `A > B`: the shl moves the low half
of V into the high half, and the ashr then shifts it back by less than it was shifted.

Rewrite, inserted before the ashr:

```
t = trunc V to iA          ; the low half
s = sext t to iW
r = shl s, (A - B)
```

Metadata: V → t, ashr → s, the shl → r. Then RAUW the ashr with r and erase it. The old shl is left for DCE.
This is the identity `(ashr (shl V, W/2), B) == (shl (sext (trunc V to iW/2)), W/2 - B)` for `B < W/2`.

**Fixed.** The captures used to be swapped (`m_ConstantInt(shift_right)` bound the shl amount), so the rewrite
fired when the *ashr* amount was the half width and larger than the shl amount, which is not
semantics-preserving: `ashr(shl x, 8), 32` on i64 became `sext(trunc x to i32) << 24`. `basic.ll` checks both the
rewritten pattern and that the swapped shape is now left alone.

Real IR: `tests/golden/passes/CombineAdjacentShifts/basic.ll`, run as `anvill-opt --passes=CombineAdjacentShifts`. Input:

```llvm
; (ashr (shl V, A), B) with A = N/2 and B < A sign-extends the low half of V
; and shifts it left by A - B:
;   trunc V to iA ; sext to iN ; shl by (A - B)
; Other shift amounts are left alone. Previously the two shift amounts were
; swapped while matching, so the pass rewrote (ashr (shl V, 8), 16) -- a
; right shift -- into a left shift, and skipped the valid case.

; A = 16 = N/2, B = 8: combined.
define i32 @half_then_less(i32 %v) {
  %s = shl i32 %v, 16
  %r = ashr i32 %s, 8, !pc !0
  ret i32 %r
}

; A = 8, B = 16 (B > A): not a left shift, unchanged.
define i32 @more_than_shl(i32 %v) {
  %s = shl i32 %v, 8
  %r = ashr i32 %s, 16
  ret i32 %r
}

; A = 24 is not half the width: unchanged.
define i32 @not_half(i32 %v) {
  %s = shl i32 %v, 24
  %r = ashr i32 %s, 8
  ret i32 %r
}

; A = B: a plain sign extension, left to ConvertMasksToCasts.
define i32 @equal(i32 %v) {
  %s = shl i32 %v, 16
  %r = ashr i32 %s, 16
  ret i32 %r
}

; 64-bit: A = 32, B = 4.
define i64 @wide(i64 %v) {
  %s = shl i64 %v, 32
  %r = ashr i64 %s, 4
  ret i64 %r
}

!0 = !{i64 4096}
```

Output (`basic.expected.ll`):

```llvm
define i32 @half_then_less(i32 %v) {
  %s = shl i32 %v, 16
  %1 = trunc i32 %v to i16
  %2 = sext i16 %1 to i32, !pc !0
  %3 = shl i32 %2, 8
  ret i32 %3
}

define i32 @more_than_shl(i32 %v) {
  %s = shl i32 %v, 8
  %r = ashr i32 %s, 16
  ret i32 %r
}

define i32 @not_half(i32 %v) {
  %s = shl i32 %v, 24
  %r = ashr i32 %s, 8
  ret i32 %r
}

define i32 @equal(i32 %v) {
  %s = shl i32 %v, 16
  %r = ashr i32 %s, 16
  ret i32 %r
}

define i64 @wide(i64 %v) {
  %s = shl i64 %v, 32
  %1 = trunc i64 %v to i32
  %2 = sext i32 %1 to i64
  %3 = shl i64 %2, 28
  ret i64 %3
}

!0 = !{i64 4096}
```

#### 13.4.14 `ConvertAddressesToEntityUses`. File `lib/Passes/ConvertAddressesToEntityUses.cpp`

Kind: function pass. The constructor is
`ConvertAddressesToEntityUses(const CrossReferenceResolver&, std::optional<unsigned> pc_metadata_id = nullopt)`.
It also has a public `EntityUsages EnumeratePossibleEntityUsages(Function&)`, where
`struct EntityUse { llvm::Use *use; ResolvedCrossReference xref; }` and `using EntityUsages = std::vector<EntityUse>`.

Enumeration:

* Build a `CrossReferenceFolder(xref_resolver, dl)`.
* For every operand Use of every instruction (skipping null operands), compute
  `ra = folder.TryResolveReferenceWithClearedCache(val)`.
* Keep the use if `ra.is_valid && !ra.references_return_address && !ra.references_stack_pointer` and
  `(references_entity || references_global_value || references_program_counter)`.

The folder resolves instructions as well as constants. The resolver is normally an
`EntityCrossReferenceResolver(lifter)`, which maps lifted functions and variables to addresses and back.

Rewrite, for each kept use:

* `entity = xref_resolver.EntityAtAddress(ra.u.address, /*value_type*/nullptr, /*AS*/0)`. If it is null, skip.
* `entity = entity->stripPointerCasts()`.
* If `pc_metadata_id` is set and the entity is a `GlobalObject`, call
  `obj->setMetadata(pc_id, !{iPTR address})`. The metadata goes **on the global** (function or variable),
  not on the instruction.
* `CHECK` that the entity has a pointer type.
* Choose the insertion point: for a PHI user, the incoming block's terminator; otherwise the user instruction.
  Then `use->set(AdaptToType(ir, entity, original value type))`. For an integer operand this gives
  `ptrtoint @entity to iN`. For a pointer operand it is a pointer cast, or the entity directly.
* If the old value was an instruction, add it to `to_erase`. Afterwards, erase those that are `use_empty()`.
* The pass returns `none()` whenever the enumeration was non-empty, even if no replacement was made (kept).

Real IR: `tests/golden/passes/ConvertAddressesToEntityUses/basic.ll`, run as `anvill-opt --passes=ConvertAddressesToEntityUses`. Input:

```llvm
; Values that resolve to the address of a lifted entity (here, globals named
; sub_/var_/data_<hex>, see anvill-opt) through @__anvill_pc-relative
; arithmetic are replaced by references to the entity; the entity gets the
; `pc` metadata of its address. Addresses that are not entities stay as
; they are; stack-pointer and return-address values are never converted.
; NOTE: anvill-opt's resolver only knows exact entity addresses, so the
; interior address below is not converted here; the lifter's resolver maps
; interior addresses to GEPs into the containing variable.

@__anvill_pc = external global i8
@__anvill_sp = external global i8
@var_404000_I = global i32 7
@var_404010_L = global i64 0
declare i32 @sub_402000__AII_B_0(i32)

define i32 @f(i32 %x) {
  ; Load of a global through its PC-relative address.
  %v = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4210688) to ptr)
  ; Interior address of a global (offset 4 into var_404010_L).
  %p = inttoptr i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4210708) to ptr
  store i32 %x, ptr %p
  ; A function address used as an integer.
  %fp = add i64 ptrtoint (ptr @__anvill_pc to i64), 4202496
  %fptr = inttoptr i64 %fp to ptr
  %r = call i32 %fptr(i32 %v)
  ; Not an entity, and a stack address.
  %unknown = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4227072) to ptr)
  %stack = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8) to ptr)
  %s0 = add i32 %r, %unknown
  %s = add i32 %s0, %stack
  ret i32 %s
}
```

Output (`basic.expected.ll`):

```llvm
@__anvill_pc = external global i8
@__anvill_sp = external global i8
@var_404000_I = global i32 7, !pc !0
@var_404010_L = global i64 0

declare !pc !1 i32 @sub_402000__AII_B_0(i32)

define i32 @f(i32 %x) {
  %v = load i32, ptr @var_404000_I, align 4
  %p = inttoptr i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4210708) to ptr
  store i32 %x, ptr %p, align 4
  %r = call i32 @sub_402000__AII_B_0(i32 %v)
  %unknown = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 4227072) to ptr), align 4
  %stack = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__anvill_sp to i64), i64 -8) to ptr), align 4
  %s0 = add i32 %r, %unknown
  %s = add i32 %s0, %stack
  ret i32 %s
}

!0 = !{i64 4210688}
!1 = !{i64 4202496}
```

More cases in `tests/golden/passes/ConvertAddressesToEntityUses/`: `edge_cases.ll`.

In `basic.ll`, `anvill-opt`'s resolver knows only exact entity addresses (globals named `sub_/var_/data_<hex>`),
so the interior address `0x404014` is not converted; the lifter's resolver (`EntityCrossReferenceResolver`)
maps interior addresses of variables to GEPs into the containing variable (§11). `edge_cases.ll` covers PHI
incoming values (the replacement goes into the predecessor), instruction-computed addresses (replaced values
that become unused are erased, but not their operands), integer uses (`ptrtoint @entity`), addresses computed
from another global, plain integer constants (not PC-related, so left alone) and `--pc_metadata=` (no `pc`
annotations). The unit test "Regression test for unresolved anvill_pc" checks that the pass does not crash when
no entity exists.

Interaction: this runs after stack recovery, so SP-related values are excluded. The final step of
`OptimizeModule` replaces the remaining `__anvill_pc` uses with null when `should_remove_anvill_pc`.

#### 13.4.15 `BranchRecovery`

See §13.2.4.

#### 13.4.16 `LowerSwitchIntrinsics`

See §13.3.4.

---- second function pass manager ----

#### 13.4.17 `TransformRemillJumpIntrinsics`. File `lib/Passes/TransformRemillJumpIntrinsics.cpp`

Kind: function pass. The constructor is `TransformRemillJumpIntrinsics(const CrossReferenceResolver&)`.
The header defines `enum ReturnAddressResult { kReturnAddressProgramCounter, kUnclassifiableProgramCounter }`
and private `QueryReturnAddress(const CrossReferenceFolder&, Module*, Value*)` and
`TransformJumpIntrinsic(CallBase*)`.

`QueryReturnAddress(folder, M, v)` returns `kReturnAddressProgramCounter` when:

1. `IsReturnAddress(M, v)` is true; or
2. `v` is a `PtrToIntOperator` and recursing on operand 0 gives that result; or
3. `xr = folder.TryResolveReferenceWithClearedCache(v)` has `is_valid && references_return_address` and
   `xr.u.address == folder.MagicReturnAddressValue()` (0x4141…41 at pointer width). This catches CEs that
   byte-shuffle `__anvill_ra` but are value-equivalent to it.

Otherwise it returns `kUnclassifiableProgramCounter`.

`run(F)`:

* `folder = CrossReferenceFolder(xref_resolver, dl)`.
* The targets are calls whose callee is named exactly `__remill_jump` and whose
  `QueryReturnAddress(arg[kPCArgNum]->stripPointerCastsAndAliases())` is `kReturnAddressProgramCounter`.
* For each target:
  * `intrinsic = FindIntrinsic(M, jump's FunctionType, "__remill_function_return")`. This gets or creates the
    function, then adds the fn attributes `NoDuplicate, NoUnwind, OptimizeNone, NoInline` and removes
    `NoReturn, UWTable, AlwaysInline`.
  * Set arg 0 (the State pointer) to `undef`, copying the metadata of the old state argument onto it. Since
    undef is not an Instruction, this has no effect.
  * `call->setCalledOperand(intrinsic)`.
  * If `__remill_jump` is now use_empty, erase the declaration.
* If anything changed, run a **private nested FunctionPassManager** `DCE, SROA, SimplifyCFG, InstCombine` on `F`
  with the same FAM. Return `none()` if anything changed, else `all()`.

Real IR: `tests/golden/passes/TransformRemillJumpIntrinsics/basic.ll`, run as `anvill-opt --passes=TransformRemillJumpIntrinsics`. Input:

```llvm
; An indirect jump (__remill_jump) whose target is the return address is a
; return: the call is redirected to __remill_function_return (with an undef
; state pointer), and the function is cleaned up with DCE, SROA, SimplifyCFG
; and InstCombine. The return address is recognized directly
; (ptrtoint @__anvill_ra), or through arbitrary arithmetic that still
; evaluates to the magic return address value 0x4141414141414141 (e.g. a
; byte-by-byte reassembly). Other targets are left alone.

@__anvill_ra = external global i8

declare ptr @__remill_jump(ptr, i64, ptr)

define ptr @direct(ptr %state, ptr %mem) {
  %m = call ptr @__remill_jump(ptr %state, i64 ptrtoint (ptr @__anvill_ra to i64), ptr %mem), !pc !0
  ret ptr %m
}

define ptr @reassembled(ptr %state, ptr %mem) {
  %ra = ptrtoint ptr @__anvill_ra to i64
  %hi = lshr i64 %ra, 32
  %lo = and i64 %ra, 4294967295
  %hi2 = shl i64 %hi, 32
  %back = or i64 %hi2, %lo
  %m = call ptr @__remill_jump(ptr %state, i64 %back, ptr %mem)
  ret ptr %m
}

define ptr @unknown_target(ptr %state, ptr %mem, i64 %target) {
  %m = call ptr @__remill_jump(ptr %state, i64 %target, ptr %mem)
  ret ptr %m
}

!0 = !{i64 4096}
```

Output (`basic.expected.ll`):

```llvm
@__anvill_ra = external global i8

declare ptr @__remill_jump(ptr, i64, ptr)

define ptr @direct(ptr %state, ptr %mem) {
  %m = call ptr @__remill_function_return(ptr undef, i64 ptrtoint (ptr @__anvill_ra to i64), ptr %mem), !pc !0
  ret ptr %m
}

define ptr @reassembled(ptr %state, ptr %mem) {
  %m = call ptr @__remill_function_return(ptr undef, i64 ptrtoint (ptr @__anvill_ra to i64), ptr %mem)
  ret ptr %m
}

define ptr @unknown_target(ptr %state, ptr %mem, i64 %target) {
  %m = call ptr @__remill_jump(ptr %state, i64 %target, ptr %mem)
  ret ptr %m
}

declare ptr @__remill_function_return(ptr, i64, ptr) #0

!0 = !{i64 4096}
```

The unit test (on `data/TransformRemillJumpDataARM32_0.ll`) asserts that `__remill_function_return` exists and has
uses, and that `__remill_jump` is absent or has no uses.

Interaction: this must run before RemoveRemillFunctionReturns, which then removes the call.

#### 13.4.18 `RemoveRemillFunctionReturns`. File `lib/Passes/RemoveRemillFunctionReturns.cpp`

Kind: function pass. The constructor is `RemoveRemillFunctionReturns(const CrossReferenceResolver&)`.
The header defines `enum ReturnAddressResult { kFoundReturnAddress, kFoundSymbolicStackPointerLoad, kUnclassifiableReturnAddress }`.
It is a separate enum from §13.4.17's, with the same name in the same namespace but a different header.

`QueryReturnAddress(folder, sp_resolver, M, v)`, checked in this order:

1. `IsReturnAddress(M, v)` → `kFoundReturnAddress`.
2. A `CallBase` to `__remill_read_memory_*`: if `IsRelatedToStackPointer(M, arg1)`, return
   `kFoundSymbolicStackPointerLoad`; otherwise `kUnclassifiableReturnAddress`. Any other call →
   `kUnclassifiableReturnAddress`.
3. A `LoadInst`: if the pointer operand is SP-related, `kFoundSymbolicStackPointerLoad`; otherwise unclassifiable.
4. A `PtrToIntOperator` or `CastInst`: recurse on operand 0.
5. `IsRelatedToStackPointer(M, v)` → `kFoundSymbolicStackPointerLoad`.
6. A folder result with `references_return_address` and the magic value → `kFoundReturnAddress`.
7. Otherwise `kUnclassifiableReturnAddress`.

The `sp_resolver` parameter is passed but unused; the free function `IsRelatedToStackPointer` is called instead.

`run(F)`: for every call to a function named exactly `__remill_function_return`, classify
`arg[kPCArgNum]->stripPointerCastsAndAliases()`:

* `kFoundReturnAddress` → **FoldReturnAddressMatch(call)**:
  * Remember `ret_addr = dyn_cast<Instruction>(arg1)`. This is not stripped.
  * `mem = arg2`. `CopyMetadataTo(call, mem)`, then RAUW the call with `mem` and erase it.
  * While `ret_addr` exists and is use_empty: if it is a `CastInst`, erase it and continue with operand 0; else if
    `IsReturnAddress`, erase it and stop; else LOG(ERROR) and stop.
* `kFoundSymbolicStackPointerLoad` → do nothing. The pass is probably running before stack recovery.
* `kUnclassifiableReturnAddress` → add `(call, ret_addr)` to the fixups.
* If there are fixups and `AddressOfReturnAddressFunction(M)` is non-null, run **OverwriteReturnAddress**:
  * Insert one `call ptr @llvm.addressofreturnaddress.p0()` at the front of the entry block.
  * For each fixup, before the call: `bc = bitcast aora to ptr`; `store ret_addr, bc`; RAUW the call with `mem`
    (arg2); erase it. Metadata is copied onto each created value.
* Return `none()` if anything changed.

Real IR: `tests/golden/passes/RemoveRemillFunctionReturns/basic.ll`, run as `anvill-opt --passes=RemoveRemillFunctionReturns`. Input:

```llvm
; Returns to the real return address are removed: the
; __remill_function_return call is replaced by its memory pointer and the
; return-address computation is erased. A return to a value loaded from the
; stack (not yet resolved by stack recovery) is left alone. A return to any
; other value means the function changed its return address: the value is
; stored into the return address slot (llvm.addressofreturnaddress) and the
; call is removed.

@__anvill_ra = external global i8
@__anvill_sp = external global i8

declare ptr @__remill_function_return(ptr, i64, ptr)
declare i64 @__remill_read_memory_64(ptr, i64)

define ptr @returns_normally(ptr %mem) {
  %m = call ptr @__remill_function_return(ptr undef, i64 ptrtoint (ptr @__anvill_ra to i64), ptr %mem), !pc !0
  ret ptr %m
}

define ptr @returns_to_stack_value(ptr %mem) {
  %ra = call i64 @__remill_read_memory_64(ptr %mem, i64 ptrtoint (ptr @__anvill_sp to i64))
  %m = call ptr @__remill_function_return(ptr undef, i64 %ra, ptr %mem)
  ret ptr %m
}

define ptr @returns_elsewhere(ptr %mem, i64 %target) {
  %m = call ptr @__remill_function_return(ptr undef, i64 %target, ptr %mem), !pc !1
  ret ptr %m
}

!0 = !{i64 4096}
!1 = !{i64 8192}
```

Output (`basic.expected.ll`):

```llvm
@__anvill_ra = external global i8
@__anvill_sp = external global i8

declare ptr @__remill_function_return(ptr, i64, ptr)

declare i64 @__remill_read_memory_64(ptr, i64)

define ptr @returns_normally(ptr %mem) {
  ret ptr %mem
}

define ptr @returns_to_stack_value(ptr %mem) {
  %ra = call i64 @__remill_read_memory_64(ptr %mem, i64 ptrtoint (ptr @__anvill_sp to i64))
  %m = call ptr @__remill_function_return(ptr undef, i64 %ra, ptr %mem)
  ret ptr %m
}

define ptr @returns_elsewhere(ptr %mem, i64 %target) {
  %1 = call ptr @llvm.addressofreturnaddress.p0(), !pc !0
  store i64 %target, ptr %1, align 8, !pc !0
  ret ptr %mem
}

declare ptr @llvm.addressofreturnaddress.p0() #0

!0 = !{i64 8192}
```

The golden case has one function per classification: a return to `ptrtoint @__anvill_ra` (folded away), a
return to a value loaded from the stack before stack recovery (`kFoundSymbolicStackPointerLoad`, left alone; this
is also case 3 of the unit-test data `RecoverStackFrameInformation.ll`) and a return to an unrelated value
(stored through `llvm.addressofreturnaddress`).

#### 13.4.19 `ConvertSymbolicReturnAddressToConcreteReturnAddress`. File `lib/Passes/ConvertSymbolicReturnAddressToConcreteReturnAddress.cpp`

Kind: function pass (no constructor arguments). The header comment says `__remill_ra`, but the code uses `__anvill_ra`.

Algorithm:

1. Skip declarations. Build a `CrossReferenceFolder(NullCrossReferenceResolver, dl)`.
2. Collect `(inst, use)` for every operand that is a `ConstantExpr` whose fold has `references_return_address`.
   If there are none, return `all()`.
3. Insert `%return_address = call ptr @llvm.returnaddress(i32 0)` at the entry block's first insertion point.
   `ce_insert_loc = ra->getNextNode()`.
4. Work through the list, which grows as it goes. For each `(inst, use)`, with `ce = use->get()` (skip if it is no
   longer a CE):
   * `ce` is `ptrtoint @__anvill_ra`: create `ptrtoint %return_address to ce type`, inserted right after `ra`.
     Copy the metadata of `inst` onto it, then `use->set(...)`.
   * `ce` is `bitcast @__anvill_ra`:
     * same type: `use->set(ra)`;
     * pointer type: create a bitcast after `ra` and `use->set` it. (**Fixed:** the code never called `use->set`
       here, so the use kept the CE.)
     * integer type: ptrtoint as above.
   * Any other CE: `ce_inst = ce->getAsInstruction()`, inserted before `ce_insert_loc`, then
     `ce_insert_loc = ce_inst` (nested CEs stack upward). Copy metadata from `inst` and `use->set(ce_inst)`.
     Scan `ce_inst`'s operands for further RA-referencing CEs and append them to the list.
5. Return `none()`.

Real IR: `tests/golden/passes/ConvertSymbolicReturnAddressToConcreteReturnAddress/basic.ll`, run as `anvill-opt --passes=ConvertSymbolicReturnAddressToConcreteReturnAddress`. Input:

```llvm
; Remaining uses of the symbolic return address (`ptrtoint @__anvill_ra`,
; possibly inside larger constant expressions) are replaced by the real
; return address: one `llvm.returnaddress(0)` call at the top of the entry
; block, `ptrtoint`s of it, and the enclosing constant expressions turned
; into instructions. Functions without such uses are unchanged.

@__anvill_ra = external global i64

define void @stores_ra(ptr %slot) {
entry:
  store i64 ptrtoint (ptr @__anvill_ra to i64), ptr %slot, !pc !0
  ret void
}

define i64 @adjusted_ra() {
entry:
  br label %next
next:
  ret i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 8)
}

define i64 @no_ra(i64 %x) {
  ret i64 %x
}

!0 = !{i64 4096}
```

Output (`basic.expected.ll`):

```llvm
@__anvill_ra = external global i64

define void @stores_ra(ptr %slot) {
entry:
  %return_address = call ptr @llvm.returnaddress(i32 0)
  %0 = ptrtoint ptr %return_address to i64, !pc !0
  store i64 %0, ptr %slot, align 8, !pc !0
  ret void
}

define i64 @adjusted_ra() {
entry:
  %return_address = call ptr @llvm.returnaddress(i32 0)
  %0 = ptrtoint ptr %return_address to i64
  %1 = add i64 %0, 8
  br label %next

next:                                             ; preds = %entry
  ret i64 %1
}

define i64 @no_ra(i64 %x) {
  ret i64 %x
}

declare ptr @llvm.returnaddress(i32 immarg) #0

!0 = !{i64 4096}
```

#### 13.4.20 `LowerRemillUndefinedIntrinsics`. File `lib/Passes/LowerRemillUndefinedIntrinsics.cpp`

Kind: function pass. Every CallInst whose direct callee name starts with `__remill_undefined_` is RAUW'd with
`UndefValue::get(call type)` and erased. `CopyMetadataTo` onto the undef is a no-op. This should run late, to
keep undefinedness from spreading.

Real IR: `tests/golden/passes/LowerRemillUndefinedIntrinsics/basic.ll`, run as `anvill-opt --passes=LowerRemillUndefinedIntrinsics`. Input:

```llvm
; Calls to __remill_undefined_* are replaced by undef values of their type.

declare i8 @__remill_undefined_8()
declare i32 @__remill_undefined_32()
declare double @__remill_undefined_f64()

define i32 @f(i32 %x) {
  %flag = call i8 @__remill_undefined_8()
  %bits = call i32 @__remill_undefined_32()
  %fp = call double @__remill_undefined_f64()
  %z = zext i8 %flag to i32
  %r = or i32 %z, %bits
  %fpi = fptosi double %fp to i32
  %s = add i32 %r, %fpi
  ret i32 %s
}
```

Output (`basic.expected.ll`):

```llvm
declare i8 @__remill_undefined_8()

declare i32 @__remill_undefined_32()

declare double @__remill_undefined_f64()

define i32 @f(i32 %x) {
  %z = zext i8 undef to i32
  %r = or i32 %z, undef
  %fpi = fptosi double undef to i32
  %s = add i32 %r, %fpi
  ret i32 %s
}
```

#### 13.4.21 `RemoveUnusedBranchHints`

See §13.2.5.

#### 13.4.22 `SpreadPCMetadata`. File `lib/Passes/SpreadPCMetadata.cpp`

Kind: function pass. The constructor is `SpreadPCMetadata(const char *pc_metadata_name)`.
`AddSpreadPCMetadata(fpm, LifterOptions)` adds the pass only if `options.pc_metadata_name` is non-null.

Algorithm (`md_id = getMDKindID(name)`), per basic block:

1. **Forward pass.** For each instruction `I`:
   * If `I` lacks the metadata, set `has_missing = true` and continue.
   * Otherwise set `last_md = md(I)`. For each operand of `I` that is an instruction **in the same block** and
     lacks the metadata, give it `md(I)`. Since operands precede `I`, a value defined earlier in the block inherits
     the PC of its first annotated user.
2. If `has_missing` was set: **backward pass** from the end of the block. `last_md` starts as the block's last
   annotated metadata from the forward pass. For each instruction: if it has metadata, set `last_md` to it; else if
   `last_md` exists, assign it.

   The effect: unannotated instructions take the PC of the next annotated instruction below them. Trailing
   unannotated instructions take the last annotated PC in the block. Blocks with no annotations stay unannotated.

Real IR: `tests/golden/passes/SpreadPCMetadata/basic.ll`, run as `anvill-opt --passes=SpreadPCMetadata`. Input:

```llvm
; Instructions without `pc` metadata get one: first, an annotated
; instruction gives its metadata to unannotated operands defined in the same
; block; then, walking each block backwards starting with the block's last
; metadata, unannotated instructions take the metadata of the next annotated
; instruction after them (so instructions after the last annotated one take
; its metadata). Blocks without any annotated instruction are unchanged.

define i32 @f(i32 %a, i32 %b) {
entry:
  %x = add i32 %a, 1
  %y = mul i32 %x, %b, !pc !0
  %z = sub i32 %y, 3
  %w = xor i32 %z, %a, !pc !1
  %tail = add i32 %w, 1
  br label %next
next:
  %n = add i32 %tail, %x
  ret i32 %n
}

!0 = !{i64 4096}
!1 = !{i64 4100}
```

Output (`basic.expected.ll`):

```llvm
define i32 @f(i32 %a, i32 %b) {
entry:
  %x = add i32 %a, 1, !pc !0
  %y = mul i32 %x, %b, !pc !0
  %z = sub i32 %y, 3, !pc !1
  %w = xor i32 %z, %a, !pc !1
  %tail = add i32 %w, 1, !pc !1
  br label %next, !pc !1

next:                                             ; preds = %entry
  %n = add i32 %tail, %x
  ret i32 %n
}

!0 = !{i64 4096}
!1 = !{i64 4100}
```

#### 13.4.23 `CodeQualityStatCollector`. File `lib/Passes/CodeQualityStatCollector.cpp`

Kind: function pass. It is analysis-only, always returns `all()`, and uses `DEBUG_TYPE "code_quality"`.
`llvm::STATISTIC` counters:

* `ConditionalComplexity`;
* `NumberOfInstructions` (every instruction);
* `AbruptControlFlow` (calls to `__anvill_complete_switch` or `__anvill_incomplete_switch`);
* `IntToPointerCasts` (inttoptr instructions);
* `PointerToIntCasts` (ptrtoint instructions).

`ConditionalComplexityVisitor` starts from each conditional branch's condition:

* +1 for each `CmpInst`, which stops the recursion;
* +1 for each `i1` `BinaryOperator`, then recurse into both operands;
* +1 for each integer-typed `UnaryOperator`, then recurse.

#### 13.4.24 `ConvertXorsToCmps`. File `lib/Passes/ConvertXorsToCmps.cpp`

Kind: function pass. Helpers:

* `getVariableOperands(binop)`: returns `(var, ConstantInt)` when exactly one operand is a ConstantInt, in either
  position.
* `getComparisonOperands(binop)`: the same, plus the variable must be an `ICmpInst`.
* `negateCmpPredicate(cmp)`: `IRBuilder(cmp).CreateICmp(inverse(pred), op0, op1)`, inserted before `cmp`.

Collection (one scan over `xor` BinaryOperators):

* If it is `xor (icmp ...), C` and `C` is an `i1` all-ones (`true`), add it to `xors`. If it is an icmp xor with
  any other constant, `continue` (it does not fall through to the next case).
* Else if it is `xor V, C` with `C = i1 true`, add it to `noncmp_xors`.

Phase 1, `noncmp_xors` (`%x = xor i1 %v, true`): for every **BranchInst** user of `%x`:
`br.setCondition(%v); br.swapSuccessors()`. If at least one branch was flipped and `%x` is now use_empty,
erase `%x`.

Phase 2, `xors` (`%x = xor i1 %c, true` with `%c = icmp P a, b`):

* Check invertibility over **all** users of `%c` other than `%x`:
  * a `BranchInst` user is added to `brs_to_invert`;
  * a `SelectInst` user whose **condition** is `%c` is added to `selects_to_invert`;
  * any other user makes the pair non-invertible, so skip it.
* If it is invertible:
  * `n = icmp inverse(P) a, b`, with `CopyMetadataTo(%x, n)`;
  * swap the successors of each branch in `brs_to_invert`;
  * `swapValues()` on each select in `selects_to_invert`;
  * `%c->RAUW(n)` and erase `%c`;
  * `%x->RAUW(n)` and erase `%x`.

Correctness: the xor users get `!c == n`, as they should. Branches and selects on `%c` now see `n = !c`, so they
are swapped back.

**Fixed (was a real bug).** `brs_to_invert.clear()` and `selects_to_invert.clear()` used to run **inside the loop
over `%c`'s users, once per user**, so only the *last* visited non-xor user was kept; other branch or select users
received the negated condition **without** being swapped, which inverted their semantics. The vectors also lived
outside the per-xor loop, so when `%c`'s only user was the xor they still held the *previous* xor's branches and
selects, which were then swapped again. The vectors are now cleared once per xor, before the loop, and a select
user only counts when `%c` is its condition (not one of its values). The unit test `xor_conversion.ll` only counts
xors and did not detect this; the golden `compare.ll` has a compare used by an xor, two branches and a select.

Real IR: `tests/golden/passes/ConvertXorsToCmps/compare.ll`, run as `anvill-opt --passes=ConvertXorsToCmps`. Input:

```llvm
; (xor (icmp P a, b), true) becomes (icmp !P a, b) when every other user of
; the compare is a branch or a select condition: those branches get their
; successors swapped and those selects their values swapped, so they keep
; their meaning. Previously only the *last* such user was swapped (the list
; was cleared per use), silently inverting the others.

define i32 @only_xor(i32 %a, i32 %b) {
  %c = icmp slt i32 %a, %b
  %x = xor i1 %c, true, !pc !0
  %r = select i1 %x, i32 1, i32 2
  ret i32 %r
}

define i32 @two_branches(i32 %a, i32 %b, ptr %p) {
entry:
  %c = icmp ult i32 %a, %b
  %x = xor i1 true, %c
  store i1 %x, ptr %p
  br i1 %c, label %t1, label %f1
t1:
  br label %mid
f1:
  br label %mid
mid:
  %v = phi i32 [ 1, %t1 ], [ 2, %f1 ]
  br i1 %c, label %t2, label %f2
t2:
  ret i32 %v
f2:
  ret i32 0
}

define i32 @select_condition(i32 %a, i32 %b) {
  %c = icmp eq i32 %a, %b
  %x = xor i1 %c, true
  %s = select i1 %c, i32 %a, i32 %b
  %t = select i1 %x, i32 10, i32 %s
  ret i32 %t
}

!0 = !{i64 4096}
```

Output (`compare.expected.ll`):

```llvm
define i32 @only_xor(i32 %a, i32 %b) {
  %1 = icmp sge i32 %a, %b, !pc !0
  %r = select i1 %1, i32 1, i32 2
  ret i32 %r
}

define i32 @two_branches(i32 %a, i32 %b, ptr %p) {
entry:
  %0 = icmp uge i32 %a, %b
  store i1 %0, ptr %p, align 1
  br i1 %0, label %f1, label %t1

t1:                                               ; preds = %entry
  br label %mid

f1:                                               ; preds = %entry
  br label %mid

mid:                                              ; preds = %f1, %t1
  %v = phi i32 [ 1, %t1 ], [ 2, %f1 ]
  br i1 %0, label %f2, label %t2

t2:                                               ; preds = %mid
  ret i32 %v

f2:                                               ; preds = %mid
  ret i32 0
}

define i32 @select_condition(i32 %a, i32 %b) {
  %1 = icmp ne i32 %a, %b
  %s = select i1 %1, i32 %b, i32 %a
  %t = select i1 %1, i32 10, i32 %s
  ret i32 %t
}

!0 = !{i64 4096}
```

More cases in `tests/golden/passes/ConvertXorsToCmps/`: `non_compare.ll`, `not_invertible.ll`.

Non-changes (golden `not_invertible.ll` and `non_compare.ll`; unit-test data named below):

* `xor_conversion_nochange.ll`: `%6` also has `zext` users, so it is not invertible.
* `xor_removal_noremove.ll`, case `xor i1 %10, false`: wrong constant.
* `xor_removal_noremove.ll`, case where the xor is unused by any branch: nothing to flip, and the xor is not
  erased because `changed_this_xor` stays false.

#### 13.4.25 Passes not scheduled by `OptimizeModule`

* **HoistUsersOfSelectsAndPhis**. The call is commented out in Optimize.cpp: "has an issue on `SMIME_write_ASN1`
  of the ARM64 Challenge 5". See §13.5.
* **SimplifyStackArithFlags**. Removed (it was never built). See §13.2.6.
* **`OurVerifierPass`** in Optimize.cpp. A debugging helper wrapping `llvm::VerifierPass`; unused.


### 13.5 `HoistUsersOfSelectsAndPhis` (unscheduled). File `lib/Passes/HoistUsersOfSelectsAndPhis.cpp`


Kind: function pass. It uses `DominatorTreeAnalysis`, and a nested `class PassFunctionState` holds `dt`.
`using InstructionList = std::vector<llvm::Instruction*>`.

Driver, `run`:

* Skip declarations.
* `next_worklist = SelectInstructions<SelectInst, PHINode>(F)`.
* Run up to **8 rounds** ("gas"). Each round swaps the worklists. Each instruction is processed once; a global
  `visited_instructions` set enforces this.
* PHIs go through `FoldPHINode(next_worklist, phi)` and selects through `FoldSelectInstruction(...)`. Newly created
  replacement selects and PHIs are pushed to `next_worklist`.
* At the end, erase every visited instruction that is `use_empty()`.
* Return `none()` if anything changed.

`FoldSelectInstruction(out, S)` handles each **user** `U` of `S` whose opcode is in `kSelectInstructionFolderMap`.
Each folder has signature
`bool(Instruction *&output, Instruction *sel, Value *cond, Value *t, Value *f, Instruction *user)`:

* **Binary ops** (`Add, FAdd, Sub, FSub, Mul, FMul, UDiv, SDiv, FDiv, URem, SRem, FRem, Shl, LShr, AShr, And, Or, Xor`)
  use `FoldSelectWithBinaryOp`:
  * The "other" operand must be a `Constant`.
  * At U, build `nt = op(t, other)`, `nf = op(f, other)` and `select cond, nt, nf`, copying metadata (U → nt/nf,
    S → the new select).
  * The operand order is preserved: `sub C, %sel` becomes `select(c, C - t, C - f)`. (**Fixed:** the selected
    value used to be placed as the LHS, giving `select(c, t - C, f - C)`.)
* **Casts** (`Trunc, ZExt, SExt, FPToUI, FPToSI, UIToFP, SIToFP, FPTrunc, FPExt, PtrToInt, IntToPtr, BitCast`)
  use `FoldSelectWithCastInst`:
  * For a vector condition, require an `i1` element and an element count equal to the destination vector's.
  * Build `cast(t)`, `cast(f)` and the select.
* **GetElementPtr** uses `FoldSelectWithGEPInst`:
  * `CollectAndValidateGEPIndexes(index_list, S, gep)` (shared with PHIs): indices before the select or PHI index
    must not be instructions in the GEP's block; indices after it must be constants.
  * If the select is the **base pointer** (and not also an index), build `gep t, indices` and `gep f, indices` at
    the GEP, then a select. (**Fixed:** the fold used to fail in that case.) Otherwise the select must be one of
    the indices. In both cases the new GEPs keep the old GEP's `inbounds` flag (previously dropped).
  * Build `gep base, [.., t, ..]`, the same with `f`, then a select.
* Each successful replacement is recorded `(U → newSelect)` and its result pushed to `out`. Finally RAUW and erase
  each U. The select itself is left for the driver's cleanup.

`FoldPHINode(out, P)`:

* Collect the `(block, value)` incoming pairs, then sort and unique them.
* `IsPHINodeFoldable`: false if any incoming value is a PHI, or if any incoming value is itself a user of P
  (a cycle).
* For each user U whose opcode is in `kPHINodeFolderMap` (the same opcode set as for selects, including the
  PtrToInt, IntToPtr and BitCast entries under `#if 1`; a NOTE warns these may ping-pong), call the member-function
  folder.
* Apply the replacements. Erase incoming-value instructions that became use_empty.

`InsertionBlock(iv)`: the block of the incoming value if it is an instruction, else the incoming block. The new
per-edge instruction goes **before that block's terminator**.

`BuildPHI(P, type, map)`: `IRBuilder(P).CreatePHI(type, n)` (inserted before P), copying P's metadata. For each
original `(value_i, block_i)` it adds `map[(value_i, block_i)]`. It uses `CHECK_NOTNULL` and
`DCHECK(BasicBlockIsSane(P))`.

The per-user PHI folders:

* **FoldPHINodeWithBinaryOp**: the other operand must be a Constant. For each incoming value, build
  `op(iv, C)` (or `op(C, iv)` when the PHI is the right operand) in `InsertionBlock(iv)`, then
  `BuildPHI(P, P type)`. Like the select version, it now preserves the operand order (`phi.ll`).
* **FoldPHINodeWithCastInst**: build `cast(iv)` per incoming value, then `BuildPHI(P, dest type)`.
* **FoldPHINodeWithGEPInst**:
  * `CollectAndValidateGEPIndexes` must succeed, and the GEP must be in **the same block as P**.
  * Build `value_map[v][pred] =` a per-predecessor value for each GEP operand:
    * a Constant or Argument maps to itself for every predecessor;
    * an instruction outside the current block maps to itself if it dominates every incoming block's terminator;
    * every PHI at the top of the current block maps through its incoming values. This covers P itself and other
      PHIs such as an index PHI.
  * Every GEP operand needs an entry, otherwise fail.
  * Per incoming value: `gep srcTy, value_map[base][bb], mapped indices`, inserted in `InsertionBlock`.
    Then `BuildPHI(P, gep type)`.

Real IR: `tests/golden/passes/HoistUsersOfSelectsAndPhis/select.ll`, run as `anvill-opt --passes=HoistUsersOfSelectsAndPhis`. Input:

```llvm
; A binary operator with a constant other operand, a cast, or a GEP that uses
; a select is pushed into both arms of the select:
;   (op (select c, a, b), K) -> (select c, (op a, K), (op b, K))
; The operand order is preserved: (sub K, select) becomes
; (select c, (sub K, a), (sub K, b)). Previously the select was always put
; on the left, turning `sub 100, x` into `sub x, 100`.
; (Not scheduled by OptimizeModule.)

define i32 @select_lhs(i1 %c, i32 %a, i32 %b) {
  %s = select i1 %c, i32 %a, i32 %b
  %r = sub i32 %s, 100
  ret i32 %r
}

define i32 @select_rhs(i1 %c, i32 %a, i32 %b) {
  %s = select i1 %c, i32 %a, i32 %b
  %r = sub i32 100, %s
  ret i32 %r
}

define i32 @not_constant(i1 %c, i32 %a, i32 %b, i32 %k) {
  %s = select i1 %c, i32 %a, i32 %b
  %r = sub i32 %s, %k
  ret i32 %r
}

define i64 @cast(i1 %c, i32 %a, i32 %b) {
  %s = select i1 %c, i32 %a, i32 %b
  %r = zext i32 %s to i64
  ret i64 %r
}

define ptr @gep_index(i1 %c, ptr %p) {
  %s = select i1 %c, i64 1, i64 3
  %g = getelementptr inbounds [4 x i32], ptr %p, i64 0, i64 %s
  ret ptr %g
}

define ptr @gep_base(i1 %c, ptr %p, ptr %q) {
  %s = select i1 %c, ptr %p, ptr %q
  %g = getelementptr inbounds i32, ptr %s, i64 2
  ret ptr %g
}
```

Output (`select.expected.ll`):

```llvm
define i32 @select_lhs(i1 %c, i32 %a, i32 %b) {
  %1 = sub i32 %a, 100
  %2 = sub i32 %b, 100
  %3 = select i1 %c, i32 %1, i32 %2
  ret i32 %3
}

define i32 @select_rhs(i1 %c, i32 %a, i32 %b) {
  %1 = sub i32 100, %a
  %2 = sub i32 100, %b
  %3 = select i1 %c, i32 %1, i32 %2
  ret i32 %3
}

define i32 @not_constant(i1 %c, i32 %a, i32 %b, i32 %k) {
  %s = select i1 %c, i32 %a, i32 %b
  %r = sub i32 %s, %k
  ret i32 %r
}

define i64 @cast(i1 %c, i32 %a, i32 %b) {
  %1 = zext i32 %a to i64
  %2 = zext i32 %b to i64
  %3 = select i1 %c, i64 %1, i64 %2
  ret i64 %3
}

define ptr @gep_index(i1 %c, ptr %p) {
  %1 = getelementptr inbounds [4 x i32], ptr %p, i64 0, i64 1
  %2 = getelementptr inbounds [4 x i32], ptr %p, i64 0, i64 3
  %3 = select i1 %c, ptr %1, ptr %2
  ret ptr %3
}

define ptr @gep_base(i1 %c, ptr %p, ptr %q) {
  %1 = getelementptr inbounds i32, ptr %p, i64 2
  %2 = getelementptr inbounds i32, ptr %q, i64 2
  %3 = select i1 %c, ptr %1, ptr %2
  ret ptr %3
}
```

More cases in `tests/golden/passes/HoistUsersOfSelectsAndPhis/`: `phi.ll`.

`CombineGEPWithSelect` in the unit-test data `InstructionFolderPass.ll` has the select as the GEP *base*; it is
now folded. That unit test only runs the pass and verifies the module; the goldens pin the output.


### 13.6 Exact pipeline (`lib/Optimize.cpp`, `void OptimizeModule(const EntityLifter &lifter, llvm::Module &module)`)


Pre-steps:

* `module.materializeAll()`, which is fatal on error.
* Erase the GVs `llvm.used` and `llvm.compiler.used` (made private first).
* Erase every call to `__anvill_memory_escape` (`kMemoryPointerEscapeFunction`), and the function itself.
* `CHECK(remill::VerifyModule(&module))`.
* `pc_metadata_id = getMDKindID(options.pc_metadata_name)` if the name is set.
* `EntityCrossReferenceResolver xr(lifter)` and `const MemoryProvider &mp = lifter.MemoryProvider()`.

Pass manager setup:

* Build a `PassBuilder pb` and the analysis managers `mam, lam, cam, fam`. Call
  `pb.registerFunctionAnalyses(fam)`, `registerModuleAnalyses(mam)`, `registerCGSCCAnalyses(cam)` and
  `registerLoopAnalyses(lam)`.
* Register the custom analyses: `fam.registerPass([&]{ return BranchAnalysis(); })` and
  `fam.registerPass([&]{ return JumpTableAnalysis(lifter); })`.
* Commented out: the inliner (`ModuleInlinerWrapperPass`), `SinkingPass`, `DSEPass` ("extremely slow with LLVM 14"),
  `NewGVNPass` in the first FPM (buggy on chal5), and `AddHoistUsersOfSelectsAndPhis`.

**Module pass manager `mpm`:**

1. `llvm::GlobalOptPass`
2. `llvm::GlobalDCEPass`
3. `llvm::StripDeadDebugInfoPass`

**First function pass manager `fpm`:**

1. `llvm::DCEPass`
2. `llvm::SCCPPass`
3. `llvm::SROAPass`
4. `llvm::EarlyCSEPass(true)` (with MemorySSA)
5. `llvm::BDCEPass`
6. `llvm::SimplifyCFGPass`
7. `llvm::SimplifyCFGPass`
8. `llvm::InstCombinePass`
9. `AddSinkSelectionsIntoBranchTargets` → SinkSelectionsIntoBranchTargets
10. `AddRemoveUnusedFPClassificationCalls` → RemoveUnusedFPClassificationCalls
11. `AddRemoveDelaySlotIntrinsics` → RemoveDelaySlotIntrinsics
12. `AddRemoveErrorIntrinsics` → RemoveErrorIntrinsics
13. `AddLowerRemillMemoryAccessIntrinsics` → LowerRemillMemoryAccessIntrinsics
14. `AddRemoveCompilerBarriers` → RemoveCompilerBarriers
15. `AddLowerTypeHintIntrinsics` → LowerTypeHintIntrinsics
16. (HoistUsersOfSelectsAndPhis is commented out here)
17. `llvm::InstCombinePass`
18. `llvm::DCEPass`
19. `llvm::SROAPass`
20. `AddConvertMasksToCasts` → ConvertMasksToCasts
21. `AddSinkSelectionsIntoBranchTargets` → SinkSelectionsIntoBranchTargets (2nd time)
22. `AddRemoveTrivialPhisAndSelects` → RemoveTrivialPhisAndSelects
23. `llvm::DCEPass`
24. `AddRemoveStackPointerCExprs(fpm, options.stack_frame_recovery_options)`
25. `AddRecoverBasicStackFrame(fpm, options.stack_frame_recovery_options)`
26. `AddSplitStackFrameAtReturnAddress(fpm, options.stack_frame_recovery_options)`
27. `llvm::SROAPass`
28. `AddCombineAdjacentShifts` → CombineAdjacentShifts. A stale comment about xor→cmp follows it; ConvertXorsToCmps is actually in the second FPM.
29. `AddConvertAddressesToEntityUses(fpm, xr, pc_metadata_id)`
30. `AddBranchRecovery` → BranchRecovery, which uses the BranchAnalysis analysis
31. `AddLowerSwitchIntrinsics(fpm, mp)` → LowerSwitchIntrinsics, which uses JumpTableAnalysis and DominatorTree

Then `pb.crossRegisterProxies(lam, fam, cam, mam)`,
`mpm.addPass(createModuleToFunctionPassAdaptor(std::move(fpm)))` and **`mpm.run(module, mam)`**.

**Second function pass manager `second_fpm`:**

1. `AddTransformRemillJumpIntrinsics(second_fpm, xr)`. This internally runs DCE, SROA, SimplifyCFG and
   InstCombine on any function it changes.
2. `AddRemoveRemillFunctionReturns(second_fpm, xr)`
3. `AddConvertSymbolicReturnAddressToConcreteReturnAddress`
4. `AddLowerRemillUndefinedIntrinsics`
5. `AddRemoveFailedBranchHints` → RemoveUnusedBranchHints
6. `llvm::NewGVNPass`
7. `AddSpreadPCMetadata(second_fpm, options)`, only if `pc_metadata_name` is set
8. `CodeQualityStatCollector()`
9. `AddConvertXorsToCmps` → ConvertXorsToCmps
10. `llvm::DCEPass`

Then `mpm.addPass(createModuleToFunctionPassAdaptor(std::move(second_fpm)))` and **`mpm.run(module, mam)` again**.

**Important subtlety:** the second `addPass` appends to the *same* `mpm`. The second `run` therefore executes
GlobalOpt → GlobalDCE → StripDeadDebugInfo → **the entire first FPM again** → the second FPM. The effective
sequence is: [M1 + FPM1] then [M1 + FPM1 + FPM2]. The first FPM runs twice in total, and the second FPM runs once.

This looks accidental, but it is **kept deliberately** (and now documented in a comment in `lib/Optimize.cpp`):
running FPM1 only once was tried and made the output worse. The second round removes the stack frames left
around calls and the dead blocks left by switch lowering, as the `tests/golden/lifter/**/*.optimized.ll` files
show. A reimplementation that wants the same output must run FPM1 twice.

Since the remill-template image's LLVM has assertions enabled, the `instcombine` that `anvill-opt` builds from a
pipeline string is `instcombine<no-verify-fixpoint>`: the default verifies that InstCombine reaches a fixpoint in
one iteration and aborts otherwise. `OptimizeModule` constructs `InstCombinePass()` directly; under assertions
that also verifies the fixpoint, which the lifter goldens show is reached.

Post-steps:

* If `lifter.Options().should_remove_anvill_pc`, call
  `remill::ReplaceAllUsesOfConstant(@__anvill_pc, null, &module)`.
* `mam.clear(); fam.clear(); cam.clear(); lam.clear();` (to avoid ASAN destructor issues).
* `CHECK(remill::VerifyModule(&module))`.

Ordering rationale stated in the comments:

* FP-classification removal must happen before function renaming.
* `RemoveRemillFunctionReturns` should run as late as possible, because it depends on the memory pointer. It runs after
  `TransformRemillJumpIntrinsics`.
* Undefined-value lowering is late, so undefinedness does not spread.
* ConvertMasksToCasts runs before the stack analyses, to fix truncated SP and PC displacements.
* The stack analyses run on InstCombine'd IR after memory intrinsics are lowered to `inttoptr`-CE loads and stores.
* ConvertAddressesToEntityUses runs after stack recovery, because it skips SP-related values.
* BranchRecovery and the jump-table analysis expect InstCombine-canonical IR.


### 13.7 Test harness (`tests/anvill_passes`)


Build (`tests/anvill_passes/CMakeLists.txt`):

* The executable is `test_anvill_passes`: `main.cpp` (`#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN` + doctest),
  `Utils.{h,cpp}`, and one .cpp per suite.
* It links `remill_settings`, `remill`, `anvill` and `doctest::doctest`.
* `ANVILL_TEST_DATA_PATH="<src>/data"`.
* The include dirs add `../src` and **`../../lib/Passes`**, so tests can include private sources.
  `RecoverStackFrameInformation.cpp` does `#include "RecoverBasicStackFrame.cpp"` to reach the static
  `EnumerateStackPointerUsages`, `AnalyzeStackFrame`, `GenerateStackFrameType` and `UpdateFunction`.
* `add_test(NAME test_anvill_passes ...)`.

`src/Utils.{h,cpp}`:

```cpp
bool VerifyModule(llvm::Module*);                 // llvm::verifyModule; prints "Module verification failed for '<name>': ..." to stderr
std::unique_ptr<llvm::Module> LoadTestData(llvm::LLVMContext&, const std::string &data_name);
    // parseIRFile(ANVILL_TEST_DATA_PATH "/" + name); throws runtime_error on parse failure;
    // runs verifyModule and only PRINTS failures (does not throw)
template <typename PassT> bool RunFunctionPass(llvm::Module *m, PassT &&pass) {
    PassBuilder pb; FunctionPassManager fpm; FunctionAnalysisManager fam; ModuleAnalysisManager mam;
    pb.registerModuleAnalyses(mam); pb.registerFunctionAnalyses(fam);
    fam.registerPass([&]{ return ModuleAnalysisManagerFunctionProxy(mam); });
    fpm.addPass(std::forward<PassT>(pass));
    for (auto &func : *m) fpm.run(func, fam);     // includes declarations; passes must tolerate them
    return VerifyModule(m);
}
struct Platform { std::string os, arch; };  const PlatformList &GetSupportedPlatforms(); // {{"linux","amd64"}}
std::unique_ptr<llvm::LLVMContext> CreateContextWithOpaquePointers(); // enableOpaquePointers() if LLVM < 15
```

Suites and their data:

| Suite (file) | Data | What it checks |
|---|---|---|
| SinkSelectionsIntoBranchTargets | `SinkSelectionsIntoBranchTargets.ll` | whole pass verifies; `AnalyzeFunction` replacement and disposable counts 2/1, 6/3, 6/1 |
| RecoverBasicStackFrame (`RecoverStackFrameInformation.cpp`) | `RecoverStackFrameInformation.ll` | all 4 init strategies × padding {0, 32, 64} verify; 14 SP uses; lowest -28, highest 16, size 44; frame type size 48 (176 with 128 padding); after UpdateFunction (kZeroes), alloca first, 14 GEPs, re-analysis empty |
| SplitStackFrameAtReturnAddress | `SplitStackFrameAtReturnAddress.ll` | verifies with default options |
| InstructionFolderPass | `InstructionFolderPass.ll` | HoistUsersOfSelectsAndPhis verifies |
| BrightenPointers | `gep_add.ll`, `multiple_bitcast.ll`, `loop_test.ll`, `rx_message.ll`, `chall2.ll`, `ret0.ll`, `jmp0.ll`, `test_*_rt.ll`, `test_rx.ll` (22 cases) | **only runs `llvm::DCEPass`** with a bare FAM. The BrightenPointers pass no longer exists. These are just parse, verify and DCE smoke tests |
| TransformRemillJump_Test0/1, _ARM32_0/1 | `TransformRemillJumpData{0,1,ARM32_0,ARM32_1}.ll` | builds a `remill::Arch` (amd64 or aarch32), `LifterOptions` with Null providers, `EntityLifter`, and `EntityCrossReferenceResolver`; after the pass `__remill_function_return` has uses and `__remill_jump` has none |
| SwitchLowerLargeFunction | `SwitchLoweringLarge.ll`, `SwitchLoweringNeg.ll` | `MockMemProv : MemoryProvider` with an `std::map<uint64_t, uint8_t>` and `AddJumpTableOffset(uint32_t)` (endian-aware); checks JumpTableAnalysis bounds and indexRel values, then the lowered case count (5 and 4) and the index sets |
| XorConversion | `xor_*.ll` | xor counts before and after |
| BranchRecoveryPass | `BranchRecoveryAarch64.ll`, `RecoverSubBranch.ll`, `UnrecoverableBranch.ll` | runs InstCombine, then BranchAnalysis predicate and operands, then BranchRecovery produces an icmp; the unrecoverable case gives an empty map |
| RemoveStackPointerCExprs | `RegressionRecoverStack.ll` | runs the pass on `@slice`, dumps, verifies |
| RecoverEntityUses | `TestingUnresolvedEntity.ll` | runs ConvertAddressesToEntityUses on `@sub_12b30__A_SBI_B_0.6` with an empty FAM; does not crash |

Unreferenced data: `BaseFunctionPass.ll`, `maybe_proof.smt`, `proof_result.smt` (Z3 dumps of BranchAnalysis queries).

The suites that need analyses (switch lowering, branch recovery, RemoveStackPointerCExprs) build their own full
`PassBuilder` with all four managers and `crossRegisterProxies`. They clear the managers at the end, mirroring Optimize.cpp.


### 13.8 Quick gotcha list, with status

The status column says what this branch did. "Fixed" items have a golden case that pins the new behaviour; the
old behaviour is described in the section referenced.

| # | Behaviour | Status |
|---|---|---|
| 1 | The pipeline runs the first FPM twice, because `mpm` is reused (§13.6). | **Kept** deliberately; documented in Optimize.cpp. |
| 2 | `ConvertXorsToCmps` clears its invert lists per use and can mis-invert branches or selects (§13.4.24). | **Fixed** (`ConvertXorsToCmps/compare.ll`). |
| 3 | `CombineAdjacentShifts` swaps its capture variables, giving the wrong condition and rewrite (§13.4.13). | **Fixed** (`CombineAdjacentShifts/basic.ll`). |
| 4 | `ConvertMasksToCasts`: shl/ashr ignores the shift amount; shl_add does not set `changed` (§13.4.8). | **Fixed** (`ConvertMasksToCasts/sign_extend.ll`, `shifted_add.ll`). |
| 5 | `HoistUsersOfSelectsAndPhis`: binop folding ignores operand order; a select GEP base is not folded; `inbounds` is dropped (§13.5). | **Fixed** (`HoistUsersOfSelectsAndPhis/select.ll`, `phi.ll`). Still unscheduled. |
| 6 | `SplitStackFrameAtReturnAddress`: `seen` never populated; variable-index GEPs lose the prefix offset, lack a leading zero and may violate dominance; subframe names inverted (§13.4.12). | **Fixed** (`SplitStackFrameAtReturnAddress/*.ll`). |
| 7 | `ConvertSymbolicReturnAddressToConcreteReturnAddress`: the bitcast-to-pointer case never sets the use (§13.4.19). | **Fixed** (`.../basic.ll`). |
| 8 | `RemoveStackPointerCExprs`: `Displacement()` returns 0 for i1, so SP comparisons fold to `false` (§13.4.10). | **Fixed** in the folder (§12); `RemoveStackPointerCExprs/*.ll`. |
| 9 | `RemoveUnusedBranchHints` also removes `__remill_compare_exchange*` calls (§13.2.5). | **Fixed** (`RemoveUnusedBranchHints/basic.ll`). |
| 10 | `SliceManager` performs RAUW on uniqued CEs, mutating the original module; `@__anvill_pc` slices never become interpretable, so jump tables were never lowered (§13.3.2). | **Fixed** (`LowerSwitchIntrinsics/jump_table.ll`, `lifter/flow/jump_table`). |
| 11 | `LowerSwitchIntrinsics`: no wrap guard on the bound loop; PHIs not updated (invalid IR) (§13.3.4). | **Fixed** (`LowerSwitchIntrinsics/shared_target.ll`). |
| 12 | `SimplifyStackArithFlags` is not compiled; `AddSimplifyStackArithFlags` is declared but undefined (§13.2.6). | **Removed.** |
| 13 | `ConvertAddressesToEntityUses` returns `none()` even when nothing was replaced (§13.4.14). | Kept (harmless: only costs analysis invalidation). |
| 14 | `RecoverBasicStackFrame`: frame not word-aligned; `__anvill_stack_zero` mixes frame and stack offsets; whole-frame zero/undef store; array length counts slots, not words; initialization ignores the clamp (§13.4.11). | **Fixed** (`RecoverBasicStackFrame/*.ll`). |
| 15 | `RemoveTrivialPhisAndSelects` does not collapse self-referencing PHIs (`phi [%x, a], [%p, loop]`). | Kept (documented limitation). |
| 16 | Loads and stores created by lowering use the data layout's ABI alignment, not the access's real alignment. | Kept (documented limitation). |

---

## 14. The `anvill-decompile-spec` driver

Source: `bin/Decompile/Main.cpp`. Flags use gflags.

| Flag | Meaning |
|---|---|
| `--spec <path>` | Protobuf `specification.Specification`: binary, or text format when the name ends in `.textproto` or `.txtpb` (new). `/dev/stdin` or `-` reads stdin. (The help text used to say "JSON".) |
| `--ir_pre_opt <path>` | (new) write the IR after lifting and the lifter's local cleanup, before `OptimizeModule` |
| `--ir_out <path>` | write textual LLVM IR |
| `--bc_out <path>` | write bitcode |
| `--stats_out <path>` | `llvm::EnableStatistics()` before optimizing, then `PrintStatisticsJSON`. This is where `CodeQualityStatCollector`'s `STATISTIC` counters show up. |
| `--add_breakpoints` | sets `options.add_breakpoints` (§10; **fixed:** it was declared but not wired; `lifter/flow/breakpoints`) |
| `--add_names` | after lifting, rename each function and variable to its spec symbol. On Apple triples a leading `_` is stripped. Functions that failed to lift are skipped (**fixed:** `setName` on a null `func` crashed). Since `OptimizeModule` can rename or replace entities, names of `sub_`/`var_` entities are re-applied after it through `lifter.AddressOfEntity`. |
| `--default_callable_spec <path>` | a binary protobuf **`specification.Function`** whose `callable` is used as the prototype for any call target without type info (`DefaultCallableTypeProvider`). If it fails to parse, the error is printed and the tool exits with an error (**fixed:** `maybe_default_callable.Value()` was still called and threw). |
| `--lift_list 0x..,0x..` | hex addresses separated by commas. Listed functions are lifted and all others are only declared. When empty, everything is lifted. |
| `--version` | git-derived version info (`libraries/version` / `cmake/git_watcher.cmake` → `Version.cpp`) |

Flow:

1. Read the file and create an `LLVMContext`. On LLVM < 15, call `enableOpaquePointers()`.
2. Create `Module("lifted_code")` and call `Specification::DecodeFromPB`.
3. Create the providers: `SpecificationTypeProvider` wrapped in a `ProxyTypeProvider` (or a `DefaultCallableTypeProvider`), `SpecificationControlFlowProvider` and `SpecificationMemoryProvider`.
4. Build `LifterOptions` with `pc_metadata_name = "pc"` and `stack_frame_recovery_options.stack_offset_metadata_name = "stack_offset"`. Everything else keeps its default:
   - state init `kGlobalRegisterVariablesAndZeroes`;
   - symbolic PC, SP and RA;
   - stack frame `kSymbolic`, max frame 8192, word = pointer size;
   - `should_remove_anvill_pc = true`.
5. `EntityLifter lifter(options)`. Then `ForEachFunction` → `LiftEntity` or `DeclareEntity`, and `ForEachVariable` → `LiftEntity`.
6. If `--ir_pre_opt` is set, write the IR now. Apply `--add_names` (skipping functions that failed to lift).
7. `OptimizeModule(lifter, module)`, then re-apply the names of `sub_`/`var_` entities.
8. Write the outputs. The exit code is non-zero on I/O errors, on a specification that fails to load (e.g. a
   duplicate function or override; see the `EXPECT-ERROR` cases) and on a bad `--default_callable_spec`.
   Individual function lift failures are only logged.

To reproduce the tool from scratch, a minimal command is:

```sh
anvill-decompile-spec --spec prog.pb --ir_out prog.ll --add_names --stats_out stats.json
anvill-decompile-spec --spec tests/golden/lifter/basic/increment.textproto --ir_out inc.ll --add_names
```

The integration scripts (`scripts/test-amp-challenge-bins.sh`, `test-angha-1k.sh`, `ci/*settings.json`) drive this tool over corpora of binaries, using specs produced by the external Ghidra plugin (`irene3`). See §15.12–15.13.

---

---

## 15. Python tooling (legacy spec generator)


Scope: `python/anvill/**`, `python/CMakeLists.txt`,
`python/install.cmake`, `setup.py`, `plugins/ida/anvill.py`, `parse_cspec/`,
`bin/Decompile/tests/**`, `ci/*`, `scripts/*`. Every claim below comes from reading the code.
Lines marked [verified] were also run in a sandbox, using a pure-Python harness that loads
`type.py`, `arch.py`, `loc.py` and `mem.py` without IDA or Binja.


### 15.0 Bottom line: the Python generator is stale and its output is incompatible with main


* **Output format.** `python -m anvill` writes JSON (`json.dumps(p.proto(), indent="  ")`).
  The IDA plugin also writes JSON. The JSON follows the *old* schema that
  `docs/SpecificationFormat.md` describes. Type fields in it are the char-string encoding
  from `docs/TypeEncoding.md`.
* **What main consumes.** `anvill-decompile-spec` (bin/Decompile/Main.cpp) calls
  `anvill::Specification::DecodeFromPB(context, buff)`. That function does
  `::specification::Specification::ParseFromString(pb)` (lib/Specification.cpp:318), which
  parses the **binary protobuf** wire format of `data_specifications/specification.proto`.
  There is no JSON path: no `JsonStringToMessage`, and the old `lib/JSON.cpp` is gone. A
  Python JSON file therefore fails with `"Failed to parse specification"`. The
  `--spec` flag's help text still says "Path to a JSON specification" (stale). The error
  message in the same file says "Protobuf specification file".
* **When it broke.** The JSON parser (`lib/JSON.cpp`, 1066 lines) and the string-type parser
  `TypeTranslator::DecodeFromString` were removed in commit 7f309bc on 2022-11-14,
  "Migrate to new spec format (#328)". That commit also deleted `bin/Specify`
  (anvill-specify-bitcode), the JSON test specs in `bin/Decompile/tests/specs/*.json`, and
  the CTest registration of roundtrip.py. The last commit that touches `python/` is 3e476b8
  on 2022-09-30, which added context_assignments. The README says to use tag
  `binja-final-version` for the open-source Binja generator. That tag is not present in
  this clone.
* **Docs are stale too.** `docs/SpecificationFormat.md` and `docs/TypeEncoding.md` still
  describe the JSON and char-string format. They match the Python output, with a few small
  discrepancies (§15.9), but they do not match the protobuf schema.
* **Build wiring is dead.**
  * `lib/CMakeLists.txt:191` adds the `python` subdir only `if (ANVILL_ENABLE_PYTHON3_LIBS)`.
    That option exists (`cmake/options.cmake`, default TRUE), so the subdir *is* added.
  * `python/CMakeLists.txt` installs the IDA plugin to `share/anvill/ida` and runs
    `install.cmake`, which calls `setup.py install`.
  * With `ANVILL_INSTALL_PYTHON3_LIBS` set, it adds a custom target `frontend_installer`
    that runs `setup.py install` (`--force --user --prefix=` outside a venv) at build time.
  * That target's dependency list omits `call.py`, `util.py` and `imageparser/*`.
    `setup.py` lists them correctly.
* **Not tested in CI.**
  * `bin/Decompile/tests/CMakeLists.txt` now only prints "TBD: Ghidra-generated
    specification tests".
  * `bin/Decompile/CMakeLists.txt` comments out `add_subdirectory("tests")`.
  * The AnghaBench step that used `python3 -m anvill` is commented out in
    `.github/workflows/build.yml`.
  * CI now generates specs with the closed-source "irene3" Ghidra plugin
    (`just install-irene3-ghidra`, Ghidra 10.1.5).

A reimplementation that targets main needs a translation from the JSON model to protobuf.
§15.9.3 gives the precise field-by-field mapping and lists the information that is lost or
missing.


### 15.1 Package layout and front-end selection


```
python/anvill/
  __init__.py      from .arch import *; try IDA (import ida_idp; from .ida import *)
                   except ImportError: try Binja (import binaryninja; from .binja import *)
                   else raise NotImplementedError("Could not find either IDA or Binary Ninja APIs")
  __main__.py      CLI (Binja only: does `import binaryninja as bn` unconditionally)
  arch.py          Arch ABC + AMD64Arch, X86Arch, AArch64Arch, AArch32Arch, Sparc32Arch, Sparc64Arch
  os.py            CC NewType(int) + OS ABC: LinuxOS, MacOS, WindowsOS, SolarisOS
  type.py          Type hierarchy + char-string serializer
  loc.py           Location (register | [base_reg+off] | [abs])
  function.py      Function ABC (proto())
  call.py          CallSite (proto())
  var.py           Variable (proto())
  mem.py           Memory (byte map -> coalesced ranges)
  program.py       Specification ABC (the "Program"): registries + proto()
  exc.py           AnvillException subclasses
  util.py          logging (DEBUG/INFO/WARN/ERROR/FATAL), config_logger, create_logger
  logging.ini      root logger WARNING -> stderr
  binja/           BNSpecification, BNFunction, BNExternalFunction, BNVariable, TypeCache,
                   CallingConvention (unused), table.py (jump targets), bninstruction.py
                   (IL predicates), xreftype.py
  ida/             IDASpecification, IDAFunction, IDAVariable, utils.py (segments/xrefs)
  imageparser/     ImageParser ABC, ELFParser (relocation->import thunk list)
```

`setup.py` does `os.chdir("python")` and then
`setuptools.setup(name="anvill", version="1.0.2", py_modules=[...every module...],
data_files=[('anvill', ['anvill/logging.ini'])], license "AGPL 3")`.

`util.py` logging quirk. It calls `logging.config.fileConfig(...)` without
`import logging.config`. Unless another module has already imported `logging.config`, this
raises AttributeError. The bare `except` then falls back to
`logging.basicConfig(level=ERROR, stderr)`. `config_logger(logfile, verbose)` works as
follows:
* It adds a FileHandler (mode "w") and lowers every non-file StreamHandler to ERROR.
* `verbose` sets the root logger to DEBUG.

This matters for roundtrip.py, which asserts that the spec generator writes nothing to
stderr.


### 15.2 CLI: `python -m anvill` (python/anvill/__main__.py, Binary Ninja headless)


#### 15.2.1 Flags (argparse)

| flag | meaning |
|--|--|
| `--bin_in PATH` (required) | input binary |
| `--spec_out PATH` (required) | output JSON file |
| `--log_file PATH` | log to this file (stream handlers then raised to ERROR) |
| `--verbose` | DEBUG logging |
| `--base_address HEX` | parsed with `int(s,16)`. Passed to `get_program`, which uses `bn.BinaryViewType.get_view_of_file_with_options(path, options={"loader.imageBase": base})`. Otherwise it uses `get_view_of_file(path)`. A bad value logs "The specified address it not valid" and returns 1. |
| `--entrypoint NAME|HEX` | restrict function definitions to the call-graph closure from this function |
| `--ignore_no_refs` | when mapping a variable's bytes, skip bytes at addresses whose BN data var has no code and no data refs |

#### 15.2.2 Algorithm

1. Configure the logger. `p = get_program(binary_path, base_address)` returns a
   `BNSpecification`. If that returns None, the program writes "FATAL: Could not initialize
   BinaryNinja's BinaryView" and returns 1.
2. Set `flist = bv.functions`.
3. Handle `--entrypoint`.
   * If no function has that name but `"_"+name` exists, it prepends `_` (Mach-O).
   * If a function has the name, it uses that function's `.start`. Otherwise it uses
     `int(entrypoint, 16)`.
   * It calls `bv.add_function(epoint)` and takes the first function whose start equals
     `epoint`. This can raise StopIteration if BN has not analysed the function yet.
   * It runs a worklist DFS over `curr.callees` into a set `newflsit`.
     `if curr in worklist: continue` is a no-op guard, so duplicate entries are possible
     but harmless.
   * It sets `flist = newflsit`.
4. For every function f in flist: `p.add_function_definition(f.start, True)`, meaning
   `add_refs_as_defs=True`. Exceptions are logged with ERROR plus a traceback and then
   ignored.
5. For every `s in bv.get_symbols()`, using `ea = s.address`, `name = s.name`:
   * Naming applies when `s.name != "_start"` or `bv.get_symbol_at(ea).name == s.name`:
     * If any section at ea is named `.extern`: `add_symbol(ea, name)`.
     * Else if `name == "main"`, or the binding is `GlobalBinding` or `WeakBinding`:
       `add_symbol(ea, name)`.
     * Else: `add_symbol(ea, f"{name}_{ea:x}")`. Local symbols get an address suffix.
   * Then dispatch on the symbol type:
     * `FunctionSymbol`: skip, since it was already handled.
     * `ExternalSymbol`: if `bv.get_data_var_at(ea).type` is a `bn.FunctionType`, call
       `add_function_declaration(ea, False)`. Otherwise call
       `add_variable_declaration(ea, False)`.
     * `LibraryFunctionSymbol`, `ImportedFunctionSymbol`, `ImportAddressSymbol`: skip
       (TODO).
     * Anything else (data symbols etc.): `add_variable_definition(ea, True, ignore_no_refs)`
       inside try/except with ERROR logging.
6. Write `json.dumps(p.proto(), indent="  ")` to `--spec_out` and return 0.

Note that `get_variable_impl` also calls `_try_add_symbol(address)`, which adds
`sym.full_name` with no suffix. A local data symbol can therefore get two names:
`foo` and `foo_4010`. `symbols` is a `defaultdict(set)`, so both are emitted.

`scripts/docker-spec-entrypoint.sh` sources `$VIRTUAL_ENV/bin/activate` and runs
`python3 -m anvill "$@"`. It is the ENTRYPOINT of the Dockerfile's `binja` stage. That stage
installs only gpg and unzip, and installs neither Binja nor the Python package, so it cannot
work as is.

#### 15.2.3 IDA plugin (plugins/ida/anvill.py)

* Registers the action `generate-anvill-spec-file` with hotkey **Ctrl+H**.
* Attaches the action to the disassembly-view popup through a `UI_Hooks`
  `finish_populating_widget_popup` hook. `update()` enables the action only for
  `BWN_DISASM`.
* `activate()` asks "Would you like to export all functions?" with
  `ask_yn(ASKBTN_YES, ...)`. Cancel returns 1.
* It calls `p = anvill.get_program()`, which goes through IDA `get_program(arch=None,
  os=None, maybe_base_address=None, cache=False)`.
* If the answer is No:
  * The current function at the screen ea is used, and the default file name is
    `<funcname>.json`.
  * It calls `p.add_function_definition(screen_ea)` with `add_refs_as_defs=False`.
* If the answer is Yes:
  * It loops over `idautils.Functions()` calling `add_function_definition(ea)`.
  * Failures print a message and the loop continues.
  * The default file name is `program.json`.
* It then shows `ask_file(True, hint, ...)` and writes
  `json.dumps(p.proto(), sort_keys=False, indent=2)`.


### 15.3 Core object model


#### 15.3.1 `Specification` (program.py): the "Program"

State. All maps are keyed by address.
```
_arch: Arch, _os: OS, _memory: Memory
_var_defs, _var_decls: Dict[int, Variable]
_func_defs, _func_decls: Dict[int, Function]
_control_flow_redirections: Dict[int src, int dst]
_control_flow_targets: Dict[int src, ControlFlowTargetList(source, destination_list, complete)]
_symbols: DefaultDict[int, Set[str]]
_call_sites: Dict[(func_ea, call_ea), CallSite]      # filled directly by BNFunction
```
Abstract methods: `get_context_assignments_for_addr(ea)`, `get_symbols_impl(ea)`,
`get_function_impl(ea)` and `get_variable_impl(ea)`.

Registry semantics. These rules are what keep the visit from recursing forever:
* `get_function(ea)` checks `_func_defs`, then `_func_decls`, then `get_function_impl`.
  Exceptions are re-raised as `type(e)(f"Error when trying to get function {ea:x}: ...")`.
  `get_variable` follows the same pattern.
* `add_function_definition(ea, add_refs_as_defs)`:
  1. `func = get_function(ea)`. If it returns None, return False.
  2. Set `ea = func.address()`, normalising to the function start.
  3. If ea is not yet in defs: delete it from decls, insert it into defs, then call
     `func.visit(self, True, add_refs_as_defs)`. The visit happens *after* insertion, which
     cuts cycles.
  4. Return True.
* `add_function_declaration`: inserts only if ea is in neither defs nor decls, then calls
  `visit(self, False, ...)`. The visit is a no-op for declarations.
* `add_variable_definition` and `add_variable_declaration` mirror these, with an extra
  `ignore_no_refs` argument passed to `var.visit`.
* `try_add_referenced_entity(ea, add_refs_as_defs=False, ignore_no_refs=False)`:
  1. If `add_refs_as_defs`: try a function definition, which swallows
     `InvalidFunctionException`. If that fails, try a variable definition, which swallows
     `InvalidVariableException`.
  2. Then try a function declaration. If that fails, try a variable declaration. Return
     False on `InvalidVariableException`. Other exception types propagate.
* `add_control_flow_redirection(src, dst)`: stores the pair, then calls
  `try_add_referenced_entity(src, False)` and the same for dst, adding both as declarations.
* `set_control_flow_targets(src, dests, complete)`:
  1. Calls `try_add_referenced_entity` on src and on each dest, with `False`.
  2. If src is already present, returns False. The first set wins.
  3. Otherwise stores `[[dest, get_context_assignments_for_addr(dest)] ...]`.
* `add_symbol(ea, name)`: ignores empty names.

`proto()` builds the top-level JSON. Key order:
`arch, os, functions, variables, symbols, memory, control_flow_redirections,
control_flow_targets, call_sites`.
* `functions`: decls and defs merged into one list, sorted by `address`. There is **no
  flag** that tells a declaration from a definition. A definition is recognisable only
  because its bytes are in `memory`.
* `variables`: decls and defs merged, sorted by address.
* `symbols`: a list of `[ea, name]` tuples sorted by ea. These are tuples, not dicts, so
  that integers do not become JSON string keys.
* `memory`: `Memory.proto()`.
* `control_flow_redirections`: a list of `[src, dst]` sorted by src.
* `control_flow_targets`: a list of
  `{"source", "is_complete", "destinations": sorted([[dst, {ctx}]...])}` sorted by
  source. If the same dst address appears twice, the sort compares the dicts and raises
  `TypeError`. `table._extract_targets_from_jump_to` can produce duplicates because it
  appends all targets once per basic block at the address.
* `call_sites`: sorted by `(function_address, address)`.
* `arch` is `self._arch.name()`, evaluated at the **end**. The x86 and amd64 names change
  to `*_avx` or `*_avx512` as soon as any YMM or ZMM register name has gone through
  `register_name()` (sticky instance flag; §15.5).

#### 15.3.2 `Function` (function.py)

Constructor:
`Function(arch, address, parameters: List[Location], return_values: List[Location],
func_type: FunctionType, is_entrypoint=False, cc: CC=0, context_assignments={})`.
* There is a shared mutable default for `context_assignments`. It is not mutated, so this
  is harmless.
* It asserts that each param and return Location has a non-void, non-function type.
* For more than one return value it builds a `StructureType` and then discards it (dead
  code).

Methods:
* `is_variadic()` returns `self._type.is_variadic()`.
* `is_noreturn()` returns False and is overridden by subclasses.
* `is_external()` returns False.

`proto()`:
```python
{
  "address": ea,
  "return_stack_pointer": arch.return_stack_pointer_proto(type.num_bytes_popped_off_stack()),
  "is_variadic": bool, "is_noreturn": bool, "calling_convention": int(cc),
  ["context_assignments": {"TMReg": 0|1}]          # only if non-empty
  ["return_address": arch.return_address_proto()]  # omitted when is_entrypoint
  # if params or returns non-empty:
  "parameters": [loc.proto(arch)...], "return_values": [loc.proto(arch)...]
  # else:
  "type": func_type.proto(arch)                    # char-string function type
}
```
The old C++ JSON parser gave "type" precedence and synthesised a declaration from it with
`FunctionDecl::Create(dummy llvm::Function)`.

#### 15.3.3 `CallSite` (call.py)

Constructor:
`CallSite(arch, address, func_address, parameters, return_values, is_variadic=False,
is_noreturn=False, cc=0, call_stack_adjustment=0)`.

`proto()` always emits every field:
```
{"address", "function_address",
 "return_stack_pointer": arch.return_stack_pointer_proto(call_stack_adjustment),
 "is_variadic", "is_noreturn", "calling_convention",
 "return_address": arch.return_address_proto(),
 "parameters": [...], "return_values": [...]}
```

#### 15.3.4 `Variable` (var.py)

`Variable(arch, address, type_)` with `proto()` returning
`{"address": ea, ["type": type.proto(arch)]}`.

#### 15.3.5 `Location` (loc.py)

Slots: `_register`, `_mem_base_register`, `_mem_offset`, `_name`, `_type`.
* `set_register(r)`: raises `InvalidLocationException` if r is None, and asserts the
  location is still empty.
* `set_memory(base, off)`: raises if base is None.
* `set_absolute_memory(addr)`: sets the offset only.
* `set_name(n)` and `set_type(t)`.

`proto(arch)`:
* `{"register": R}`, or
* `{"memory": {"register": base, "offset": off}}`, or
* for absolute addresses, `{"memory": {"register": "MEMORY", "offset": addr}}`. The old C++
  parser treated `"MEMORY"` as "no base register".
* Then optional `"name"` and `"type"` (a char string).
* An empty location raises "Can't get prototype of empty location".

#### 15.3.6 `Memory` (mem.py)

* `_bytes: Dict[ea, (val&0xFF, can_write, can_exec)]`.
* `map_byte(ea, val, w, x)` overwrites any earlier entry for ea.
* `proto()` walks the addresses in sorted order. It starts a new range when permissions
  differ or when `prev.address + len(prev.data)/2 != ea`, which detects gaps.
* Each range is `{"address", "is_executable", "is_writeable", "data": lowercase hex}`.
* Readability is implicit. [verified] Bytes 0x1000..0x1003 RX, 0x1004 RWX and 0x1010 R give
  3 ranges: `554889e5`, `c3`, `00`.

#### 15.3.7 `OS` (os.py): calling-convention constants

These equal LLVM `CallingConv::ID` numbers.
* Named constants: `DEFAULT_CC=0`, `X86_CDECL_CC=0`, `X86_STDCALL_CC=64`,
  `X86_THISCALL_CC=70`, `AARCH32_CDECL_CC=48`.
* 48 is **not** a standard LLVM ID. LLVM's `ARM_AAPCS` is 67.

`name()` / `default_calling_convention(arch)`:

| OS | name | x86 | amd64 | other |
|--|--|--|--|--|
| LinuxOS | linux | 0 | 78 (X86_64_SysV) | 0 |
| MacOS | macos | 0 | 78 | 0 |
| WindowsOS | windows | 64 (stdcall) | 79 (Win64) | 0 |
| SolarisOS | solaris | 0 | 0 | 0 |

`default_calling_convention` compares `arch.name()` with "x86" or "amd64" exactly, so the
`_avx` variants fall through to 0. Only the IDA path uses these defaults. **The Binja path
never passes `cc`**, so every Binja function and call site has `calling_convention: 0`.


### 15.4 Type model and char-string encoding (type.py)


`Type` ABC methods: `size(arch)`, `serialize(arch, ids: Dict[Type,int]) -> str`,
`proto(arch) = serialize(arch, {})`, `flatten(arch, out_list)` and `unaliased_type()`.
Each top-level `proto()` call gets a fresh `ids` table, so structure ids restart at 0 per
type string.

| Class | Encoding | size | Notes |
|--|--|--|--|
| `VoidType` (singleton) | `v` | raises UnhandledTypeException | flatten raises |
| `PointerType` | `*` | `arch.pointer_size()` | **Opaque**: the element type is stored but never serialized. The C++ encoder also emits a bare `*` (opaque pointers since #296). The docs' `**b` / `*%0` examples are obsolete. |
| `IntegerType(size, signed)` (interned per key) | 1:`b`/`B`, 2:`h`/`H`, **3**:`w`/`W`, 4:`i`/`I`, 8:`l`/`L`, 16:`o`/`O` (lowercase = signed) | size | Other sizes raise UnhandledTypeException. The interning cache means `IntegerType(4,True) is IntegerType(4,True)`. |
| `FloatingPointType(size)` (interned) | 2:`e`, 4:`f`, 8:`F`, **10:`d`, 12:`D`**, 16:`Q` | size | Other sizes raise. |
| `CharacterType(is_signed=None)` | `c` (None), `s` (True), `S` (False) | 1 | **Broken**: subclasses IntegerType, whose `__new__(cls,size,is_signed)` is called with the wrong arity. `CharacterType()` and `CharacterType(False)` raise TypeError [verified]. Only the IDA path uses it. |
| `BoolType` (singleton AliasType over `B`) | `?` | 1 | |
| `MMXType` | `M` | 8 | |
| `ArrayType` (SequentialType) | `[<elem>x<N>]` | elem*N | defaults: elem `B`, N=1. `set_num_elements` allows 0 (variable-length objects). |
| `VectorType` | `<<elem>x<N>>` | elem*N | |
| `PaddingType` | `p` repeated N times | N | N must be >0. |
| `StructureType` | `=<id>{<elems...>}`, or `%<id>` if already in `ids` | sum of elems, or 1 if empty | An empty struct serializes as `=<id>{B}`. **Every** struct gets an `=N` id even when it is not recursive. |
| `UnionType` | `=<id>{<one member>}` | max member size (min 1) | **Bug**: `serialize` and `flatten` never update `max_size`, so they pick the *last* member with size >= 1, not the largest. `size()` is correct. [verified] union{uint64; uint8} gives `=0{B}` while `size()` is 8. |
| `FunctionType` | `(` params, then `&` if variadic, `)`. With no params: `&` if variadic else `v`. The return type comes last. | raises NotImplementedError | Also carries `_num_bytes_popped_off_stack` (excluding the return address) and `is_variadic`. |
| `AliasType` / `EnumType` / `TypedefType` | transparent: serializes the underlying type | underlying | AliasType defaults to `i`. `EnumType` is used with an underlying `IntegerType(width, False)`. |

Examples [verified]:
* `struct{int; struct pair{int,int}; pair; bool; pad[3]}` gives `=0{i=1{ii}%1?ppp}`. The
  second use of the same struct object becomes the back-reference `%1`.
* `long long[256]` gives `[lx256]`.
* `int printf(const char*, ...)` gives `(*&i)`.
* `void(void)` gives `(vv)` and `void(...)` gives `(&v)`.
* `<float x4>` gives `<fx4>`.
* enum (4 bytes) gives `I`.
* All integers in order: `bBhHwWiIlLoO`. All floats: `efFdDQ`.

`Type.extract(arch, offset, size)` is used only by IDA for scattered and register-pair
locations. It is **effectively broken**: the loop appends to `elem_types`, the flatten
list, instead of `out_types`, and the result is built from `elem_types`. The function
therefore works only when `offset==0` and `size >= self.size()`; it pads with `p` when the
type is smaller.
* [verified] `{iiL}.extract(0,16)` gives `=0{iiL}`.
* `i.extract(0,8)` gives `=0{ipppp}`.
* `{iiL}.extract(0,8)`, `L.extract(0,4)` and `L.extract(4,4)` raise
  UnhandledTypeException.


### 15.5 arch.py: register tables, return-address and SP protos


Each Arch provides the following:
* `name()`, `program_counter_name()`, `stack_pointer_name()`, `pointer_size()`.
* `stack_offset()`, which is unused by the visible code.
* `return_address_proto()` and `return_stack_pointer_proto(n_popped)`.
* `register_name(raw)`: strips a leading `%`, upper-cases (lower-cases on SPARC), and
  returns the name if it is in `_REG_FAMILY`, else **None**.
* `register_family(reg)`: returns a tuple of `(name, byte_offset, byte_size)` tuples for the
  whole register family, ordered by **descending size**. IDA uses it to pick the sub-register
  whose size equals the value type size at a given offset.

Register names are emitted verbatim. They are meant to equal remill's register names:
uppercase for x86, amd64 and ARM, lowercase for SPARC. `remill::Arch::RegisterByName`
resolves them on the C++ side.

| Arch | name() | PC | SP | ptr | stack_offset | return_address_proto | return_stack_pointer_proto(n) |
|--|--|--|--|--|--|--|--|
| AMD64Arch | `amd64`, `amd64_avx` or `amd64_avx512` | RIP | RSP | 8 | 8 | `{"memory":{"register":"RSP","offset":0},"type":"L"}` | `{"register":"RSP","offset":abs(n)+8,"type":"L"}` |
| X86Arch | `x86`, `x86_avx` or `x86_avx512` | EIP | ESP | 4 | 4 | `{"memory":{"register":"ESP","offset":0},"type":"I"}` | `{"register":"ESP","offset":abs(n)+4,"type":"I"}` |
| AArch64Arch | `aarch64` | PC | SP | 8 | 0 | `{"register":"LP","type":"L"}` | `{"register":"SP","offset":abs(n),"type":"L"}` |
| AArch32Arch | `aarch32` | PC | SP | 4 | 0 | `{"register":"LR","type":"I"}` | `{"register":"SP","offset":abs(n),"type":"I"}` |
| Sparc32Arch | `sparc32` | pc | o6 | 4 | 92 | `{"register":"o7","type":"I"}` | `{"register":"o6","offset":0,"type":"I"}` (ignores n) |
| Sparc64Arch | `sparc64` | pc | o6 | 8 | 2227 | `{"register":"o7","type":"L"}` | `{"register":"o6","offset":0,"type":"L"}` (ignores n) |

AVX detection. In both x86 classes, `register_name()` sets `self._has_avx512 = True` when
the upper-cased name starts with `ZMM`, and `self._has_avx = True` when it starts with `YMM`.
This happens for any lookup, including failed ones. `name()` prefers avx512, then avx.

Register families:
* **AMD64**:
  * `rX` for A/B/C/D: `(RxX,0,8)(ExX,0,4)(xX,0,2)(xH,1,1)(xL,0,1)`.
  * `rI` for SI/DI/SP/BP/IP: `(Rx,0,8)(Ex,0,4)(x,0,2)(xL,0,1)`. IP has no IPL (noted in
    source), and the key "IPL" is absent from the table.
  * `rN` for R8..R15: `(Rn,0,8)(RnD,0,4)(RnW,0,2)(RnB,0,1)`.
  * `xN` for 0..31: `(ZMMn,0,64)(YMMn,0,32)(XMMn,0,16)`.
  * `MM0..7` are 8 bytes.
  * `ST0..7` are `(STn,0,10)(STn,0,12)(STn,0,16)`.
  * Keys cover every alias (AL/AH/AX/EAX/RAX, SIL/SI/ESI/RSI, ..., R8B/R8W/R8D/R8,
    XMMn/YMMn/ZMMn, MMn, STn). There are no flags, segment or control registers, so
    BN's `eflags`, `fsbase` and similar map to None.
* **X86**: the same without the R* forms and without R8–R15. It still includes XMM, YMM
  and ZMM 0..31 (too many for 32-bit, harmless), MM and ST.
* **AArch64**:
  * `Xn` is `(Xn,0,8)(Wn,0,4)` for n=0..29.
  * X30 is `(LP,0,8)(X30,0,8)(WLP,0,4)(W30,0,4)`, with keys X30, LP, W30 and WLP. remill
    calls the link register `LP`. **"LR" is not a key**, even though the docs use "LR".
  * SP is `(SP,0,8)(WSP,0,4)`.
  * ZR is `(ZR,0,8)(WZR,0,4)` with keys XZR and WZR. Note that the family's first name is
    "ZR".
  * PC is 8 bytes.
  * `Vn` for 0..31 is `(Vn,0,16)(Qn,0,16)(Dn,0,8)(Sn,0,4)(Hn,0,2)(Bn,0,1)`, with keys
    V, Q, D, S, H and B for every n.
  * `TPIDR_EL0` and `TPIDRRO_EL0` are 8 bytes.
  * The binja helper `should_ignore_register` lists XZR and WZR as ignorable for aarch64,
    but nothing calls it.
* **AArch32**:
  * `_REG_FAMILY_Rn = lambda l: (("R{}".format(l),0,8))` has **no trailing comma**, so each
    R0..R12 family is a bare 3-tuple `("Rn",0,8)` and not a tuple of tuples. It also uses
    size **8** for 32-bit registers.
  * R13/SP, R14/LR and R15/PC are bare tuples `("SP",0,8)` etc. in the same way.
    `register_name()` works, but `register_family()` iteration is broken. Only IDA iterates
    it.
  * `Qn` for 0..15 is `(Qn,0,16)(D2n,0,8)(D2n+1,8,16)(S4n..S4n+3, 0/4/8/12, 4/8/12/16)`.
    The third element here looks like an *end offset* rather than a size, which is
    inconsistent with the other tables.
  * D0..D31 and S0..S31 map into the Q families.
* **SPARC32**:
  * g0–7, l0–7, i0–7 and o0–7 are 4 bytes.
  * `o6` and `sp` share one family `(sp,0,4)(o6,0,4)`, and `i6` and `fp` share
    `(fp,0,4)(i6,0,4)`.
  * pc and npc are 4 bytes.
  * The FP families q0..q28 (step 4) contain d and f subregisters. The f, d and q keys map
    into them.
* **SPARC64**: the same with 8-byte integer registers, plus q32..q60 and d32..d62. Those
  families use `_qXv9` and have no f registers.

Calling-convention handling:
* **Binja** (`binja/callingconvention.py`): a `CallingConvention` class wraps BN's
  cc. It has int and float arg-reg lists, overrides the float args for cdecl and sysv from
  `_FLOAT_ARGS_REGS` (x86: st0–st7, x86_64: xmm0–7, armv7: r0–r3, thumb2: s0–s7,
  aarch64: v0–v7), and has `next_int_arg_reg` and `next_float_arg_reg`.
  * It is **unused**: the use in `_get_function_parameters` is commented out.
  * It is also buggy: it reads `self._cc.int_arg_regs` before the `if self._cc is None`
    fallback.
* **IDA** `_get_calling_convention(arch, os, ftd)` returns `(cc, is_variadic)`, starting
  from `is_variadic = ftd.is_vararg_cc()`. The bit tests are evaluated in this order:
  STDCALL, CDECL, ELLIPSIS, THISCALL.
  * x86: STDCALL gives 64. CDECL gives 0. ELLIPSIS gives `(0, True)`. THISCALL gives 70.
    Anything else gives the OS default.
  * amd64: STDCALL, CDECL and ELLIPSIS all give the OS default, with ELLIPSIS forcing
    variadic. THISCALL gives 70. Anything else gives the default.
  * aarch32: CDECL gives 48. Anything else gives the default.
  * Other architectures: the default.

  The tests are `(cc & MASK) == MASK`, so overlapping bit patterns can match more than one
  case.


### 15.6 How a Binary Ninja database is walked (python/anvill/binja)


#### 15.6.1 BNSpecification (bnprogram.py)

Construction:
* `_get_arch(bv)` maps `bv.arch.name` to an Arch class:
  * `x86_64` → AMD64Arch
  * `x86` → X86Arch
  * `aarch64` → AArch64Arch
  * `armv7` and `thumb2` → AArch32Arch
  * anything else → `UnhandledArchitectureType`

  No SPARC support exists on the Binja side.
* `_get_os(bv)` checks `str(bv.platform)` for the substrings "linux", "mac" and "windows".
  Anything else raises `UnhandledOSException`.
* `_is_ELF_exe = "ELF" in str(bv.view_type) and bv.executable`.
* It creates `TypeCache(arch, bv)` and then `_init_func_thunk_ctrl_flow()`. A failure
  there is logged at WARN and otherwise ignored.

`get_context_assignments_for_addr(ea)` finds the first function containing ea and returns
`get_entry_assignments(func)`:
* `{"TMReg": 1}` if `func.arch` is `thumb2` or `thumb2eb`.
* `{"TMReg": 0}` if it is `armv7` or `armv7eb`.
* `{}` otherwise.

`BNFunction` also passes these assignments as the function's `context_assignments`.

`get_variable_impl(addr)`:
1. `bn_var = bv.get_data_var_at(addr)`.
2. If that is None, try `get_previous_data_var_before(addr)`. If that variable strictly
   contains addr, recurse on its start address. Otherwise raise `InvalidVariableException`.
3. Call `_try_add_symbol(addr)`, which adds `sym.full_name`.
4. Set `var_type = type_cache.get(bn_var.type)`. A `VoidType` is replaced by
   `ArrayType()`, whose defaults are elem `B` and N=1, giving `[Bx1]`.
5. Return `BNVariable`.

`get_function_impl(ea)` tries these in order:
1. `bv.get_function_at(ea)`.
2. Each function in `get_functions_containing(ea)`. Failures are skipped by remembering
   `last_start`.
3. If the symbol at ea is an `ExternalSymbol` whose data var has a `bn.FunctionType`:
   `BNExternalFunction(sym, var, arch, ea, type_cache.get(var.type))`.
   `ImportedFunctionSymbol` and `LibraryFunctionSymbol` are TODO.
4. Otherwise return None.

`_get_function_from_bnfunction(ea, bn_func)`:
1. Set `func_type = type_cache.get(bn_func.function_type)`. If it is not a FunctionType,
   raise `InvalidFunctionException`.
2. Compute `is_entrypoint = _is_ELF_exe and bv.entry_function == bn_func`. If true,
   `return_address` is omitted from the output. The comment notes this can be a false
   positive on shared objects.
3. Compute `is_external` from the symbol type (Imported, Library or External).
4. Compute the return values with `ret_type = type_cache.get(bn_func.return_type)` and
   `use_type = not void`.
   * If the type is non-void, set
     `ret_regs = [arch.register_name(r) for r in bn_func.return_regs]`.
   * If there is exactly one register, set `use_type = False` and create one register
     Location with the full ret_type.
   * Any exception sets `use_type = True`. This includes `set_register(None)` for an
     unknown register.
5. Compute the parameters with `_get_function_parameters`. An
   `InvalidParameterException` sets `use_type = True`.
6. If `use_type`, build `BNFunction(..., [], [], func_type)`. The output then contains only
   `"type"`. This happens for:
   * multi-register returns (for example EDX:EAX)
   * unknown registers
   * void parameters

   Otherwise build `BNFunction(params, rets, ...)`.
7. Note that `num_bytes_popped_off_stack` is never set on the Binja side, so
   `return_stack_pointer.offset` is always the pointer size. That is wrong for stdcall.

`_get_function_parameters(bn_func)` iterates over `bn_func.parameter_vars`:
* A variable with `var.type` None is skipped.
* For a `RegisterVariableSourceType`, the register name is
  `bv.arch.get_reg_name(var.storage)`.
  * A `VoidType` raises `InvalidParameterException`.
  * If `arch.register_name()` returns None, it raises `InvalidParameterException`.
  * Otherwise it creates a register Location.
  * The calling-convention conformance check is commented out. The source cites BN
    issues 2399 and 2400.
* For a `StackVariableSourceType`, it creates `Location.set_memory(SP, var.storage)`. BN's
  storage is the offset relative to SP at entry. On amd64 the first stack argument is at
  +8, above the return address at 0, which matches anvill's convention.
* No parameter names are set on the Binja side. Only IDA sets names.

`_init_func_thunk_ctrl_flow()` handles ELF import thunks and runs only when
`bv.view_type == "ELF"`:
1. Parse the file with `create_elf_image_parser(bv.file.filename)` to get
   `get_function_thunk_list()`, a list of `(start=r_offset, name)`. These are **GOT slot
   addresses** of STT_FUNC dynamic relocations.
2. For each thunk:
   * Read the pointer at the GOT slot with a little-endian `BinaryReader`, 32 or 64 bits
     according to `e_ident[EI_CLASS]`. In BN's view this is usually the address of the
     synthetic `.extern` symbol. Call it `redirection_dest`.
   * Take `bv.get_data_var_at(slot)`. If there is none, log DEBUG and continue.
   * For each `caller` in `var.code_refs`, and for each function containing
     `caller.address`:
     * If the thunk name equals the function name, or equals `name[1:]` (for example the
       BN PLT function `_printf` versus `printf`): call
       `add_control_flow_redirection(func.start, redirection_dest)`. The PLT stub's entry
       is redirected to the external.
     * If `caller.address` is an LLIL call (`_is_call_site`), call
       `set_control_flow_targets(caller.address, [dest], True)` and continue.
     * Otherwise call `get_jump_targets(bv, caller.address, slot)`. For each jump whose
       target list contains the slot, call `set_control_flow_targets(jump, [dest], True)`.
3. Log a WARN for every thunk that was not redirected, except `__libc_start_main`.

#### 15.6.2 BNFunction.visit (bnfunction.py)

The visit does work only for definitions. It does the following:
1. `_fill_bytes(program, mem, start, highest_address, ref_eas)`. For each basic block and
   each byte ea in `[bb.start, bb.end)`:
   * Look up the segment and read one byte.
   * Mark the byte executable if `seg.executable`, or if the segment is neither readable
     nor writable. That second rule is a workaround for BN's fake `.extern` section,
     which is mapped ---. Writability comes from `seg.writable`.
   * Call `memory.map_byte`.
   * If there is an LLIL instruction at ea and it is not LLIL_UNIMPL, call
     `_collect_xrefs_from_inst(bv, program, inst, ref_eas)`.

   Only basic-block bytes are mapped. Gaps between blocks, such as inline jump tables or
   padding, are not mapped.
2. Typed-register pass. For every LLIL instruction, `_extract_types(program,
   inst.operands, inst)` recurses through operands. For each non-temporary `ILRegister`
   other than `x87control` and `x87status`, it gets `inst.get_reg_value(name)`. If that is
   a `ConstantPointerValue` or `ExternalPointerValue` with a non-zero value, the value is
   yielded and added to `ref_eas`.
3. `_visit_calls(spec, tc, ref_eas)`. For every MLIL instruction that is a
   `MediumLevelILCallBase`, call `_visit_mlil_call`. Exceptions are logged with ERROR plus a
   traceback.
4. For each `ref_ea` with `bv.get_segment_at(ref_ea)` not None:
   `program.try_add_referenced_entity(ref_ea, add_refs_as_defs)`. Under the CLI this is
   True, so everything reachable becomes a definition, transitively.

`_collect_xrefs_from_inst(bv, program, item, ref_eas, reftype=XREF_NONE)` is a recursive
walk over LLIL/MLIL. Note that the list branch does not return, but its trailing type
check returns.
* Instructions that are UNIMPL or UNDEF are skipped.
* For a call (LLIL CALL, TAILCALL or CALL_STACK_ADJUST; MLIL CALL, TAILCALL or
  CALL_UNTYPED), set reftype to CONTROL_FLOW.
* For LLIL/MLIL JUMP or JUMP_TO, set reftype to CONTROL_FLOW. Then call
  `get_jump_targets(bv, inst.address)`, and for each `(jump_ea, targets)` with non-empty
  targets call `program.set_control_flow_targets(jump_ea, targets, True)`. **This is the
  only source of jump-table and indirect-jump targets.** They are always marked complete.
* For a LOAD, STORE or UNIMPL_MEM:
  * The memory operand is `inst.dest` for a store and `inst.src` otherwise.
  * reftype becomes MEMORY if the operand is a constant, and DISPLACEMENT otherwise.
  * The walk recurses into the memory operand with that reftype, and into all operands with
    reftype NONE.
* For a CONST_PTR:
  * If the address is in a `ReadOnlyCodeSectionSemantics` section and the reftype is not
    memory: add it.
  * Else if the address is in a ReadOnlyData or ReadWriteData section: add it.
* The walk then always recurses into the operands with the current reftype. For LLIL it
  also recurses into `inst.mlil` with reftype NONE.

`XrefType` constants: NONE 0, IMMEDIATE 1, DISPLACEMENT 2, MEMORY 3, CONTROL_FLOW 4.
`is_memory(reftype)` is true for {2, 3}.

`_visit_mlil_call(call, spec, tc, ref_eas)` builds a CallSite:
1. Determine `called_func_ea`. It is `call.dest` if that is an int, or the `.constant` of a
   `MLIL_CONST_PTR` or `MLIL_CONST`. If it is known:
   * Call `spec.add_function_declaration(ea, False)` and set
     `called_func = spec.get_function(ea)`. Add the address to `ref_eas`.
   * Collect `called_func_return_regs` from `bv.get_function_at(ea).return_regs.regs`
     through `arch.register_name`. Failing that, take the register locations of
     `called_func.return_values()`.
2. Compute the stack adjustment:
   * `stack_offset = bn_func.get_reg_value_at(call.address, arch.stack_pointer)`, which is
     SP relative to function entry.
   * `stack_adjust = abs(stack_offset.value)`, plus `arch.address_size` if
     `return_address_proto` has "memory", meaning the return address is pushed (x86 and
     amd64).
   * Negate it if `stack_offset.value > 0` (a stack that grows up).
   * A caller stack variable at entry-relative offset `storage` lies at callee-entry
     offset `storage + stack_adjust`.
3. Returns: `rets = [_var_to_loc(v, ...) for v in call.output]`, where `_var_to_loc` sets
   the type `tc.get(v.type)` and a register, or a stack slot at `v.storage + stack_adjust`.
   Other variable kinds raise `InvalidLocationException`. If there are more rets than
   `called_func_return_regs`, keep only the rets whose register is in that list, or that
   have no register. This works around aarch64 outputs such as x0..xzr.
4. Parameters:
   * If `len(call.params) == len(call.vars_read)`, use `vars_read` through `_var_to_loc`.
   * Otherwise go through `call.params` one by one:
     * `MLIL_VAR` uses `.src`.
     * `MLIL_SET_VAR` uses `.dest`.
     * `MLIL_VAR_FIELD` uses `.src`. The source comments that this is approximate.
     * `MediumLevelILConstBase` uses `_const_to_loc(p, arch, tc.get(p.expr_type),
       stack_adjust)`. This takes `p.llil`, or the last of `p.llils`:
       * An `LLIL_SET_REG_SSA` to a non-temporary register gives that register.
       * An `LLIL_STORE_SSA` uses `ll.mapped_medium_level_il`, an MLIL_VAR or
         MLIL_SET_VAR, through `_set_loc`.
       * Anything else raises.
     * Anything else raises `InvalidLocationException`.
5. If `called_func` is known, copy its `is_variadic`, `is_noreturn` and cc. If
   `len(rets) < len(called_func.return_values())`, replace rets with the callee's. Otherwise
   the cc stays `DEFAULT_CC`.
6. Create
   `CallSite(arch, call.address, bn_func.start, params, rets, is_variadic, is_noreturn, cc,
   bn_func.get_call_stack_adjustment(call.address).value)` and store it in
   `spec._call_sites[(func_start, call.address)]`.

`BNFunction.is_noreturn()` is `not to_bool(bn_func.can_return)`. `to_bool` returns
`b.value` only if `b.confidence >= 80% of max_confidence`; otherwise it returns
`default=False`. **A low-confidence can_return therefore yields is_noreturn=True.**
`BNExternalFunction` applies the same rule to `bn_var.type.can_return`. Its constructor
passes `False` positionally into the `is_entrypoint` slot.

#### 15.6.3 BNVariable.visit (bnvariable.py)

The visit does work only for definitions with a non-None, non-void type. For each
`ea in [addr, addr+type.size)`:
* Skip `ea == 0`. The comment says this keeps `_elf_header` and null references out.
* With `ignore_no_refs`, skip the byte if `bv.data_vars.get(ea)` exists with no code refs
  and no data refs. In practice this checks only the variable's own start address.
* Map the byte with `seg.writable`. Executability follows the same `.extern` workaround as
  in `_fill_bytes`.
* `seg` can be None, which would raise AttributeError.

Pointers inside variables are **not** followed. There is no data-xref recursion from
variables.

#### 15.6.4 TypeCache (typecache.py): BN type to anvill Type

Lookup order in `_convert_bn_type(tinfo)`:
1. If `tinfo.altname` or `tinfo.name` is in `_core_types`, return the core type:
   * `size_t` → `IntegerType(addr_size,False)`; `ssize_t` and `ptrdiff_t` → signed
     address-size integer.
   * `int8_t`..`int128_t` and `__int128` → signed; `uint8_t`..`uint128_t` and `__uint128`
     → unsigned.
   * `__m64` → MMXType.
   * `u_char`/`u_short`/`u_int`/`u_quad_t` and their `__u_*` variants → unsigned
     1/2/4/8 bytes.
   * `__ino64_t` → `L`.
2. `NamedTypeReferenceClass`: cached by `type_id` in `_named_cache`. Resolve with
   `target(bv)`. A None target gives VoidType.
3. If `str(tinfo)` is in `_cache`, return the cached value.
4. Otherwise dispatch on the type class:

| type class | result |
|--|--|
| Void | VoidType |
| Pointer | `PointerType`. It is cached *before* recursing into the target, which breaks cycles. |
| Function | FunctionType: return type, then parameters. A void parameter becomes `IntegerType(addr_size, False)` with a WARN. `has_variable_arguments` sets variadic. |
| Array | `ArrayType(elem, count)`, cached |
| Structure (union variant) | UnionType of all members; cached only if `registered_name` |
| Structure (struct or class) | byte-slot algorithm, described after the table |
| Enumeration | `EnumType` over `IntegerType(width, False)`, always unsigned; cached if named |
| Bool | BoolType `?` |
| Integer | width 10 or 12 → `FloatingPointType(width)`, because BN shows long double as int80_t. Otherwise `IntegerType(width, to_bool(signed))`. |
| Float | `FloatingPointType(width)` |
| VarArgs, Value, WideChar | WARN, then VoidType. A `wchar_t` member therefore becomes void and is then fudged. |
| anything else | `UnhandledTypeException` |

`_convert_typedef` is dead code.

Struct byte-slot algorithm:
1. Create `at_offset = [1]*width + [0]`. Keep only members with
   `offset + len(type) <= width`.
2. Cache the struct before converting its members, if it has a `registered_name`.
3. For each kept member:
   * Convert its type.
   * A void member goes to `skipped`.
   * A function member becomes a function-pointer type of address size.
   * A zero-length member uses the converted type's size. If that is still 0, the member
     is skipped.
   * Mark the member's bytes 0 and place the Type at its offset. Overlapping members
     (bitfields) overwrite.
4. For each skipped member:
   * Count the contiguous padding bytes still equal to 1 from its offset.
   * Fudge a type: `IntegerType(addr_size)` if `pad <= addr_size` and the offset is
     aligned, else 4, else 2, else 1, all unsigned.
   * Place it and WARN.
5. Replace each run of remaining 1-bytes with `PaddingType(run)`. Those serialize as `p`
   characters.
6. Collect the Types in offset order.

Example: `struct{int a; char c;}` with width 8 gives `=0{i?ppp}` if c is a bool, and
`=0{ibppp}` for an int8 member. A plain `char` in BN is int8 or uint8, never `c`.

`get(ty)`:
* None → VoidType.
* A Type → itself.
* A Function → `.type()`.
* A `bn.Type` → convert it.
* Anything else → raise.

#### 15.6.5 Jump-target recovery (binja/table.py)

`get_jump_targets(bv, inst_ea, entry_ea=BADADDR) -> Dict[jump_ea, List[target]]`:
1. If `is_jump_addr(bv, inst_ea)` (BN `arch.get_instruction_info` reports branches), set
   `jump_eas = [inst_ea]`. Otherwise use `_find_jumps_near(bv, inst_ea)`: for each basic
   block at the address, linear-decode from inst_ea to the first instruction with branches
   (16-byte reads).
2. For each jump, read its `info.branches`:
   * TrueBranch, FalseBranch and UnconditionalBranch append `branch.target`.
   * IndirectBranch and UnresolvedBranch set
     `branch_targets = _get_jump_targets_unresolved(bv, jump_ea)`.
3. `_get_jump_targets_unresolved`: for each function containing jump_ea, take the LLIL at
   jump_ea:
   * A TAILCALL uses `_extract_targets_from_tailcall`.
   * A JUMP uses `_extract_targets_from_jump`.
   * A JUMP_TO uses `_extract_targets_from_jump_to`, which reads `inst.targets`. This is
     BN's resolved jump table, appended once per basic block at the address.

   Zero addresses are filtered out.
4. The tailcall and jump extractors call `_evaluate_destination_expression(bv, inst,
   dest)`. If no target was found and the instruction is LLIL, they also recurse on
   `inst.mlil`:
   * `CONST_PTR` or `MLIL_IMPORT` gives `dest.constant`.
   * LOAD, STORE or UNIMPL_MEM gives `dest.value.constant` if that is a constant pointer.
   * An `LLIL_REG` (or a PUSH instruction) gives `inst.get_reg_value(reg)` if its type is
     ConstantPointer, ExternalPointer or ImportedAddress.

`bninstruction.py` is a set of trivial predicates over LLIL/MLIL operations:
`is_constant`, `is_constant_pointer`, `is_register_inst`, `is_function_call`,
`is_function_tailcall`, `is_jump`, `is_jump_to`, `is_load_inst`, `is_store_inst`,
`is_memory_inst`, `is_import_address`, `is_push_inst`, `is_unimplemented`,
`is_unimplemented_mem` and `is_undef`.


### 15.7 How an IDA database is walked (python/anvill/ida)


Front-end detection:
* `_guess_architecture()`:
  * `ax` and `xmm0` in `ph_get_regnames()` → amd64 or x86 by `inf.is_64bit()`.
  * `"ARM"` in procName → aarch64 or aarch32.
  * `"sparc"` → sparc64 or sparc32.
* `_guess_os()`:
  * ABI name "OSX" → macos.
  * Otherwise by filetype: ELF, AOUT and COFF → linux; MACHO → macos; PE, EXE and COM →
    windows.

`get_program(arch, os, maybe_base_address, cache)` returns
`IDASpecification(arch, os, base)`. The constructor:
* Rebases with `rebase_program(delta, MSF_FIXONCE)` if a base address was given.
* Calls `ida_auto.auto_wait()`.
* Calls `_init_func_thunk_ctrl_flow()`. This is ELF only and works as follows:
  1. For each thunk, read the GOT dword or qword (`redirection_dest`).
  2. Take `caller = get_first_cref_to(dest)` and `src = FUNCATTR_START` of that caller.
  3. If the thunk name is a substring of the caller function's name, add a redirection
     `src → dest`.
  4. Always call `set_control_flow_targets(caller, [dest], True)`.

`get_function_impl(ea)`:
1. Set `pfn = get_func(ea)`, or `get_prev_func(ea)`.
2. Raise `InvalidFunctionException` if the address is not contained in the function,
   unless the segment is an extern or import-table segment (`.idata`, `.plt` or `.got`
   in its name).
3. Get the function type with `tinfo` (`get_tinfo` or `guess_tinfo`), which must satisfy
   `is_func()`. Then `get_func_details(ftd)` and
   `_get_type(tif, TYPE_CONTEXT_FUNCTION)`.
4. Set `cc, is_variadic = _get_calling_convention(...)`.
5. For each argument, run
   `_expand_locations(arch, pfn, arg_type, funcarg.argloc, param_list)`, then name the
   locations.
   * A single location gets the argument's name.
   * For a split argument, the loop always calls `param_list[-1]` instead of
     `param_list[k]`. The **last** piece therefore ends up named `name_{n-1}` and the other
     pieces stay unnamed.
6. Build the return list with `_expand_locations(ret_type, ftd.retloc)`.
7. Set `is_entrypoint = (name == "_start")`.
8. Return `IDAFunction(..., ftd.is_noret(), func_type, cc, is_entrypoint)`.

`_expand_locations` cases:

| argloc | result |
|--|--|
| ALOC_STACK | `[SP + stkoff + (frame_off_args - frame_off_retaddr)]` |
| ALOC_DIST | recurse per part with `ty.extract(part.off, part.size)`. **Breaks**, because extract is broken (§15.4). |
| ALOC_REG1 | Look up the register name in `ph_get_regnames()[reg1].upper()`. If that fails, use `get_reg_name(reg1, ty_size)`. Then pick the family member with matching `regoff` and `size == ty_size`. For example IDA's `ax` with a 4-byte type becomes `EAX`. |
| ALOC_REG2 | Uses `itertools.product(family1, family2)` to find two offset-0 members whose sizes sum to ty_size. **`itertools` is never imported**, so this raises NameError, for example on x86 EDX:EAX returns. It also computes `ty.extract(...ty_size/2...)` with a float. |
| ALOC_RREL | `[addr-sized reg in the family of reg + off]` |
| ALOC_STATIC | absolute `MEMORY` location |
| anything else | `InvalidLocationException` |

`_convert_ida_type(tinfo, cache, depth, context)`. The contexts are NESTED 0, GLOBAL_VAR 1,
FUNCTION 2, PARAMETER 3 and RETURN 4. Any `depth > 0` forces NESTED. The cache is used only
in the NESTED and FUNCTION contexts.
* Pointers → PointerType.
* Functions → FunctionType. `is_purging_cc` sets `num_bytes_popped` from
  `calc_purged_bytes()`. Outside the NESTED and FUNCTION contexts the result is wrapped as
  a function pointer.
* Arrays with 0 elements:
  * In the GLOBAL_VAR context they become the element type. The comment explains that IDA
    gives strings the type `char[]`.
  * Otherwise they become a pointer.
* Other arrays → `ArrayType`.
* SSE types → `VectorType` of `B` x size.
* UDTs → a StructureType or UnionType of the members in index order. There is no padding
  or bitfield handling (TODO), so offsets are lost.
* Enums → EnumType over the base type.
* Bool → `?`.
* char and uchar → `CharacterType`. This **crashes with TypeError** (§15.4).
* Integral → `IntegerType(unpadded_size, signed)`.
* Floating:
  * Use the unpadded size if it is in {2, 4, 8, 10, 12, 16}.
  * Otherwise long double gives 10, double gives 8 and float gives 4.
* Complex → raises.
* Typerefs resolve through `get_realtype(True)`.

`get_variable_impl(ea)`:
1. `_invent_var_type`: walk back to the item head, then form `[Bx N]`, where N is at least
   the item size and is clipped to the next head in the same segment.
2. The variable's type is the `tinfo`, falling back to the invented type, through
   `_get_type(GLOBAL_VAR)`.
3. Add the symbol `_variable_name(ea)` if it has a name.

`IDAFunction.visit`:
1. Compute `_get_function_bounds`. These are deliberately loose: the range runs from the
   previous function's end to the next function's start, within an executable segment.
   They are tightened to `pfn` bounds only when there is no neighbouring function.
2. Map every byte with `_try_map_byte`:
   * Writability comes from `seg.perm & SEGPERM_WRITE`.
   * Executability comes from `_is_executable_seg`: the EXEC perm, or segment type
     CODE/XTRN, or a class containing "CODE" or "XTRN".
   * The value is 0 if the byte has no value.
3. Collect xrefs per byte:
   * Take crefs, drefs and fixup targets that lie in some segment and outside `pfn`.
   * `_add_real_xref` also adds `get_operand_value` for operands whose printed text
     contains the ref name. This covers `[foo+10]`.
4. Map function chunks with `func_tail_iterator_t` in the same way.
5. Call `_visit_ref_ea`, which runs `try_add_referenced_entity` and prints on failure.

`IDAVariable.visit` forces a definition for import-table segments, then **does nothing**.
The memory mapping is a TODO, so IDA specs contain no variable bytes.

The IDA path has **no call sites**, **no context_assignments** and **no jump tables**
other than the thunk targets. It never adds function symbols, and
`get_symbols_impl` returns None.


### 15.8 imageparser/elfparser.py


Purpose: find **ELF import thunks**, so the BN and IDA front-ends can redirect PLT stubs
and GOT-indirect calls to external symbols. The parser is pure Python, little-endian only,
and uses no libraries.

`ELFParser(path)` runs these steps in its constructor:
1. `_read_file_header()`:
   * Reads `e_ident[16]`. `get_image_bitness()` reads `e_ident[4]`: 1 gives 32, 2 gives 64,
     anything else raises NotImplementedError.
   * Then reads type, machine, version, entry, phoff, shoff, flags and the six u16 fields.
     entry, phoff and shoff are pointer-sized.
2. `_read_section_header_list()` reads `e_shnum` headers at `e_shoff`.
3. `_read_string_table()` reads the `.shstrtab` given by `e_shstrndx`, using a size
   truncated through `c_int32`.
4. `_parse_symbol_table()` reads `.dynsym` with entry size 16 (32-bit) or 24 (64-bit).
   * **The 64-bit path reads `st_shndx` as u32 instead of u16**, so st_value and st_size are
     misread. They are unused; only st_name and st_info matter.
5. `_process_function_thunks()`:
   * Read `.dynstr`.
   * For every section of type SHT_REL (9) or SHT_RELA (4): read the section data by name.
     The entry size is 8 or 16, plus 4 or 8 for RELA addends.
   * For each entry, read r_offset and r_info. The 64-bit symbol index is `r_info >> 32`.
   * **The 32-bit symbol index is never computed** (it stays 0). Index 0 is STN_UNDEF, not
     STT_FUNC, so **no thunks are ever found for 32-bit ELF**.
   * Keep entries where `(st_info & 0xF) == STT_FUNC (2)`. Each becomes
     `ImageFunctionThunk(start=r_offset /*GOT slot VA*/, name=dynstr name)`.

Quirks:
* `_section_header_list`, `_symbol_list`, `_function_thunk_list` and `_file_header` are
  **class-level** mutable attributes. A second ELFParser in the same process appends to the
  first one's lists.
* `MAX_STRING_LENGTH` is 2048.
* `_get_string_table_entry` returns None if there is no NUL within the limit.

`imageparser/__init__.py` defines:
* the `ImageFunctionThunk` dataclass (`start`, `name`)
* the abstract classes `ImageReader` and `ImageParser`
* `create_elf_image_parser(path)`


### 15.9 Concrete output and how it compares with the current spec format


#### 15.9.1 Example JSON (amd64 Linux, shape exactly as the Python emits it)

Values are illustrative but shaped exactly like the code's output. Here `main` is defined
and calls `f`, `printf` is an external declaration, and there is one global and one PLT
redirection.
```json
{
  "arch": "amd64",
  "os": "linux",
  "functions": [
    {"address": 4144, "return_stack_pointer": {"register": "RSP", "offset": 8, "type": "L"},
     "is_variadic": true, "is_noreturn": false, "calling_convention": 0,
     "return_address": {"memory": {"register": "RSP", "offset": 0}, "type": "L"},
     "type": "(*&i)"},
    {"address": 4400, "return_stack_pointer": {"register": "RSP", "offset": 8, "type": "L"},
     "is_variadic": false, "is_noreturn": false, "calling_convention": 0,
     "return_address": {"memory": {"register": "RSP", "offset": 0}, "type": "L"},
     "parameters": [{"register": "RDI", "type": "i"}, {"register": "RSI", "type": "*"}],
     "return_values": [{"register": "RAX", "type": "i"}]}
  ],
  "variables": [{"address": 16400, "type": "=0{ii}"}],
  "symbols": [[4144, "printf"], [4400, "main"], [16400, "a"]],
  "memory": [{"address": 4400, "is_executable": true, "is_writeable": false, "data": "f30f1efa..."},
             {"address": 16400, "is_executable": false, "is_writeable": true, "data": "000000002a000000"}],
  "control_flow_redirections": [[4128, 4144]],
  "control_flow_targets": [{"source": 4128, "is_complete": true, "destinations": [[4144, {}]]}],
  "call_sites": [
    {"address": 4420, "function_address": 4400,
     "return_stack_pointer": {"register": "RSP", "offset": 8, "type": "L"},
     "is_variadic": false, "is_noreturn": false, "calling_convention": 0,
     "return_address": {"memory": {"register": "RSP", "offset": 0}, "type": "L"},
     "parameters": [], "return_values": [{"register": "RAX", "type": "i"}]}
  ]
}
```
An old upstream example (`bin/Decompile/tests/specs/jmp_ret0.json`, deleted in 7f309bc)
also had a top-level `"stack": {"address", "size", "start_offset"}` object. The current
Python does not emit `stack`.

#### 15.9.2 Consistency with docs/SpecificationFormat.md and TypeEncoding.md (the old JSON docs)

Mostly consistent. Discrepancies:
* **AArch64 return address.** The doc example uses `{"register":"LR","type":"L"}`.
  The Python emits `"LP"`, which is remill's name. "LR" is not in the AArch64 table.
* **`w`/`W` size.** TypeEncoding.md lists 4 bytes. The Python uses **3** (int24), and the
  C++ dictionary uses `getIntNTy(24)`.
* **`d`/`D`.**
  * Python and TypeEncoding.md: `d` = 10 bytes, `D` = 12 bytes.
  * The C++ encoder (lib/Type.cpp) emits `d` when `X86_FP80` alloc size == 12, else `D`.
  * Type.h comments say `float80_12` → `d` and `float80_16` → `D`.
  * The three sources disagree.
* **Pointers.** The doc says `*` is followed by a pointee (`**b`, `=0{*%0i}`). The Python
  emits a bare opaque `*`.
* **Undocumented keys.** The doc does not list the `control_flow_redirections` or
  `call_sites` keys, nor a function's alternative `"type"` key. The Python emits all three.
* **Optional flags.** The doc says `is_variadic` and `is_noreturn` are optional. The Python
  always emits them.
* **Declarations versus definitions.** The doc: "a function whose address is not covered
  by any memory range is treated as an external declaration". The Python relies on exactly
  this, since it has no linkage flag.

#### 15.9.3 Mapping from Python JSON to specification.proto (what a translator must do, and what diverges)

| JSON (Python) | proto | Divergence / notes |
|--|--|--|
| `"arch": "amd64"` etc. | `Specification.arch: Arch` enum: X86=1, X86_AVX=2, X86_AVX512=3, AMD64=4, AMD64_AVX=5, **`ARCH_ADM64_AVX512`**=6 (typo in proto), AARCH64=7, AARCH32=8, SPARC32=9, SPARC64=10 | string to enum |
| `"os": "linux"` | `operating_system: OS` enum: LINUX=1, MACOS=2, WINDOWS=3, SOLARIS=4 | field renamed |
| `functions[]` | `Function{entry_address, context_assignments map<string,uint64>, func_linkage, callable: Callable}` | The Python has no linkage. A translator needs `_func_defs` → `FUNCTION_LINKAGE_NORMAL_UNSPECIFIED`, `_func_decls` → `DECL`, and `is_external()` → `EXTERNAL`. That information is lost in the JSON, because decls and defs are merged into one list. |
| `address` | `entry_address` | renamed |
| `return_address` `{memory:{register,offset}, type}` | `Callable.return_address: Value` (`oneof reg{register_name}` / `mem{optional base_reg, offset}`) | **There is no type.** C++ uses an integer of `arch->address_size`. The entrypoint omits the field, which is still supported (`has_return_address`). |
| `return_stack_pointer` `{register, offset, type}` | `ReturnStackPointer{reg: Register, optional offset}` | The type is dropped. The field is **required** by C++. |
| `is_variadic`, `is_noreturn` | `Callable.is_variadic`, `is_noreturn` | same |
| `calling_convention: int` | `CallingConvention` enum: UNSPECIFIED=0, **CDECL=1**, STDCALL=64, FASTCALL=65, THISCALL=70, AMD64_SYSV=78, WIN64=79, VECTORCALL=80 | C++ does `static_cast<llvm::CallingConv::ID>(value)`, so the numbers must be LLVM IDs. The Python's 0 lands on UNSPECIFIED = llvm C (fine). The proto's CDECL=1 is *not* an LLVM ID. The Python's 48 (AArch32 via IDA) is not an enum member. proto3 keeps unknown values, but 48 is not a meaningful LLVM CC either. |
| `parameters[]` `{register \| memory, name?, type}` | `Parameter{optional name, repr_var: Variable{repeated Value values, TypeSpec type}}` | C++ requires `values_size()==1` per parameter. A split parameter must stay as several Parameters, as the Python already does. `MEMORY` base becomes an absent `base_reg`. |
| `return_values[]` (one type per location) | `Callable.return: optional Variable{values[], type}` | **A single TypeSpec for all values.** C++ decodes each value with that same type (Protobuf.cpp ~L208), so one-type-per-location cannot be expressed. Multi-location returns would need a struct type, and the C++ would still assign the whole type to each value. |
| `"type": "(…)"` (fallback when there are no params or rets) | `Callable.type: optional TypeSpec` (function) | The string needs a full parse into TypeSpec. C++ checks that `is_variadic` equals the type's variadic flag. |
| `context_assignments {"TMReg":0/1}` | `Function.context_assignments` | same |
| `variables[] {address, type}` | `global_variables[] GlobalVariable{type: TypeSpec, address}` | renamed. The decl/def distinction is again implicit through memory. |
| `symbols [[ea, name]]` | `symbols[] Symbol{name, address}` | tuple to message. Empty names are rejected by C++. The Python never emits empty names. |
| `memory[] {address, is_writeable, is_executable, data: hex}` | `memory_ranges[] MemoryRange{address, is_writeable, is_executable, bytes values}` | hex becomes raw bytes. C++ rejects overlapping ranges, which the Python never produces because its byte map is unique. |
| `control_flow_targets[] {source, is_complete, destinations:[[ea,{ctx}]]}` | `overrides.jumps[] Jump{address, targets[] JumpTarget{address, context_assignments}, bool stop}` | **`is_complete` has no equivalent.** `stop` means "stop lifting here" and is different. C++ requires `overrides` to be present ("Spec has no control flow overrides"), so even an empty spec must carry an empty `ControlFlowOverrides`. |
| `control_flow_redirections [[src,dst]]` | **none** | `SpecificationImpl::redirections` still exists in C++ and is iterated by `ForEachControlFlowRedirection`, but nothing in `ParseSpecification` fills it. The closest proto construct is `overrides.calls[] Call{address, optional return_address, is_tailcall, stop, optional target_address}`, for example a tail call at the PLT `jmp [GOT]` with `target_address=dst`. The Python emits nothing like it. |
| `call_sites[] {address, function_address, + callable fields}` | `callsites[] Callsite{call_address, inside_function_address, callable}` | field renames |
| (none) | `overrides.returns[]`, `overrides.others[]`, `overrides.calls[]` | The Python never produces these. |
| (none) | `type_aliases map<int64, TypeSpec>` | needed to express the recursive `=N`/`%N` structs (see the type mapping below) |

Char-string type to `TypeSpec`. This is what a converter would do:

| letter | proto `BaseType` |
|--|--|
| `?` | BT_BOOL=0 |
| `c` | BT_CHAR=1 |
| `s` | BT_SCHAR=2 |
| `S` | BT_UCHAR=3 |
| `b` | BT_I8=4 |
| `B` | BT_U8=5 |
| `h` | BT_I16=6 |
| `H` | BT_U16=7 |
| `w` | BT_I24=8 |
| `W` | BT_U24=9 |
| `i` | BT_I32=10 |
| `I` | BT_U32=11 |
| `l` | BT_I64=12 |
| `L` | BT_U64=13 |
| `o` | BT_I128=14 |
| `O` | BT_U128=15 |
| `e` | BT_FL16=16 |
| `f` | BT_FL32=17 |
| `F` | BT_FL64=18 |
| `d` | BT_FL80=19 |
| `D` | BT_FL96=20 |
| `Q` | BT_FL128=21 |
| `M` | BT_M64=22 |
| `v` | BT_VOID=23 |
| `p` | BT_PADDING=24 (one per byte) |

* `*` becomes `pointer{}` with no pointee. C++ then defaults the pointee to Void; `const`
  is false.
* `[Tx N]` becomes `array{base, size}` and `<Tx N>` becomes `vector{base, size}`.
* `=N{…}` becomes `struct{members, identifier=N?}`.
* `%N` has no inline form. Use `alias = K`, with the struct placed in
  `type_aliases[K]`. C++ resolves it with `type_map.at(alias)`.
* `(…)` becomes `function{return_type, arguments, is_variadic}`. `v` as the sole parameter
  means no arguments, and `&` sets is_variadic.
* The proto has an `unknown: uint32 size` with no char-string equivalent. Ghidra's
  UINT32_MAX special case becomes i32.
* The C++ `DecodeType` function branch never `return`s its result. It falls through to the
  alias and error path, which looks like a C++ bug in Protobuf.cpp ~L432. Flagged for the
  C++ author.

Other proto-only features:
* `Variable.values` (repeated) allows multi-location variables.
* `PointerType.const`.

Python-only information:
* types on return address and SP
* `is_complete`
* redirections


### 15.10 parse_cspec (Ghidra .cspec to default-callable JSON)


`parse_cspec/src/main.py` uses BeautifulSoup with the lxml "xml" parser. The Pipfile asks
for Python 3.9 with `beautifulsoup4` and `lxml`; the lock has bs4 4.10.0 and lxml 4.9.1.
* It was introduced in 345af48, "Ian/abi guess type provider (#278)", together with
  `anvill-decompile-*`'s `--default_callable_spec`.
* Usage: `python main.py <target.cspec> <out.json>`, with the argparse description
  "Translates cspec default prototypes into json specs".

Algorithm:
1. `target_proto = soup.default_proto.prototype` and
   `pointer_size = soup.data_organization.pointer_size["value"]`.
2. Build the output object with `json.dump(func, indent=4, sort_keys=True)`:
   * `is_noreturn: false`, `calling_convention: 0`, `is_variadic: false`.
   * `parameters` = `<input>` pentries, `return_values` = `<output>` pentries. For each
     `<pentry>` that has a `<register>` child, emit
     `{"register": trim(reg.name), "type": gen(maxsize, metatype=="float")}`.
     * `trim` drops anything from `"_Qa"` on, so `XMM0_Qa` becomes `XMM0`.
     * Stack pentries (no register) are **dropped**, which is why the x86 example has
       `"parameters": []`.
   * `gen(sz, is_float)`:
     * 0 gives `v`.
     * For floats: `{2:e, 4:f, 8:F, 10:d, 12:D}`.
     * Otherwise integers `{1:c, 2:h, 4:i, 8:l, 16:o}`. 1 byte becomes **char `c`**, and
       all integers are signed.
     * Anything else gives `"{" + "p"*sz + "}"`.
   * `return_address`:
     * If `<returnaddress>` exists and has a `<register>`, it emits
       `{"register": ret_addr.name, ...}`. **Bug**: `ret_addr.name` is the XML tag name
       ("returnaddress"), not the register name.
     * If it has a stack varnode, it emits
       `{"memory": {"register": <stackpointer register>, "offset": varnode.offset},
       "type": gen(varnode.size)}`.
     * If `<returnaddress>` is absent, it emits `{"memory":{"register":SP,"offset":0},
       "type": gen(ptr_sz)}`.
     * If the element exists with neither child, the function returns None.
   * `return_stack_pointer`: `{"register": stackpointer.register, "offset": 0,
     "type": gen(ptr_sz)}`. The **offset is 0**, not the pointer size, unlike `arch.py`.
3. `return_values` lists *alternative* return registers from the cspec. Under anvill
   semantics, several return values mean a packed struct, so the semantics do not match.

Example outputs:
* `parse_cspec/example_output/x86gcc.json`: no parameters,
  `return_address {"memory":{"offset":0,"register":"ESP"},"type":"i"}`,
  `return_stack_pointer {"offset":0,"register":"ESP","type":"i"}`, and
  `return_values [{"register":"ST0","type":"d"},{"register":"EAX","type":"i"}]`.
* `x86-64gcc.json`: parameters `XMM0..XMM7` typed `F`, then `RDI, RSI, RDX, RCX, R8, R9`
  typed `l`. return_address is `[RSP+0]` with type `l`, return_stack_pointer is `RSP+0`
  with type `l`, and return_values are `XMM0:F`, `RAX:l`.

Status: **stale**. `--default_callable_spec` now goes through
`CallableDecl::DecodeFromPB`, which does `::specification::Function::ParseFromString`. It
expects a *binary* `specification.Function` message with `callable` set, and
`DecodeDefaultCallableDecl` fails with "all functions should have a callable" otherwise.
The JSON is not accepted.


### 15.11 roundtrip.py test flow and test cases


`bin/Decompile/tests/scripts/roundtrip.py` (unittest).
* Usage: `roundtrip.py <anvill-decompile-spec> <tests_dir> <clang> [workspace] [-t TIMEOUT]`.
  * The workspace is created with `os.makedirs`, which fails if it already exists.
  * The timeout defaults to None, meaning none.
* For each file in `tests_dir`, it adds `TestRoundtrip.test_<stem>`, then runs
  `unittest.main(argv=[argv0, "-v"])`.

Each test does the following:
1. `tempdir = mkdtemp(prefix="test_<stem>_", dir=workspace)`. Every command is appended to
   `<tempdir>/commands.log` with a `# description` line.
2. **compile**: `clang <case.c> -o <t>_compiled`, with no flags. The test asserts rc==0
   and an **empty stderr** (no warnings).
3. Run the original binary and capture stdout, stderr and the return code.
4. **specify**:
   `python3 -m anvill --bin_in <compiled> --spec_out <t>_rt.json --entrypoint main`.
   The test asserts rc==0 and an empty stderr. The PYTHONPATH formerly came from the
   CTest registration, `PYTHONPATH=${PROJECT_SOURCE_DIR}/python`.
5. **decompile**: `<anvill> --spec <t>_rt.json --bc_out <t>_rt.bc -add_names`. The test
   asserts rc==0 and an empty stderr.
6. **recompile**: `clang -Wno-everything <t>_rt.bc -o <t>_rebuilt`, directly from bitcode.
   **No rellic** is involved.
7. Run the rebuilt binary.
8. If there is no workspace, `rmtree(tempdir)`. The cleanup happens before the asserts, so
   failures with no workspace leave no artifacts.
9. Assert that stderr, stdout and the return code are equal.

`run_cmd` maps `FileNotFoundError` and `PermissionError` to `RunError`.

Status: dead.
* Its CTest registration (`anvill_test_roundtrip`, with `anvill-decompile-json`) was
  removed in 7f309bc.
* The decompiler no longer reads JSON.
* `bin/Decompile/CMakeLists.txt` does not add the tests subdir.

`cases/` (expected to pass). Each test checks only the exit code and stdout:

| case | what it exercises |
|--|--|
| array_swap.c | global `int a[2]={0,42}` swap, return `a[0]` (42) |
| binops.c | `target(0xdeadbeef)` with mod-4 branches over `| & ^ +` with 0xbaaad0bf |
| bitops.c | global `a=0xFF`, `a=(unsigned)a>>7`, return `a&1` |
| init_list.c | `unsigned a[5]`, return `a[1]` |
| inttoptr.c | `unsigned long a=0xDEADBEEF` cast to `int*`, non-NULL gives 42 |
| nullptr.c | global `int *ptr=NULL` compared with NULL |
| ret0.c | `f()` returns 1, `main` returns `f()` |
| struct.c / struct_swap.c | global `struct _pair{int,int}` field read and swap |
| trunc.c | `unsigned long long a=-1`, return truncated to int |
| zeroinit.c | zero-initialised nested struct `_record{int; _pair; _person{const char*; char}}` and `long long a1[256]`, writes, returns the sum |
| zext.c | `unsigned char a=1`, return zero-extended |

`broken_cases/` (known failures, not run):
* assert.c (`assert` and abort)
* binja_var_none_type.c (BN variables with None type; see "should be handled in
  extract_types")
* branch.c, loop.c and nested_struct.c (printf and libc)
* cast.c (pointer to int of `&a`)
* funcptr.c (indirect call through a function pointer)
* sum.c (loop with `%=`)


### 15.12 ci/ directory


* `install_binja.sh`:
  1. GPG-decrypts `BinaryNinja-headless.zip.gpg` and `license.txt.gpg` (AES256 symmetric)
     with `--passphrase "$BINJA_DECODE_KEY"`. It skips the step if the file is already
     decrypted.
  2. Unzips into `${VIRTUAL_ENV:-/opt/vector35/binaryninja}`.
  3. Copies the license to `~/.binaryninja/license.dat`.
  4. Runs `binaryninja/scripts/linux-setup.sh -s -d -m -l` and then
     `scripts/install_api.py` (with `-v` inside a venv).
* `switcher.py`: Binja version switcher. Usage:
  `switcher.py [--version_string V] CHANNEL`.
  * Validates the channel name against `UpdateChannel`.
  * Disables auto-updates, then finds the first `channel.versions` entry whose version
    string contains V, and calls `v.update()` and `install_pending_update()`.
  * The `channel_string is None` branch (update to latest) is unreachable, because the
    channel is a required positional argument.
  * The caller in `run-on-anghabench.sh` passes `--version`. argparse accepts that as a
    prefix abbreviation of `--version_string`.
* `install_clang.sh`: maps `$LLVM_VERSION` llvm80*, 90*, 100* and 110* to clang-8, 9, 10
  and 11. It `apt-get install clang-$V` and falls back to `apt.llvm.org/llvm.sh $V`.
  It is obsolete: the repo now builds against LLVM 14 and 15.
* `angha_1k_test_settings.json`: `{"tests.ignore": [...]}`. The ignored entries are
  SoftEtherVPN `extr_memory_t.h_SW_LONG_AT` for x86, amd64 and armv7, plus a few
  `.../python/success/.../output.json` entries:
  * reactos ext2 `extr_linux.c_wait_queue_create` (amd64, x86)
  * armv7 `extr_getargs.c_aexpand`
  * armv7 FFmpeg `extr_libmodplug.c_modplug_read_packet`

  The `python/` path component is a remnant of the Python-spec era.
* `challenge_bins_test_settings.json`: `"timeout.seconds": "800"` and `tests.ignore`
  covering every `challenge-3_{amd64,x86,arm64,armv7}_program_go[_patched].elf` and its
  `/output.json`. These are giant Go binaries.
* Current CI (`.github/workflows/build.yml`) does not call `ci/install_binja.sh`. The
  `binja: {channel: headless, version: 3.1.3479}` matrix entry and the `BINJA_DECODE_KEY`
  env in "Run the tests" are leftovers. CI does the following:
  1. Installs Ghidra 10.1.5 and irene3.
  2. Builds and installs anvill (once with build.sh-style cmake, once with
     `scripts/build-preset.sh debug`).
  3. Runs `ctest -V` and packages DEB, RPM and TGZ with cpack.
  4. Runs `scripts/test-amp-challenge-bins.sh --ghidra-install-dir $GHIDRA_INSTALL_DIR
     --decompile-cmd anvill-decompile-spec`, using the `TOB_AMP_PASSPHRASE` secret.


### 15.13 scripts/ directory


* `build.sh` (Apache-2 header). Builds against prebuilt cxx-common vcpkg.
  * Defaults: `INSTALL_DIR=/usr/local`, `LLVM_VERSION=llvm-15`, `CXX_COMMON_VERSION=0.2.12`,
    `BUILD_DIR=$PWD/anvill-build`, `DOWNLOAD_DIR=<src>/../lifting-bits-downloads`.
  * Flags: `--prefix`, `--llvm-version 14|15`, `--build-dir`, `--download-dir`, `--debug`
    (`-DCMAKE_BUILD_TYPE=Debug`), `--install` (install only, no cpack; the help text says
    "Rellic", a copy-paste slip) and `--extra-cmake-args`.
  * OS detection: Ubuntu focal (and groovy) maps to 20.04. bionic, cosmic, disco and
    "eoam" (sic) map to 18.04. arch and kali map to 18.04. macOS maps to `macos-11` with
    Xcode 13.0.
  * The library name is `vcpkg_<os>_<llvm>_<amd64|arm64>`, or
    `..._xcode-13.0_...` on macOS. It is downloaded from
    `github.com/lifting-bits/cxx-common/releases/download/v<ver>/<lib>.tar.xz`. The triplet
    is `x64|arm64-linux-rel` or `-osx-rel`.
  * `BuildRemill` only runs `git submodule update --init`; it builds nothing.
  * `Configure`: `cmake -DANVILL_ENABLE_INSTALL=true -G Ninja
    -Dremill_DIR=$INSTALL_DIR/lib/cmake/remill -DCMAKE_INSTALL_PREFIX
    -DCMAKE_PREFIX_PATH -DCMAKE_TOOLCHAIN_FILE=<vcpkg> -DVCPKG_TARGET_TRIPLET`.
  * Then it runs `Build`, and `Install` or `Package`. `Package` uses
    `DESTDIR=./install`, `cpack -D ANVILL_DATA_PATH -R <tag-sans-v>.<sha7>
    --config packaging/main.cmake`.
* `build-preset.sh <debug|release> [--debug-vcpkg] [-- cmake args]`.
  * It needs the env vars `CMAKE_TOOLCHAIN_FILE` and `INSTALL_DIR`.
  * It sets `VCPKG_TARGET_TRIPLET=<x64|arm64>-<linux|osx>[-rel]`.
  * It runs `cmake --preset vcpkg-<arch>-<dbg|rel>`, then
    `cmake --build --preset <arch>-<dbg|rel>`, then the install target. The logs go to
    `anvill-configure.log` and `anvill-build.log`.
* `docker-spec-entrypoint.sh`: see §15.2.2.
* `emit-artifact.sh <out>`: `apt install pixz`, then
  `tar -Ipixz -cf <out> -C /opt/trailofbits anvill remill`.
* `format-files`: a Python clang-format wrapper. It takes `--format_exe`, `--source_dir`
  (default: the repo root), `--files ...` and `--check`. `--check` is accepted through
  `parse_known_args` and ignored.
  * Before formatting it fixes comments: a blank line before a comment block unless the
    previous line is empty or `}`.
  * Comments placed before `} else` are moved after it using a `// !!! REFLOW-COMMENT`
    placeholder, re-indented by -2 spaces.
  * It forces a trailing newline and inserts a space after `//`.
  * It needs `.clang-format` in the source dir.
  * Files without fixes get `clang-format -i`. Files with fixes are piped through
    `--style=file --assume-filename`.
* `format-added-files`: a git pre-commit hook helper. It formats the staged `.h` and `.cpp`
  files with `format-files` and re-`git add`s them.
  * Its grep regex `'\.\(h\)\|\(cpp\)$'` is sloppy.
  * In the hooks-dir case it computes `GIT_DIR` from the not-yet-set `SCRIPTS_DIR`.
* `generate_changelog.sh <out.md>`: `git log prev_tag...current` formatted as
  ` * [%h](http://github.com/lifting-bits/anvill/commit/%H) - %s`, with `Merge branch`
  lines filtered out.
* `test-amp-challenge-bins.sh [--ghidra-install-dir D] [--decompile-cmd C]`.
  * Defaults: `~/ghidra_10.1.5_PUBLIC/` and `anvill-decompile-spec`.
  * It checks `import stats` from `libraries/lifting-tools-ci/tool_run_scripts`. That
    submodule is empty in this clone.
  * It checks that `C --version` runs.
  * It runs `datasets/fetch_amp_challengebins.sh` with `TOB_AMP_PASSPHRASE` and extracts
    `*.tar.xz`.
  * It runs `tool_run_scripts/anvill.py --ghidra-install-dir --anvill-decompile
    --input-dir challenge-binaries --output-dir results/... --run-name
    anvill-live-ci-amp-bins --test-options ci/challenge_bins_test_settings.json
    --dump-stats --dump-benchmark`.
  * It fails if `results/<dir>/python/stats.json` or `.../decompile/stats.json` reports
    failures (`Stats().get_fail_count()`). The `python/` name is a leftover; it now holds
    the Ghidra spec-generation stage.
* `test-angha-1k.sh [--python-cmd "python3 -m anvill"] [--decompile-cmd
  anvill-decompile-spec]`. This is the older equivalent using `--anvill-python` and
  `fetch_anghabench.sh --run-size 1k --binaries`, iterating over `binaries/<arch>`. It is
  commented out in CI (and the CI comment still says `anvill-decompile-json`).
* `run-on-anghabench.sh`: a template for a remote CI box. Its placeholders are
  `__ANVILL_BRANCH__`, `__RUN_SIZE__`, `__BINJA_DECODE_KEY__`, `__BINJA_CHANNEL__` and
  `__BINJA_VERSION__`.
  1. apt installs clang-13 and similar, plus cmake 3.22.1.
  2. Clones anvill and `lifting-tools-ci` (`$CI_BRANCH`). Creates a venv.
  3. Runs `scripts/build.sh --install --llvm-version 14 --extra-cmake-args
     -DCMAKE_BUILD_TYPE=Release` and `python3 setup.py install`.
  4. Runs `ci/install_binja.sh` and `ci/switcher.py --version $V $CHANNEL`.
  5. Runs `fetch_anghabench.sh --clang 14 --binaries --run-size ${RUN_SIZE:-1k}`.
  6. Runs `tool_run_scripts/anvill.py --anvill-decompile /usr/local/bin/anvill-decompile-spec
     --slack-notify`. It passes **no `--anvill-python`**, so it is inconsistent with the
     Binja install it just did.
  7. Optionally uploads `anvill-ci-<date>.tar.xz` to the DigitalOcean Spaces bucket
     `tob-amp-ci-results` with `s3cmd`, and posts to Slack.


### 15.14 Bug and edge-case checklist (quick reference)


1. JSON output against a binary-protobuf consumer. The whole Python pipeline is
   incompatible with main (§15.0).
2. Binja `calling_convention` is always 0. `num_bytes_popped` is never set, so
   `return_stack_pointer` is wrong for callee-cleanup conventions.
3. `UnionType` serializes and flattens the last member instead of the largest. `size()` is
   correct.
4. `Type.extract` is broken except for offset 0 with a covering size. This breaks IDA's
   ALOC_DIST and ALOC_REG2 handling.
5. `CharacterType` construction raises TypeError (IDA char types).
6. IDA ALOC_REG2 uses `itertools` without importing it.
7. IDA split-parameter naming always renames `param_list[-1]`.
8. IDA variables never map memory bytes.
9. AArch32 register families are malformed (missing comma, 8-byte size, end offsets used as
   sizes).
10. The ELF parser finds no 32-bit thunks (symbol index never computed). It has class-level
    shared lists. The 64-bit st_shndx is read as u32.
11. The arch name changes to `*_avx` or `*_avx512` as a side effect of any YMM or ZMM
    register lookup.
12. Low-confidence `can_return` yields `is_noreturn: true`.
13. `control_flow_targets` with duplicate destination addresses crash `proto()` with a
    TypeError while sorting dicts.
14. `util.py` calls `logging.config` without importing it, so it falls back to basicConfig
    at ERROR level.
15. Every struct gets an `=N` id. Back-references `%N` occur for repeated identical struct
    objects, not only for recursion, because pointers are opaque.
16. `binja/callingconvention.py` is unused and dereferences None before its fallback.
17. parse_cspec: register return addresses use the XML tag name, stack parameters are
    dropped, the return-SP offset is 0, and alternative return registers are listed as a
    multi-value return.

---

## 16. Build, packaging, tests and CI

### 16.1 CMake

- The top-level `CMakeLists.txt` needs CMake ≥ 3.19 and C++17 (no extensions), and exports `compile_commands.json`.
- `find_package` for XED, gflags, glog, **Z3**, doctest and LLVM (components support, core, irreader, bitreader, bitwriter); sleigh is optional; remill is required.
- Options (`cmake/options.cmake`):

  | Option | Default |
  |---|---|
  | `ANVILL_ENABLE_INSTALL` | ON |
  | `ANVILL_ENABLE_PYTHON3_LIBS` | ON |
  | `ANVILL_INSTALL_PYTHON3_LIBS` | OFF |
  | `ANVILL_ENABLE_TESTS` | ON |
  | `ANVILL_ENABLE_SANITIZERS` | — |

  The default build type is `RelWithDebInfo` (`Release` on Windows). When the install prefix is the default, it is forced to `/usr`.
- `lib/CMakeLists.txt` builds a **static** library `anvill`:
  - It runs `protobuf_generate_cpp` on `data_specifications/specification.proto`, which produces `specification.pb.{h,cc}` (namespace `specification`).
  - Passes are listed by name in `anvill_passes`. Each name must have `include/anvill/Passes/<Name>.h` and `lib/Passes/<Name>.cpp`.
  - The version file `Version.cpp` is generated from `Version.cpp.in` by `git_watcher.cmake`.
  - It links remill, LLVM, protobuf, glog, gflags and z3. The headers are installed and the target is exported as `anvill::anvill`, with `anvillConfig.cmake.in` as the package config.
- `bin/Decompile` builds the `anvill-decompile-spec` executable. Its round-trip test subdirectory is commented out.
- `python/CMakeLists.txt` and `install.cmake` handle the setuptools build and install of the Python package (§15).
- `CMakePresets.json` defines vcpkg-based presets:
  - debug-flags: `-O0 -gfull -fno-omit-frame-pointer`; release-flags;
  - arm64 / x86_64;
  - `vcpkg-common`, which uses the Ninja generator and the env vars `VCPKG_TARGET_TRIPLET`, `CMAKE_TOOLCHAIN_FILE` and `INSTALL_DIR`.

  `scripts/build-preset.sh` wraps them.
- `cmake/ccache.cmake` enables ccache when it is found. `cmake/modules/Find*.cmake` are thin wrappers.

### 16.2 Tests

`tests/tools` → `test_anvill`, which runs `Result` and `TypeSpecification` checks. `tests/anvill_passes` → `test_anvill_passes`, the pass unit tests, which load `.ll` fixtures from `tests/anvill_passes/data` (§13.7). Both are doctest executables registered with `add_test`, so you run them with `ctest -V`. The Python round-trip test (`bin/Decompile/tests/scripts/roundtrip.py`, §15.11) is no longer registered.

### 16.3 Docker

The `Dockerfile` has multiple stages. The args are `LLVM_VERSION` (15), `UBUNTU_VERSION` (20.04) and `CXX_COMMON_VERSION` (0.2.16).

1. Download the cxx-common vcpkg tarball `vcpkg_ubuntu-<ver>_llvm-<ver>_amd64.tar.xz`.
2. Build and install remill from the submodule into `/opt/trailofbits` using the vcpkg toolchain (`x64-linux-rel`).
3. Configure, build and install anvill with tests enabled, then run `ctest -V`.
4. The `dist` stage copies `/opt/trailofbits` and sets `ENTRYPOINT ["anvill-decompile-spec"]`.

A `binja` stage adds `scripts/docker-spec-entrypoint.sh`, which runs the legacy Binary Ninja spec generator.

### 16.4 Packaging

`packaging/main.cmake` is a CPack script: TGZ, DEB and RPM on Linux, TGZ on macOS. It requires `ANVILL_DATA_PATH` and `ANVILL_PACKAGE_VERSION`, and `dispatcher.cmake` picks the per-generator settings. The package description is "anvill forges beautiful LLVM bitcode out of raw machine code".

### 16.5 CI (`.github/workflows/build.yml`)

1. **Cancel stale runs.** `abort_previous_workflows.py` cancels older runs of the same branch.
2. **Matrix.** Ubuntu 20.04 × LLVM {14, 15} × cxx-common v0.2.16, in the `cxx-common` vcpkg-builder container.
3. **Toolchain.** Install Rust and `just`, then clone and install the **Ghidra spec generator** (closed source, needs credentials) and Ghidra itself.
4. **Build.** Download cxx-common, then build and install remill and anvill, both directly and via presets.
5. **Test and package.** Run `ctest -V`, build the packages, and install the DEB.
6. **Integration tests.**
   - AMP challenge binaries (`scripts/test-amp-challenge-bins.sh`, `ci/challenge_bins_test_settings.json`).
   - The AnghaBench-1K corpus (`scripts/test-angha-1k.sh`, `ci/angha_1k_test_settings.json`).

   These use the `lifting-tools-ci` submodule. Its settings files list known-bad functions and timeouts. See §15.12.

### 16.6 Build after the remill / LLVM 19 port

The cxx-common/vcpkg setup described above has since been replaced by the [remill-template](https://github.com/LLVMParty/remill-template) layout:

- **Remill** is a submodule at `dependencies/remill` (LLVMParty's fork, branch `sparc-sleigh-v2`, see below) and is built as part of anvill with `add_subdirectory`, with remill testing turned off. The old root `remill` submodule, `cmake/modules/Find*.cmake`, `CMakePresets.json` and the cxx-common scripts are gone.
- **`dependencies/`** is a CMake superbuild (from the template) that installs a prefix in `dependencies/install`. It contains:
  - remill's dependencies: gflags, glog, googletest and XED;
  - sleigh, with remill's patches;
  - anvill's extras: doctest 2.4.11, protobuf 21.12 (the last release without abseil) and Z3 4.13.4;
  - LLVM, which by default is the LLVMParty 21.1.6 prebuilt (or `USE_EXTERNAL_LLVM=ON` / `DOWNLOAD_PREBUILT_LLVM=OFF`).

  `BUILD_REMILL_DEPENDENCIES=OFF` skips remill's dependencies when they already exist.
- **`cmake/SetupDependenciesPrefix.cmake`** picks up `dependencies/install` automatically. If `CMAKE_PREFIX_PATH` is already set, as in the Docker image, it layers `dependencies/install` on top of it.
- **Docker / CI.** `ghcr.io/llvmparty/remill-template/dependencies:22.04-llvm19.1.7-remill2026.03.20` already provides LLVM 19.1.7 and remill's dependencies in `/dependencies`. The CI job and the root `Dockerfile` use that image as-is: they install Z3, protobuf and doctest from the Ubuntu packages and build anvill directly, without a dependency superbuild. Remill fetches sleigh itself, and the CMake falls back to module-mode `FindProtobuf` and a manual Z3 lookup when no CMake config packages exist.
- **Defaults.** `ANVILL_ENABLE_INSTALL` and `ANVILL_ENABLE_PYTHON3_LIBS` now default to OFF.
- **remill fork.** The submodule tracks [LLVMParty/remill](https://github.com/LLVMParty/remill), branch
  `sparc-sleigh-v2`: LLVMParty's `master` (synced with upstream remill) plus sixteen commits, meant for upstreaming:
  (1) the generic Sleigh control-flow categorization, (2) SPARC32 fixes, (3) replacing the hand-written SPARC64
  implementation with Sleigh, (4) removing the dead hand-written SPARC32 decoder, (5) JIT-executed lifting tests
  for both SPARCs (`tests/SPARC`) and CI smoketests, then three fixes found by anvill's SPARC kitchen-sink cases:
  (6) Sleigh register parts lifted by value, (7) the FP overlays in SPARC's byte order, and (8) struct returns
  (`jmp %o7 + 12`) categorized as returns; and (9) removing the obsolete `REMILL_BUILD_SPARC32/64_RUNTIME`
  options and the obsolete `scripts/setup.sh`; and from review of the upstream PR (lifting-bits/remill#789),
  (11) branches to the end of the p-code counted as fallthroughs and the branch-taken op found by its
  instruction-wide index, (12) SPARC32's `MaxInstructionSize` of 8 without fusion, (13) inverted branch-taken
  variables honoured (SPARC annulled branches were dispatched the wrong way), (14) mixed flows rejected
  when an intra-instruction branch can skip the conditional exit, and two fixes found by anvill's compiled-C
  cases: (15) p-code blocks that end at a local label fall through instead of leaving the instruction (a
  conditional move in the delay slot of `retl` skipped the return), and (16) a patch to Ghidra's SPARC spec
  (`dependencies/sleigh_patches/0014-SPARC-signed-divide.patch`) sign-extending the divisor of `sdiv`/`sdivcc`.
  Each commit builds. (This was first carried as a patch applied
  at configure time, then as commits that added a separate `sparc64_sleigh` architecture; this series replaces
  them.) What they do:
  - **Why.** remill replaced its hand-written SPARC32 semantics with Ghidra's Sleigh specification (remill #681,
    arch name `sparc32_sleigh`). The old `sparc32` arch kept its decoder but lost its semantics, so every
    instruction became a `kSPARC32EmulateInstruction` hyper call. The hand-written SPARC64 semantics depend on
    deleted SPARC32 files, so their runtime was never built and `Arch::Build` for `sparc64` aborted. `Arch.h`
    already declared `GetSPARC64Sleigh`, but nothing defined it.
  - **Deletions (about 9,600 lines).** The whole hand-written SPARC64 implementation (decoder, semantics,
    runtime, `State`) and the hand-written SPARC32 decoder are removed, with the `remill_arch_sparc32/64`
    libraries. As for `aarch32`, `thumb2` and `ppc`, the plain names are now the Sleigh architectures:
    `kArchSparc32` (`sparc32`) and `kArchSparc64` (`sparc64`); `sparc32_sleigh` remains an alias of `sparc32`.
  - **SPARC64.** Ghidra's `SparcV9_64.sla`, a `State` laid out after its register space
    (`include/remill/Arch/SPARC64/Runtime/State.h`: 64-bit `G0`–`I7`, `PC`, `NPC`, ancillary and privileged
    registers, condition codes, `FS`/`FD`/`FQ` overlays in big-endian numbering), a register table and a
    `sparc64.bc` runtime. Ghidra decodes a delayed control transfer together with its delay slot, so the
    architecture reports no separate delay slots.
  - **`DECOMPILE_MODE`.** On both SPARCs it is a decoding-context value of 1 (as in `SparcV9.pspec`) instead of a
    `State` register. Otherwise `save`/`restore` would also spill and fill the register-window backing store
    through computed register-space addresses, which remill lifts as memory accesses.
  - **Control-flow categories.** Ghidra's SPARC `call` is `o7 = inst_start; didrestore = 0; <delay slot>; call
    target; if (didrestore == 0) goto inst_next; return [o7]`. The p-code after `CALL` is unreachable in remill's
    p-code CFG, so it is now ignored when categorizing (unless an intra-instruction branch targets it). Instructions
    that mix intra-instruction branches with exits (`ret` with `restore` in its delay slot) are categorized by their
    exits. Limitation: the `call x; restore` tail-call idiom is treated as a normal call that returns to `pc + 8`.
  - **Register parts (generic Sleigh fix).** Sleigh accesses a part of a register that has no name of its own as
    a register varnode inside it: SPARC V9 `st %o0` stores the low word of the 64-bit `o0` as
    `(register, o0 + 4, 4)`. `getRegisterName` returns the containing register, and the lifter accessed it as if
    the varnode started at the register's first byte, which under SPARC's big-endian data layout is the high word
    (anvill's `bump` stored the carry of the addition instead of the sum). Such varnodes are now read as
    `trunc(lshr(whole, shift))` and written by merging into the whole register's value, with the shift taken
    from Sleigh's register-space byte order.
  - **Byte order of the state.** The SPARC runtimes are compiled for SPARC, and lifted modules use SPARC's
    big-endian data layout, so the `State` is laid out big-endian: `fs(4q)` and `fd(4q)` (the high halves of
    `fd(4q)` and `fq(4q)`) are the first bytes of `fq(4q)`, as in the original SPARC32 table. (An intermediate
    version swapped the halves for host byte order to please remill's JIT test runner, which forces the host's
    data layout; that broke anvill's view of the overlays.) The JIT runner therefore cannot check how the FP
    registers overlay each other; the tests access each register at its table offset.
  - The FP condition codes are registered as `FCC0`–`FCC3` (they were `ccf_fcc0`–`3`, which never matched
    Ghidra's `fcc0`–`3`, so each instruction got a fresh local and e.g. `fcmp` followed by `fbne` lost the
    condition). `Arch::IsSPARC32`/`IsSPARC64` also accept the Sleigh variants.
  - **Tests.** Each case lifts one instruction, runs it with the JIT and checks the category and registers:
    `add`, `retl`/`call` with delay slots, `jmp %o7 + 12` / `jmp %i7 + 12` (returns) and `jmp %o7 + 16` (an
    indirect jump), `save`, `ret` + `restore`, `brz` (taken and not), `fcmps` (`FCC0`) and `fmovd`. One more
    SPARC64 test checks the lifted IR instead of executing it: every load of `o0` in a lifted `st %o0` loads all
    8 bytes (the JIT runner, using the host's byte order, cannot see the register-part bug). Against the unfixed
    code the `call`, `save`, `ret` + `restore`, `fcmps`, struct-return and register-part cases fail.
- **Source changes.** These were mechanical LLVM 16–19 API updates:
  - `starts_with`, `std::optional` and the `TypeSize` getters;
  - `ConstantFoldIntegerCast` in place of the removed `zext` constant expression;
  - the new-pass-manager cleanup in `FunctionLifter`;
  - `icmp` constant-expression handling compiled out on LLVM ≥ 19;
  - three test `.ll` fixtures rewritten without removed constant expressions.

  The remill API that anvill uses was unchanged between the old pin (Dec 2022) and current `master`.

---

### 16.7 Golden tests: the executable specification

`tests/golden` holds input files and the exact expected output of the current implementation. Together they
specify anvill's observable behaviour: a clean-room reimplementation is correct when it reproduces these files
(modulo value names, if it chooses not to match them).

**Tools.**

- `anvill-decompile-spec` (§14) also accepts protobuf **text format** (`.textproto`/`.txtpb`) specifications,
  and `--ir_pre_opt FILE` writes the IR after lifting and the lifter's local cleanup, before `OptimizeModule`.
- `anvill-opt` (`bin/Opt/Main.cpp`, new) runs anvill passes on an `.ll` file, like LLVM's `opt`:
  - `--passes=A,B,...`: anvill pass names (`RecoverBasicStackFrame`, `LowerSwitchIntrinsics`, …, the names in
    §13); any other name is parsed by LLVM's `PassBuilder` (e.g. `instcombine<no-verify-fixpoint>`). The
    pseudo-pass `OptimizeModule` runs the whole pipeline of §13.6, and `AllocateSignatures` prints the
    calling-convention allocation of every function (§8.11) instead of IR.
  - `--function NAME` restricts function passes to one function; `-o FILE`; `--verify` (default on).
  - `--arch`/`--os` (default: from the module's triple), `--pc_metadata` (default `pc`; empty disables it).
  - Stack-frame options: `--stack_init=symbolic|zeroes|undef|none`, `--stack_lower_padding`,
    `--stack_higher_padding`, `--stack_max_size` (8192), `--stack_word_size` (0 = pointer size),
    `--stack_offset_metadata` (`stack_offset`), `--stack_grows_up`.
  - The cross-reference resolver maps globals named `sub_<hex>…`, `var_<hex>…` and `data_<hex>…` to those
    addresses (exact addresses only). The memory provider reads `!anvill.memory = !{!{i64 address, !"hex
    bytes", !"rwx"}}` module metadata, so jump tables can be given inline.
- `tests/golden/run_golden.py --anvill-opt BIN --anvill-decompile-spec BIN [--update] [--filter TEXT] DIR`
  runs the cases; `--update` rewrites the expected files. CMake registers it as the `golden` test, and
  `cmake --build build --target update-golden` regenerates everything.
- `tests/golden/tools/assemble.py [--triple T] [--address A] [--no-link] file.s|file.c` assembles a snippet
  (or compiles C with `clang -O2 -fno-jump-tables -ffreestanding -fno-pic`) at a fixed address (clang, ld.lld,
  llvm-objcopy, llvm-objdump) and prints the disassembly as comments, the escaped bytes for a `memory_ranges`
  entry and a `symbols` entry per function. With `--no-link` (SPARC, which ld.lld cannot link) the object file
  must have no relocations.

**Case formats.**

- `passes/<Pass>/<name>.ll`: `; RUN: <anvill-opt flags>` header lines (`%S` = the case's directory), a comment
  explaining the case, and the input. Expected output: `<name>.expected.ll`, or `<name>.expected.txt` for
  `AllocateSignatures`.
- `lifter/<area>/<name>.textproto`: a `specification.Specification` in text format, `# RUN: <flags>` for
  `anvill-decompile-spec`, and comments with the C source and disassembly. Expected output: `<name>.lifted.ll`
  (`--ir_pre_opt`) and `<name>.optimized.ll` (the final IR). A `# EXPECT-ERROR: <text>` line instead requires the
  tool to fail with that text.
- The harness replaces `; ModuleID` and normalizes `source_filename` to the file's basename, so outputs do not
  depend on the checkout path.

**Index.** The first sentence of each case's comment:

| Case | What it pins down |
|---|---|
| `passes/AllocateSignatures/aarch32.ll` | AArch32 (AAPCS, soft-float, Linux). |
| `passes/AllocateSignatures/aarch64.ll` | AArch64 (AAPCS64, Linux). |
| `passes/AllocateSignatures/sparc.ll` | SPARC32 (Linux). |
| `passes/AllocateSignatures/sparc64.ll` | SPARC V9 (64-bit, Linux) with remill's Sleigh-based architecture (sparc64): 8-byte argument slots; the first six integer slots are in O0-O5, floating-point arguments use the FP register of their slot (FS2k+1, FD2k, … |
| `passes/AllocateSignatures/x86_32.ll` | 32-bit x86 (Linux): cdecl, stdcall, fastcall and thiscall. |
| `passes/AllocateSignatures/x86_64_sysv.ll` | Calling-convention allocation for x86-64 System V (Linux), as computed by FunctionDecl::Create for each declared function: the location of every parameter and return value, the return address, and the stack pointer after the … |
| `passes/AllocateSignatures/x86_64_sysv_avx.ll` | x86-64 System V with AVX (--arch=amd64_avx): each XMM constraint gains a YMM variant (ApplyX86Ext), so 256-bit vectors are passed and returned in YMM registers while smaller values keep the XMM names. |
| `passes/BranchRecovery/aarch64.ll` | AArch64 flag computations (NZCV) behind a compare hint. |
| `passes/BranchRecovery/unrecoverable.ll` | A compare hint over the flags of an `add` (not a comparison of two values) matches none of the tried predicates and is left unchanged (it is removed later by RemoveUnusedBranchHints). |
| `passes/BranchRecovery/x86_sub_sle.ll` | A signed less-or-equal (x86 jle after sub): the __remill_compare_sle hint over the ZF/SF/OF flag computations is proven (with Z3) equal to icmp sle RDX, RAX and replaced by it. |
| `passes/CombineAdjacentShifts/basic.ll` | (ashr (shl V, A), B) with A = N/2 and B < A becomes (shl (sext (trunc V to iA)), A - B); other shapes are left alone. |
| `passes/ConvertAddressesToEntityUses/basic.ll` | Values that resolve to the address of a lifted entity (here, globals named sub_/var_/data_<hex>, see anvill-opt) through @__anvill_pc-relative arithmetic are replaced by references to the entity; the entity gets the `pc` … |
| `passes/ConvertAddressesToEntityUses/edge_cases.ll` | Edge cases of ConvertAddressesToEntityUses: - @phi: an address flowing into a PHI is replaced in the incoming block |
| `passes/ConvertMasksToCasts/masks.ll` | (and V, M) where M keeps exactly the low half of the bits becomes (zext (trunc V)). |
| `passes/ConvertMasksToCasts/shifted_add.ll` | (add (shl V, N), M << N) with N in {8, 16, 32, 64, 128} becomes (shl (add V, M), N); the original shl is removed if it has no other users. |
| `passes/ConvertMasksToCasts/sign_extend.ll` | (ashr (shl V, S), S) sign-extends the low N - S bits of V and becomes (sext (trunc V to i(N-S))) for any 0 < S < N. |
| `passes/ConvertSymbolicReturnAddressToConcreteReturnAddress/basic.ll` | Remaining uses of the symbolic return address (`ptrtoint @__anvill_ra`, possibly inside larger constant expressions) are replaced by the real return address: one `llvm.returnaddress(0)` call at the top of the entry block, … |
| `passes/ConvertXorsToCmps/compare.ll` | (xor (icmp P a, b), true) becomes (icmp !P a, b) when every other user of the compare is a branch or a select condition: those branches get their successors swapped and those selects their values swapped, so they keep their … |
| `passes/ConvertXorsToCmps/non_compare.ll` | (xor V, true) of a non-compare i1 used by branches: the branches use V and swap their successors; the xor is erased if nothing else uses it. |
| `passes/ConvertXorsToCmps/not_invertible.ll` | The compare is not inverted when another user needs its original value (here a zext, and a select that also uses it as a value). |
| `passes/HoistUsersOfSelectsAndPhis/phi.ll` | The same for PHI nodes: the operation is moved into each incoming block (before its terminator) and a new PHI merges the results. |
| `passes/HoistUsersOfSelectsAndPhis/select.ll` | A binary operator with a constant other operand, a cast, or a GEP that uses a select is pushed into both arms of the select: |
| `passes/LowerRemillMemoryAccessIntrinsics/basic.ll` | Remill memory intrinsics become plain loads and stores through `inttoptr` of the address; the memory pointer result of a write is replaced by its memory-pointer argument. |
| `passes/LowerRemillMemoryAccessIntrinsics/extended_float.ll` | Extended-precision accesses, with remill's real signatures (amd64.bc): |
| `passes/LowerRemillUndefinedIntrinsics/basic.ll` | Calls to __remill_undefined_* are replaced by undef values of their type. |
| `passes/LowerSwitchIntrinsics/jump_table.ll` | A lifted jump table: a bounds check (x > 3 goes to %default), a load of a 32-bit table entry at 0x401038 + 4*x, the target 0x401038 + entry, and __anvill_complete_switch mapping the target to the case index of the lifted targets. |
| `passes/LowerSwitchIntrinsics/missing_memory.ll` | Without the table bytes in memory the switch cannot be built and the dispatch is left unchanged. |
| `passes/LowerSwitchIntrinsics/shared_target.ll` | Table entries 1 and 2 both point to 0x40101d (case1), so case2 is no longer a successor after lowering: its PHI drops the incoming value from the dispatch block (previously left behind, which made the IR invalid). |
| `passes/LowerTypeHintIntrinsics/basic.ll` | Calls to __anvill_type_hint* functions are replaced by a bit/pointer cast of their (pointer-cast-stripped) argument to the call's type. |
| `passes/RecoverBasicStackFrame/clamped_frame.ll` | The frame (recovered size + padding) is clamped to --stack_max_size. |
| `passes/RecoverBasicStackFrame/init_none.ll` | Every use of a constant expression derived from `__anvill_sp` becomes a GEP into a new frame alloca (`%<function>.frame_type` = { [N x iW] }, W = word size); `--stack_init=none`. |
| `passes/RecoverBasicStackFrame/init_symbolic.ll` | Every use of a constant expression derived from `__anvill_sp` becomes a GEP into a new frame alloca (`%<function>.frame_type` = { [N x iW] }, W = word size); `--stack_init=symbolic`. |
| `passes/RecoverBasicStackFrame/init_undef.ll` | Every use of a constant expression derived from `__anvill_sp` becomes a GEP into a new frame alloca (`%<function>.frame_type` = { [N x iW] }, W = word size); `--stack_init=undef`. |
| `passes/RecoverBasicStackFrame/init_zeroes.ll` | Every use of a constant expression derived from `__anvill_sp` becomes a GEP into a new frame alloca (`%<function>.frame_type` = { [N x iW] }, W = word size); `--stack_init=zeroes`. |
| `passes/RecoverBasicStackFrame/no_stack_uses.ll` | A function without stack pointer uses gets no frame. |
| `passes/RecoverBasicStackFrame/padding_and_word_size.ll` | Padding below (--stack_lower_padding, e.g. a red zone) and above (--stack_higher_padding) the accessed range grows the frame, and --stack_word_size=1 makes the frame an array of bytes. |
| `passes/RemoveCompilerBarriers/basic.ll` | Compiler barriers are empty side-effecting inline asm calls. |
| `passes/RemoveDelaySlotIntrinsics/absent.ll` | A module that does not declare the delay slot intrinsics is left unchanged. |
| `passes/RemoveDelaySlotIntrinsics/basic.ll` | Calls to __remill_delay_slot_begin/__remill_delay_slot_end are replaced by their memory-pointer argument; their metadata is copied onto the memory pointer when it is an instruction. |
| `passes/RemoveErrorIntrinsics/absent.ll` | Without a __remill_error declaration nothing changes. |
| `passes/RemoveErrorIntrinsics/basic.ll` | A call to __remill_error and everything after it in its block is replaced by `unreachable` (the call's metadata moves to the `unreachable`). |
| `passes/RemoveErrorIntrinsics/phi_incoming.ll` | PHI nodes lose the incoming values from blocks that now end in `unreachable`: a PHI left with one incoming value is replaced by it, with several it is rebuilt, and with none its block becomes unreachable too (and its value … |
| `passes/RemoveRemillFunctionReturns/basic.ll` | Returns to the real return address are removed: the __remill_function_return call is replaced by its memory pointer and the return-address computation is erased. |
| `passes/RemoveRemillFunctionReturns/sparc.ll` | On SPARC, returns to the return address plus 8 and plus 12 (structure returns, past the `unimp`) are removed; a return to the return address plus 16 is left alone, as SPARC has no return address slot. |
| `passes/RemoveStackPointerCExprs/narrow.ll` | Constant expressions involving the stack pointer (`__anvill_sp`) that are narrower than a pointer (e.g. the low bits of RSP used by flag computations) are folded using a concrete stack pointer value: 0x00007ffc07000000 on … |
| `passes/RemoveStackPointerCExprs/unresolvable.ll` | Stack pointer constant expressions that cannot be folded (they mix the stack pointer with an unknown global) are turned into instructions in the entry block, so that later passes see the individual operations. |
| `passes/RemoveStackPointerCExprs/x86_flags.ll` | 32-bit x86 (concrete ESP 0x00860000): a sign-flag computation on ESP - 12. |
| `passes/RemoveTrivialPhisAndSelects/basic.ll` | PHIs whose incoming values are all the same value, and selects whose two values are the same, are replaced by that value. |
| `passes/RemoveUnusedBranchHints/basic.ll` | Branch hints that BranchRecovery did not use are removed: calls to __remill_compare_* and __remill_flag_computation_* are replaced by their first argument (the computed i1). |
| `passes/RemoveUnusedFPClassificationCalls/basic.ll` | Calls to fpclassify, __fpclassifyd, __fpclassifyf and __fpclassifyld whose result is unused are erased; used calls and calls to other functions with an unused result are kept. |
| `passes/SinkSelectionsIntoBranchTargets/basic.ll` | A select whose condition is also the condition of a branch: uses of the select dominated by the taken edge use the true value, uses dominated by the not-taken edge use the false value. |
| `passes/SinkSelectionsIntoBranchTargets/partial.ll` | Uses not dominated by either edge (here, after the join and in the branch block itself) keep the select; PHI uses are judged by their incoming edge. |
| `passes/SplitStackFrameAtReturnAddress/after_recovery.ll` | After RecoverBasicStackFrame, the frame is split at the slot that holds the return address into three allocas: the callee's locals (lower addresses), `return_address_loc`, and the caller's stack `parameters` (higher addresses). |
| `passes/SplitStackFrameAtReturnAddress/full_cleanup.ll` | The split frames are designed for SROA: after it the local becomes an SSA value and the stack argument a part of the symbolic stack word @__anvill_stack_plus_8. |
| `passes/SplitStackFrameAtReturnAddress/variable_index.ll` | A GEP with constant and then variable indices into the frame: the new GEP must start from the constant part of the offset (slot 1) and be placed where the old GEP was, because its variable index (%i) is not available in the … |
| `passes/SpreadPCMetadata/basic.ll` | Instructions without `pc` metadata get one: first, an annotated instruction gives its metadata to unannotated operands defined in the same block; then, walking each block backwards starting with the block's last metadata, … |
| `passes/TransformRemillJumpIntrinsics/basic.ll` | An indirect jump (__remill_jump) whose target is the return address is a return: the call is redirected to __remill_function_return (with an undef state pointer), and the function is cleaned up with DCE, SROA, SimplifyCFG and … |
| `lifter/arch/aarch32_even_pair.textproto` | AArch32 (base AAPCS): a 64-bit argument starts at an even register, so `b` is in R2:R3 and R1 is unused. |
| `lifter/arch/aarch64_add.textproto` | AArch64 with a type-only prototype: arguments in W0 and W1, the result in W0, the return address in X30 (LR). |
| `lifter/arch/aarch64_indirect_result.textproto` | AArch64 result larger than 16 bytes: the caller passes the address of the result buffer in X8, so the lifted native function takes a hidden first `ptr` parameter and returns void. |
| `lifter/arch/sparc32_annulled_branch.textproto` | SPARC32 annulled branch (`brz,a`): its delay slot runs only when taken, and remill's branch-taken variable is the inverted condition of a branch to the fallthrough; the result is 20 when x == 0 and 7 otherwise. |
| `lifter/arch/sparc32_call.textproto` | SPARC32 function with a register window: `save` makes the caller's O registers the callee's I registers, the call's argument is computed in its delay slot, and `restore` both pops the window and computes the result (g(a + 1) + … |
| `lifter/arch/sparc32_kitchen_sink.textproto` | A bit of everything on SPARC32 (V8 ABI), one small function each: a signed compare and branch with a delay slot, a global load and store (the store in the delay slot of `retl`), a seventh argument on the stack at [SP + 92], a `double` argument moved from O0:O1 to F0 through the stack, a structure returned in memory (address at [SP + 64], return to O7 + 12) and its caller (`unimp 8` after the call's delay slot). |
| `lifter/arch/sparc32_compiled.textproto` | Compiled C (`lifter/arch/sparc_compiled.c`, clang -O2 for SPARC V8): shifts and logic, `smul`/`sdiv`/`udiv` through `%y`, `ldsb`/`ldsh`/`ldub`, `stb`/`sth`, `fstoi`/`fitod`, `fmuls`/`fadds`, `fcmps` + `fbl`, and branch chains (a conditional select and a switch); each optimized function computes what the C source says. |
| `lifter/arch/sparc32_delay_slot.textproto` | SPARC32 leaf function whose addition is in the delay slot of `retl`. |
| `lifter/arch/sparc64_annulled_branch.textproto` | The same annulled `brz,a` on SPARC64. |
| `lifter/arch/sparc64_branch.textproto` | SPARC V9 conditional branch with a delay slot that is not annulled: the `mov 20` in the delay slot executes on both paths, so the result is 20 when x == 0 and 10 otherwise. |
| `lifter/arch/sparc64_call.textproto` | SPARC V9 function with a register window: `save` makes the caller's O registers the callee's I registers, the call's argument is computed in its delay slot, and `restore` both pops the window and computes the result (g(a + 1) … |
| `lifter/arch/sparc64_compiled.textproto` | The same C for SPARC V9: also `mulx`, `ldsw`, float arguments in `%f1`/`%f3`, `movl %fcc0` in the delay slot of `retl`, and `movg %icc`. |
| `lifter/arch/sparc64_kitchen_sink.textproto` | A bit of everything on SPARC64 (V9 ABI), one small function each: `bge %xcc` with a delay slot, a global load and a 32-bit store of a 64-bit register in the delay slot of `retl`, a seventh argument in stack slot 6 ([SP + 2047 + 176]), a `double` in F0, a two-register structure result and its caller with a register window. |
| `lifter/arch/sparc64_leaf.textproto` | SPARC V9 (64-bit) leaf function, lifted with remill's Sleigh-based `sparc64` architecture: the 64-bit addition in the delay slot of `retl` is part of the same decoded instruction. |
| `lifter/arch/x86_cdecl.textproto` | 32-bit x86 cdecl with a type-only prototype: the allocator puts both arguments on the stack in 4-byte slots ([ESP + 4], [ESP + 8]) and the result in EAX; the caller pops the arguments (ESP + 4 after the return). |
| `lifter/arch/x86_fastcall.textproto` | 32-bit x86 fastcall: the first two 32-bit arguments are in ECX and EDX, the third is on the stack at [ESP + 4], and the callee pops it (`ret 4`, ESP + 8 after the return). |
| `lifter/basic/increment.textproto` | `int inc(int x) { return x + 1; }` with an explicit-location prototype (EDI → EAX): the end-to-end example of §10.10. |
| `lifter/data/integer_bytes.textproto` | Integer initializers are read from the memory bytes in the architecture's endianness. |
| `lifter/data/pointers.textproto` | Pointer-typed data is lifted to references to the entities at the target addresses: a function (declared from its prototype), the start of another variable, an interior address of a variable (a GEP into it), a pointer to … |
| `lifter/flow/breakpoints.textproto` | With --add_breakpoints every lifted instruction is preceded by a call to `breakpoint_<pc>(mem, PC, NEXT_PC)`; the functions are `optnone` so the calls survive optimization (previously the flag was ignored). |
| `lifter/flow/call_without_prototype.textproto` | A call to an address with no function declaration and no call-site prototype is lifted as `__remill_function_call` (logged as missing type information); lifting continues at the return address. |
| `lifter/flow/conditional_branch.textproto` | A conditional branch is lifted as a `br` on remill's BRANCH_TAKEN variable between the taken target and the fall-through; each `ret` is a separate return. |
| `lifter/flow/declaration_only.textproto` | FUNCTION_LINKAGE_DECL: the function is declared with its prototype but its bytes are not lifted. |
| `lifter/flow/direct_call.textproto` | A frame-pointer function that spills its argument to the stack and calls an external function. |
| `lifter/flow/direct_jump_no_override.textproto` | A direct jump without a control-flow override goes to the decoded target (previously a fatal error: every direct jump needed a Jump override). |
| `lifter/flow/falls_off_mapped_memory.textproto` | Execution falls through to an address with no bytes in the specification: the decode fails and the block ends with `__remill_error`. |
| `lifter/flow/global_variable_access.textproto` | RIP-relative loads and stores of a global variable become direct uses of the lifted global (ConvertAddressesToEntityUses). |
| `lifter/flow/indirect_call_callsite.textproto` | An indirect call whose prototype comes from a Callsite entry (keyed by the containing function and the call address). |
| `lifter/flow/indirect_jump_unknown.textproto` | An indirect jump without targets (and without an override) becomes a tail call to `__remill_jump` (previously a fatal error without an override). |
| `lifter/flow/jump_table.textproto` | A switch compiled to a jump table. |
| `lifter/flow/loop.textproto` | A backwards branch produces a loop. |
| `lifter/flow/noreturn_call.textproto` | A call to an `is_noreturn` function ends the block with `__remill_error`; the code after the call is not lifted, and the callee is declared noreturn. |
| `lifter/flow/stop_override.textproto` | An `others { stop: true }` override on a normal instruction stops lifting after that instruction: the block ends with `__remill_error` and the following instructions are not lifted. |
| `lifter/flow/syscall.textproto` | `syscall` is an asynchronous hyper call: the block ends with a tail call to `__remill_async_hyper_call`. |
| `lifter/flow/tail_call.textproto` | A direct jump marked as a call by a Call override is a tail call: the callee is called with the current state and the block ends with `__remill_error` (control never falls out of a tail call). |
| `lifter/flow/trap_instruction.textproto` | `ud2` is an error instruction: its path ends with `__remill_error`, which RemoveErrorIntrinsics turns into `unreachable`, so the optimizer can assume that path is never taken. |
| `lifter/flow/undecodable.textproto` | Bytes that do not decode (here `06`, invalid in 64-bit mode) end the block with `__remill_error`. |
| `lifter/spec/callable_type.textproto` | Prototype given as a C-level function type (`callable.type`) instead of explicit locations: the calling-convention allocator places the arguments. |
| `lifter/spec/cdecl_calling_convention.textproto` | CALLING_CONVENTION_CDECL (1) is not an LLVM calling convention ID; it maps to the C calling convention (0). |
| `lifter/spec/duplicate_function.textproto` | Two functions at the same address are rejected. |
| `lifter/spec/duplicate_override.textproto` | Two control-flow overrides for the same address are rejected (previously a CHECK failure that aborted the process). |
| `lifter/spec/global_variables.textproto` | Global variables are lifted as `var_<addr>_<type>` with an initializer built from the memory bytes. |
| `lifter/spec/unsupported_arch.textproto` | The architecture must be specified. |
| `lifter/spec/void_return.textproto` | A void prototype may omit `return` entirely (previously the loader required `return { type { base: BT_VOID } }` and silently skipped the function). |

## 17. Consolidated list of quirks and bugs, with status

These were found in the original code (commit `9948d26`). The status says what this branch did: **Fixed** (with
the golden case or unit test that pins the new behaviour), **Kept** (deliberately, with the reason), or
**Open** (still present). The section reference describes the old and the new behaviour. A clean-room
reimplementation that wants the original output must reproduce the "old" side of each fixed item.

| # | Original behaviour | Status | Evidence |
|---|---|---|---|
| | **Specification and protobuf (§5, §6)** | | |
| 1 | `ProtobufTranslator::DecodeType` builds a `FunctionType` and never returns it, so every `callable.type` prototype is skipped. | Fixed | `lifter/spec/callable_type`, `lifter/arch/*`, `SpecificationTest.cpp` |
| 2 | A global-variable decode failure is logged, then `.Value()` throws on the failed `Result`. | Fixed (skipped with a warning) | `lifter/spec/global_variables` |
| 3 | The duplicate global-variable check looks in the *function* map. | Fixed | `SpecificationTest.cpp` |
| 4 | `Specification::operator!=` is implemented as `==`. | Fixed | `SpecificationTest.cpp` |
| 5 | `VariableContaining` only matches exact start addresses. | Fixed | `lifter/data/pointers`, `SpecificationTest.cpp` |
| 6 | `overrides` is mandatory. | Fixed (optional) | every lifter case without overrides |
| 7 | `CALLING_CONVENTION_CDECL = 1` is cast straight to `CallingConv::ID` (not a valid ID). | Fixed (maps to C) | `lifter/spec/cdecl_calling_convention` |
| 8 | `return.type` is decoded unconditionally, so a void prototype needs `return { type { base: BT_VOID } }`; one type applies to every return location. | Fixed (void may omit `return`); one type per `return` kept | `lifter/spec/void_return` |
| 9 | `Call.return_address`, `Call.is_tailcall`, `Call.stop`, `Return.stop`, `Jump.stop` and `StructType.identifier` are parsed but ignored. | Open | — |
| 10 | `docs/SpecificationFormat.md` describes the removed JSON format; the `--spec` help said JSON. | Fixed (help text; the doc carries an "outdated" banner pointing here) | — |
| 10a | A duplicate control-flow override is a `CHECK` failure (process abort). | Fixed (an error) | `lifter/spec/duplicate_override` |
| | **ABI / calling conventions (§8)** | | |
| 11 | SysV: the RVO pointer is in RAX, typed as the struct, with RDI blocked; `{long, double}` goes to RVO on plain AMD64; aggregates are split ad hoc. | Fixed (psABI eightbyte classification) | `AllocateSignatures/x86_64_sysv*.ll` |
| 12 | fastcall/thiscall never use ECX/EDX; stdcall/fastcall/thiscall on AMD64 use the 32-bit cdecl object. | Fixed | `AllocateSignatures/x86_32.ll`, `x86_64_sysv.ll`, `lifter/arch/x86_fastcall` |
| 13 | There is no Win64 (or vectorcall) convention; AMD64 Windows is an error. | Open | — |
| 14 | No register-allocation rollback, no alignment or even-pair rules, stack slots not rounded. | Fixed | `AllocateSignatures/*` |
| 15 | Split integer returns typed i32 on AArch64 and SPARC64; AArch32 `double` returns as `R0:double, R1:double`; AArch32 RVO without a hidden parameter. | Fixed (AAPCS64/AAPCS rewrites; SPARC64 i64 parts) | `AllocateSignatures/aarch64.ll`, `aarch32.ll` |
| 16 | Float vectors crash the allocator; a failed vector allocation "succeeds" with zero locations. | Fixed | `AllocateSignatures/x86_64_sysv*.ll` (`<4 x float>`, `<8 x float>`) |
| 16a | AArch64: a ninth integer argument and `i128` go to V registers; `sret` in X0; no HFAs; large aggregates rejected. | Fixed | `AllocateSignatures/aarch64.ll`, `lifter/arch/aarch64_indirect_result` |
| 16b | SPARC32: `double` arguments always on the stack; aggregate results rejected; register names no longer exist in remill. | Fixed | `AllocateSignatures/sparc.ll` |
| 16d | SPARC64: old register names, not slot-based, fixed stack offset 2227. | Fixed (V9 ABI rewrite) | `AllocateSignatures/sparc64.ll` |
| 16f | Found in review of the rewritten allocators: AMD64 `fp128` arguments on the stack and `fp128` results an error; AMD64 aggregates with vector members (`{ <2 x i64> }`) in memory; AArch32 128-bit vector results in memory; fastcall hidden result pointer in ECX; thiscall `this` on the stack after an explicit `sret`; AArch64 short-vector aggregates (HVAs) by reference. | Fixed | `AllocateSignatures/x86_64_sysv.ll` (`quad`, `vector_struct`), `aarch32.ll` (`vector128_ret`), `x86_32.ll` (`fastcall_ret_struct`, `*_explicit_sret`), `aarch64.ll` (`hva`) |
| 16c | x86-32 cdecl returns small aggregates in EAX:EDX (MSVC style) even on Linux, where the i386 psABI uses memory. | Kept | `AllocateSignatures/x86_32.ll` |
| | **Types (§7)** | | |
| 17 | The encoder always uses unsigned letters; `d`/`D` and `w`/`W` sizes disagree with TypeEncoding.md. | Fixed (docs corrected; unsigned letters kept, documented) | `docs/TypeEncoding.md` |
| 18 | In the wrapped-types branch (dead code), the 24-bit ints are assigned into the int32 slots. | Fixed | — (compiled out) |
| | **Lifter (§10, §11)** | | |
| 19 | Missing `Jump` or `Call` overrides for direct jumps and calls are `LOG(FATAL)`. | Fixed (defaults, §5.3) | `lifter/flow/direct_jump_no_override`, `indirect_jump_unknown`, `direct_call` |
| 20 | `MaxInstructionSize` is cached in a function-local `static`. | Fixed | — |
| 21 | Dead redirection-recovery code in `VisitInstructions`. | Fixed (removed) | — |
| 22 | `ValueLifter::ConsumeBytesAsInt` sign-extends bytes ≥ 0x80. | Fixed | `lifter/data/integer_bytes` |
| 23 | `ValueLifter::Lift(ea, type, as)` passes the address space as `loc_ea`. | Fixed | — |
| 24 | `DataLifter::GetOrDeclareData` ignores constant-expression entities. | Fixed | `lifter/data/pointers` |
| 25 | `DefaultCallableTypeProvider::TryGetCalledFunctionType` returns the *containing* function's type. | Fixed (step removed) | `lifter/flow/call_without_prototype` |
| 26 | `SpecificationControlFlowProvider` inserts into the shared map on a lookup miss. | Fixed | — |
| 26a | Tail calls did not return the callee's result. | Fixed | `lifter/flow/tail_call` |
| 26b | Declaration-only functions (no uses) are removed by GlobalDCE in `OptimizeModule`. | Open (documented) | `lifter/flow/declaration_only` |
| 26c | A data pointer to its own variable stays an `inttoptr` constant. | Open (documented) | `lifter/data/pointers` |
| 26d | SPARC32 lifts every instruction as an EmulateInstruction hyper call; SPARC64 `Arch::Build` aborts. (Cause: anvill used remill's old SPARC archs, whose semantics are gone.) | Fixed (Sleigh-based archs; SPARC64 added in the LLVMParty remill fork, §16.6) | `lifter/arch/sparc32_*`, `lifter/arch/sparc64_*`, `AllocateSignatures/sparc64.ll` |
| 26e | SPARC `call x; restore` (tail-call idiom) is treated as a call that returns to `pc + 8`. | Open (documented) | — |
| 26f | SPARC64: a 32-bit access to a 64-bit register (`st %o0`) reads its high word (Sleigh register part lifted from the register's first byte, under the big-endian layout). | Fixed (remill fork, §16.6) | `lifter/arch/sparc64_kitchen_sink` (`bump`), remill `SPARC64Lifts.StoreWordReadsLowWordOfRegister` |
| 26g | SPARC32: the stack pointer is always 0, so stack accesses become absolute addresses. (`SP` is the high half of the `SP_7` pair; the lifter initialized the enclosing `SP_7` with a zero-extended `__anvill_sp`.) | Fixed (the stack pointer register is `SP` itself when its enclosing register is wider) | `lifter/arch/sparc32_kitchen_sink` (`seventh`, `twice`, `use_pair`) |
| 26j | SPARC64 `sdiv` divides by the zero-extended low word of its operand (Ghidra's spec), so `7 / -2` is 0. | Fixed (Ghidra spec patch in the remill fork, §16.6) | `lifter/arch/sparc64_compiled` (`mul_div`), remill `SPARC*Lifts.SignedDivide*` |
| 26k | remill's p-code CFG makes a block that ends at a local label (`if (!c) goto <end>; x = y; <end>: ...`) leave the instruction, skipping the ops after the label on that path: on SPARC64 `retl; movl %fcc0, 10, %o0` did not return when it moved. | Fixed (remill fork, §16.6) | `lifter/arch/sparc64_compiled` (`float_less`), remill `SPARC*Lifts.ReturnWithConditionalMove*` |
| 26l | SPARC64: an `i32` argument is zero-extended into its 64-bit register, while the V9 ABI sign-extends signed integers (LLVM types carry no signedness). Code that uses the whole register of a negative `int` argument (e.g. as an address offset) is lifted with the wrong upper bits. | Open (documented) | — |
| 26i | SPARC annulled branches (`b<cond>,a`, `br<cond>,a`) branch the wrong way: remill set `BRANCH_TAKEN` to the condition of the branch to the fallthrough without applying `BranchTakenVar::invert`. | Fixed (remill fork, §16.6) | `lifter/arch/sparc32_annulled_branch`, `sparc64_annulled_branch`, remill `SPARC*Lifts.AnnulledBranch*` |
| 26h | SPARC: structure-returning functions (`jmp %o7 + 12`) end in an indirect jump, keeping the whole `State`. | Fixed (remill fork categorizes them as returns; displacement 12 accepted) | `lifter/arch/sparc32_kitchen_sink` (`make_pair`), `RemoveRemillFunctionReturns/sparc.ll` |
| | **Cross-reference folder (§12)** | | |
| 27 | `ICmp ule` is `<`; clz/ctz/ctpop use 64-bit semantics (clz/ctz of 0 UB); oversized shifts are not invalid. | Fixed | `CrossReferenceFolderTest.cpp` |
| 28 | The entity fast path leaves flags uninitialised; `Displacement()` returns 0 for widths other than 8/16/32/64. | Fixed | `CrossReferenceFolderTest.cpp`, `RemoveStackPointerCExprs/*` |
| | **Passes and pipeline (§13; full table in §13.8)** | | |
| 29 | The first function pipeline (and GlobalOpt/GlobalDCE) runs **twice**. | Kept (the output depends on it) | `lifter/**/*.optimized.ll` |
| 30–40 | `ConvertXorsToCmps`, `CombineAdjacentShifts`, `ConvertMasksToCasts`, `HoistUsersOfSelectsAndPhis`, `SplitStackFrameAtReturnAddress`, `ConvertSymbolicReturnAddressToConcreteReturnAddress`, `RemoveStackPointerCExprs`, `RemoveUnusedBranchHints`, `SliceManager`, `LowerSwitchIntrinsics` bugs; dead `SimplifyStackArithFlags`. | Fixed / removed | §13.8 |
| 40a | `RecoverBasicStackFrame`: unaligned frame, wrong `__anvill_stack_zero`, whole-frame init store, slot-count array length, init past a clamped frame. | Fixed | `RecoverBasicStackFrame/*` |
| | **Driver (§14)** | | |
| 41 | `--add_breakpoints` is not wired up; `--add_names` crashes on functions that failed to lift; a bad `--default_callable_spec` throws. | Fixed | `lifter/flow/breakpoints` |
| | **Python (§15)** — see §15.14 for 17 items, including union serialisation, the IDA `char` crash and the missing `itertools` import. | Open (the Python generator was not changed) | — |

---

## 18. Reimplementation roadmap

A practical order for building an equivalent tool, with the "must match" contracts for each step.

1. **Spec model and parser.**
   - Generate C++ from `specification.proto` and implement §5–§6.
   - Decide up front whether to reproduce the original quirks (§17's "old" behaviour, e.g. mandatory overrides) or the fixed behaviour that the golden files pin down.
   - Write a protobuf **text-format → binary** helper so you can author tests by hand (e.g. `protoc --encode=specification.Specification specification.proto < x.textproto > x.pb`).
2. **TypeSpec ⇄ LLVM types and the symbol-name encoder** (§7).
   - Structs are packed literals, pointers are opaque `ptr`, and `Unknown(n)` becomes `i(8n)`.
   - The encoder is needed for `sub_<addr>_<enc>_<cc>` and `var_<addr>_<enc>` names, which later passes rely on. For example, `.frame_type` lookup uses the function name prefix.
3. **Calling-convention allocator** (§8): `AllocationState` first-fit over ordered register tables, plus per-convention tables, stack starting offsets, the return stack pointer and the return-address location. Needed for `callable.type` prototypes and for `FunctionDecl::Create` from LLVM functions. Explicit-location specs bypass it. Check it against `tests/golden/passes/AllocateSignatures/*.expected.txt` (§8.11).
4. **`LoadLiftedValue` / `StoreNativeValue` / `AdaptToType`** (Appendix B), then **`CallFromLiftedBlock`** (§8.5).
5. **Function lifter** (§10).
   - Implement the edge work list, the flow table in §10.4, typed calls through the symbolic PC, and the `__anvill_complete_switch` index switch.
   - Then the native wrapper with `State` alloca and register globals, recursive inlining with `!pc` propagation, the light cleanup, and the copy into the target module.
   - Use the §10.10 example (`tests/golden/lifter/basic/increment`) as the first end-to-end test.
6. **Data and value lifter** (§11): globals as `var_<addr>_<enc>` with initialisers built from memory bytes, pointers resolved to entities, interior pointers as GEPs, and constness from permissions.
7. **Cross-reference folder** (§12). Many passes depend on it.
8. **The passes**, in this order of payoff:
   1. `LowerRemillMemoryAccessIntrinsics`
   2. `RemoveRemillFunctionReturns`
   3. `TransformRemillJumpIntrinsics`
   4. `RecoverBasicStackFrame` and `SplitStackFrameAtReturnAddress`
   5. `ConvertAddressesToEntityUses`
   6. the `__remill_*` cleanup passes (error, delay slot, barrier, undefined, FP classify)
   7. `JumpTableAnalysis` and `LowerSwitchIntrinsics` (Z3)
   8. `BranchAnalysis`/`BranchRecovery` (Z3)
   9. the peepholes

   Schedule them exactly as in §13.6, including the double run if output parity matters.
9. **Driver** (§14).
10. **Validation.**
    - Run the golden suite (§16.7) against your implementation: each `passes/**/*.ll` through your pass runner
      with the `RUN` flags, each `lifter/**/*.textproto` through your lifter, and compare with the expected files.
      A port of `run_golden.py` only needs a different command line per tool.
    - Port `tests/anvill_passes` (the `.ll` fixtures and their expected counts) and `tests/tools`.
    - Re-create the round-trip harness (§15.11): compile C, generate a spec, lift, recompile the `.bc`, and compare stdout and exit code. A spec producer is needed for this; the protobuf one is not open source.

Things you can leave out at first:

- the Python generator (stale; §15);
- `HoistUsersOfSelectsAndPhis` (not scheduled); `SimplifyStackArithFlags` was removed;
- data-provenance and breakpoint instrumentation;
- the wrapped-types mode of `TypeDictionary` (compiled out).

---

## Appendix A. Generated names and constants


All are `extern const std::string` in namespace `anvill`.

| Constant | Value | Purpose / where used |
|---|---|---|
| `kAnvillNamePrefix` | `"__anvill_"` | common prefix |
| `kSymbolicPCName` | `"__anvill_pc"` | global var whose `ptrtoint` taints PC-derived values (LifterOptions::SymbolicProgramCounterInit; `IsProgramCounter`) |
| `kSymbolicSPName` | `"__anvill_sp"` | same for the stack pointer (SymbolicStackPointerInit; `IsStackPointer`) |
| `kSymbolicRAName` | `"__anvill_ra"` | same for the return address (SymbolicReturnAddressInit; `IsReturnAddress`) |
| `kUnmodelledRegisterPrefix` | `"__anvill_reg_"` | globals `__anvill_reg_<REGNAME>` that are loaded to fill the State struct (FunctionLifter; `IsLoadOfUnmodelledRegister`) |
| `kTypeHintFunctionPrefix` | `"__anvill_type_hint"` | prefix of type-hint functions (see §7.7) |
| `kMemoryPointerEscapeFunction` | `"__anvill_memory_escape"` | sink for the final Remill `Memory*` so memory intrinsics are not DCE'd (FunctionLifter / Optimize) |
| `kStackFrameTypeNameSuffix` | `".frame_type"` | recovered stack frame struct type name = `<func_name>.frame_type` (RecoverBasicStackFrame) |
| `kGlobalVariableNamePrefix` | `"var_"` | lifted global var name `var_<hexaddr>_<alnum type encoding>` (DataLifter) |
| `kGlobalAliasNamePrefix` | `"data_"` | lifted global alias name `data_<hexaddr>_<alnum type encoding>` (DataLifter) |
| `kSymbolicStackFrameValuePrefix` | `"__anvill_stack_"` | symbolic stack-frame init values (RecoverBasicStackFrame) |
| `kAnvillSwitchCompleteFunc` | `"__anvill_complete_switch"` | switch lowering |
| `kAnvillSwitchIncompleteFunc` | `"__anvill_incomplete_switch"` | switch lowering |
| `kAnvillDataProvenanceFunc` | `"__anvill_data_provenance"` | data-provenance uninterpreted function (`track_provenance`) |
| `kAnvillStackZero` | `"__anvill_stack_zero"` | metadata kind on stack-frame `alloca`s: the logical "zero offset" |

Also from Utils.cpp: `CreateFunctionName(addr)` = `"sub_" + hex(addr)` (lowercase hex, no `0x`), `CreateVariableName(addr)` = `"data_" + hex(addr)`.
From ValueLifter: a temporary function named `.anvill.value_lifter.temp` (PrivateLinkage) is created and erased again (§11.2).


## Appendix B. IR utility helpers (`lib/Utils.cpp`)


### B.1 `Value *AdaptToType(IRBuilderBase &ir, Value *src, Type *dest)`
- same type → src.
- int → int: CHECK the sizes differ. Widening → `zext`. Narrowing to i1 → `icmp ne src, 0`. Other narrowing → `trunc`.
- int → ptr: if `src` is a `PtrToIntOperator`, use its operand (bitcast to `ptr` if it isn't already dest); otherwise `inttoptr` to `ptr` addrspace 0. Then `addrspacecast` if dest's address space ≠ 0.
- ptr → ptr: addrspacecast if the spaces differ, then bitcast if the type still differs.
- ptr → int: addrspacecast to AS0 if needed, then `ptrtoint` to `iN` (N = DL pointer bits of the insertion block's module), then recurse.
- float → double: `fpext`. float → int: `bitcast` to i32, then recurse.
- double → float: `fptrunc`. double → int: `bitcast` to i64, then recurse.
- Fallback when `src` is a LoadInst: re-issue the load at the same position with `dest` type (copying volatile, atomic ordering, alignment and metadata). This is how a register value gets reinterpreted, e.g. loading `double` from the XMM0 storage.
- otherwise → nullptr. Callers then type-pun through memory.
Every created instruction gets `CopyMetadataTo(src, new)`.

### B.2 `CopyMetadataTo(src, dst)`
Only acts when both are distinct Instructions. Copies all non-debug-loc metadata *except* `tbaa`, `tbaa.struct`, `noalias` and `alias.scope` (so `!pc` and `!stack_offset` propagate).

### B.3 `UnfoldConstantExpressions(Instruction*)`
For every operand that is a ConstantExpr: `ce->getAsInstruction()` inserted before `inst`, recursively unfolded, and the use is replaced. For calls, the args are also processed (a redundant second walk).

### B.4 Classification predicates
- `IsStackPointerRegName(module, name)` (by target triple): x86 `esp`; x86_64 `rsp|esp`; aarch64 `sp|xsp|wsp`; arm/armeb/aarch64_32 `r13|sp|wsp`; sparc/sparcel/sparcv9 `o6|sp`.
- `IsProgramCounterRegName`: x86 `eip`; x86_64 `rip|eip`; aarch64 `pc|wpc`; arm `pc`; sparc `pc|npc`.
- `IsLoadOfUnmodelledRegister(load, pred)`: the pointer operand is a GlobalVariable named `__anvill_reg_<X>` and `pred(lower(X))` holds.
- `IsStackPointer(M, v)`: GlobalVariable named `__anvill_sp`; or a Load of `__anvill_reg_<sp>`; or a call to `llvm.sponentry`, or to `llvm.read_register` whose metadata string names the SP.
- `IsProgramCounter(M, v)`: GlobalVariable `__anvill_pc`, or a Load of `__anvill_reg_<pc>`.
- `IsReturnAddress(M, v)`:
  - GlobalVariable `__anvill_ra`;
  - a call to `llvm.returnaddress` or `llvm.sponentry` **[QUIRK: sponentry]**;
  - a call to `__remill_read_memory_*` whose arg1 is a call to `llvm.addressofreturnaddress`;
  - a load from an `addressofreturnaddress` call;
  - PtrToInt / IntToPtr instructions, or BitCast operators → recurse on the operand;
  - ConstantExpr `add` with one RA side and the other side an "acceptable displacement" (SPARC: 0, 4 or 8; others: 0), or CE IntToPtr → recurse.
- `StackPointerResolver(Module*)` / `IsRelatedToStackPointer(M, v)`: a memoised DFS that returns true if *any* source is the SP. It walks PtrToInt operators; CEs (casts, GEP, shifts, div, ext/trunc → op0; add, sub, mul, and, or, xor, icmp → either side; select / fcmp → any of the 3 operands); binary/unary operators; select instructions; `stripPointerCastsAndAliases`; `stripAndAccumulateConstantOffsets`; and finally `IsStackPointer`.
- `CanBeAliased(v)`: GlobalVariable/Function that is not a declaration; GlobalAlias → its aliasee; GEP → its base; CE BitCast/PtrToInt/IntToPtr → its operand; else false.

### B.5 `LoadLiftedValue(decl, types, intrinsics, block, state_ptr, mem_ptr)`
CHECK that the module equals `intrinsics.read_memory_8`'s parent, and set `decl_type = Recontextualize(decl.type)`.
- reg: `p = decl.reg->AddressOf(state_ptr, block)`; `r = load reg_type, p` (copy mem_ptr metadata); `a = types.ConvertValueToType(ir, r, decl_type)`. Return `a` if non-null, else `load decl_type, p` (type pun).
- mem_reg: `base = load mem_reg_type, AddressOf(mem_reg)`; `addr = base + off` (add, or sub for a negative offset; skipped when 0); `v = remill::LoadFromMemory(intrinsics, block, decl_type, mem_ptr, addr)` (emits `__remill_read_memory_N` calls, struct-wise if needed); return `ConvertValueToType(v, decl_type)`, an identity.
- absolute (`mem_offset != 0`, no regs): `addr = ConstantInt(type of arg1 of read_memory_8, mem_offset)`, then LoadFromMemory.
- none: DLOG(ERROR), return `undef decl_type`.

### B.6 `StoreNativeValue(native, decl, types, intrinsics, block, state_ptr, mem_ptr) → new mem_ptr`
CHECK `native->getType() == decl_type`.
- reg: `p = AddressOf`. If `decl_type != reg_type`, first `store zeroinitializer(reg_type), p`, which clears the upper bits. Then `a = ConvertValueToType(native, reg_type)` and `store a, p`; if that is null, `store native, p` (pun). Return the mem_ptr unchanged.
- mem_reg: compute `addr` as in the load case, then `remill::StoreToMemory(intrinsics, block, native, mem_ptr, addr)`, which returns the new mem_ptr.
- absolute: same with a constant address.
- none: return `undef(mem_ptr type)`.


## Appendix C. `Result<V, E>` and the tool tests


```cpp
template <typename ValueType, typename ErrorType> class Result final {
  bool destroyed{true};         // "contents taken / not set"
  mutable bool checked{false};  // Succeeded() has been called
  std::variant<ValueType, ErrorType> data;
 public:
  Result();                         // checked=true, data=ErrorType(), destroyed stays TRUE → unusable until assigned
  bool Succeeded() const;           // VerifyState; checked=true; holds_alternative<ValueType>
  const ErrorType &Error() const;   // VerifyState, VerifyChecked, VerifyFailed
  ErrorType TakeError();            // same, then move out; destroyed=true
  const ValueType &Value() const;   // VerifyState, VerifyChecked, VerifySucceeded
  ValueType TakeValue();            // same, then move out; destroyed=true
  const ValueType *operator->() const;   // &Value()
  Result(const ValueType&); Result(ValueType&&);     // destroyed=false, checked=false
  Result(const ErrorType&); Result(ErrorType&&);
  Result(Result&&) noexcept; Result &operator=(Result&&) noexcept;
      // data = exchange(other.data, ErrorType()); checked = exchange(other.checked, true); destroyed = exchange(other.destroyed, false)
  Result(const Result&) = delete; Result &operator=(const Result&) = delete;
};
```
Violations throw `std::logic_error` with these messages:
- VerifyState (`destroyed`): "The Result<ValueType, ErrorType> object no longer contains its internal data because it has been moved with TakeError/TakeValue"
- VerifyChecked: "...object was not checked for success"
- VerifySucceeded: "...object has not succeeded"
- VerifyFailed: "...object has not failed"

Semantics to reproduce:
- You must call `Succeeded()` before `Value()`/`Error()`.
- `Take*` invalidates the object (destroyed=true) until it is assigned again.
- A moved-from Result becomes `{ErrorType(), checked=true, destroyed=false}`, so `TakeValue` on it throws "has not succeeded".
- Assigning a raw value works through an implicit converting constructor plus the move assignment, and resets `checked=false`.
- Because the default `Result()` is "destroyed", `Succeeded()` on it throws.
- Ambiguity caveat: if ValueType == ErrorType the converting constructors clash. The repo always uses distinct types, e.g. `Result<X, std::string>` and `Result<std::monostate, std::string>`.

tests/tools/src/Result.cpp (doctest suite "Result"; `main.cpp` is `DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN`; target `test_anvill`):
- "Must not be copyable": static `is_*copy*` traits are all 0.
- "Self-test": a custom deleter counts deletions.
- "Sanity checks", using `Result<std::unique_ptr<void, Deleter>, TestErrorCode>`:
  1. `Succeeded()` on a default-constructed Result throws.
  2. Assign a value: no deletion, `Succeeded()` is true, and `Value()` can be called repeatedly.
  3. `TakeValue()` moves the value out (deleted when it goes out of scope, count=1); a second `TakeValue()` throws.
  4. Re-assign, then `result2 = std::move(result)`: result2 is destroyed at scope end (count=2); `TakeValue()` on the moved-from object throws.
  5. Re-assign, then `Value()`/`Error()` without calling `Succeeded()` first both throw (not checked).

tests/tools/src/TypeSpecification.cpp: see §7.4. It checks that `DecodeFromSpec` succeeds and prints the expected LLVM type string. There are two cases, "Basic string to type conversions" and "Simple spec -> type -> spec roundtrip"; the encode-side test is commented out.


## Appendix D. Short reimplementation checklist

1. The CC is chosen from the LLVM `callingconv` on the function: non-C uses the ID table, C uses the arch/OS table. There is no Win64 CC, and on AMD64 stdcall/fastcall/thiscall map to the *32-bit* X86_C object.
2. Return values are bound before parameters; an injected sret on x86 adds a leading param typed as the *struct*. SysV puts it in RAX and blocks RDI; x86 puts it at [ESP+4].
3. The register allocator is first-fit over an ordered table with type-class masks. Packing is only enabled inside aggregates and vectors, there is no rollback, there is no alignment, and the stack offset grows by `getTypeAllocSize` with no slot rounding.
4. Returns: multiple ValueDecls in the same register are coalesced into an identified struct. Multiple return registers make the function type return an identified struct; `CallFromLiftedBlock` `extractvalue`s each field.
5. The decl type is always overwritten with the ABI layout: params = list of ValueDecl types, return = single or struct.
6. Spec structs → packed literal structs; pointers → opaque `ptr`; Unknown(n) → i(8n) (i32 for UINT32_MAX).
7. Type encoding for symbol names always uses unsigned integer letters, explicit `p` padding (`[pxN]` for 8 bytes or more), `=N{}`/`%N` (default) or `_XN_E…_F`/`_MN` (alnum).
8. Globals `var_<hex>_<enc>` are const when the first byte is R or RX; aliases `data_<hex>_<enc>`; everything registered goes into `@llvm.compiler.used`.
9. XRef folding works on 64-bit-masked integers, with sign wrapping for add/sub/mul, a signed displacement via `Displacement()`, and a magic RA of `0x41…41`.
