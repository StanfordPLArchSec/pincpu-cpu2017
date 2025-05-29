#!/usr/bin/env python3

import argparse
import sys
import collections

parser = argparse.ArgumentParser()
parser.add_argument("ref")
parser.add_argument("exp")
parser.add_argument("--errhist")
parser.add_argument("--errtrace")
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
    exp_prev = 0
    for exp in exp_it:
        assert exp[0] >= ref_begin[0]
        assert exp[0] <= ref_end[0]
        if exp[0] == ref_end[0]:
            # Flush+yield the chunk.
            weight = exp[0] - exp_prev
            yield ref_begin, ref_end, exp_chunk, weight
            exp_chunk = []
            ref_begin = ref_end
            try:
                ref_end = next(ref_it)
            except StopIteration:
                return
        exp_chunk.append(exp)
        exp_prev = exp[0]
    assert len(exp_chunk) == 0

def generator2(ref_it, exp_it):
    ref_end = next(ref_it)
    ref_begin = [0] * len(ref_end)
    exp_prev = 0
    for exp in exp_it:
        assert exp[0] >= ref_begin[0]
        assert exp[0] <= ref_end[0]
        assert exp[0] > exp_prev
        weight = exp[0] - exp_prev
        exp_prev = exp[0]
        yield ref_begin, ref_end, exp, weight
        if exp[0] == ref_end[0]:
            # Shift the window.
            ref_begin = ref_end
            try:
                ref_end = next(ref_it)
            except StopIteration:
                return
            

def compute_error(exp, ref_begin, ref_end):
    return max(abs(exp - ref_begin), abs(exp - ref_end))

gen = generator2(iter(generate_tuples(args.ref)),
                 iter(generate_tuples(args.exp)))
total_error = None
max_error = None
total_insts = None

def compute_error_i(ref_begin, ref_end, exp, i):
    begin_err = abs(ref_begin[i] - exp[i])
    end_err = abs(ref_end[i] - exp[i])
    if ref_begin[0] == exp[0]:
        return begin_err
    elif ref_end[0] == exp[0]:
        return end_err
    else:
        return max(begin_err, end_err)

def compute_error(ref_begin, ref_end, exp):
    return [compute_error_i(ref_begin, ref_end, exp, i) for i in range(1, len(exp))]

error_hists = None
def get_error_hists(n):
    global error_hists
    if not error_hists:
        error_hists = []
        for i in range(n):
            error_hists.append(collections.defaultdict(int))
    return error_hists

if args.errtrace:
    errtrace_f = open(args.errtrace, "wt")

for ref_begin, ref_end, exp, weight in gen:
    print(ref_begin, ref_end, exp, weight,
          file=sys.stderr)

    error = compute_error(ref_begin, ref_end, exp)
    print(weight, error)

    if args.errtrace:
        print(exp[0], *error, file=errtrace_f)

    for hist, err in zip(get_error_hists(len(error)), error):
        hist[err] += weight

    total_insts = ref_end[0]

# Normalize the error histogram weights.
for hist in error_hists:
    for key in hist:
        hist[key] /= total_insts

# Compute the mean, median, max error per histogram.
def compute_mean(errhist):
    return sum(err * weight for err, weight in errhist.items())
def compute_median(errhist):
    l = list(errhist.items())
    l.sort(key=lambda t: t[0])
    total_weight = 0
    for err, w in l:
        total_weight += w
        if total_weight >= 0.5:
            break
    return err
def compute_max(errhist):
    return max(errhist.keys())

max_error = []
mean_error = []
median_error = []
for errhist in error_hists:
    mean_error.append(compute_mean(errhist))
    median_error.append(compute_median(errhist))
    max_error.append(compute_max(errhist))

if args.errhist:
    keys = set()
    for errhist in error_hists:
        keys.update(errhist.keys())
    keys = sorted(keys)
    with open(args.errhist, "wt") as f:
        for err in keys:
            print(err, *[int(err * errhist[err] * total_insts) for errhist in error_hists], file=f)
        
print(f"max error: {max_error}", file=sys.stderr)
print(f"median error: {median_error}", file=sys.stderr)
print(f"mean error: {mean_error}", file=sys.stderr)
exit(1)
