#!/usr/bin/env python3

import argparse
import sys
from traceval_util import parse_lochist, instloctrace

parser = argparse.ArgumentParser()
parser.add_argument("--bbtraces", nargs="+")
parser.add_argument("--bbhists", nargs="+")
parser.add_argument("--locmaps", nargs="+")
parser.add_argument("--lochist", required=True)
args = parser.parse_args()

# Parse lochist.
with open(args.lochist) as f:
    lochist = parse_lochist(f)

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
    loc = l[0][1]
    for _, loc2 in l[1:]:
        if loc != loc2:
            # print(loc, loc2, file=sys.stderr)
            pass
    print(*[n for n, _ in l])
