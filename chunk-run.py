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

cptdir = f"{args.dir}/${{PINCPU_CHUNK_INPUT}}"
expdir = f"/pincpu/bench-cpu2017/{bench}/chunk/{size}/{sw}/exp/{hw}/${{PINCPU_CHUNK_INPUT}}/${{PINCPU_CHUNK_INDEX}}"
hwconf = hwconfs[args.hw]
sim = hwconf.sim
script_opts = " ".join(hwconf.script_opts)
exe = f"/pincpu/bench-cpu2017/{bench}/bin/{sw}/exe"

def make_environment(input, cptid):
    return {
        "variables": {
            "PINCPU_CHUNK_INPUT": input,
            "PINCPU_CHUNK_INDEX": cptid,
            "PINCPU_CHUNK_INDEX_PLUS_1": str(int(cptid) + 1),
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
                            "entrypoint": f"mount -o nolock 10.103.56.106:/pincpu /pincpu && rm -rf {expdir} && mkdir -p {expdir} && /usr/bin/time -vo {expdir}/time.txt -- /pincpu/gem5/{sim}/build/X86/gem5.opt -re --silent-redirect --outdir={expdir} --debug-flag=Heartbeat --debug-file=dbgout.txt /pincpu/gem5/{sim}/configs/deprecated/example/se.py --output=stdout.txt --errout=stderr.txt --cpu-type=X86O3CPU --caches --max-stack-size=8MiB --mem-size=1GiB --checkpoint-dir={cptdir} --checkpoint-restore=${{PINCPU_CHUNK_INDEX_PLUS_1}} --restore-simpoint-checkpoint {script_opts} -- {exe}",
                            "volumes": [],
                        },
                    }
                ],
                "volumes": [],
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
                }
            }
        ]
    },
    "logsPolicy": {
        "destination": "CLOUD_LOGGING"
    },
}

with open("chunk-run.json", "wt") as f:
    json.dump(d, f, indent=4)
