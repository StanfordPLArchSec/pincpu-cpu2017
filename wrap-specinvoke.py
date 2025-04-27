#!/usr/bin/env python3

import argparse
import os

parser = argparse.ArgumentParser()
parser.add_argument("command", nargs="+")
args = parser.parse_args()

command = args.command
command.insert(1, "-E")

os.execvp(command[0], command)
