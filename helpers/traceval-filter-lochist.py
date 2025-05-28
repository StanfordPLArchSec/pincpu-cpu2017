#!/usr/bin/env python3

import argparse
import sys
from traceval_util import loctrace, parse_lochist

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
lochist = parse_lochist(sys.stdin)

# Iterate over location traces, eliminating any locations from
# the location histogram that aren't in the right position.
loc_gens = [
    loctrace(lochist, bbtrace, bbhist, locmap) \
    for bbtrace, bbhist, locmap in \
    zip(args.bbtraces, args.bbhists, args.locmaps, strict=True)
]

# print([len(list(x)) for x in loc_gens], file=sys.stderr)

for locs in zip(*loc_gens, strict=True):
    assert subset(locs, lochist)
    if not all_equal(locs):
        for loc in set(locs):
            del lochist[loc]

for loc, count in lochist.items():
    print(count, loc)
