#!/bin/bash
#Globals
echo "step start: globals"
GENLOAD="${1:-no}"
INSTALLDOCKER="${2:-no}"
SERVER_IP="${3:-10.0.0.4}"
DOCKER_PASS=$4
DOCKER_USER=$5
AQUA_REPO="${6:-aquasec}"
AQUA_VERSION="${7:-3.0.3}"
ELK_IP="${8:-172.19.0.4}"
echo "step end: globals"

#Cleanup containers from VM
if [ $INSTALLDOCKER == "no" ];then
  sudo docker system prune --all --force --volumes
fi

#Pre config
echo "step start: pre-config"
mkdir -p /home/$(whoami)/scripts/logs
chmod -R 777 /home/$(whoami)/scripts
touch /home/$(whoami)/scripts/logs/extension.log
chmod 777 /home/$(whoami)/scripts/logs/extension.log
echo "step end: pre-config"

if [ $INSTALLDOCKER == "yes" ];then
  #install docker
  echo "step start: install docker-ce"
  sudo apt-get update
  sudo apt-get install \
      apt-transport-https \
      ca-certificates \
      curl \
      software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo apt-key fingerprint 0EBFCD88
  sudo add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) \
     stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce sqlite3 jq postgresql-client sysstat dos2unix
  sudo groupadd docker
  sudo usermod -aG docker $(whoami)
  sudo systemctl start docker
  sudo systemctl enable docker
   sudo apt-get update
  sleep 10
  docker version
  lExitCode=$?
  if [ $lExitCode == "0" ];then
    echo "Docker installed successfully"
  else
    echo "Failed to install docker, exit code : $lExitCode, exiting"
    exit 1
  fi
  echo "step end: install docker-ce"
fi

#Validations
echo "step start: validations"
echo "SERVER_IP: $SERVER_IP" >> /home/ubuntu/scripts/logs/extension.log
echo "AQUA_REPO: $AQUA_REPO" >> /home/ubuntu/scripts/logs/extension.log
echo "AQUA_VERSION: $AQUA_VERSION" >> /home/ubuntu/scripts/logs/extension.log
BABA=$(echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin docker.io)
echo "step end: validations"


#Run logstash
echo "step start: logspout"
docker run --name="logspout" \
--volume=/var/run/docker.sock:/var/run/docker.sock -d \
--restart=always \
-e ROUTE_URIS=logstash+tcp://$ELK_IP:5000 \
libermanov/logspout-logstash:v1
echo "step end: logspout"

cd /home/$(whoami)/scripts
#Run Cadvisor
echo "step start: cadvisor"
docker run --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro \
--restart=always \
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
