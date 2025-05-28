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
            yield [int(x) for x in line.split()]

def generator(ref_it, exp_it):
    exp_chunk = []
    ref_end = next(ref_it)
    ref_begin = [0] * len(ref_end)
    for exp in exp_it:
        assert exp[0] >= ref_begin[0]
        assert exp[0] <= ref_end[0]
        if exp[0] == ref_end[0]:
            # Flush+yield the chunk.
            yield ref_begin, ref_end, exp_chunk
            exp_chunk = []
            ref_begin = ref_end
            try:
                ref_end = next(ref_it)
            except StopIteration:
                return
        exp_chunk.append(exp)
    assert len(exp_chunk) == 0

def compute_error(exp, ref_begin, ref_end):
    return max(abs(exp - ref_begin), abs(exp - ref_end))

gen = generator(iter(generate_tuples(args.ref)),
                iter(generate_tuples(args.exp)))
total_error = None
max_error = None
total_insts = None
for ref_begin, ref_end, exp_chunk in gen:
    # Compute error.
    errors = []
    for exp in exp_chunk:
        errors.append([])
        for i in range(1, len(exp)):
            errors[-1].append(compute_error(exp[i], ref_begin[i], ref_end[i]))
    print(f"{ref_begin=} {ref_end=} {exp_chunk=} {errors=}", file=sys.stderr)

    # Update max error stats.
    for error in errors:
        if not max_error:
            max_error = list(error)
        for i in range(len(error)):
            max_error[i] = max(max_error[i], error[i])

        if total_error:
            for i in range(len(error)):
                total_error[i] += error[i]
        else:
            total_error = list(error)

    total_insts = ref_end[0]

mean_error = [total_err / total_insts for total_err in total_error]
print(f"max error: {max_error}", file=sys.stderr)
print(f"total error: {total_error}", file=sys.stderr)
print(f"mean error: {mean_error}", file=sys.stderr)
exit(1)
