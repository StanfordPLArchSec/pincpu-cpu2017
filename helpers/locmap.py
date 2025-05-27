#!/usr/bin/env python3

import argparse
import sys
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("cmd", nargs="+")
args = parser.parse_args()

# Get instruction list.
insts = set()
for line in sys.stdin:
    _, block = line.split()
    new_insts = block.split(",")
    insts.update(new_insts)
insts = list(insts)
    
# Run addr2line.
response = subprocess.run(
    args.cmd,
    input="\n".join(insts),
    text=True,
    capture_output=True,
    check=True,
)

locations = [line for line in response.stdout.splitlines() if len(line)]

assert len(locations) == len(insts)
locmap = dict(filter(lambda t: not t[1].startswith("?"), zip(insts, locations)))

for inst, loc in zip(insts, locations):
    if not loc.startswith("?"):
        print(inst, loc)
