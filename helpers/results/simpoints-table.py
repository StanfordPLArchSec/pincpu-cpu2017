#!/usr/bin/env python3

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--config", "-c", action="append")
parser.add_argument("--bench", "-b", required=True)
parser.add_argument("-k", required=True, type=int)
args = parser.parse_args()

if args.config is None or len(args.config) == 0:
    args.config = ["unsafe", "stt", "slh", "retpoline"]

bench, size, input = args.bench.split("/")

# Header
print("method", *args.config)

modes = ["gold", "valgrind", "legacy", "translate"]
for mode in modes:
    tokens = [mode]
    for config in args.config:
        path = f"results/{bench}/{size}/{input}/simpoints/{args.k}/{config}/{mode}"
        with open(path) as f:
            x = float(f.read().strip())
        tokens.append(f"{x:f}")
    print(*tokens)
