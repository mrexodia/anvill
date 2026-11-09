#!/usr/bin/env python3
"""Golden IR tests for anvill.

Every test case is an input file plus checked-in expected outputs. The
expected outputs are the *actual* output of the current implementation, so
together they form an executable specification of anvill's behavior.

Pass cases (`passes/**/<name>.ll`)
    The first lines may contain `; RUN: <anvill-opt flags>` (`%S` expands to
    the directory of the test case), e.g.
    `; RUN: --passes=RecoverBasicStackFrame --stack_init=zeroes`. The
    transformed module is compared with `<name>.expected.ll`.

Lifter cases (`lifter/**/<name>.textproto`)
    A text-format `specification.Specification`. Optional `# RUN: <flags>`
    lines add `anvill-decompile-spec` flags. The IR after lifting (before
    optimization) is compared with `<name>.lifted.ll` and the final IR with
    `<name>.optimized.ll`. A `# EXPECT-ERROR: <text>` line instead requires
    the tool to fail with `<text>` in its output.

Usage:
    run_golden.py --anvill-opt BIN --anvill-decompile-spec BIN [--update]
                  [--filter TEXT] DIR
"""

import argparse
import difflib
import pathlib
import re
import shlex
import subprocess
import sys
import tempfile


def header_values(path, prefix):
    values = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith(prefix):
                values.append(line[len(prefix):].strip())
    return values


def normalize(text):
    lines = text.splitlines(keepends=True)
    # The module ID of anvill-opt outputs is the (machine specific) input path.
    if lines and lines[0].startswith("; ModuleID = "):
        lines = lines[1:]
    # So is the source file name; keep only the base name.
    lines = [re.sub(r'^source_filename = ".*/([^/"]*)"', r'source_filename = "\1"',
                    line) for line in lines]
    return "".join(lines)


def compare(expected_path, actual, update):
    actual = normalize(actual)
    if update:
        expected_path.write_text(actual)
        return True
    if not expected_path.exists():
        print(f"  missing expected output {expected_path.name} (run with --update)")
        return False
    expected = expected_path.read_text()
    if expected == actual:
        return True
    diff = difflib.unified_diff(expected.splitlines(keepends=True),
                                actual.splitlines(keepends=True),
                                fromfile=str(expected_path),
                                tofile="actual")
    sys.stdout.writelines(list(diff)[:200])
    return False


def run(cmd):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True)


def run_flags(path, prefix):
    flags = []
    for value in header_values(path, prefix):
        flags.extend(shlex.split(value.replace("%S", str(path.parent))))
    return flags


def run_pass_case(args, path, tmp):
    flags = run_flags(path, "; RUN:")
    out = tmp / "out.ll"
    proc = run([args.anvill_opt, *flags, str(path), "-o", str(out)])
    if proc.returncode != 0:
        print(proc.stderr[-4000:])
        return False
    return compare(path.with_suffix(".expected.ll"), out.read_text(),
                   args.update)


def run_lifter_case(args, path, tmp):
    flags = run_flags(path, "# RUN:")
    errors = header_values(path, "# EXPECT-ERROR:")
    pre, post = tmp / "pre.ll", tmp / "post.ll"
    proc = run([args.anvill_decompile_spec, "--spec", str(path),
                "--ir_pre_opt", str(pre), "--ir_out", str(post), *flags])
    if errors:
        output = proc.stdout + proc.stderr
        ok = proc.returncode != 0 and all(e in output for e in errors)
        if not ok:
            print(f"  expected failure containing {errors!r}, got exit code "
                  f"{proc.returncode}:\n{output[-4000:]}")
        return ok
    if proc.returncode != 0:
        print(proc.stderr[-4000:])
        return False
    base = path.with_suffix("")
    ok = compare(pathlib.Path(f"{base}.lifted.ll"), pre.read_text(),
                 args.update)
    return compare(pathlib.Path(f"{base}.optimized.ll"), post.read_text(),
                   args.update) and ok


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--anvill-opt", required=True)
    parser.add_argument("--anvill-decompile-spec", required=True)
    parser.add_argument("--update", action="store_true",
                        help="overwrite the expected outputs")
    parser.add_argument("--filter", default="",
                        help="only run cases whose path contains this text")
    parser.add_argument("dir", type=pathlib.Path)
    args = parser.parse_args()

    cases = []
    for path in sorted((args.dir / "passes").rglob("*.ll")):
        if not path.name.endswith(".expected.ll"):
            cases.append((run_pass_case, path))
    for path in sorted((args.dir / "lifter").rglob("*.textproto")):
        cases.append((run_lifter_case, path))

    failed = []
    for func, path in cases:
        rel = path.relative_to(args.dir)
        if args.filter not in str(rel):
            continue
        with tempfile.TemporaryDirectory() as tmp:
            ok = func(args, path, pathlib.Path(tmp))
        print(f"{'PASS' if ok else 'FAIL'}: {rel}")
        if not ok:
            failed.append(rel)

    if failed:
        print(f"\n{len(failed)} golden test(s) failed")
        return 1
    print("\nall golden tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
