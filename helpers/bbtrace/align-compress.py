#!/usr/bin/env python3

import argparse
import sys
import struct

parser = argparse.ArgumentParser()
args = parser.parse_args()

prev_counts = None
for line in sys.stdin:
    tokens = line.split()
    cur_counts = list(map(int, tokens[1::2]))
    if not prev_counts:
        prev_counts = [0] * len(cur_counts)
    delta_counts = [struct.pack("<Q", y - x) for x, y in zip(prev_counts, cur_counts, strict=True)]
    delta_counts = list(map(lambda x, y: y - x, prev_counts, cur_counts))
    print(*delta_counts)
    prev_counts = cur_counts
