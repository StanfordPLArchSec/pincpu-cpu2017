#!/usr/bin/env python3

import argparse
import json
import glob
import os
import sys
import re
from hwconfs import hwconfs

parser = argparse.ArgumentParser()
parser.add_argument("--manifest", required=True, type=os.path.abspath)
parser.add_argument("--base", required=True, type=int)
parser.add_argument("--count", "-n", required=True, type=int)
args = parser.parse_args()

d = {
    "name": "projects/pincpu/locations/us-central1/jobs/test-chunk-run",
    "taskGroups": [
        {
            "taskCount": args.count,
            "parallelism": args.count,
            "taskSpec": {
                "computeResource": {
                    "cpuMilli": "1000",
                    "memoryMib": "1024",
                },
                "runnables": [
                    {
                        "container": {
                            "imageUri": "gcr.io/pincpu/pincpu",
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
                            "server": "10.103.56.106",
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
                    "machineType": "c2d-highcpu-16",
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
