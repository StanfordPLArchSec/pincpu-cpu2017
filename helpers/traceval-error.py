#!/usr/bin/env python3

import argparse
import sys

parser = argparse.ArgumentParser()
parser.add_argument("ref")
parser.add_argument("exp")
args = parser.parse_args()

# NOTE: ref is always a subsequence of exp, colinear in locations.
#       exp is generally not colinear in locations.
#       This script is trying to bound the error introduced by the
#       non-colinearity of exp.

def generate_tuples(path):
    with open(path) as f:
        for line in f:
            yield line.split()

def cmp_le(a_, b_):
    return all(a <= b for a, b in zip(a_, b_, strict=True))

def generator(ref_it, exp_it):
    # Approach:
    # Accumulate exp records into list until we counter
    # a ref that matches.
    chunk = [0]
    ref = next(ref_it)
    for exp in exp_it:
        # print(f"{ref=} {exp=}", file=sys.stderr)
        # assert cmp_le(exp, ref)
        chunk.append(exp)
        if exp[0] == ref[0]:
            yield chunk
            chunk = chunk[-1:]
            ref = next(ref_it)

    assert len(chunk) == 1


gen = generator(iter(generate_tuples(args.ref)),
                iter(generate_tuples(args.exp)))
for chunk in gen:
    print(chunk, file=sys.stderr)

exit(1)
