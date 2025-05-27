#!/usr/bin/env python3

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("lochist", nargs="+")
args = parser.parse_args()

def parse_lochist(path):
    with open(path) as f:
        lochist = dict()
        for line in f:
            count, loc = line.split()
            lochist[loc] = count
    return lochist

lochists = [parse_lochist(path) for path in args.lochist]
candidate_locs = list(lochists[0].keys())
shlochist = dict()

for loc, count in lochists[0].items():
    good = True
    for lochist in lochists[1:]:
        if loc in lochist and lochist[loc] == count:
            continue
        good = False
        break
    if good:
        shlochist[loc] = count

# Print shared location histogram.
for loc, count in shlochist.items():
    print(count, loc)


            
