#!/usr/bin/env python3

import argparse
import collections

parser = argparse.ArgumentParser()
parser.add_argument("--locmap", required=True)
parser.add_argument("--bbhist", required=True)
args = parser.parse_args()

# Build locmap.
locmap = dict()
with open(args.locmap) as f:
    for line in f:
        inst, loc = line.split()
        locmap[inst] = loc

# Build lochist.
lochist = collections.defaultdict(int)
with open(args.bbhist) as f:
    for line in f:
        count, block = line.split()
        insts = block.split(",")
        for inst in insts:
            if inst in locmap:
                loc = locmap[inst]
                lochist[loc] += int(count)

# Print lochist.
for loc, count in lochist.items():
    print(count, loc)
