#!/bin/bash
AQUA_SERVER_IP="http://${1}:8080"
AQUA_REGISTRY="${2:-aquadev}"
AQUA_VERSION="${3:-master}"
DOCKER_HUB_REGISTRY_USER=${4}
DOCKER_HUB_REGISTRY_PASSWORD=${5}
NO_OF_SCANNERS="${6:-2}"
AQUA_ADMIN_PASSWORD=${7}


for i in $(seq 1 $NO_OF_SCANNERS);do \
docker run --name scanner${i}-$(hostname | awk -F'-' ' { print $NF } ') \
-d -v /var/run/docker.sock:/var/run/docker.sock \
aquadev/scanner-cli:ido-conn-leak daemon --user administrator --password Password1 --host $AQUA_SERVER_IP \
done