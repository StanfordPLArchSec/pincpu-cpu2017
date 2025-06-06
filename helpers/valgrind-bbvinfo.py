#!/usr/bin/env python3

import sys
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--warmup", type=int, required=True)
parser.add_argument("bbv", nargs="+")

args = parser.parse_args()

def process_line(line):
    total_count = 0
    for token in line.removeprefix("T").split():
        _, blockid, count = token.split(":")
        total_count += int(count)
    return total_count

def process_bbv(bbv_path):
    bbvinfo_path = bbv_path.replace("bbv.txt", "bbvinfo.txt")
    instcount = 0
    with open(bbv_path) as f_in, \
         open(bbvinfo_path, "wt") as f_out:
        for line in f_in:
            if line.startswith("T"):
                interval_begin = instcount
                instcount += process_line(line)
                interval_end = instcount
                interval_warmup = max(0, interval_begin - args.warmup)
                print(interval_warmup, interval_begin, interval_end, file=f_out)

for bbv_path in args.bbv:
    process_bbv(bbv_path)
