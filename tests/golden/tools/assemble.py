#!/usr/bin/env python3
"""Assemble a snippet at a fixed address and print it for a .textproto case.

    assemble.py [--triple x86_64-linux-gnu] [--address 0x401000] file.s

Prints the disassembly as `#` comments and the escaped bytes for a
`memory_ranges { values: "..." }` entry. Data such as jump tables can be
emitted inline (e.g. with `.long`). Needs clang, ld.lld, llvm-objcopy and
llvm-objdump, which are all in the remill-template Docker image.

With `--no-link` (needed for SPARC, which ld.lld cannot link) the `.text`
section is taken from the object file as is: branches within the file are
resolved by the assembler, but references to other symbols are not, and the
disassembly shows addresses relative to `--address`."""
import argparse
import pathlib
import subprocess
import sys
import tempfile


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--triple", default="x86_64-linux-gnu")
    p.add_argument("--address", type=lambda v: int(v, 0), default=0x401000)
    p.add_argument("--no-link", action="store_true")
    p.add_argument("source")
    args = p.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        obj, exe, raw = tmp / "a.o", tmp / "a.elf", tmp / "a.bin"
        subprocess.run(["clang", "-c", "-x", "assembler",
                        f"--target={args.triple}", "-o", str(obj),
                        args.source], check=True)
        if args.no_link:
            exe = obj
            dis_args = [f"--adjust-vma={args.address:#x}"]
        else:
            # Link at the requested address so PC-relative operands are final.
            subprocess.run(["ld.lld", "-o", str(exe), "--image-base=0",
                            f"--section-start=.text={args.address:#x}",
                            "-e", f"{args.address:#x}", str(obj)], check=True)
            dis_args = []
        subprocess.run(["llvm-objcopy", "-O", "binary",
                        "--only-section=.text", str(exe), str(raw)],
                       check=True)
        dis = subprocess.run(["llvm-objdump", "-d", "--print-imm-hex"] +
                             dis_args + [str(exe)], check=True,
                             stdout=subprocess.PIPE, text=True).stdout
        data = raw.read_bytes()
    for line in dis.splitlines():
        line = line.rstrip()
        if line.startswith(" ") and ":" in line:
            print("#   " + " ".join(line.split()))
    print('values: "' + "".join(f"\\x{b:02x}" for b in data) + '"')


if __name__ == "__main__":
    sys.exit(main())
