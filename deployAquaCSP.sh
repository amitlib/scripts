#!/bin/bash
set -x

#Globals
echo "step start: globals"
ADMIN_USER=ubuntu
DOCKER_USER=$1
DOCKER_PASS=$2
AQUA_REPO=$3
AQUA_VERSION=$4
AQUA_LICENSE_TOKEN=$5
AQUA_ADMIN_PASSWORD=$6
INSTALL_DOCKER="${7:-no}"
echo "step end: globals"

echo "step start: arguments"
echo "ADMIN_USER: $ADMIN_USER"
echo "DOCKER_USER: $DOCKER_USER"
echo "AQUA_REPO: $AQUA_REPO"
echo "AQUA_VERSION: $AQUA_VERSION"
echo "AQUA_ADMIN_PASSWORD: $AQUA_ADMIN_PASSWORD"
echo "INSTALL_DOCKER: $INSTALL_DOCKER"
echo "step end: arguments"

if [ $INSTALL_DOCKER == "yes" ];then
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
    sudo apt-get install -y docker-ce
    sudo groupadd docker
    sudo usermod -aG docker $ADMIN_USER
    sudo systemctl start docker
    sudo systemctl enable docker
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

#Docker login
echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin $DOCKER_REGISTRY
lExitCode=$?
if [ $lExitCode == "0" ];then
  echo "Sucessfully logged in to DOCKER_REGISTRY"
else
  echo "Failed to login to DOCKER_REGISTRY, exit code : $lExitCode , exiting"
  exit 1
fi

#Run Aqua CASP
echo "step start: deploy Aqua CSP"
docker run -d -p 5432:5432 -p 3622:3622 -p 8080:8080 \
   -e POSTGRES_PASSWORD=${AQUA_ADMIN_PASSWORD} \
   -e SCALOCK_DBUSER=postgres \
   -e SCALOCK_DBPASSWORD=${AQUA_ADMIN_PASSWORD} \
   -e SCALOCK_DBNAME=scalock \
   -e SCALOCK_DBHOST=$(hostname -i) \
   -e SCALOCK_AUDIT_DBUSER=postgres \
   -e SCALOCK_GATEWAY_NAME=sfgateway \
   -e BATCH_INSTALL_NAME=sf-batch-install \
   -e BATCH_INSTALL_TOKEN=sf-batch-token \
   -e BATCH_INSTALL_ENFORCE_MODE=y \
   -e BATCH_INSTALL_GATEWAY=sfgateway \
   -e SCALOCK_AUDIT_DBPASSWORD=${AQUA_ADMIN_PASSWORD} \
   -e SCALOCK_AUDIT_DBNAME=slk_audit \
   -e SCALOCK_AUDIT_DBHOST=$(hostname -i) \
   -e LICENSE_TOKEN=${AQUA_LICENSE_TOKEN} \
   -e ADMIN_PASSWORD=${AQUA_ADMIN_PASSWORD} \
   -v /var/lib/postgresql/data:/var/lib/postgresql/data \
   -v /var/run/docker.sock:/var/run/docker.sock \
$AQUA_REPO/csp:$AQUA_VERSION
 
 lExitCode=$?
if [ $lExitCode == "0" ];then
  echo "Sucessfully ran  $AQUA_REPO/csp:$AQUA_VERSION"
else
  echo "Failed to run  $AQUA_REPO/csp:$AQUA_VERSION, exit code : $lExitCode , exiting"
  exit 1
fi
echo "step start: deploy Aqua CSP"
