#!/usr/bin/env python3

import argparse
import glob
import sys

parser = argparse.ArgumentParser()
parser.add_argument("dir")
args = parser.parse_args()

def parse_stats(path):
    t = None
    with open(path) as f:
        for line in f:
            if line.startswith("simSeconds"):
                t = float(line.split()[1])

    if t is None:
        print(f"warning: no time found in: {path}", file=sys.stderr)
        return 0.0
    return t

total_time = 0.0
for path in glob.glob(args.dir + "/*/*/stats.txt"):
    total_time += parse_stats(path)

print(total_time)

