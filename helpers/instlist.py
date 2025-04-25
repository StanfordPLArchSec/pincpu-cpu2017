#!/usr/bin/python3

import sys

insts = set()
for line in sys.stdin:
    insts.update(line.split()[1].split(","))

for inst in insts:
    print(inst)
