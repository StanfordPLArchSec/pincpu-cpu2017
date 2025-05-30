#!/usr/bin/env python3

import argparse
import sys
import collections

parser = argparse.ArgumentParser()
parser.add_argument("ref")
parser.add_argument("exp")
args = parser.parse_args()

# Given an n-way alignment, generate the sequence of
# dynamic instruction count n-tuples.
def stream_align_counts(path):
    with open(path) as f:
        for line in f:
            yield list(map(int, line.split()[1::2]))


def stream_weighted_ref_bounded_exp(ref_path, exp_path):
    ref_it = stream_align_counts(ref_path)
    exp_it = stream_align_counts(exp_path)
    ref_end = next(ref_it)
    ref_begin = [0] * len(ref_end)
    exp_prev = 0
    for exp in exp_it:
        # Shift the reference interval if needed.
        while exp[0] > ref_end[0]:
            ref_begin = ref_end
            ref_end = next(ref_it)
        assert ref_begin[0] <= exp[0] <= ref_end[0]
        weight = exp[0] - exp_prev
        exp_prev = exp[0]
        yield ref_begin, ref_end, exp, weight

for ref_begin, ref_end, exp, weight in \
        stream_weighted_ref_bounded_exp(args.ref, args.exp):
    assert ref_begin[0] <= exp[0] <= ref_end[0]
    assert weight >= 0

    
    print(ref_begin, exp, ref_end, weight)
    
