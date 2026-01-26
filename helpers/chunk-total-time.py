#!/usr/bin/env python3

import argparse
import glob
import sys
import os

parser = argparse.ArgumentParser()
parser.add_argument("dir")
args = parser.parse_args()

def parse_stats(stats_path):
    dir = os.path.dirname(stats_path)
    simout_path = os.path.join(dir, "simout.txt")
    with open(simout_path) as f:
        simout_last = f.readlines()[-1]
    if 'Done running SimPoint!' in simout_last:
        pass
    elif 'because exiting with last active thread context' in simout_last:
        pass
    else:
        print(f"error: bad simout: {dir}", file=sys.stderr)
        exit(1)
    
    t = None
    with open(stats_path) as f:
        for line in f:
            if line.startswith("simSeconds"):
                t = float(line.split()[1])

    if t is None:
        print(f"warning: no time found in: {path}", file=sys.stderr)
        return 0.0
    return t

total_time = 0.0
for stats_path in glob.glob(args.dir + "/*/*/stats.txt"):
    total_time += parse_stats(stats_path)

print(total_time)

