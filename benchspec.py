benchspec_int = [
    # INT
    "600/ref/2",
    "602/train/2",
    "605/train/0",
    "620/train/0",
    "623/train/0",
    "625/ref/0",
    "631/test/0",
    "641/test/0",
    "648/train/0",
    "657/train/1",
]

benchspec_fp = [
    # FP
    "603/train/1",
    "607/train/0",
    "619/train/0",
    "621/train/0",
    "638/train/0",
    "644/train/0",
    "649/train/0",
    "654/test/0",
]

benchspec = benchspec_int + benchspec_fp

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--int", action="store_true")
    parser.add_argument("--fp", action="store_true")
    parser.add_argument("--sep", default=" ")
    args = parser.parse_args()
    benches = []
    if args.int:
        benches.extend(benchspec_int)
    if args.fp:
        benches.extend(benchspec_fp)
    print(*benches, sep=args.sep)

if __name__ == "__main__":
    main()
