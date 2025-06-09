#!/usr/bin/env python3

import argparse
import os
import shutil
import sys
import glob
import stat

parser = argparse.ArgumentParser()
parser.add_argument("benches", nargs="+")
parser.add_argument("-k", required=True, type=int)
args = parser.parse_args()

confs = {
    "unsafe": "base/unsafe",
    "stt": "base/stt",
    "slh": "slh/unsafe",
    "retpoline": "retpoline/unsafe",
}

def cp(inpath, outpath):
    try:
        with open(inpath) as f_in, open(outpath, "wt") as f_out:
            shutil.copyfileobj(f_in, f_out)
        os.chmod(outpath, stat.S_IRUSR | stat.S_IRGRP | stat.S_IROTH)
    except FileNotFoundError:
        print(f"error: failed to copy {inpath} -> {outpath}", file=sys.stderr)

for benchspec in args.benches:
    bench, size, input = benchspec.split("/")
    for conf in confs:
        sw, hw = confs[conf].split("/")
        outdir = os.path.join("results", bench, size, input, "simpoints", f"{args.k}", conf)
        goldpath = os.path.join("results", bench, size, input, "chunk", conf)
        os.makedirs(outdir, exist_ok=True)

        # Create gold file.
        cp(goldpath, os.path.join(outdir, "gold"))

        # Create legacy simpoints files.
        for mode in ["valgrind", "legacy"]:
            inpath, = glob.glob(f"{bench}.*_s/simpoints/{mode}/{size}/{sw}/{sw}/exp/{hw}/{input}/stats.txt")
            cp(inpath, os.path.join(outdir, mode))
    
        # Create translate simpoints files.
        inpath, = glob.glob(f"{bench}.*_s/simpoints/translate/{size}/main/{sw}/exp/{hw}/{input}/stats.txt")
        cp(inpath, os.path.join(outdir, "translate"))

