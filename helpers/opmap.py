#!/usr/bin/env python3

import argparse
from disasm import Disassembler

parser = argparse.ArgumentParser()
parser.add_argument("--bbhist", required=True)
parser.add_argument("--exe", required=True)
args = parser.parse_args()

# Get list of distinct instructions.
insts = set()
with open(args.bbhist) as f:
    for line in f:
        count, block = line.split()
        for inst in block.split(","):
            inst = int(inst, 16)
            insts.add(inst)

# Get opcodes for instructions.
disasm = Disassembler(args.exe)
for inst in insts:
    print(f"{inst:x} {disasm.opcode(inst)}")
