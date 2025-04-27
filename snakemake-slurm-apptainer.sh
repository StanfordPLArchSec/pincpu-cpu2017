#!/bin/sh

PATH="$PATH:$PWD/dummy" snakemake --workflow-profile=profiles/slurm --latency-wait=15 "$@"
