#!/usr/bin/env python3

import argparse
import subprocess
import shutil
import os
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--stdout")
parser.add_argument("command", nargs="+")

args = parser.parse_args()

os.environ["LD_LIBRARY_PATH"] += ":/home/linuxbrew/.linuxbrew/lib"

subprocess.run(args.command, check=True)

if args.stdout:
    with open(args.stdout) as f:
        shutil.copyfileobj(f, sys.stdout)
