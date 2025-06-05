#!/usr/bin/env python3

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--lochist", required=True)
parser.add_argument("--locmap", required=True)
args = parser.parse_args()

# Parse the lochist.
loc_waypoints = set()
with open(args.lochist) as f:
    for line in f:
        count, loc = line.split()
        assert loc not in loc_waypoints
        loc_waypoints.add(loc)

# Parse the locmap.
waypoints = set()
with open(args.locmap) as f:
    for line in f:
        inst, loc = line.split()
        if loc in loc_waypoints:
            print(inst)
