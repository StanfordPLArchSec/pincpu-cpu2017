#!/usr/bin/env python3

import argparse
import json
import sys
import os

def parse_json_file(path):
    with open(path) as f:
        return json.load(f)

parser = argparse.ArgumentParser()
parser.add_argument("--simpoints", required=True, type=parse_json_file)
parser.add_argument("stamps", nargs="+")
parser.add_argument("--bbhist", required=True)
args = parser.parse_args()

stats = [os.path.join(os.path.dirname(stamp), "stats.txt") for stamp in args.stamps]

# Get instruction count from bbhist.
instcount = 0
with open(args.bbhist) as f:
    for line in f:
        count, block = line.split()
        instcount += int(count) * len(block.split(","))

def get_last_stat(path, key, check_count=True):
    values = []
    with open(path) as f:
        for line in f:
            if line.startswith(key):
                values.append(float(line.split()[1]))
    if check_count and len(values) < 2:
        print(f"error: got fewer than expected instances of {key} in {path}", file=sys.stderr)
        exit(1)
    return values[-1]
        
def find_simpoint(name):
    for simpoint in args.simpoints:
        if simpoint["name"] == name:
            return simpoint

ticks_per_clock = get_last_stat(stats[0], "system.clk_domain.clock", check_count=False)
ticks_per_second = get_last_stat(stats[0], "simFreq", check_count=False)

total_ipc = 0
total_weight = 0
for stats_path in stats:
    cptname = stats_path.split("/")[-2]
    ipcs = []
    with open(stats_path) as f:
        for line in f:
            tokens = line.split()
            if len(tokens) >= 2 and tokens[0] == "system.switch_cpus.ipc":
                ipcs.append(float(tokens[1]))
    if len(ipcs) < 2:
        print(f"error: < 2 ipcs for {stats_path}", file=sys.stderr)
        exit(1)
    weight = find_simpoint(cptname)["weight"]
    total_ipc += ipcs[-1] * weight
    total_weight += weight

assert abs(total_weight - 1) < 0.01

clocks = instcount / total_ipc
ticks = clocks * ticks_per_clock
seconds = ticks / ticks_per_second / 2
print(f"{seconds:.3f}")
