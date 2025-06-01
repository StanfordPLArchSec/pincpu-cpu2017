#!/usr/bin/env python3

import sys

instcount = 0
for line in sys.stdin:
    count, block = line.split()
    count = int(count)
    num_insts = len(block.split(","))
    instcount += num_insts * count

print(instcount)
