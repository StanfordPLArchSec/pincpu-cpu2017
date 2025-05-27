#!/usr/bin/env python3

import argparse
import sys
import gzip
import xxhash

parser = argparse.ArgumentParser()
parser.add_argument("--bbtraces", nargs="+")
parser.add_argument("--bbhists", nargs="+")
parser.add_argument("--locmaps", nargs="+")
args = parser.parse_args()

def all_equal(l):
    return all(x == y for x, y in zip(l[:-1], l[1:], strict=True))

def subset(a, b):
    return all(x in b for x in a)

assert all_equal([len(args.bbtraces), len(args.bbhists), len(args.locmaps)])

# Parse the lochist from stdin.
lochist = dict()
for line in sys.stdin:
    count, loc = line.split()
    lochist[loc] = count

# Generator for location traces.
def loctrace(bbtrace_path, bbhist_path, locmap_path):
    # Parse the bbhist file first, indexing by block hash.
    block_to_insts = dict()
    with open(bbhist_path) as f:
        for line in f:
            count, block = line.split()
            block_hash = xxhash.xxh32(block).intdigest()
            assert block_hash not in block_to_insts
            block_to_insts[block_hash] = block.split(",")

    # Build the locmap.
    locmap = dict()
    with open(locmap_path) as f:
        for line in f:
            inst, loc = line.split()
            locmap[inst] = loc


    with gzip.open(bbtrace_path, "rb") as f:
        while True:
            block_hash = f.read(4)
            if not block_hash:
                break
            assert len(block_hash) == 4
            block = int.from_bytes(block_hash, byteorder="little")
            insts = block_to_insts[block]
            for inst in insts:
                if inst in locmap:
                    loc = locmap[inst]

                    # Only return locations that are in the lochist.
                    if loc in lochist:
                        yield loc


# Iterate over location traces, eliminating any locations from
# the location histogram that aren't in the right position.
loc_gens = map(loctrace, args.bbtraces, args.bbhists, args.locmaps)

# print([len(list(x)) for x in loc_gens], file=sys.stderr)

for locs in zip(*loc_gens, strict=True):
    assert subset(locs, lochist)
    if not all_equal(locs):
        for loc in set(locs):
            del lochist[loc]

for loc, count in lochist.items():
    print(count, loc)
