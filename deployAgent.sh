#!/bin/bash

#Cleanup containers from VM
sudo docker system prune --all --force --volumes

#Globals
echo "step start: globals"
GENLOAD="${1:-no}"
SERVER_IP="${2:-10.0.0.5}"
DOCKER_PASS=$3
DOCKER_USER=$4
AQUA_REPO="${5:-aquadev}"
AQUA_VERSION="${6:-3.0.1}"
echo "step end: globals"

#Pre config
echo "step start: pre-config"
touch /home/ubuntu/scripts/logs/extension.log
chmod 777 /home/ubuntu/scripts/logs/extension.log
echo "step end: pre-config"

#Validations
echo "step start: validations"
echo "SERVER_IP: $SERVER_IP" >> /home/ubuntu/scripts/logs/extension.log
echo "AQUA_REPO: $AQUA_REPO" >> /home/ubuntu/scripts/logs/extension.log
echo "AQUA_VERSION: $AQUA_VERSION" >> /home/ubuntu/scripts/logs/extension.log
echo "DOCKER_PASS: $DOCKER_PASS" >> /home/ubuntu/scripts/logs/extension.log
BABA=$(echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin docker.io)
echo "step end: validations"

cd /home/$(whoami)/scripts
#Run Cadvisor
echo "step start: cadvisor"
docker run --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro \
--volume=/var/lib/docker/:/var/lib/docker:ro --volume=/dev/disk/:/dev/disk:ro -p 8090:8080 --detach=true \
--name=cadvisor google/cadvisor:latest
echo "step end: cadvisor"

#Run Aqua Agent
echo "step start: aqua agent"
docker run --rm -e SILENT=yes \
-e AQUA_TOKEN=agent-scale-token \
-e AQUA_SERVER=${SERVER_IP}:3622 \
-e AQUA_LOGICAL_NAME="scale-enforcer-$(hostname)" \
-e RESTART_CONTAINERS="no" \
-v /var/run/docker.sock:/var/run/docker.sock \
$AQUA_REPO/agent:$AQUA_VERSION
echo "step end: aqua agent"

#Load agents
if [ $GENLOAD == "yes" ];then
  sleep 60
  mkdir -p /home/$(whoami)/scripts/logs
  chmod -R 777 /home/$(whoami)/scripts/
  cd /home/$(whoami)/scripts/
  wget https://raw.githubusercontent.com/amitlib/scripts/master/loadGen.sh
  dos2unix loadGen.sh
  chmod 777 loadGen.sh
  ./loadGen.sh
fi
