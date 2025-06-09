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
parser.add_argument("--config", "-c", action="append")
parser.add_argument("--sim-mem-size", required=True)
parser.add_argument("--stack", default="8MiB")
parser.add_argument("--workload", required=True, type=int)
parser.add_argument("--failed", action="store_true")
args = parser.parse_args()

if args.config is None or len(args.config) == 0:
    args.config = ["base/unsafe", "base/stt", "slh/unsafe", "retpoline/unsafe"]

# GOAL: Generate a vector of commands (starting with /usr/bin/time -vo ...).

configs = collections.defaultdict(list)
for config in args.config:
    sw, hw = config.split("/")
    configs[sw].append(hw)


def check_cpt(expdir):
    if os.path.exists(f"{expdir}/stamp.txt"):
        return True
    if not os.path.exists(f"{expdir}/simout.txt"):
        return False
    with open(f"{expdir}/simout.txt") as f:
        line = f.readlines()[-1].strip()
    if line == "Done running SimPoint!":
        return True
    print(f"missing {expdir}: bad line:", line, file=sys.stderr)
    return False


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

        expdir = f"{bench}/chunk/{size}/{sw}/exp/{hw}/{input}/{cptid}"
        # Did this expdir succeed?
        if args.failed and check_cpt(expdir):
            continue
        
        # Build command.
        cptdir = f"{bench}/chunk/{size}/{sw}/cpt/{input}"
        cmd = f"cd /pincpu/bench-cpu2017 && rm -rf {expdir} && mkdir -p {expdir} && /usr/bin/time -vo {expdir}/time.txt -- /pincpu/gem5/{hwconf.sim}/build/X86/gem5.opt -re --silent-redirect --outdir={expdir} --debug-flag=Heartbeat --debug-file=dbgout.txt /pincpu/gem5/{hwconf.sim}/configs/deprecated/example/se.py --output=stdout.txt --errout=stderr.txt --cpu-type=X86O3CPU --caches --max-stack-size={args.stack} --mem-size={args.sim_mem_size} --checkpoint-dir={cptdir} --checkpoint-restore={cptid+1} --restore-simpoint-checkpoint {script_opts} -- {exe}"
        cmds.append(cmd)

with open(args.output, "wt") as f:
    json.dump(cmds, f, indent=4)

print(f"manifest contains {len(cmds)} commands", file=sys.stderr)
