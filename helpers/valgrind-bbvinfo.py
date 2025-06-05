#!/usr/bin/env python3

import sys
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--warmup", type=int, required=True)
parser.add_argument("bbv", nargs="+")

args = parser.parse_args()

def process_line(line, f_out):
    total_count = 0
    for token in line.removeprefix("T").split():
        _, blockid, count = token.split(":")
        total_count += int(count)
    print(max(0, total_count - args.warmup), 0, total_count, file=f_out)

def process_bbv(bbv_path):
    bbvinfo_path = bbv_path.replace("bbv.txt", "bbvinfo.txt")
    with open(bbv_path) as f_in, \
         open(bbvinfo_path, "wt") as f_out:
        for line in sys.stdin:
            if line.startswith("T"):
                process_line(line, f_out)

for bbv_path in args.bbv:
    process_bbv(bbv_path)
