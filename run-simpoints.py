#!/usr/bin/env python3

import argparse
import os

# Config:
# bench.size.workload.sw.hw.type
parser = argparse.ArgumentParser()
parser.add_argument("configs", nargs="+", help="bench/size/workload/sw/hw/type")
parser.add_argument("--dry-run", "-n", action="store_true")
args = parser.parse_args()

files = []
for config in args.configs:
    bench, size, workload, sw, hw, type = config.split("/")
    if type == "translate":
        group = "main"
    else:
        group = sw
    files.append(f"{bench}/simpoints/{type}/{size}/{group}/{sw}/exp/{hw}/{workload}/stats.txt")

cmd = ["snakemake", "--cores=all", "--keep-going", "--rerun-incomplete", "--nolock", *files]
if args.dry_run:
    print(*cmd)
else:
    os.execvp(cmd[0], cmd)
