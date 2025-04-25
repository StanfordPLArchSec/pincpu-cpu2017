#!/usr/bin/python3

import argparse
import collections

parser = argparse.ArgumentParser()
parser.add_argument("--bbhist", required=True)
parser.add_argument("--srclocs", required=True)
args = parser.parse_args()

# Parse srclocs.
locs = dict()
with open(args.srclocs) as f:
    for line in f:
        inst, loc = line.split()
        assert inst not in locs
        locs[inst] = loc

# Compute location edge histogram.
hist = collections.defaultdict(int)
with open(args.bbhist) as f:
    for line in f:
        tokens = line.split()
        block_hits = int(tokens[0])
        insts = tokens[1].split(",")
        assert len(insts) > 0
        for inst1, inst2 in zip(insts[:-1], insts[1:]):
            if inst1 in locs and inst2 in locs:
                loc1 = locs[inst1]
                loc2 = locs[inst2]
                if loc1 != loc2:
                    hist[(loc1, loc2)] += block_hits

# Write out sorted histogram.
hist = sorted(list(hist.items()))
for locs, count in hist:
    print(*locs, count)

