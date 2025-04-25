#!/usr/bin/python3

import argparse
import sys

parser = argparse.ArgumentParser()
parser.add_argument("inpaths", nargs = "+")
args = parser.parse_args()

def get_line_set(path: str) -> set:
    with open(path) as f:
        return set(f)

lines = list(set.intersection(*map(get_line_set, args.inpaths)))
lines.sort()

for line in lines:
    sys.stdout.write(line)
