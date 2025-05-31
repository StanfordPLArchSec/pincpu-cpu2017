#!/usr/bin/env python3

import argparse
import sys

parser = argparse.ArgumentParser()
args = parser.parse_args()

prev_counts = None
for line in sys.stdin:
    cur_counts = list(map(int, line.split()))
    if not prev_counts:
        prev_counts = [0] * len(cur_counts)
    delta_counts = list(map(lambda x, y: y - x, prev_counts, cur_counts))
    print(*delta_counts)
    prev_counts = cur_counts
