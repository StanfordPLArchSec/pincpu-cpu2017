#!/usr/bin/env python3

import argparse
from locations import locations
import json
import subprocess
import math

parser = argparse.ArgumentParser()
parser.add_argument("--manifest", required=True)
args = parser.parse_args()

# Compute weight of all locations.
total_cpus = sum(locations.values())
with open(args.manifest) as f:
    cmds = json.load(f)
num_tasks = len(cmds)
task_locs = dict([(location, cpus / total_cpus * num_tasks) for location, cpus in locations.items()])

base = 0
for location, cpus in locations.items():
    count = math.ceil(cpus / total_cpus * num_tasks)
    count = min(num_tasks - base, count)
    subprocess.run(["/pincpu/bench-cpu2017/chunk-run2.py",
                    f"--manifest={args.manifest}",
                    f"--base={base}",
                    f"--count={count}"],
                   check=True)
    submit = f"gcloud beta batch jobs submit --location {location} --config /pincpu/bench-cpu2017/chunk-run.json --no-external-ip-address --network=projects/pincpu/global/networks/default --subnetwork=projects/pincpu/regions/{location}/subnetworks/default"
    subprocess.run(submit, shell=True, check=True)
    base += count
    
