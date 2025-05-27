#!/usr/bin/env python3

import argparse
import subprocess
import os

parser = argparse.ArgumentParser()
parser.add_argument("--expdir", required=True, type=os.path.abspath)
parser.add_argument("--cptdir", required=True, type=os.path.abspath)
parser.add_argument("--sim", required=True)
parser.add_argument("--input", required=True, type=int)
parser.add_argument("--index", required=True, type=int)
parser.add_argument("--script-opts", required=True)
parser.add_argument("--exe", required=True, type=os.path.abspath)
args = parser.parse_args()

cptdir = f"{args.cptdir}/{args.input}"
expdir = f"{args.expdir}/{args.input}/{args.index}"

# subprocess.run("mount -o nolock 10.103.56.106:/pincpu /pincpu", check=True)
subprocess.run(f"rm -rf {expdir}", shell=True, check=True)
subprocess.run(f"mkdir -p {expdir}", shell=True, check=True)
subprocess.run(f"/usr/bin/time -vo {expdir}/time.txt -- /pincpu/gem5/{args.sim}/build/X86/gem5.opt -re --silent-redirect --outdir={expdir} --debug-flag=Heartbeat --debug-file=dbgout.txt /pincpu/gem5/{args.sim}/configs/deprecated/example/se.py --output=stdout.txt --errout=stderr.txt --cpu-type=X86O3CPU --caches --max-stack-size=8MiB --mem-size=1GiB --checkpoint-dir={cptdir} --checkpoint-restore={args.index+1} --restore-simpoint-checkpoint {args.script_opts} -- {args.exe}", shell=True, check=True)
