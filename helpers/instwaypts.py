#!/usr/bin/python3

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--bbhist", required = True)
parser.add_argument("--shlocedges", required = True)
parser.add_argument("--srclocs", required = True)
args = parser.parse_args()

# Parse srclocs.
# Format: instaddr srclocstr
inst_to_loc = {}
with open(args.srclocs) as f:
    for line in f:
        inst, loc = line.split()
        inst_to_loc[inst] = loc

# Parse shlocedges.
# Format: srcloc dstloc count
loc_edges = set()
with open(args.shlocedges) as f:
    for line in f:
        loc1, loc2, count = line.split()
        loc_edges.add((loc1, loc2))

# Parse bbhist into an intra-block instruction successor map.
# Format: count inst1,inst2,...,instn
# For the above line, we'd parse it into inst1->inst2, inst2->inst3, ..., inst{n-1}->instn.
inst_edges = {}
with open(args.bbhist) as f:
    for line in f:
        count, insts = line.split()
        insts = insts.split(",")
        assert len(insts) > 0
        for inst1, inst2 in zip(insts[:-1], insts[1:]):
            if inst1 in inst_to_loc and inst2 in inst_to_loc:
                loc1 = inst_to_loc[inst1]
                loc2 = inst_to_loc[inst2]
                if (loc1, loc2) in loc_edges:
                    assert inst_edges.get(inst1, inst2) == inst2
                    inst_edges[inst1] = inst2

# Print inst_edges to file.
for inst1 in inst_edges:
    print(inst1)

