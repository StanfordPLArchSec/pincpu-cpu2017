#!/usr/bin/env python3

import argparse
import os
import sys
import benchspec
import subprocess

# Config:
# bench.size.workload.sw.hw.type
parser = argparse.ArgumentParser()
parser.add_argument("configs", nargs="*", help="bench/size/workload/sw/hw/type")
parser.add_argument("--dry-run", "-n", action="store_true")
parser.add_argument("--all", "-a", action="store_true")
parser.add_argument("-k", required=True, action="append")
parser.add_argument("--cores", "-j", default="all")
parser.add_argument("--swhw", default=None, action="append")
parser.add_argument("--passes", choices=[0, 1, 2], type=int, default=0)
args = parser.parse_args()

if args.swhw is None:
    args.swhw = ["base/unsafe", "base/stt", "slh/unsafe", "retpoline/unsafe"]

if args.all:
    assert len(args.configs) == 0
    args.configs = []
    for mode in ["valgrind", "legacy", "translate"]:
        for bench in benchspec.benchspec:
            for swhw in args.swhw:
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
    "603": "603.bwaves_s",
    "607": "607.cactuBSSN_s",
    "619": "619.lbm_s",
    "621": "621.wrf_s",
    "627": "627.cam4_s",
    "628": "628.pop2_s",
    "638": "638.imagick_s",
    "644": "644.nab_s",
    "649": "649.fotonik3d_s",
    "654": "654.roms_s",
}

targets1 = []
targets2 = []
for config in args.configs:
    bench, size, workload, sw, hw, type = config.split("/")
    if bench in bench_map:
        bench = bench_map[bench]
    if type == "translate":
        group = "main"
    else:
        group = sw
    for k in args.k:
        targets1.append(f"{bench}/simpoints/{type}/{size}/{group}/simpoint.k{k}.i{workload}.json")
        targets2.append(f"{bench}/simpoints/{type}/{size}/{group}/{sw}/exp.k{k}/{hw}/{workload}/stats.txt")

def run_snakemake(targets):
    cmd = ["./snakemake-slurm-apptainer.sh", f"--cores={args.cores}", "--keep-going", "--rerun-incomplete", "--nolock", *targets]
    if args.dry_run:
        print(*cmd)
    else:
        result = subprocess.run(cmd)
        if result.returncode != 0:
            print("error: command failed", file=sys.stderr)
            exit(1)

print("===== Generating SimPoints =====", file=sys.stderr)
if args.passes == 0 or args.passes == 1:
    run_snakemake(targets1)
print("==== Evaluating SimPoints =====", file=sys.stderr)
if args.passes == 0 or args.passes == 2:
    run_snakemake(targets2)
