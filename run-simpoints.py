#!/usr/bin/env python3

import argparse
import os
import benchspec

# Config:
# bench.size.workload.sw.hw.type
parser = argparse.ArgumentParser()
parser.add_argument("configs", nargs="*", help="bench/size/workload/sw/hw/type")
parser.add_argument("--dry-run", "-n", action="store_true")
parser.add_argument("--all", "-a", action="store_true")
args = parser.parse_args()

if args.all:
    assert len(args.configs) == 0
    args.configs = []
    for mode in ["valgrind", "legacy", "translate"]:
        for bench in benchspec.benchspec:
            for swhw in ["base/unsafe", "base/stt", "slh/unsafe", "retpoline/unsafe"]:
                args.configs.append(f"{bench}/{swhw}/{mode}")

# Translate benches
bench_map = {
    "600": "600.perlbench_s",
    "602": "602.gcc_s",
    "605": "605.mcf_s",
    "620": "620.omnetpp_s",
    "623": "623.xalancbmk_s",
    "625": "625.x264_s",
    "631": "631.deepsjeng_s",
    "641": "641.leela_s",
    "648": "648.exchange2_s",
    "657": "657.xz_s",
}

files = []
for config in args.configs:
    bench, size, workload, sw, hw, type = config.split("/")
    if bench in bench_map:
        bench = bench_map[bench]
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
