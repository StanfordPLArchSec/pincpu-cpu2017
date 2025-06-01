#!/usr/bin/env python3

import argparse
import glob
import os
import sys
import collections
from hwconfs import hwconfs
import json

parser = argparse.ArgumentParser()
parser.add_argument("--output", "-o", required=True)
parser.add_argument("--dir", "-d", required=True)
parser.add_argument("--config", "-c", action="append", required=True)
parser.add_argument("--sim-mem-size", required=True)
parser.add_argument("--workload", required=True, type=int)
args = parser.parse_args()

# GOAL: Generate a vector of commands (starting with /usr/bin/time -vo ...).

configs = collections.defaultdict(list)
for config in args.config:
    sw, hw = config.split("/")
    configs[sw].append(hw)

# Enumerate all checkpoints.
cmds = []
for cptdir in glob.glob(f"{args.dir}/**/{args.workload}/cpt.[0-9]*/m5.cpt", recursive=True):
    bench, _, size, sw, _, input, cptname, _ = cptdir.split("/")
    input = int(input)
    _, cptid = cptname.split(".")
    cptid = int(cptid)
    exe = f"{bench}/bin/{sw}/exe"
    for hw in configs[sw]:
        hwconf = hwconfs[hw]
        script_opts = " ".join(hwconf.script_opts)

        # Build command.
        expdir = f"{bench}/chunk/{size}/{sw}/exp/{hw}/{input}/{cptid}"
        cptdir = f"{bench}/chunk/{size}/{sw}/cpt/{input}"
        cmd = f"cd /pincpu/bench-cpu2017 && rm -rf {expdir} && mkdir -p {expdir} && /usr/bin/time -vo {expdir}/time.txt -- /pincpu/gem5/{hwconf.sim}/build/X86/gem5.opt -re --silent-redirect --outdir={expdir} --debug-flag=Heartbeat --debug-file=dbgout.txt /pincpu/gem5/{hwconf.sim}/configs/deprecated/example/se.py --output=stdout.txt --errout=stderr.txt --cpu-type=X86O3CPU --caches --max-stack-size=8MiB --mem-size={args.sim_mem_size} --checkpoint-dir={cptdir} --checkpoint-restore={cptid+1} --restore-simpoint-checkpoint {script_opts} -- {exe}"
        cmds.append(cmd)

with open(args.output, "wt") as f:
    json.dump(cmds, f, indent=4)
