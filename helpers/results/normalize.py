#!/usr/bin/env python3

import sys

def tryfloat(s):
    try:
        return float(s)
    except ValueError:
        return None

for line in sys.stdin:
    tokens = line.split()
    out = []
    if len(tokens) >= 2 and (base := tryfloat(tokens[1])):
        out = [tokens[0]]
        for s in tokens[1:]:
            if x := tryfloat(s):
                out.append(x / base)
            else:
                out.append(x)
    else:
        out = tokens    
    print(*out)

