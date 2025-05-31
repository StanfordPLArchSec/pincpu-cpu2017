#!/usr/bin/env python3

import argparse
import sys

parser = argparse.ArgumentParser()
args = parser.parse_args()

total_counts = None
for line in sys.stdin:
    delta_counts = line.split()
    if total_counts is None:
        total_counts = [0] * len(delta_counts)

    for i in range(len(delta_counts)):
        total_counts[i] += int(delta_counts[i])

    print(*total_counts)
