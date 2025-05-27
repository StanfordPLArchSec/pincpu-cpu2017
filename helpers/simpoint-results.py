#!/usr/bin/env python3

import argparse
import json
import os
import types

parser = argparse.ArgumentParser()
parser.add_argument("--instcount", required=True, help="Path to gem5 stats.txt file containing total instruction count")
parser.add_argument("--expdir", required=True, help="Path to experiment directory containing checkpoints' results")
parser.add_argument("--simpoints", required=True, help="Path to simpoints.json file")
args = parser.parse_args()

def get_last_stat(path, key):
    value = None
    with open(path) as f:
        for line in f:
            if line.startswith(key):
                value = float(line.split()[1])
    return value

instcount = get_last_stat(args.instcount, "simInsts")

with open(args.simpoints) as f:
    simpoints = json.load(f)
simpoints = [types.SimpleNamespace(**simpoint) for simpoint in simpoints]

ticks_per_clock = None
ticks_per_second = None

total_ipc = 0.0
total_weight = 0.0
for simpoint in simpoints:
    stats_path = os.path.join(args.expdir, simpoint.name, "stats.txt")
    ticks_per_clock = get_last_stat(stats_path, "system.clk_domain.clock")
    ticks_per_second = get_last_stat(stats_path, "simFreq")
    ipc = get_last_stat(stats_path, "system.switch_cpus.commitStats0.ipc")
    total_ipc += ipc * simpoint.weight
    total_weight += simpoint.weight

assert abs(total_weight - 1) < 0.01

clocks = instcount / total_ipc
ticks = clocks * ticks_per_clock
seconds = ticks / ticks_per_second / 2 # We need to divide by two, but don't ask me why.
print(seconds)
