#!/usr/bin/env python3

import sys

errhist = []

def parse_weight(weight):
    if weight == "-":
        return None
    else:
        return float(weight)

for line in sys.stdin:
    error, *weights = line.split()
    error = int(error)
    weights = [parse_weight(weight) for weight in weights]
    errhist.append((error, weights))
errhist.sort()
n = len(errhist[0][1])

# Compute mean error.
def compute_mean(errhist, i):
    return sum([error * weights[i] for error, weights in errhist if weights[i] is not None])

# Compute median error.
def compute_median(errhist, i):
    total_weight = 0
    for error, weights in errhist:
        if weights[i] is not None:
            total_weight += weights[i]
            if total_weight >= 0.5:
                break
    return error

def compute_max(errhist, i):
    return max([error for error, weights in errhist if weights[i] is not None])

def print_stat(name, f):
    print(name, end="")
    for i in range(n):
        value = f(errhist, i)
        print(f" {value:f}", end="")
    print("\n", end="")


print_stat("mean", compute_mean)
print_stat("median", compute_median)
print_stat("max", compute_max)
