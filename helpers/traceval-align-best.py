#!/usr/bin/env python3

# TODO: Need to use edlib to align.

import argparse
import sys
import edlib
from traceval_util import parse_lochist, instloctrace
import disasm
import re
import util

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
    

# The generated sequence contains None.
def match_generator_unfiltered(ref, exp, cigar):
    if cigar is None:
        for ref_i in ref:
            yield ref_i, None
        return

    # NOTE: For now, we only want to include positions that are matches for everyone...
    ref_it = iter(ref)
    exp_it = iter(exp)
    for op in cigar_expander(cigar):
        if op == "=":
            yield next(ref_it), next(exp_it)
        elif op == "I":
            yield next(ref_it), None
        elif op == "D":
            yield None, next(exp_it)
        elif op == "X":
            yield next(ref_it), next(exp_it)
    try:
        next(ref_it)
    except StopIteration:
        return
    assert False, "ref_it wasn't empty!"

def match_generator(ref, exp, cigar):
    return filter(lambda t: t[0], match_generator_unfiltered(ref, exp, cigar))

for blocks in zip(*gens, strict=True):
    ref_block = blocks[0]

    # Is this an anchor, i.e., are the blocks of each size 1 and
    # have locs?
    if all(len(block) == 1 and block[0][2] for block in blocks):
        tokens = []
        for block, in blocks:
            addr, count, _ = block
            tokens.extend([addr, count])
        print(*tokens)
        continue

    # If the reference block is empty, then skip.
    if len(ref_block) == 0:
        continue

    # Otherwise, perform optimal subalignment using edlib.
    opcodes = list(map(get_opcodes_for_block, blocks, disasms))
    ref_opcode_l = opcodes[0]
    match_gens = []
    for exp_opcode_l, exp_block in zip(opcodes[1:], blocks[1:]):
        subalign = edlib.align(ref_opcode_l, exp_opcode_l, task="path")
        cigar = subalign["cigar"]
        match_gens.append(match_generator(ref_block, exp_block, cigar))

    for matches in zip(*match_gens, strict=True):
        # Only consider ones where we match (or mismatch) all of them.
        assert util.all_equal(map(lambda x: x[0], matches))
        matches = [matches[0][0]] + [x[1] for x in matches]
        if not all(matches):
            continue
        tokens = []
        for addr, count, _ in matches:
            tokens.extend([addr, count])
        print(*tokens)
