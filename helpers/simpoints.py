#!/usr/bin/python3

import argparse
import sys
import json

parser = argparse.ArgumentParser()
parser.add_argument("--intervals", required = True)
parser.add_argument("--weights", required = True)
parser.add_argument("--bbvinfo", required = True)
args = parser.parse_args()

infos = []
with open(args.weights) as f_weights, \
     open(args.intervals) as f_intervals:
    for weight_line, interval_line in zip(f_weights, f_intervals):
        weight, idx1 = weight_line.split()
        interval, idx2 = interval_line.split()
        assert idx1 == idx2
        weight = float(weight)
        interval = int(interval)
        infos.append({
            "interval": interval,
            "weight": weight,
        })

# Add waypoints.
with open(args.bbvinfo) as f:
    waypoints_lines = list(map(str.strip, f))
for info in infos:
    tokens = list(map(int, waypoints_lines[info["interval"]].split()))
    assert len(tokens) == 3
    info["waypoints"] = tokens

# Number the simpoints.
infos.sort(key = lambda d: d["interval"])
for i, info in enumerate(infos):
    info["name"] = str(i)

# Dump output file.
json.dump(infos, sys.stdout, indent = 4)
