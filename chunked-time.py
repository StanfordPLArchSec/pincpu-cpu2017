#!/usr/bin/env python3

import argparse
import glob
import sys
import os

parser = argparse.ArgumentParser()
parser.add_argument("exp")
args = parser.parse_args()

# Compute cpt dir from exp dir.
bench, chunk, size, sw, exp, hw, workload = args.exp.split("/")
cptdir = os.path.join(bench, chunk, size, sw, "cpt", workload)

def check_cpt(cptid):
    expdir = f"{args.exp}/{cptid}"
    if os.path.exists(f"{expdir}/stamp.txt"):
        return True
    if not os.path.exists(f"{expdir}/simout.txt"):
        print(f"missing {cptid}: no simout", file=sys.stderr)
        return False
    with open(f"{expdir}/simout.txt") as f:
        line = f.readlines()[-1].strip()
    if line == "Done running SimPoint!":
        return True
    print(f"missing {cptid}: bad line:", line, file=sys.stderr)
    return False

missing = False
total_time = 0
for cpt in glob.glob(f"{cptdir}/cpt.[0-9]*"):
    cptid = int(cpt.split(".")[-1])
    if not check_cpt(cptid):
        missing = True

    # Get the time.
    sim_secs = []
    with open(f"{args.exp}/{cptid}/stats.txt") as f:
        for line in f:
            if line.startswith("simSeconds"):
                sim_secs.append(float(line.split()[1]))
    if len(sim_secs) != 2:
        print(f"unexpected number of simSeconds for {cptid}", file=sys.stderr)
    if len(sim_secs) > 0:
        total_time += sim_secs[-1]

print(f"{total_time:.3f}")

if missing:
    exit(1)
