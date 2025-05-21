#!/usr/bin/env python3

import argparse
import json
import glob
import os
import sys
import re
from hwconfs import hwconfs

parser = argparse.ArgumentParser()
parser.add_argument("dir", type=os.path.abspath)
parser.add_argument("--hw", required=True)
args = parser.parse_args()

# Benchmark name.
bench, _, size, sw, _ = args.dir.split("/")[-5:]
hw = args.hw
print(f"{bench=} {size=} {sw=} {hw=}", file=sys.stderr)

# Enumerate the chunks as (input, cptid) pairs.
cpt_paths = glob.glob(os.path.join(args.dir, "*", "cpt.[0-9]*", "m5.cpt"))
chunks = []
for path in cpt_paths:
    input, cpt_name = path.split("/")[-3:-1]
    cptid = cpt_name.split(".")[1]
    chunks.append((input, cptid))

cptdir = f"{args.dir}"
expdir = f"/pincpu/bench-cpu2017/{bench}/chunk/{size}/{sw}/exp/{hw}"
hwconf = hwconfs[args.hw]
sim = hwconf.sim
script_opts = " ".join(hwconf.script_opts)
exe = f"/pincpu/bench-cpu2017/{bench}/bin/{sw}/exe"

command = f"/pincpu/bench-cpu2017/chunk-run-entrypoint.py --expdir={expdir} --cptdir={cptdir} --sim={sim} --input=${{PINCPU_CHUNK_INPUT}} --index=${{PINCPU_CHUNK_INDEX}} '--script-opts={script_opts}' --exe={exe}"

def make_environment(input, cptid):
    return {
        "variables": {
            "PINCPU_CHUNK_INPUT": input,
            "PINCPU_CHUNK_INDEX": cptid,
        }
    }

d = {
    "name": "projects/pincpu/locations/us-central1/jobs/test-chunk-run",
    "taskGroups": [
        {
            "taskCount": len(chunks),
            "parallelism": min(100, len(chunks)),
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
                                f"{command}", # TODO: Convert to regular command and access env variables from within runscript.
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
            "taskEnvironments": [make_environment(input, cptid) for input, cptid in chunks],
        }
    ],
    "allocationPolicy": {
        "instances": [
            {
                "policy": {
                    "provisioningModel": "SPOT",
                    "machineType": "e2-medium",
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
