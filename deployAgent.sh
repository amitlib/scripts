#!/bin/bash

SERVER_IP="${1:-10.0.0.5}"
AQUA_REPO="${2:-aquadev}"
AQUA_VERSION="${3:-3.0.1}"

cd /home/ubuntu/scripts

docker run --rm -e SILENT=yes \
-e AQUA_TOKEN=agent-scale-token \
-e AQUA_SERVER=${SERVER_IP}:3622 \
-e AQUA_LOGICAL_NAME="scale-enforcer-test" \
-e RESTART_CONTAINERS="no" \
-v /var/run/docker.sock:/var/run/docker.sock \
$AQUA_REPO/agent:$AQUA_VERSION
