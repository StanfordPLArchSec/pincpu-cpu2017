#!/usr/bin/env python3

# TODO: Need to use edlib to align.

import argparse
import sys
import edlib
from traceval_util import parse_lochist, instloctrace
import disasm

parser = argparse.ArgumentParser()
parser.add_argument("--bbtraces", nargs="+")
parser.add_argument("--bbhists", nargs="+")
parser.add_argument("--locmaps", nargs="+")
parser.add_argument("--lochist", required=True)
parser.add_argument("--exes", nargs="+")

args = parser.parse_args()

disasms = [disasm.Disassembler(exe) for exe in args.exes]

# Parse lochist.
with open(args.lochist) as f:
    lochist = parse_lochist(f)

# Convert into blocks. Each of the N streams should have
# the same number of blocks.
def chunked_stream(lochist, bbtrace, bbhist, locmap):
    insts = []
    count = 0
    for inst, loc in instloctrace(lochist, bbtrace, bbhist, locmap):
        if loc:
            yield insts
            insts = []
            yield [(inst, count, loc)]
        else:
            insts.append((inst, count, None))
        count += 1
    yield insts

gens = [
    chunked_stream(lochist, bbtrace, bbhist, locmap) \
    for bbtrace, bbhist, locmap in \
    zip(args.bbtraces, args.bbhists, args.locmaps, strict=True)
]

def get_opcodes_for_block(block, disasm):
    return [disasm.opcode(inst) for inst, count in block]

for blockcountlocs in zip(*gens, strict=True):
    blocks, counts, locs = zip(*blockcountlocs)
    opcodes = list(map(get_opcodes_for_block, blocks, disasms))
    assert any(locs) == all(locs)

    ref_block = blocks[0]
    for exp_block in blocks[1:]:
        # print(f"aligning {ref_block} and {exp_block}", file=sys.stderr)
        pass
        # edlib.align(ref_block, exp_block)

exit(1)

def loctrace_with_instcount(lochist, bbtrace, bbhist, locmap):
    inst_count = 0
    for inst, loc in instloctrace(lochist, bbtrace, bbhist, locmap):
        if loc:
            yield inst_count, loc
        inst_count += 1
    yield inst_count, "<exit>"
    
gens = [
    loctrace_with_instcount(lochist, bbtrace, bbhist, locmap) \
    for bbtrace, bbhist, locmap in \
    zip(args.bbtraces, args.bbhists, args.locmaps, strict=True)
]

for l in zip(*gens, strict=True):
    print(*[n for n, _ in l])
