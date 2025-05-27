#!/usr/bin/env python3

import argparse
import gzip
import xxhash
import collections
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--bbhist", required=True)
parser.add_argument("--bbtrace", required=True)
args = parser.parse_args()

# TODO: Extract to shared function?
def hash_block(block):
    return xxhash.xxh32(block).intdigest()

# Parse bbhist.
bbhist = collections.defaultdict(int)
bbhashes = {}
with open(args.bbhist) as f:
    for line in f:
        count, block = line.split()
        bbhist[block] = int(count)
        bbhash = hash_block(block)
        bbhashes[bbhash] = block

# Stream through bbtrace.
mybbhist = collections.defaultdict(int)
with gzip.open(args.bbtrace, "rb") as f:
    while blockhash := f.read(4):
        blockhashdec = int.from_bytes(blockhash, "little")
        block = bbhashes[blockhashdec]
        mybbhist[block] += 1

# Print out differences.
for block in set(bbhist.keys()) | set(mybbhist.keys()):
    if bbhist[block] != mybbhist[block]:
        print(f"mismatch for block {block}: {bbhist[block]} in hist, but {mybbhist[block]} in trace",
              file=sys.stderr)
        exit(1)
