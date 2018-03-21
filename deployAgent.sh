#!/bin/bash

SERVER_IP="${1:-10.0.0.5}"
DOCKER_PASS=$2
DOCKER_USER=$3
AQUA_REPO="${4:-aquadev}"
AQUA_VERSION="${5:-3.0.1}"

touch /home/ubuntu/scripts/logs/extension.log
chmod 777 /home/ubuntu/scripts/logs/extension.log
echo "SERVER_IP: $SERVER_IP" >> /home/ubuntu/scripts/logs/extension.log
echo "AQUA_REPO: $AQUA_REPO" >> /home/ubuntu/scripts/logs/extension.log
echo "AQUA_VERSION: $AQUA_VERSION" >> /home/ubuntu/scripts/logs/extension.log
echo "DOCKER_PASS: $DOCKER_PASS" >> /home/ubuntu/scripts/logs/extension.log
BABA=$(echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin docker.io)

cd /home/ubuntu/scripts

docker run --rm -e SILENT=yes \
-e AQUA_TOKEN=agent-scale-token \
-e AQUA_SERVER=${SERVER_IP}:3622 \
-e AQUA_LOGICAL_NAME="scale-enforcer-test" \
-e RESTART_CONTAINERS="no" \
-v /var/run/docker.sock:/var/run/docker.sock \
$AQUA_REPO/agent:$AQUA_VERSION
