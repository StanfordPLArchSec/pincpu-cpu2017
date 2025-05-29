#!/bin/bash

set -e

usage() {
    cat <<EOF
usage: $0 [location]
EOF
}

case $# in
    0)
	location=us-central1
	;;
    1)
	location="$1"
	;;
    *)
	usage >&2
	exit 1
esac

exec gcloud batch jobs submit --location ${location} --config /pincpu/bench-cpu2017/chunk-run.json --no-external-ip-address --network=projects/soe-pincpu/global/networks/default --subnetwork=projects/soe-pincpu/regions/${location}/subnetworks/default
