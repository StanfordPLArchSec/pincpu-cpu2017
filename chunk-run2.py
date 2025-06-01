#!/usr/bin/env python3

import argparse
import json
import glob
import os
import sys
import re
from hwconfs import hwconfs

def parse_mem_mib(s):
    m = re.match(r"(\d+)GiB", s)
    assert m
    return int(m.group(1)) * 1024

parser = argparse.ArgumentParser()
parser.add_argument("--manifest", required=True, type=os.path.abspath)
parser.add_argument("--base", type=int, default=0)
parser.add_argument("--count", "-n", type=int, default=0)
parser.add_argument("--parallelism", "-j", type=int, default=0)
parser.add_argument("--hostmem", required=True, type=parse_mem_mib)
args = parser.parse_args()

if args.count == 0:
    with open(args.manifest) as f:
        args.count = len(json.load(f))

if args.parallelism == 0:
    args.parallelism = args.count

d = {
    "name": "projects/soe-pincpu/locations/us-central1/jobs/test-chunk-run",
    "taskGroups": [
        {
            "taskCount": args.count,
            "parallelism": args.parallelism,
            "taskSpec": {
                "computeResource": {
                    "cpuMilli": "1000",
                    "memoryMib": str(args.hostmem),
                },
                "maxRetryCount": 3,
                "runnables": [
                    {
                        "container": {
                            "imageUri": "gcr.io/soe-pincpu/pincpu",
                            "entrypoint": "/bin/sh",
                            "commands": [
                                "-c",
                                f"/pincpu/bench-cpu2017/chunk-run-entrypoint2.py --manifest={args.manifest} --base={args.base} --index=${{BATCH_TASK_INDEX}}",
                                # TODO: Convert to main command and read env var
                            ],
                            "volumes" : ["/home/nmosier/pincpu:/pincpu"],
                        },
                    }
                ],
                "volumes": [
                    {
                        "nfs": {
                            "server": "172.25.91.250",
                            "remotePath": "/pincpu",
                        },
                        "mountPath": "/home/nmosier/pincpu",
                    }
                ],
            },
        }
    ],
    "allocationPolicy": {
        "instances": [
            {
                "policy": {
                    "provisioningModel": "SPOT",
                },
            }
        ]
    },
    "logsPolicy": {
        "destination": "CLOUD_LOGGING"
    },
}

with open("chunk-run.json", "wt") as f:
    json.dump(d, f, indent=4)
