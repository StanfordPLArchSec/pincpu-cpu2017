#!/usr/bin/python3

import sys
import json
import types
import argparse
import os

parser = argparse.ArgumentParser()
parser.add_argument("--basename", "-b", action="store_true")
args = parser.parse_args()

def get_srcloc(line: str) -> str:
    j = json.loads(line)
    assert len(j["Symbol"]) == 1
    symbol = types.SimpleNamespace(**j["Symbol"][0])
    addr = j["Address"].removeprefix("0x")
    if len(symbol.FileName) == 0 or \
       symbol.Line == 0 or \
       symbol.Column == 0: # TODO: Maybe too strict?
        return None
    if args.basename:
        symbol.FileName = os.path.basename(symbol.FileName)
    return f"{addr} {symbol.FileName}:{symbol.Line}:{symbol.Column}"

for line in sys.stdin:
    srcloc = get_srcloc(line)
    if srcloc:
        print(srcloc)

