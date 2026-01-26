#!/usr/bin/env python3

import argparse
import sys
import collections

parser = argparse.ArgumentParser()
parser.add_argument("ref")
parser.add_argument("exp")
parser.add_argument("--errtrace")
parser.add_argument("--errhist")
parser.add_argument("--verbose", "-v", action="store_true")
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
            try:
                ref_end = next(ref_it)
            except StopIteration:
                return
        assert ref_begin[0] <= exp[0] <= ref_end[0]
        weight = exp[0] - exp_prev
        exp_prev = exp[0]
        yield ref_begin, ref_end, exp, weight


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

for ref_begin, ref_end, exp, weight in \
        stream_weighted_ref_bounded_exp(args.ref, args.exp):
    if args.verbose:
        print(ref_begin, ref_end, exp, weight, file=sys.stderr)

    error = compute_error(ref_begin, ref_end, exp)
    if args.verbose:
        print(weight, error)

    if args.errtrace:
        print(weight, exp[0], *error, file=errtrace_f)

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
            # print(err, *[int(err * errhist[err] * total_insts) for errhist in error_hists], file=f)
            print(f"{err}", end="", file=f)
            for errhist in error_hists:
                if err in errhist:
                    print(f" {errhist[err]:f}", end="", file=f)
                else:
                    print(" -", end="", file=f)
            print("\n", end="", file=f)
        
print(f"max error: {max_error}")
print(f"median error: {median_error}")
print(f"mean error: {mean_error}")
