# Anvill: A Reimplementation-Grade Technical Report

This report describes the repository at commit `9948d26` ("update link to empirehacking slack (#383)"). It covers what each component does, how the components fit together, the exact data formats, the algorithms (step by step), the names Anvill generates, and the known quirks. The goal is that someone could build a functionally equivalent tool from this document alone.

Scope and method:

- I read every C++ source and header under `include/`, `lib/` and `bin/`, the protobuf schema, the docs, the tests, the Python package, the build files and the CI scripts.
- The `remill` git submodule is **not checked out** in this repository snapshot. Remill behaviour is described from how Anvill calls it, plus Remill's well-known public design. Where that matters it is marked.
- Nothing was built or run. The IR examples are either copied from the test data under `tests/anvill_passes/data/` or constructed by hand from the code. Constructed examples are labelled *illustrative*.
- **[QUIRK]** marks behaviour that differs from the real ABI or the docs, or that looks like a latent bug. A faithful clone needs to copy these to produce byte-identical output. A "better" clone would fix them. Section 17 collects them all.

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

  0 = unspecified, which is rejected. These map one-to-one to `remill::kArchX86` … `kArchSparc64`. `AARCH64` maps to `kArchAArch64LittleEndian` and `AARCH32` to `kArchAArch32LittleEndian`.
- `OS`: 1 LINUX, 2 MACOS, 3 WINDOWS, 4 SOLARIS. 0 is rejected.
- `CallingConvention`: the values are **LLVM `CallingConv::ID` numbers**: 0 unspecified/C, 1 CDECL (*note: 1 is **not** a defined LLVM calling convention; LLVM's C is 0 and fastcc is 8*, **[QUIRK]**), 64 STDCALL, 65 FASTCALL, 70 THISCALL, 78 AMD64_SYSV, 79 WIN64, 80 VECTORCALL. The value is copied verbatim into `llvm::Function::setCallingConv`.
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

| Remill flow at instruction `pc` | Override required at `pc` | Otherwise |
|---|---|---|
| Normal / NoOp | none, or `Other`. `Other.stop=true` ends the block with `__remill_error` | other kinds → `LOG(ERROR)`, ignored |
| DirectJump | **`Jump` with exactly 1 target, equal to the decoded target**, or a `Call` (tail call) | **`LOG(FATAL)`** |
| IndirectJump | `Jump` (0 targets → `__remill_jump`; 1 → `br`; N → switch), `Call` (tail call), or `Return` | **`LOG(FATAL)`** |
| Direct / indirect call | **`Call`** (looked up by `CallFunction`) | **`LOG(FATAL)` "Invalid spec for call"** |
| FunctionReturn | not consulted | — |
| Conditional | the taken branch is checked as above | — |

So a producer must emit a `Jump` record for **every** direct jump, a `Call` record for every call, and so on.

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
   - **`return.type` is always decoded, even when there are no return values.** `DecodeType(function.return_().type())` runs before the values are examined, and an absent `return` or `return.type` is an unset proto3 oneof, which fails with "Unknown/invalid data type". The function or call site is then skipped with a warning. **[QUIRK]** A void-returning prototype must therefore still carry a type and no values:

     ```textproto
     return { type { base: BT_VOID } }      # no `values` → void return
     ```

     The same applies to `Callsite.callable` and to the `--default_callable_spec` file (§14).
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

In principle you could instead set `callable.type { function { return_type { base: BT_I32 } arguments {...} arguments {...} } }` and let the SysV allocator place the arguments in EDI and RSI. In this revision that path is broken by the `DecodeType` bug described at the end of §6, so use explicit locations.

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
   - **global_variables**: decoded with `DecodeGlobalVar`. The type must decode, must not be a function type, must not be void, and must be sized. Stored in `variables` (sorted) and `address_to_var`. **[QUIRK]** On a decode failure the error is recorded but there is **no `continue`**, so `maybe_var.Value()` is then called on a failed `Result` and throws `std::logic_error`. **[QUIRK]** The duplicate check looks in `address_to_function`, not `address_to_var`.
   - **symbols**: an empty name is a hard error. Stored in `multimap<uint64, string>`.
   - **memory_ranges**: expanded **byte by byte** into `std::map<uint64, pair<uint8, BytePermission>>`. The permission is `R`, `RW`, `RX` or `RWX` from the two flags. An overlapping byte is a hard error ("was previously mapped").
   - **overrides**: if absent, hard error "Spec has no control flow overrides". Each jump, call, return and other is stored in a sorted vector *and* in `unordered_map<uint64, ControlFlowOverride> control_flow_overrides`. A duplicate address across kinds is a `CHECK` failure. Jump targets are sorted by address.
4. `Specification` is a cheap handle (`shared_ptr<SpecificationImpl>`).
   - Accessors: `FunctionAt`, `VariableAt`, `VariableContaining` (**[QUIRK]** exact-address lookup only, the same as `VariableAt` without the check), and `ForEach{Symbol,Function,Variable,CallSite,ControlFlowRedirect,Jump,Call,Return,MiscOverride}`.
   - **[QUIRK]** `operator!=` returns `impl == that.impl`.
   - `redirections` is never populated.

Protobuf type decoding (`ProtobufTranslator::DecodeType`):

- base → `static_cast<BaseType>`
- unknown → `UnknownType{n}`
- pointer → `PointerType{pointee or void, const}`
- vector/array → `{base, size}`, with an error if base is missing
- struct → members
- alias → `type_map.at(id)`

**[QUIRK]** The one-argument overload builds a `FunctionType` for `has_function()` but falls through without returning it, so it ends in "Unknown/invalid data type". The two-argument (alias-map) overload delegates to the one-argument one for anything it does not handle itself. In practice **every function-typed TypeSpec fails to decode**, whether it appears directly or via an alias. `ParseIntoCallableDecl` decodes `callable.type` with the one-argument overload, so any function or call site that uses `callable.type` is rejected with a warning and skipped. Working prototypes in this revision therefore come from `parameters`/`return`. The `FunctionDecl::Create` allocator path is still exercised by `ValueLifter` (§11.3) for hinted function types.

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
- `OverrideFunctionTypeWithABIReturnLayout()`: 0 returns → keep the type unchanged (an LLVM `void` stays void, and an sret'ed `void` already has a 1-element `returns`). 1 return → `FunctionType(returns[0].type, old params, vararg)`. N>1 → `StructType::create(elems)`, an *identified, unnamed* struct (prints as `%0`, `%1`, …), used as the return type.
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

Illustrative IR (amd64 SysV, `long f(int a, char *b)`, direct; State GEPs abbreviated):
```llvm
%rsp.0   = load i64, ptr %RSP_ptr                     ; return_stack_pointer base
%sp_exit = add i64 %rsp.0, 8
%rsp.1   = load i64, ptr %RSP_ptr                     ; return_address = [RSP+0]
%ra      = call i64 @__remill_read_memory_64(ptr %mem, i64 %rsp.1)
%a       = load i32, ptr %EDI_ptr                     ; reg type == decl type → as is
%rsi     = load i64, ptr %RSI_ptr
%b       = inttoptr i64 %rsi to ptr                   ; AdaptToType(i64 → ptr)
%r       = call i64 @f(i32 %a, ptr %b)
store i64 %r, ptr %RAX_ptr                            ; StoreNativeValue
store i64 %ra, ptr %NEXT_PC
store i64 %sp_exit, ptr %RSP_ptr
```
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
  - otherwise unchanged. **[QUIRK]** The replacement always uses `kTypeFloatOrVec`, even if the original XMM entry was `kTypeVec` (affects return-register tables: under AVX a `double` struct member *can* go to XMM0, under plain AMD64 it can't — see §8.11 example).
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
| X86_StdCall | X86_StdCall | X86_C ("ignored on AMD64") **[QUIRK: returns the 32-bit cdecl object on amd64]** | – | – | – |
| X86_FastCall | X86_FastCall | X86_C **[QUIRK]** | | | |
| X86_ThisCall | X86_ThisCall | X86_C **[QUIRK]** | | | |
| X86_64_SysV | – | X86_64_SysV | | | |
| else / no match | error `"Unsupported calling convention ID: <n>"` |
(AArch32 is not reachable via the ID path.)

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
- FixedVector: `TryVectorRegisterAllocate(vec)`; **[QUIRK]** if that returns None, the composite still returns the (empty) vector `ret` — i.e. *success with zero locations*.
- else LOG(FATAL).
- **[QUIRK] No rollback**: if a composite fails midway, the `fill`/`reserved` state already consumed by earlier members stays consumed. E.g. a SysV struct of 7×i64 eats RDI..R9, fails on the 7th, goes to the stack, and any later integer params also land on the stack.

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
- Packing (only inside composites/vectors) stacks values in one register by bit count; **[QUIRK]** the second value's ValueDecl names the *wider* variant (e.g. `{i32,i32}` → `EDI:i32`, then `RDI:i32`) and there is no notion of bit offset inside the register, so loading the 2nd member reads the *low* bits again. Params are not coalesced (only returns call `CoalescePacking`).
- No alignment rules at all (no even-register pairs on ARM, no slot skipping on SPARC64, no "struct >16 bytes → memory" SysV rule).

`TryVectorRegisterAllocate(vec)`: for each of the `N` elements:
- element must be integer, else LOG(FATAL) `"Unhandled vector type"` (**[QUIRK]** float vectors crash).
- if `conv->ID() == CallingConv::X86_64_SysV`: `ProcessIntVecX86_64SysV(elem, N, bitwidth)` per element; else pack (`can_pack=true`) `TryRegisterAllocate(elem)`.
- any failure → None; returns None also if result empty.

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

### 8.10 Per-convention tables & rules

Common BindParameters loop (SysV, AArch32, AArch64, SPARC32, SPARC64):
```
names = TryRecoverParamNames(func); dl = DataLayout(func.getParent())
alloc = AllocationState(param_constraints, arch, this); [alloc.config.type_splitter = IntegerTypeSplitter]
stack_offset = <CC constant>
for arg in func.args():
   if (a = alloc.TryRegisterAllocate(arg.type)):
       prev = params.size()
       for v in *a: params.push({type=v.type, reg=v.reg} or {mem_reg, mem_offset})
       if exactly one pushed: params[prev].name = name (if non-empty)
       else: params[prev+i].name = name + to_string(i)       // "x0","x1",...
   else:
       params.push({type=arg.type, mem_reg=SP, mem_offset=stack_offset, name})
       stack_offset += dl.getTypeAllocSize(arg.type)     // [QUIRK] no rounding to slot size/alignment
```
Every `BindReturnValues` starts with: if `func.hasStructRetAttr()`: returns = `[{reg=<sret reg>, type=ptr}]` and error if the IR return type is not void (`"Function '%s' with sret-attributed parameter has non-void return type '%s'"`). The sret *parameter* itself is then allocated like any other pointer parameter.

#### X86_64_SysV (X86_64_SysV.cpp), id 78
Param pool (basic): `[DIL/DI/EDI/RDI]`, `[SIL/SI/ESI/RSI]`, `[DL/DX/EDX/RDX]`, `[CL/CX/ECX/RCX]`, `[R8B/R8W/R8D/R8]`, `[R9B/R9W/R9D/R9]` (all kTypeIntegral, kMaxBit8/16/32/64), then `XMM0..XMM7` (kTypeFloatOrVec, kMaxBit128). AVX/AVX512 variants via ApplyX86Ext.
Return pool (used for composites and >192-bit ints): `[AL/AX/EAX/RAX]`, `[DL/DX/EDX/RDX]`, `[CL/CX/ECX/RCX]` (integral), `XMM0`, `XMM1` (**kTypeVec only**), `ST0`, `ST1` (kTypeVec, kMaxBit80).
BindReturnValues by IR return type:
- void → none. iN: N≤64 → `RAX:iN`; ≤128 → `RAX:i64, RDX:i64`; ≤192 → `RAX,RDX,RCX` each i64; else AllocationState on return pool (basically always fails for ints → error `"Could not allocate integral type ..."`).
- ptr → `RAX`. float/double → `XMM0`. x86_mmx → `MM0`. x86_fp80 → `ST0`.
- vector/array/struct → `TryRegisterAllocate` on return pool; success → `CoalescePacking`; failure → **RVO**: `injected_sret=true`, returns=`[RAX:ptr]`.
- else (half, fp128, …) → error `"Could not allocate unsupported type ..."`.
BindParameters: stack_offset starts at **8** (`[rsp+8]`, return addr at `[rsp]`), mem_reg `RSP`. If `injected_sret`: first push `{name="__struct_ret_ptr", type=func.getReturnType() (the struct type itself, not ptr!), reg=RAX}` and `reserved[0]=true` (blocks RDI). **[QUIRK]** real ABI passes the hidden pointer in RDI; anvill says RAX and types it as the struct.
Epilogue: `return_stack_pointer = RSP`, `offset = 8`; `return_address = {mem_reg=RSP, mem_offset=0, type=RSP->type}`.
**[QUIRK]** i128 params: no type_splitter on SysV → stack. `<4 x float>` params → LOG(FATAL).

#### X86_C (cdecl, X86_C.cpp), id 0
Param pool `XMM0..XMM7` (kTypeVec) exists but **BindParameters never uses it**: every param goes on the stack.
Return pool: `[AL/AX/EAX]`, `[DL/DX/EDX]`, `[CL/CX/ECX]` (integral, max 32), `ST0`, `ST1` (kTypeVec, 80).
BindReturnValues: iN ≤32 → `EAX:iN`; ≤64 → `EAX:i32, EDX:i32`; ≤96 → `EAX,EDX,ECX` i32; else pool; ptr → EAX; **float/double/x86_fp80 → ST0**; mmx → MM0; composites → pool+Coalesce, else RVO `injected_sret`, returns `[EAX:ptr]`.
BindParameters: `stack_offset = 4`, mem_reg `ESP`. If injected_sret: push `{type=func.getReturnType() (struct type), mem=[ESP+4]}`, `stack_offset += allocsize(struct)` **[QUIRK: should be +4 for a pointer]**, no name. Then each arg: `[ESP+stack_offset]`, `stack_offset += allocsize(arg)`, `name = names[argno]`.
Epilogue: `return_stack_pointer=ESP`; offset **8** if `func.hasParamAttribute(0, StructRet) || injected_sret` (callee does `ret 4`), else **4**. `return_address = [ESP+0]`.

#### X86_StdCall (id 64) / X86_FastCall (id 65) / X86_ThisCall (id 70)
Source-identical to X86_C except:
- `BindParameters` returns `llvm::ErrorOr<unsigned>` = final `stack_offset`, and `return_stack_pointer_offset = stack_offset` (callee pops args: `ESP_exit = ESP_entry + 4 + Σ allocsize(args)`). StdCall: `= 4` default then overwritten with the value; Fast/ThisCall: `remill::GetReference(maybe_rspo)`.
- no sret special case for the RSP offset (it is included via stack_offset).
- FastCall's param pool prepends `ECX`, `EDX` (kTypeIntegral, kMaxBit32); ThisCall prepends `ECX`. **[QUIRK] These pools are never consulted** — BindParameters is the stack-only loop, so `this`/fastcall register args are modelled as stack args.

#### AArch64_C (AArch64_C.cpp), id 0
Param pool: `[W0/X0]..[W7/X7]` (integral, 32/64), `V0..V7` (**kTypeIntegral**, kMaxBit128) **[QUIRK: integer overflow after X7 goes to V0..V7]**, `[H0/S0/D0]..[H7/S7/D7]` (kTypeFloat, 16/32/64), `Q0..Q7` (kTypeFloat, 128).
Return pool: `[Wn/Xn]` n=0..7, `[Hn/Sn/Dn]` n=0..7 (comment: "TODO(pag): Probably totally broken").
`IntegerTypeSplitter`: iN with N>64 → `[ceil(N/64) x i64]`, else nullptr. Used for params and composite returns.
BindReturnValues: logs `LOG(INFO) "Binding on return <type>"`. sret → `X8:ptr`. iN ≤64 → `X0:iN`; ≤512 → `X0..X(k-1)` with **type i32** each (k = ceil(N/64)) **[QUIRK: element type should be i64]**; >512 → `X8:ptr` (no injected param). ptr→X0, half→H0, float→S0, double→D0, fp128→Q0. composites → pool+splitter+Coalesce; failure → error (no RVO).
BindParameters: `CHECK(!injected_sret)` (message mentions SPARC); stack_offset 0, mem_reg `SP`.
Epilogue: `return_stack_pointer = SP`, offset 0; `return_address.reg = X30`, type = X30 type.

#### AArch32_C (AArch32_C.cpp; AAPCS soft-float only), id 0
Param pool `R0..R3` (integral, kMaxBit32). Return pool `R0..R3`.
`IntegerTypeSplitter`: N>32 → `[ceil(N/32) x i32]`.
BindReturnValues: sret → `R0:ptr`. iN ≤32 → `R0`; ≤64 → `R0,R1` i32; ≤128 → `R0..R3` i32 (count = ceil(N/32)); else `R0:ptr`. ptr/half/float → `R0`. double → `R0:double, R1:double` **[QUIRK: both typed double]**. fp128 → `R0:double, R1:double` (uses getDoubleTy, loop bounded at 2). composites → pool+Coalesce; failure → `R0:ptr` **but injected_sret is NOT set** so no hidden param is added **[QUIRK]**.
BindParameters: stack 0 off `SP`. **[QUIRK]** float/double params can never match an integral R register (and `has_free_regs` stays false so no splitter) → always stack. i64 → splitter → R0,R1 (no even-pair alignment).
Epilogue: `return_stack_pointer=SP`, offset 0, `return_address.reg = LR`.

#### SPARC32_C (SPARC32_C.cpp), id 0
Param pool `o0..o5` (**kTypeNumeric** — ints, ptrs and floats; kMaxBit32).
Return pool `o0..o5` (integral 32), `f0..f3` (float 32), `d0`, `d2` (float 64).
`IntegerTypeSplitter`: N>32 → `[ceil(N/32) x i32]`.
BindReturnValues: sret → `o0:ptr`; iN ≤32 → `o0`; ≤192 → `o0..o5` i32 (ceil(N/32)); else error. ptr → o0; half/float → f0; double → d0; composites → pool+splitter+Coalesce; failure → error.
BindParameters: `CHECK(!injected_sret)`; **stack_offset = 92** (`[%fp+92]` after `save`), mem_reg `o6`. **[QUIRK]** double param: 64 > 32 bits, splitter only for ints → stack (real ABI splits over two o regs).
Epilogue: `return_stack_pointer=o6` off 0; `return_address.reg = o7`.

#### SPARC64_C (SPARC64_C.cpp), id 0
Param pool `o0..o5` (integral, kMaxBit64), `f1,f3,...,f31` (float 32), `d0,d2,...,d30` (float 64), `q0,q4,...,q28` (float 128).
Return pool `o0..o5`, `f0..f31`, `d0..d30` even, `q0..q28` step 4.
`IntegerTypeSplitter`: N>64 → `[ceil(N/64) x i64]`.
BindReturnValues: sret → o0; iN ≤64 → o0; ≤384 → `o0..o5` **typed i32** (ceil(N/64)) **[QUIRK]**; else error. ptr→o0, half/float→f0, double→d0, fp128→q0; composites → pool+Coalesce else error.
BindParameters: `CHECK(!injected_sret)`; **stack_offset = 2227** (experimentally found; 2047 bias + 176 + 4), mem_reg `o6`. No slot-based FP register assignment.
Epilogue as SPARC32 (`o6`+0, ra in `o7`).

### 8.11 Worked examples

Canonical C: `struct S {long a; double b;} f(int, float, char*);` Input to `FunctionDecl::Create` is an `llvm::Function`. Via the protobuf path the struct TypeSpec decodes to a *packed literal* struct (§7.4), so the IR signature is `<{iL, double}> (i32, float, ptr)` with `iL` = i64 on LP64 targets and i32 on ILP32 ones. Unnamed args → names `param0`, `param1`, `param2`.

**x86-64 SysV, plain `kArchAMD64`** — signature `<{i64,double}>(i32,float,ptr)`:
- Return: composite on return pool → i64: RAX (fill 64 → reserved). double: tc Float; RDX/RCX integral, XMM0/XMM1/ST0/ST1 are kTypeVec → no match, `has_free_regs=false` → None ⇒ **RVO**: `returns=[RAX:ptr]`, `injected_sret=true`.
- Params: `__struct_ret_ptr : <{i64,double}> @ RAX` (and slot 0/RDI blocked); `param0 : i32 @ ESI` (RSI slot, fill 32 → smallest variant ESI); `param1 : float @ XMM0`; `param2 : ptr @ RDX` (RSI is partly filled and packing is off outside composites, so it skips to RDX).
- `return_stack_pointer = RSP + 8`; `return_address = [RSP+0] : i64`.
- Final `decl.type` = `ptr (<{i64,double}>, i32, float, ptr)`.
- Real ABI: RAX+XMM0 return, args EDI, XMM0, RSI. Anvill differs because of the kTypeVec return table and the sret handling.

**x86-64 SysV, `kArchAMD64_AVX`** (XMM in the return table becomes FloatOrVec):
- Return: RAX:i64, XMM0:double (fill 64 → smallest variant XMM0). `CoalescePacking` → `returns=[RAX:i64, XMM0:double]`.
- Params: `param0:i32@EDI`, `param1:float@XMM0`, `param2:ptr@RSI`. RSP+8. Type `%0 (i32, float, ptr)` where `%0 = type {i64, double}` (identified struct from `StructType::create`).
- This matches the real ABI.

Simpler SysV case `long g(int a, double b, char c, char *d)`: a→EDI, b→XMM0, c→SIL, d→RDX (the SIL slot isn't reused); returns RAX:i64.
Struct param `{i32,i32}` (e.g. `struct P{int x,y;}` passed by value as IR aggregate) → two decls `p0:i32@EDI`, `p1:i32@RDI` (packing).

**x86 cdecl (Linux i386)** — signature `<{i32,double}>(i32,float,ptr)`:
- Return: EAX:i32, then double finds no float register (ST0/ST1 are kTypeVec) → RVO: `returns=[EAX:ptr]`, injected_sret.
- Params: `<{i32,double}> @ [ESP+4]` (unnamed); stack_offset += 12 → 16; `param0:i32@[ESP+16]`, `param1:float@[ESP+20]`, `param2:ptr@[ESP+24]`.
- `return_stack_pointer_offset = 8` (sret ⇒ `ret 4`); return address `[ESP+0]`.
- For `int h(int, float, char*)`: returns `EAX:i32`; params `[ESP+4]`, `[ESP+8]`, `[ESP+12]`; RSP offset 4. `double h2()` → `ST0:double`. `long long h3()` → `EAX:i32, EDX:i32`, so the function type returns `%0 = {i32,i32}`.

**x86 stdcall / fastcall / thiscall**, `int h(int, float, char*)`: same stack layout as cdecl (`[ESP+4]`, `[ESP+8]`, `[ESP+12]`); `return_stack_pointer_offset = 16` (4 for the return address + 12 popped bytes). Fastcall/thiscall still put args on the stack, not in ECX/EDX. The sret variant gives 4+12+4+4+4 = 28.

**AArch64** — `<{i64,double}>(i32,float,ptr)`:
- Return: X0:i64 (W0/X0 slot, fill 64 → X0), D0:double (H0/S0/D0 slot) → `returns=[X0:i64, D0:double]` (real AAPCS64 would use X0,X1 since the struct is not an HFA).
- Params: `param0:i32@W0`, `param1:float@S0` (the V0..V7 slots are integral, so it skips to the H/S/D slots), `param2:ptr@X1`. SP+0, RA = X30. This matches the real ABI.

**AArch32** — `<{i32,double}>(i32,float,ptr)`:
- Return: R0:i32, double has no float reg → None → fallback `returns=[R0:ptr]`, no hidden param.
- Params: `param0:i32@R0` (collides with the "sret" R0), `param1:float@[SP+0]` (stack_offset→4), `param2:ptr@R1`. SP+0, RA = LR.
- Real soft-float AAPCS: R0=sret, R1, R2, R3. `long long k(long long)`: param `x0:i32@R0, x1:i32@R1`; returns `R0:i32,R1:i32`.

**SPARC32** — `<{i32,double}>(i32,float,ptr)`:
- Return: o0:i32; double: f0..f3 have only 32 bits → d0 → `returns=[o0:i32, d0:double]` (the real V8 ABI returns structs in memory).
- Params: `param0:i32@o0`, `param1:float@o1` (kTypeNumeric), `param2:ptr@o2`. A 7th int would be at `[o6+92]`; a double param goes straight to the stack. RSP = o6+0, RA = o7.

**SPARC64** — `<{i64,double}>(i32,float,ptr)`:
- Return: o0:i64, d0:double.
- Params: `param0:i32@o0`, `param1:float@f1`, `param2:ptr@o1` (the real V9 ABI is slot-based: f3 and o2). The first stack arg is at `[o6+2227]`.


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
  - `TryGetCalledFunctionType(fn_addr, inst)`: (1) the delegate's call-site decl; (2) **the delegate's `TryGetFunctionType(fn_addr)`, i.e. the *containing* function, not the callee [QUIRK]**, sliced to CallableDecl; (3) the default for `inst.arch_name`; (4) if `inst.arch_name != inst.sub_arch_name`, the default for `sub_arch_name`; else nullopt.
  - `TryGetFunctionType(addr)`: the delegate's, else a FunctionDecl built from the default for `default_arch` with `address = addr`. That makes *every* address look like a function.
- `SpecificationTypeProvider(const Specification&) : BaseTypeProvider(spec.impl->type_translator)`, sharing `spec.impl`.
  - `TryGetCalledFunctionType(fn, inst)` → `impl->loc_to_call_site[{fn, inst.pc}]` (a CallSiteDecl sliced to CallableDecl).
  - `TryGetFunctionType(a)` → `*impl->address_to_function[a]` (exact start address).
  - `TryGetVariableType(a, hint)` → `*impl->address_to_var[a]`. **Exact start address only**: despite the "inverted mapping of byte addresses" comment, Specification.cpp only emplaces the start address. The hint is ignored.

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
- `SpecificationControlFlowProvider(spec)` → `impl->control_flow_overrides[addr]`. This uses `unordered_map::operator[]` through the shared impl, so a lookup miss *inserts* a monostate entry. That is harmless but it mutates the shared state through a const method.


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

- Read up to `arch->MaxInstructionSize(ctx)` bytes, which is 15 on x86 and 4 on the fixed-width architectures. **[QUIRK]** The size is a function-local `static`, computed once for the first context.
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
| `DirectJump` | Override `Jump`: CHECK exactly 1 target, CHECK it equals the Remill-decoded target, lift the delay slot, `br` to the target block (static context). Override `Call` (tail call): delay slot, `CallFunction(inst, block, branch_taken_pc)`, then `InsertError`. Else **FATAL**. |
| `IndirectJump` | Override `Jump`: delay slot; then (a) if `type_provider.TryGetCalledFunctionType(func_address, inst)` gives a call-site prototype, treat it as a typed tail call: `CallCallableDecl(block, load PC, decl)` + `ret mem`; (b) else if there are targets → `DoSwitchBasedIndirectJump`; (c) else tail-call `__remill_jump`. Override `Call`: delay slot, `CallFunction(..., nullopt)`, `InsertError`. Override `Return`: `VisitFunctionReturn`. Else **FATAL**. |
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

```llvm
%pc   = load i64, ptr %PC                                       ; computed jump target
%idx  = call i64 (i64, ...) @__anvill_complete_switch(i64 %pc, i64 4198688, i64 4198720, i64 4198752)
switch i64 %idx, label %unreachable_default [ i64 0, label %inst_401220
                                              i64 1, label %inst_401240
                                              i64 2, label %inst_401260 ]
unreachable_default:  unreachable
```

`__anvill_complete_switch` is declared `iADDR (iADDR, ...)` with `readnone`. Each target block gets the context `ApplyTargetList(target.context_assignments, prev_context)`.

Later, `JumpTableAnalysis` and `LowerSwitchIntrinsics` (§13) slice `%pc` back to the jump-table index computation, bound it with Z3, read the table through the `MemoryProvider`, and replace the whole construct with a native `switch` on the *original index variable*. That is what makes decompiled `switch` statements look natural.

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

### 10.10 End-to-end example (illustrative)

Input: amd64 Linux, function at `0x401130`, bytes `8d 47 01 c3` (`lea eax,[rdi+1]; ret`), with a prototype `i32 (i32)` where the parameter is in `EDI`, the return is in `EAX`, RA = `[RSP]`, return SP = `RSP+8`, and a `Return` override at `0x401133`.

After §10.2–10.7, before inlining:

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

After inlining, the local cleanup and `OptimizeModule` (§13), the expected result is:

```llvm
define i32 @sub_401130__AII_B_0(i32 %0) {
  %2 = add i32 %0, 1, !pc !0
  ret i32 %2
}
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
       // [QUIRK/bug] passes address_space into the `loc_ea` parameter; the real address_space stays 0.
};
class ValueLifterImpl { const LifterOptions &options; const llvm::DataLayout &dl; llvm::LLVMContext &context; TypeTranslator type_specifier; … };
```
`ConsumeBytesAsInt(data&, n)`:
```
APInt r(n*8, 0); for i<n: r <<= 8; r |= data[i];  data = data.substr(n)
return (dl.isLittleEndian() && n > 1) ? r.byteSwap() : r
```
**[QUIRK/latent bug]** `data[i]` is a (signed) `char` passed to `APInt::operator|=(uint64_t)`, so a byte ≥ 0x80 sign-extends and sets all the low 64 bits. A correct reimplementation should use `(uint8_t)data[i]`.

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
   - ConstantExpr: CHECK pointer type, then `found_by_address = ga`, where `ga` is null in that scope **[QUIRK: so CE entities are effectively ignored]**.
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
`Displacement(dl)`: CHECK `size != 0`. Switch on `min(size, ptr_bits)`: 8/16/32 → sign-extend from the low 8/16/32 bits of `u.displacement`; 64 → as is; any other width → 0.
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
| ICmp **ule uses `<`** **[QUIRK/bug]** | Merge | none | yes |
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
- If `AddressOfEntity(ce)` resolves → `{address, size=ptr, references_entity, valid}`. **[QUIRK]** that `xr` is default-initialised, not `{}`, so the other bitfields are indeterminate.
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
- `llvm.ctlz` / `llvm.cttz` / `llvm.ctpop` → resolve arg0 and apply `__builtin_clzl` / `ctzl` / `popcountl` to the 64-bit address. **[QUIRK]** These use 64-bit semantics regardless of width, and clz/ctz of 0 is UB. size = call type bits.
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

Example, from `tests/anvill_passes/data/BranchRecoveryAarch64.ll`, function `@slice(ptr %0, i32 %W10, i32 %W9, ptr %PC_output)`:

```llvm
%2  = xor i32 %W10, -1
...                                   ; %5 = W9 + ~W10 + 1  (= W9 - W10 in i64)
%10 = trunc i64 %5 to i32
%11 = icmp slt i32 %10, 0
%12 = tail call i1 (i1, ...) @__remill_flag_computation_sign(i1 %11, i32 %W9, i32 %W10, i32 %10)
...
%16 = tail call i1 (i1, ...) @__remill_flag_computation_overflow(i1 %15, i32 %W9, i32 %W10, i32 %10)
%17 = xor i1 %12, %16
%18 = xor i1 %17, true
%19 = tail call zeroext i1 @__remill_compare_sge(i1 zeroext %18)
br i1 %19, label %20, label %22
```

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

Before and after, from the BranchRecoveryAarch64 test:

```llvm
; before
%19 = tail call zeroext i1 @__remill_compare_sge(i1 zeroext %18)
br i1 %19, label %20, label %22
; after
%19 = icmp sge i32 %W9, %W10
br i1 %19, label %20, label %22
```

The flag computations become dead. DCE or InstCombine removes them, and `RemoveUnusedBranchHints` handles the rest.

Interaction: the analysis is computed once per function per pass invocation and cached in the FAM.
Keys are `CallInst*`. Replaced calls are erased, but the result is only consulted for calls that still exist.

#### 13.2.5 `RemoveUnusedBranchHints`. File `lib/Passes/RemoveUnusedBranchHints.cpp`

Kind: `IntrinsicPass<RemoveUnusedBranchHints, PreservedAnalyses>` plus PassInfoMixin. `INIT_RES = all()`.
Added by **`AddRemoveFailedBranchHints(fpm)`** (note the name mismatch).

`isTargetInstrinsic`: the callee name starts with `"__remill_compare"` **or** `"__remill_flag_computation"`.

`runOnIntrinsic`: `call->replaceAllUsesWith(call->getArgOperand(0)); call->eraseFromParent();` and returns
`none()`. The `agg` argument is ignored, so the result is `none()` whenever any target existed.

```llvm
; before
%12 = call i1 (i1, ...) @__remill_flag_computation_sign(i1 %11, i32 %a, i32 %b, i32 %r)
%19 = call i1 @__remill_compare_sle(i1 %16)
; after: uses of %12 -> %11, uses of %19 -> %16
```

Gotcha: unlike BranchHintPass, this pass does **not** exclude `__remill_compare_exchange*`. If a
Remill CAS intrinsic survives to this point, its arg0 (the memory pointer) replaces the call
(which also returns `Memory*`). The CAS is silently erased.

#### 13.2.6 `SimplifyStackArithFlags` (dead code, NOT BUILT)

The files are `lib/Passes/SimplifyStackArithFlags.{h,cpp}`. They are not in the `anvill_passes` list in
`lib/CMakeLists.txt`, and they include non-existent headers (`anvill/Analysis/Utils.h`, `anvill/BranchAnalysis.h`).
`AddSimplifyStackArithFlags(fpm, bool)` is declared in Transforms.h but never defined in the build.

Intended behaviour: an IntrinsicPass over calls where `ParseFlagIntrinsic` succeeds. If `flag.over` is a
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

   Then for each scheduled pair: `ce->replaceAllUsesWith(ci); ce->destroyConstant()`.

   **Gotcha:** this is RAUW on a uniqued ConstantExpr. It also rewrites uses in the *original* lifted
   module.
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

Example. This is from the file's header comment and equals `data/SwitchLoweringNeg.ll`, function `@_start`
(aarch64-ish, 64-bit addresses):

```llvm
18:
  %19 = call i64 @_atoi()
  %20 = trunc i64 %19 to i32
  %21 = add i32 %20, 4
  %22 = zext i32 %21 to i64
  %23 = icmp ugt i32 %21, 7
  br i1 %23, label %33, label %25
25:
  %26 = shl nuw nsw i64 %22, 2
  %27 = add nuw nsw i64 %26, 4294983520
  %28 = inttoptr i64 %27 to ptr
  %29 = load i32, ptr %28, align 4
  %30 = sext i32 %29 to i64
  %31 = add nsw i64 %30, 4294983436
  %32 = call i64 (i64, ...) @__anvill_complete_switch(i64 %31, i64 4294983452, i64 4294983464,
                                                     i64 4294983476, i64 4294983484, i64 4294983496)
  switch i64 %32, label %34 [ i64 0, label %35   i64 1, label %36   i64 2, label %37
                              i64 3, label %38   i64 4, label %33 ]
```

The analysis gives:

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
   * `new_switch = SwitchInst::Create(jt.indexRel.getIndex(), jt.defaultOut, (upper - lower + 1))`.
     It is not inserted into a block.
   * For `i = lower` while `bounds.lessThanOrEqual(i, upper)`, with `++i`:
     * `addr = indexRel.apply(interp, i)`;
     * `off = ReadIntFrom(pcRel.getExpectedType(interp), addr)`. This reads `bitwidth/8` bytes via
       `MemoryProvider::Query(addr + k)`, which returns `tuple<uint8_t, ByteAvailability, BytePermission>`.
       Any byte that is not `kAvailable` fails the switch. Then `llvm::LoadIntFromMemory` (host order),
       and `byteSwap()` if `dl.isLittleEndian() != sys::IsLittleEndianHost`;
     * `pc = pcRel.apply(interp, off)` and `bb = binding.Lookup(pc)`. A missing `bb` fails the switch;
     * if `bb != defaultOut`, `new_switch->addCase(ConstantInt(i), bb)`.
   * On any failure: `delete new_switch` and return nullopt.
5. On success: `ReplaceInstWithInst(follower, new_switch)`. If `targetCall` has no uses, erase it.
   Return `none()`.

Before and after, from the SwitchLoweringNeg test. The mock memory at 4294983520 holds the i32 offsets
`[0x10, 0x3c, 0x3c, 0x1c, 0x28, 0x3c, 0x3c, 0x30]`:

```llvm
; after
25:
  ; (%26..%31 now dead)
  switch i32 %20, label %33 [ i32 -4, label %35   i32 -1, label %36
                              i32 0,  label %37   i32 3,  label %38 ]
```

The test expects 4 cases on indices {-4, -1, 0, 3}. Entries that resolve to the default-out PC
(0x3c → 4294983496 → arg 5 → case 4 → `%33`) are omitted.

Gotchas:

* The loop has no wrap guard. If `upper` is the maximum value for its width and signedness,
  `++i` wraps and the loop never terminates, unless a memory read fails first.
* `ReplaceInstWithInst` does not update PHIs in blocks that stop being successors, such as the old
  default `%34`.
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

```llvm
; before
  %2 = icmp eq i64 %1, 1
  %3 = select i1 %2, i64 10, i64 20
  br i1 %2, label %4, label %6
4:  %5 = add i64 %3, 10
6:  %7 = add i64 %3, 20
; after
  %2 = icmp eq i64 %1, 1
  br i1 %2, label %4, label %6
4:  %5 = add i64 10, 10
6:  %7 = add i64 20, 20
```

The test expects `SimpleCase`: 2 replacements and 1 disposable. `MultipleSelects` (3 selects, same
condition): 6 and 3. `MultipleSelectUsages`: 6 and 1.

Interaction: this is scheduled twice (§13.6). It feeds RemoveTrivialPhisAndSelects and cross-reference folding at
branch targets.

#### 13.4.2 `RemoveUnusedFPClassificationCalls`. File `lib/Passes/RemoveUnusedFPClassificationCalls.cpp`

Kind: function pass. It erases every call whose direct callee is named exactly `fpclassify`, `__fpclassifyd`,
`__fpclassifyf` or `__fpclassifyld`, provided the call is `use_empty()`. The NOTE says it must run before
lifted functions are renamed. Example (illustrative): `%r = call i32 @__fpclassifyd(double %x)` with no uses
is deleted.

#### 13.4.3 `RemoveDelaySlotIntrinsics`. File `lib/Passes/RemoveDelaySlotIntrinsics.cpp`

Kind: function pass. It looks up `__remill_delay_slot_begin` and `__remill_delay_slot_end` in the module, and
returns `all()` if neither exists. For each call to either:

```
mem = arg0; CopyMetadataTo(call, mem); call->RAUW(mem); erase.
```

Example (illustrative), for SPARC delay slots:

```llvm
%m1 = call ptr @__remill_delay_slot_begin(ptr %m0)
... %m2 = call ptr @__remill_write_memory_32(ptr %m1, ...)
%m3 = call ptr @__remill_delay_slot_end(ptr %m2)
; after: %m1 -> %m0, %m3 -> %m2
```

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

Example (illustrative):

```llvm
; before
bb: %x = add i64 %a, 1
    %m = call ptr @__remill_error(ptr %s, i64 %pc, ptr %mem)
    %y = load i64, ptr %p
    br label %join
join: %v = phi i64 [ %y, %bb ], [ %z, %other ]
; after
bb: %x = add i64 %a, 1
    unreachable
join: (phi folded) uses of %v -> %z
```

Gotcha: the successor's PHIs are fixed, but the CFG edge removal does not update any analyses beyond
returning `none()`.

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

Example (illustrative; addresses are tainted CEs in real code):

```llvm
; before
%v  = call i32 @__remill_read_memory_32(ptr %mem, i64 %addr)
%m2 = call ptr @__remill_write_memory_64(ptr %mem, i64 %a2, i64 %x)
; after
%1 = inttoptr i64 %addr to ptr
%v = load i32, ptr %1
%2 = inttoptr i64 %a2 to ptr
store i64 %x, ptr %2          ; uses of %m2 -> %mem
```

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

Example (illustrative):

```llvm
call void asm sideeffect "", ""()
call void asm sideeffect "", ""()     ; removed (consecutive)
call void asm sideeffect "", ""()     ; removed
%r = call double @__remill_fpu_op(...)  ; external -> the remaining first barrier is removed too
```

#### 13.4.7 `LowerTypeHintIntrinsics`. File `lib/Passes/LowerTypeHintIntrinsics.cpp`

Kind: function pass. For every CallInst whose direct callee name starts with `__anvill_type_hint`:

```
v = arg0->stripPointerCasts(); cast = IRBuilder(call).CreateBitOrPointerCast(v, call->getType());
CopyMetadataTo(call, cast); call->RAUW(cast);
```

After all calls are rewritten, `use_empty()` calls are erased. Example (illustrative):

```llvm
%p = call ptr @__anvill_type_hint_Si(i64 %x)
; after
%p = inttoptr i64 %x to ptr
```

#### 13.4.8 `ConvertMasksToCasts`. File `lib/Passes/ConvertMasksToCasts.cpp`

Kind: function pass. Collection uses PatternMatch in one forward scan. The first matching pattern wins per instruction:

1. `and V, C` or `and C, V` with `C` a ConstantInt. The mask must be exactly the **low half all-ones**:
   `activeBits(C) * 2 == width` and `countTrailingZeros(~C) == activeBits`. This means 0xFF on i16, 0xFFFF on i32,
   0xFFFFFFFF on i64, and so on. Record `(inst, operand index of V, iN/2)`. The header comment shows
   `and i64 %v, 0xff → trunc i8`, but the code only accepts the half-width mask.
2. `ashr (shl V, A), B` with `A == B`. The check compares `ConstantInt*` identity, which is value equality
   for the same type. The result width must be one of 8/16/32/64/128. Record `(inst, i(width/2))`.
   **Gotcha:** it does not check `A == width/2`. For example, `ashr(shl x, 48), 48` on i64 would be rewritten as
   `sext(trunc to i32)`, which is wrong.
3. `add (shl V, N), C`, where N ∈ {8, 16, 32, 64, 128} and `C` has at least N trailing zeros. Record
   `(inst, C >> N)`.

Rewrites, applied in this order: trunc_zexts, then shl_adds, then shl_ashrs. Each re-matches to tolerate RAUW
from earlier rewrites.

* mask: `t = trunc inst.op[k] to iN/2` and `z = zext t to iN`. Copy metadata to both. RAUW and erase.
* shl_add: re-match `add(Instruction shl, ConstantInt)` and `shl(V, ConstantInt n)`. Build
  `a = add V, (C >> N)` and `s = shl a, n`. RAUW the add with `s`, and schedule the old `shl` for erasure.
  **Gotcha:** this does not set `changed`. If only this rewrite fires, the pass returns `all()`.
* shl_ashr: re-match. `t = trunc V to half` and `s = sext t to iN`. RAUW and erase. Schedule the old `shl`.
* Scheduled `shl`s with no remaining uses are erased.

Example, from the header comment:

```llvm
%256 = shl i64 %255, 32
%257 = ashr exact i64 %256, 32, !pc !70
; after
%t = trunc i64 %255 to i32           ; !pc !70 copied
%257' = sext i32 %t to i64
%m = and i64 %v, 4294967295   ->   %t2 = trunc i64 %v to i32 ; %m' = zext i32 %t2 to i64
```

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

Example (illustrative):

```llvm
%p = phi i64 [ %a, %b1 ], [ %a, %b2 ]   ->  uses of %p become %a
%s = select i1 %c, i64 %p, i64 %p        ->  (next round) uses of %s become %a
```

There is no special handling for self-referential PHIs (`phi [%x, ...], [%p, loop]`): those are not trivial,
because the values differ.

#### 13.4.10 `RemoveStackPointerCExprs`. File `lib/Passes/RemoveStackPointerCExprs.cpp`

Kind: function pass. The constructor is `RemoveStackPointerCExprs(const StackFrameRecoveryOptions&)`.

There is a stale duplicate header, `lib/Passes/RemoveStackPointerCExprs.h`, with a default constructor and
no options. Use the one in `include/anvill/Passes/`.

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
     **Gotcha:** `Displacement()` only handles sizes 8/16/32/64, so an `i1` (icmp) result is always 0, i.e. `false`.
   * If `xr.is_valid` but the value is full width or not an integer: leave it. RecoverBasicStackFrame handles these.
   * If it is not valid: `newi = ce->getAsInstruction()`, inserted **before** `ce_insert_loc`. Then
     `ce_insert_loc = newi`, so successive unfolded CEs stack upward and nested operands come first.
     `use.set(newi)` and push `newi` onto the worklist (its operands may be CEs too).
5. The result is `none()` if anything changed.

Example (header comment and test `RegressionRecoverStack.ll`; this shows the unfold path):

```llvm
; before
%1 = call zeroext i1 (i1, ...) @__remill_flag_computation_sign(
       i1 zeroext icmp slt (i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12), i32 0),
       i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12))
; after (documented)
%1 = icmp slt i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12), 0
%2 = call zeroext i1 (i1, ...) @__remill_flag_computation_sign(i1 zeroext %1,
       i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 -12))
```

With the current folder, an `icmp` CE over the SP folds validly (with size 1), so the operand is actually
replaced by `i1 false` as described above. The test only checks that the module verifies.

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
     * The type is `StructType::create({ [num_slots x word_ty] }, name)`, a non-packed struct with one array.
     * Gotcha: the array element count is `num_slots`, where slots are sized by `slot`. When `word == ptr_size`,
       this gives a byte size of `num_slots * word`.
   * `base_stack_offset = lowest - lower_pad`. This is the same for both growth directions.
   * In the entry block, at the first insertion point: `frame = alloca <frame_type>`. All the instructions created
     below are inserted right after it, in the entry block, with the same IRBuilder.
   * If `stack_offset_metadata_name` is set, attach metadata `"__anvill_stack_zero"` = `!{iPTR base}`, where
     * if the stack grows down: `base = highest + higher_pad - word`;
     * otherwise: `base = lowest - lower_pad + word`.
   * Initialization, according to `stack_frame_struct_init_procedure`:
     * `kZeroes`: `store zeroinitializer, frame`.
     * `kUndef`: `store undef, frame`.
     * `kNone`: nothing.
     * `kSymbolic`: for `i` in `0, word, 2·word, …` up to `< padding + size`:
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

Example, from `data/RecoverStackFrameInformation.ll` (i386; 12 instructions with 14 SP uses):

```llvm
; before (excerpt)
store i32 ptrtoint (ptr @__anvill_ra to i32), ptr inttoptr (i32 ptrtoint (ptr @__anvill_sp to i32) to ptr)
store i32 %0, ptr inttoptr (i32 add (i32 ptrtoint (ptr @__anvill_sp to i32), i32 4) to ptr)
%6 = load i32, ptr inttoptr (i32 add (i32 sub (i32 ptrtoint (ptr @__anvill_sp to i32), i32 16), i32 20) to ptr)
store i32 add (i32 sub (i32 ptrtoint (ptr @__anvill_sp to i32), i32 16), i32 12),
      ptr inttoptr (i32 add (i32 sub (i32 ptrtoint (ptr @__anvill_sp to i32), i32 16), i32 -4) to ptr)
```

Expected analysis: lowest = -28, highest = 16 (12 + sizeof(i32)), size = 44, 14 uses. The frame type for i386
with word 4 has total size 48 (12 slots), or 176 with 128 bytes of padding.

```llvm
; after (illustrative shape, kZeroes)
%frame = alloca %sub_80482e0__Ai_S_Sb_S_Sbi_B_0.frame_type      ; type { [12 x i32] }
store %...frame_type zeroinitializer, ptr %frame
%g0 = getelementptr %...frame_type, ptr %frame, i32 0, i32 0, i32 7   ; offset 0 -> z=28 -> slot 7
store i32 ptrtoint (ptr @__anvill_ra to i32), ptr %g0
%g1 = getelementptr ..., i32 0, i32 0, i32 8                         ; sp+4
store i32 %0, ptr %g1
; store i32 (sp-16+12 = sp-4), ptr (sp-16-4 = sp-20):
%g2 = getelementptr ..., i32 0, i32 0, i32 6                         ; value: off -4  -> z=24 -> slot 6
%i2 = ptrtoint ptr %g2 to i32                                         ; integer-typed operand -> ptrtoint
%g3 = getelementptr ..., i32 0, i32 0, i32 2                         ; ptr:   off -20 -> z=8  -> slot 2
store i32 %i2, ptr %g3
```

The test also checks that the alloca is the first instruction and that there are 14 GEPs in the entry block.

`data/SplitStackFrameAtReturnAddress.ll` shows the kSymbolic output on the same function. It has 44
`__anvill_stack_minus_28 … plus_15` i8 globals (`word = 1`), so the frame is `<{ [44 x i8] }>`.

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

   Gotcha: the `seen` set is never inserted into, so a user that consumes the same value twice is walked twice
   and its uses are recorded twice.
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
     * `above` → `("parameters", "locals", ceil(ra_off / ptr))`;
     * `below` → `("locals", "parameters", ceil((allocSize(frame) - ra_end) / ptr))`;
     * `at` → `("return_address_loc", "return_address_loc", 1)`.

     The naming looks inverted for downward-growing stacks. Offsets below the RA are the callee's locals, but
     they are named "parameters". The code is as written.
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
    * else compute `sub_off` for the prefix and `sub_ret = DemandedOffset(off + sub_off)`, then build
      `new_gep = gep indexedType(prefix), bitcast(ret), rest` and schedule `to_replace[user] = new_gep`.
      **Gotcha:** the code uses `ret`, not `sub_ret`, as the base, so the prefix offset is lost. Also, the
      variable indices may be defined after the entry block, so the new GEP (inserted before the alloca) could
      violate dominance.
* `ICmp`, `PHI`, `Select` and the default case: `ptrtoint` if `use_inst` has an integer type, otherwise
  `bitorptrcast` to `use_inst`'s type; then `use->set(...)`.

Example, from `data/SplitStackFrameAtReturnAddress.ll` (i386, frame `<{ [44 x i8] }>`, RA stored at byte 28):

```llvm
; before (excerpt)
%4  = alloca %sub_80482e0__Ai_S_Sb_S_Sbi_B_0.frame_type, align 8
%93 = getelementptr %...frame_type, ptr %4, i32 0, i32 0, i32 28
%94 = bitcast ptr %93 to ptr
store i32 ptrtoint (ptr @__anvill_ra to i32), ptr %94, align 4
%95 = getelementptr %...frame_type, ptr %4, i32 0, i32 0, i32 32
%96 = bitcast ptr %95 to ptr
store i32 %0, ptr %96, align 4
; after (illustrative; options default: stack grows down)
%parameters         = alloca i32, i32 7     ; bytes [0,28)   ("above")
%locals             = alloca i32, i32 3     ; bytes [32,44)  ("below")
%return_address_loc = alloca i32, i32 1     ; bytes [28,32)
%r0 = getelementptr i32, ptr %return_address_loc, i32 0
store i32 ptrtoint (ptr @__anvill_ra to i32), ptr %r0
%l0 = getelementptr i32, ptr %locals, i32 0
store i32 %0, ptr %l0
%4  = alloca %...frame_type                ; now dead
```

#### 13.4.13 `CombineAdjacentShifts`. File `lib/Passes/CombineAdjacentShifts.cpp`

Kind: function pass. Matcher:

```
m_AShr(m_Shl(m_Value(V), m_ConstantInt(shift_right /* = shl amount A */)), m_ConstantInt(shift_left /* = ashr amount B */))
```

The variable names are swapped relative to their meaning. The condition is that V is an integer type,
`B > A`, and `B * 2 == width`.

Rewrite, inserted before the ashr:

```
t = trunc V to iB
s = sext t to iW
r = shl s, (B - A)
```

Metadata: V → t, ashr → s, the shl → r. Then RAUW the ashr with r and erase it. The old shl is left for DCE.
The comment states the intended identity: `(ashr (shl V, A), B)` with `A = W/2 > B` becomes
`shl(sext(trunc V to iA)), A - B`. **Gotcha: because of the swapped captures, the code applies the rewrite when
the ashr amount is the half-width and larger than the shl amount. That is not semantics-preserving.** For example,
`ashr(shl x, 8), 32` on i64 is rewritten to `sext(trunc x to i32) << 24`. A faithful reimplementation should decide
whether to keep this behaviour. The intended version is
`A == W/2 && B < A → shl(sext(trunc V to i(W/2))), A - B`.

Example of the intended behaviour (illustrative):

```llvm
%a = shl i64 %v, 32
%b = ashr i64 %a, 8
; -> %t = trunc i64 %v to i32 ; %s = sext i32 %t to i64 ; %b' = shl i64 %s, 24
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
* The pass returns `none()` whenever the enumeration was non-empty, even if no replacement was made.

Example (illustrative; the test only runs the pass on `TestingUnresolvedEntity.ll` and dumps the result). Suppose
the resolver maps 0x12bd8 to `@data_12bd8`:

```llvm
; before
%41 = add i32 %40, add (i32 ptrtoint (ptr @__anvill_pc to i32), i32 76696)
%p  = inttoptr i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 77784) to ptr
%v  = load i32, ptr %p
; after
%p'  ; the inttoptr operand use becomes ptrtoint @data_12fd8 ... the load's pointer use becomes @data_12fd8 directly
%v  = load i32, ptr @data_12fd8
; and @data_12fd8 gets !pc !{i64 77784}  (if pc_metadata_id)
```

The `%41` operand is a PC-tainted constant 0x12b98. It is replaced only if some entity exists at that address.
The test "Regression test for unresolved anvill_pc" checks that the pass does not crash when no entity exists.

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

Example, from `data/TransformRemillJumpDataARM32_0.ll`:

```llvm
; before
%109 = call ptr @__remill_jump(ptr %21, i32 or (i32 or (i32 or (i32 shl (i32 zext (i8 trunc (i32 lshr
        (i32 ptrtoint (ptr @__anvill_ra to i32), i32 24) to i8) to i32), i32 24), ...),
        i32 zext (i8 ptrtoint (ptr @__anvill_ra to i8) to i32)), ptr null)
; after
%109 = call ptr @__remill_function_return(ptr undef, i32 or (... same CE ...), ptr null)
```

The test asserts that `__remill_function_return` exists and has uses, and that `__remill_jump` is absent or has no uses.

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

Examples (illustrative):

```llvm
; match case
%ra = call ptr @llvm.returnaddress(i32 0)
%pc = ptrtoint ptr %ra to i64
%m  = call ptr @__remill_function_return(ptr undef, i64 %pc, ptr %mem)
ret ptr %m
; after
ret ptr %mem            ; %pc and %ra erased

; fixup case (x86-64): the return address was loaded from an arbitrary location
%t = load i64, ptr %slot
%m = call ptr @__remill_function_return(ptr undef, i64 %t, ptr %mem)
; after
%aora = call ptr @llvm.addressofreturnaddress.p0()       ; entry block
...
store i64 %t, ptr %aora
; uses of %m -> %mem
```

Case 3 of `RecoverStackFrameInformation.ll` is `%11 = load i32, ptr inttoptr(sp+...)` passed to `__remill_function_return`.
Before stack recovery it is classified as `kFoundSymbolicStackPointerLoad` and left alone.

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
     * pointer type: create a bitcast after `ra`. **Gotcha: the code never calls `use->set` here**, so the use
       keeps the CE;
     * integer type: ptrtoint as above.
   * Any other CE: `ce_inst = ce->getAsInstruction()`, inserted before `ce_insert_loc`, then
     `ce_insert_loc = ce_inst` (nested CEs stack upward). Copy metadata from `inst` and `use->set(ce_inst)`.
     Scan `ce_inst`'s operands for further RA-referencing CEs and append them to the list.
5. Return `none()`.

Example (illustrative):

```llvm
; before
store i64 add (i64 ptrtoint (ptr @__anvill_ra to i64), i64 0), ptr %slot
; after
entry:
  %return_address = call ptr @llvm.returnaddress(i32 0)
  %1 = ptrtoint ptr %return_address to i64
  %2 = add i64 %1, 0
  ...
  store i64 %2, ptr %slot
```

#### 13.4.20 `LowerRemillUndefinedIntrinsics`. File `lib/Passes/LowerRemillUndefinedIntrinsics.cpp`

Kind: function pass. Every CallInst whose direct callee name starts with `__remill_undefined_` is RAUW'd with
`UndefValue::get(call type)` and erased. `CopyMetadataTo` onto the undef is a no-op. This should run late, to
keep undefinedness from spreading.

```llvm
%u = call i8 @__remill_undefined_8()   ->   uses of %u become i8 undef
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

Example (illustrative, `pc_metadata_name = "pc"`):

```llvm
; before
%a = add i64 %x, 1
%b = load i64, ptr %p, !pc !1
%c = icmp eq i64 %b, %a
br i1 %c, label %t, label %f, !pc !2
; after
%a = add i64 %x, 1                ; still unannotated by the forward pass (not used by an annotated insn) ...
%b = load i64, ptr %p, !pc !1
%c = icmp eq i64 %b, %a, !pc !2   ; forward pass: operand of the annotated br
br ..., !pc !2
; backward pass then gives %a !pc !1 (from %b below it)
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

**Gotcha (real bug):** `brs_to_invert.clear()` and `selects_to_invert.clear()` are executed **inside the loop over
`%c`'s users, once per user**. After the loop, only the *last* visited non-xor user is retained. LLVM use-list
iteration is roughly most-recent-first, so this is the first user in program order. Any other branch or select users
receive the negated condition **without** being swapped, which inverts their semantics.

In addition, the two vectors live outside the per-xor loop. If `%c`'s only user is the xor, the loop body never
runs and the vectors keep the *previous* xor's branches and selects, which then get swapped again.

The `xor_conversion.ll` test (`%6` used by xor, select and br) only counts xors, so it does not detect this.
A faithful-but-correct reimplementation should clear the vectors once per xor, before the loop.

Examples, from the test data:

```llvm
; xor_removal.ll  (non-cmp case)
%10 = trunc i8 %9 to i1
%11 = xor i1 %10, true
br i1 %11, label %a17, label %a19
; after
br i1 %10, label %a19, label %a17        ; %11 erased

; xor_conversion.ll (cmp case)
%6 = icmp eq i8 %5, 0
%7 = xor i1 %6, true
%8 = zext i1 %7 to i8
%10 = select i1 %6, ptr @.str.1, ptr @.str
br i1 %6, label %18, label %12
; after (intended)
%n = icmp ne i8 %5, 0
%8 = zext i1 %n to i8
%10 = select i1 %n, ptr @.str, ptr @.str.1
br i1 %n, label %12, label %18
```

Non-changes:

* `xor_conversion_nochange.ll`: `%6` also has `zext` users, so it is not invertible.
* `xor_removal_noremove.ll`, case `xor i1 %10, false`: wrong constant.
* `xor_removal_noremove.ll`, case where the xor is unused by any branch: nothing to flip, and the xor is not
  erased because `changed_this_xor` stays false.

#### 13.4.25 Passes not scheduled by `OptimizeModule`

* **HoistUsersOfSelectsAndPhis**. The call is commented out in Optimize.cpp: "has an issue on `SMIME_write_ASN1`
  of the ARM64 Challenge 5". See §13.5.
* **SimplifyStackArithFlags**. Not built. See §13.2.6.
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
  * **Gotcha:** the selected value is always placed as the LHS, so a non-commutative `sub C, %sel` becomes
    `select(c, t - C, f - C)`, which is wrong.
* **Casts** (`Trunc, ZExt, SExt, FPToUI, FPToSI, UIToFP, SIToFP, FPTrunc, FPExt, PtrToInt, IntToPtr, BitCast`)
  use `FoldSelectWithCastInst`:
  * For a vector condition, require an `i1` element and an element count equal to the destination vector's.
  * Build `cast(t)`, `cast(f)` and the select.
* **GetElementPtr** uses `FoldSelectWithGEPInst`:
  * `CollectAndValidateGEPIndexes(index_list, S, gep)` (shared with PHIs): indices before the select or PHI index
    must not be instructions in the GEP's block; indices after it must be constants.
  * The select must be one of the **indices**. If it is the base pointer, `new_true_value` stays null and the fold
    fails.
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
  `op(iv, C)` in `InsertionBlock(iv)`, then `BuildPHI(P, P type)`. It has the same operand-order gotcha as the
  select version.
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

Examples (from `InstructionFolderPass.ll` and the header comment):

```llvm
; CombineAddWithSelect
%1 = select i1 %0, i64 11, i64 22
%2 = add i64 add (i64 ptrtoint (ptr @__anvill_pc to i64), i64 100), %1
; after
%a = add i64 11, add (...pc..., 100)      ; (operand order: selected value first)
%b = add i64 22, add (...pc..., 100)
%2 = select i1 %0, i64 %a, i64 %b

; CombineAddWithPHI
first:  %3 = add i32 %1, 1            br label %exit
second: %4 = add i32 %1, 2            br label %exit
exit:   %5 = phi i32 [ %3, %first ], [ %4, %second ]
        %6 = add i32 add (i32 ptrtoint (ptr @__anvill_pc to i32), i32 100), %5
; after
first:  %3 = add i32 %1, 1 ; %x = add i32 %3, <pc+100>  ; br
second: %4 = add i32 %1, 2 ; %y = add i32 %4, <pc+100>  ; br
exit:   %6 = phi i32 [ %x, %first ], [ %y, %second ]
```

`CombineGEPWithSelect` in the data has the select as the GEP *base*, so it is not folded.

The only test is `InstructionFolderPass.cpp`: run the pass, then verify the module.


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


### 13.8 Quick gotcha list (to replicate or fix deliberately)


1. The pipeline runs the first FPM twice, because `mpm` is reused (§13.6).
2. `ConvertXorsToCmps` clears its invert lists per use. This can mis-invert branches or selects (§13.4.24).
3. `CombineAdjacentShifts` swaps its capture variables, giving the wrong condition and rewrite (§13.4.13).
4. `ConvertMasksToCasts`: the shl/ashr case does not require amount == width/2, and the shl_add rewrite does not set `changed` (§13.4.8).
5. `HoistUsersOfSelectsAndPhis`: the binop folder ignores operand order (non-commutative ops break), and select-GEP folding only works when the select is an index (§13.5).
6. `SplitStackFrameAtReturnAddress`:
   * the `seen` set is never populated;
   * the variable-index GEP path uses `ret`, not `sub_ret`, and may violate dominance;
   * the subframe names look inverted (§13.4.12).
7. `ConvertSymbolicReturnAddressToConcreteReturnAddress`: the bitcast-to-other-pointer case never sets the use (§13.4.19).
8. `RemoveStackPointerCExprs`: `Displacement()` returns 0 for i1, so SP comparisons fold to `false` (§13.4.10).
9. `RemoveUnusedBranchHints` also removes `__remill_compare_exchange*` calls (§13.2.5).
10. `SliceManager` performs RAUW on uniqued `ptrtoint` CEs, which mutates the original module (§13.3.2).
11. `LowerSwitchIntrinsics`: no wrap guard on the bound loop; PHIs of removed successors are not updated (§13.3.4).
12. `SimplifyStackArithFlags` is not compiled; `AddSimplifyStackArithFlags` is declared but undefined (§13.2.6).
13. `ConvertAddressesToEntityUses` returns `none()` even when nothing was replaced (§13.4.14).

---

## 14. The `anvill-decompile-spec` driver

Source: `bin/Decompile/Main.cpp`. Flags use gflags.

| Flag | Meaning |
|---|---|
| `--spec <path>` | **Binary protobuf** `specification.Specification`. `/dev/stdin` or `-` reads stdin. The help text still says "JSON", which is stale. |
| `--ir_out <path>` | write textual LLVM IR |
| `--bc_out <path>` | write bitcode |
| `--stats_out <path>` | `llvm::EnableStatistics()` before optimizing, then `PrintStatisticsJSON`. This is where `CodeQualityStatCollector`'s `STATISTIC` counters show up. |
| `--add_breakpoints` | declared but **not wired** to `options.add_breakpoints` **[QUIRK]** |
| `--add_names` | after lifting, rename each function and variable to its spec symbol. On Apple triples a leading `_` is stripped. **[QUIRK]** For a function that failed to lift, `func` is null and `setName` crashes. |
| `--default_callable_spec <path>` | a binary protobuf **`specification.Function`** whose `callable` is used as the prototype for any call target without type info (`DefaultCallableTypeProvider`). **[QUIRK]** If it fails to parse, the error is printed but `maybe_default_callable.Value()` is still called and throws. |
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
6. `OptimizeModule(lifter, module)`.
7. Write the outputs. The exit code is non-zero only on I/O errors. Individual function lift failures are only logged.

To reproduce the tool from scratch, a minimal command is:

```sh
anvill-decompile-spec --spec prog.pb --ir_out prog.ll --add_names --stats_out stats.json
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

- **Remill** is a submodule at `dependencies/remill` (latest `master`) and is built as part of anvill with `add_subdirectory`, with remill testing turned off. The old root `remill` submodule, `cmake/modules/Find*.cmake`, `CMakePresets.json` and the cxx-common scripts are gone.
- **`dependencies/`** is a CMake superbuild (from the template) that installs a prefix in `dependencies/install`. It contains:
  - remill's dependencies: gflags, glog, googletest and XED;
  - sleigh, with remill's patches;
  - anvill's extras: doctest 2.4.11, protobuf 21.12 (the last release without abseil) and Z3 4.13.4;
  - LLVM, which by default is the LLVMParty 21.1.6 prebuilt (or `USE_EXTERNAL_LLVM=ON` / `DOWNLOAD_PREBUILT_LLVM=OFF`).

  `BUILD_REMILL_DEPENDENCIES=OFF` skips remill's dependencies when they already exist.
- **`cmake/SetupDependenciesPrefix.cmake`** picks up `dependencies/install` automatically. If `CMAKE_PREFIX_PATH` is already set, as in the Docker image, it layers `dependencies/install` on top of it.
- **Docker / CI.** `ghcr.io/llvmparty/remill-template/dependencies:22.04-llvm19.1.7-remill2026.03.20` already provides LLVM 19.1.7 and remill's dependencies in `/dependencies`, so only the extras are built on top of it. The CI workflow, the root `Dockerfile` and `dependencies/Dockerfile` all use that image.
- **Defaults.** `ANVILL_ENABLE_INSTALL` and `ANVILL_ENABLE_PYTHON3_LIBS` now default to OFF.
- **Source changes.** These were mechanical LLVM 16–19 API updates:
  - `starts_with`, `std::optional` and the `TypeSize` getters;
  - `ConstantFoldIntegerCast` in place of the removed `zext` constant expression;
  - the new-pass-manager cleanup in `FunctionLifter`;
  - `icmp` constant-expression handling compiled out on LLVM ≥ 19;
  - three test `.ll` fixtures rewritten without removed constant expressions.

  The remill API that anvill uses was unchanged between the old pin (Dec 2022) and current `master`.

---

## 17. Consolidated list of quirks and bugs

These are grouped by component, with the section that explains each one. A clean-room reimplementation should decide case by case whether to copy or fix each one. Copying is needed to reproduce Anvill's exact output. Fixing produces more correct output.

**Specification and protobuf (§5, §6)**
1. `ProtobufTranslator::DecodeType` builds a `FunctionType` and never returns it, so it falls through to "Unknown/invalid data type".
2. A global-variable decode failure is logged but processing continues, and then `.Value()` throws on the failed `Result`.
3. The duplicate global-variable check looks in the *function* map.
4. `Specification::operator!=` is implemented as `==`.
5. `VariableContaining` only matches exact start addresses.
6. `overrides` is mandatory. A spec with no control flow must still contain an empty `overrides {}`.
7. `CALLING_CONVENTION_CDECL = 1` is not a defined LLVM calling-convention ID (C is 0, fastcc is 8). The value is cast straight to `CallingConv::ID`.
8. `Callable.return` has a single type applied to every return location. `return.type` is decoded unconditionally, so a void prototype must still send `return { type { base: BT_VOID } }`. Omitting `return` makes the loader skip the function (§5.4).
9. `Call.return_address`, `Call.is_tailcall`, `Call.stop`, `Return.stop` and `Jump.stop` are parsed but ignored by the lifter. `StructType.identifier` is ignored too.
10. `docs/SpecificationFormat.md` describes the removed JSON format. The `--spec` help text also says JSON.

**ABI / calling conventions (§8)**
11. SysV RVO: the hidden struct-return pointer is placed in **RAX** and typed as the struct, and RDI is blocked. A `{long,double}` return triggers RVO on plain AMD64 because the XMM return registers are `kTypeVec` only. The AVX variants return it correctly.
12. fastcall and thiscall never use ECX/EDX. stdcall, fastcall and thiscall on AMD64 map to the 32-bit cdecl object.
13. There is no Win64 convention. AMD64 Windows is an error.
14. No register-allocation rollback, no alignment or even-pair rules, and stack slots are not rounded.
15. Split integer returns are typed i32 on AArch64 and SPARC64. On AArch32, `double` returns are `R0:double, R1:double`, and an RVO return has no hidden parameter.
16. Float vectors crash the allocator. A failed vector allocation "succeeds" with zero locations.

**Types (§7)**
17. The encoder always uses unsigned letters. `d`/`D` (x86_fp80) are swapped relative to the docs (12 and 16 bytes versus the documented 10 and 12). `w`/`W` are 3 bytes in code but 4 in the docs.
18. In the wrapped-types branch (dead code), the 24-bit ints are assigned into the int32 slots.

**Lifter (§10, §11)**
19. Missing `Jump` or `Call` overrides for direct jumps and calls are `LOG(FATAL)`.
20. `MaxInstructionSize` is cached in a function-local `static`.
21. There is dead redirection-recovery code in `VisitInstructions`.
22. `ValueLifter::ConsumeBytesAsInt` sign-extends bytes ≥ 0x80, which corrupts integers.
23. `ValueLifter::Lift(ea, type, as)` passes the address space as `loc_ea`.
24. `DataLifter::GetOrDeclareData` ignores constant-expression entities, because `found_by_address` is assigned a null.
25. `DefaultCallableTypeProvider::TryGetCalledFunctionType` looks up the *containing* function's type, not the callee's.
26. `SpecificationControlFlowProvider` inserts into the shared map on a lookup miss.

**Cross-reference folder (§12)**
27. `ICmp ule` is implemented as `<`. clz/ctz/ctpop use 64-bit semantics, and clz/ctz of 0 is UB.
28. `ResolveConstantExpr`'s entity fast path leaves flags uninitialised. `Displacement()` returns 0 for sizes other than 8, 16, 32 and 64 (e.g. i1).

**Passes and pipeline (§13)**
29. The module pass manager is reused, so the first function pipeline (and GlobalOpt/GlobalDCE) runs **twice**.
30. `ConvertXorsToCmps` clears its invert lists per use and can mis-invert.
31. `CombineAdjacentShifts` swaps its captured shift amounts.
32. `ConvertMasksToCasts` doesn't check that the shift amount is half the width.
33. `HoistUsersOfSelectsAndPhis` ignores operand order. It is unscheduled.
34. `SplitStackFrameAtReturnAddress` mishandles variable-index GEPs and its sub-frame names look inverted.
35. `ConvertSymbolicReturnAddressToConcreteReturnAddress` misses one replacement.
36. `RemoveStackPointerCExprs` folds every one-bit stack-pointer comparison to `false`.
37. `RemoveUnusedBranchHints` also deletes `__remill_compare_exchange*` calls.
38. `SliceManager` performs RAUW on uniqued constants, which mutates the original module.
39. `LowerSwitchIntrinsics` has no wrap guard on its loop and doesn't update PHIs.
40. `SimplifyStackArithFlags` is not compiled. `AddSimplifyStackArithFlags` is declared but never defined.

**Driver (§14)**
41. `--add_breakpoints` is not wired up. `--add_names` crashes on functions that failed to lift. A bad `--default_callable_spec` throws.

**Python (§15)** — see §15.14 for 17 items, including union serialisation, the IDA `char` crash and the missing `itertools` import.

---

## 18. Reimplementation roadmap

A practical order for building an equivalent tool, with the "must match" contracts for each step.

1. **Spec model and parser.**
   - Generate C++ from `specification.proto` and implement §5–§6.
   - Decide up front whether to keep the quirks: mandatory overrides, a single return type, and the ignored fields.
   - Write a protobuf **text-format → binary** helper so you can author tests by hand (e.g. `protoc --encode=specification.Specification specification.proto < x.textproto > x.pb`).
2. **TypeSpec ⇄ LLVM types and the symbol-name encoder** (§7).
   - Structs are packed literals, pointers are opaque `ptr`, and `Unknown(n)` becomes `i(8n)`.
   - The encoder is needed for `sub_<addr>_<enc>_<cc>` and `var_<addr>_<enc>` names, which later passes rely on. For example, `.frame_type` lookup uses the function name prefix.
3. **Calling-convention allocator** (§8): `AllocationState` first-fit over ordered register tables, plus per-convention tables, stack starting offsets, the return stack pointer and the return-address location. Needed for `callable.type` prototypes (broken in this revision, see §6) and for `FunctionDecl::Create` from LLVM functions. Explicit-location specs bypass it.
4. **`LoadLiftedValue` / `StoreNativeValue` / `AdaptToType`** (Appendix B), then **`CallFromLiftedBlock`** (§8.5).
5. **Function lifter** (§10).
   - Implement the edge work list, the flow table in §10.4, typed calls through the symbolic PC, and the `__anvill_complete_switch` index switch.
   - Then the native wrapper with `State` alloca and register globals, recursive inlining with `!pc` propagation, the light cleanup, and the copy into the target module.
   - Use the §10.10 example as the first end-to-end test.
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
    - Port `tests/anvill_passes` (the `.ll` fixtures and their expected counts) and `tests/tools`.
    - Re-create the round-trip harness (§15.11): compile C, generate a spec, lift, recompile the `.bc`, and compare stdout and exit code. A spec producer is needed for this; the protobuf one is not open source.

Things you can leave out at first:

- the Python generator (stale; §15);
- `HoistUsersOfSelectsAndPhis` and `SimplifyStackArithFlags` (unused);
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
