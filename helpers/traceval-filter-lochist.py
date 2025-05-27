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
        block = int.from_bytes(f.read(4), byteorder="little")
        insts = block_to_insts[block]
        for inst in insts:
            if inst in locmap:
                loc = locmap[inst]
                yield loc

# Iterate over location traces, eliminating any locations from
# the location histogram that aren't in the right position.
loc_gens = map(loctrace, args.bbtraces, args.bbhists, args.locmaps)
for locs in zip(*loc_gens):
    pass

exit(1)
