#!/usr/bin/env python3

import argparse
import subprocess
import os
import json

parser = argparse.ArgumentParser()
parser.add_argument("--manifest", required=True, type=os.path.abspath)
parser.add_argument("--base", required=True, type=int)
parser.add_argument("--index", required=True, type=int)
args = parser.parse_args()

with open(args.manifest) as f:
    j = json.load(f)

cmd = j[args.base + args.index]
subprocess.run(cmd, shell=True, check=True)
