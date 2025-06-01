#!/usr/bin/env python3

import argparse
import sys

parser = argparse.ArgumentParser()
args = parser.parse_args()

for line in sys.stdin:
    tokens = line.split()
    print(tokens[1::2])
    
