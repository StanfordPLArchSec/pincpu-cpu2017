#!/usr/bin/env python3

import sys

instcount = 0
for line in sys.stdin:
    if line.startswith("T"):
        line = line.removeprefix("T")
        for token in line.split():
            instcount += int(token.split(":")[2])
        
print(instcount)
