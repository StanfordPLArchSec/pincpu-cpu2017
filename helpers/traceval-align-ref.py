#!/usr/bin/env python3

# TODO: Need to use edlib to align.

import argparse
import sys
import edlib
from traceval_util import parse_lochist, instloctrace
import disasm
import re

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
    return [disasm.opcode(int(inst, 16)) for inst, _, _ in block]

def encode_opcode_lists(ls):
    domain = set()
    for l in ls:
        domain.update(l)
    lut = {}
    idxtostr = "abcdefghijklmnopqrstuvwxyz012345679"
    for key in domain:
        lut[key] = idxtostr[len(lut)]
    results = []
    for l in ls:
        result = ""
        for x in l:
            result += lut[x]
        results.append(result)
    return results

def cigar_expander(cigar):
    # Make sure we're handling all the informatin in the cigar string.
    assert all(c in "0123456789=DIX" for c in cigar)
    for count, opcode in re.findall(r"(\d+)([=DIX])", cigar):
        count = int(count)
        assert count >= 1
        assert len(opcode) == 1
        for i in range(count):
            yield opcode
    

def match_generator(ref, exp, cigar):
    # NOTE: For now, we only want to include positions that are matches for everyone...
    ref_it = iter(ref)
    exp_it = iter(exp)
    if cigar is None:
        return
    for op in cigar_expander(cigar):
        if op == "=":
            yield next(ref_it), next(exp_it)
        elif op == "I":
            yield next(ref_it), None
        elif op == "D":
            yield None, next(exp_it)
        elif op == "X":
            yield None, None
        

for blocks in zip(*gens, strict=True):
    # Is this an anchor, i.e., are the blocks of each size 1 and
    # have locs?
    if all(len(block) == 1 and block[0][2] for block in blocks):
        print(*[block[0][0] for block in blocks])
        continue

    # Otherwise, perform optimal subalignment using edlib.
    opcodes = list(map(get_opcodes_for_block, blocks, disasms))
    ref_opcode_l = opcodes[0]
    ref_block = blocks[0]
    for exp_opcode_l, exp_block in zip(opcodes[1:], blocks[1:]):
        subalign = edlib.align(ref_opcode_l, exp_opcode_l, task="path")

        # Extract the matches.
        for ref_inst, exp_inst in match_generator(ref_block, exp_block, subalign["cigar"]):
            print(ref_inst, exp_inst)

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
