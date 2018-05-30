#!/bin/bash
#Globals
AQUA_SERVER_IP="http://${1}:8080"
AQUA_REGISTRY="${2:-aquadev}"
AQUA_VERSION="${3:-master}"
DOCKER_HUB_REGISTRY_USER=${4}
DOCKER_HUB_REGISTRY_PASSWORD=${5}
NO_OF_SCANNERS="${6:-2}"
AQUA_ADMIN_PASSWORD=${7}

cd /home/${whoami}/scripts
docker login -u ${DOCKER_HUB_REGISTRY_USER} -p ${DOCKER_HUB_REGISTRY_PASSWORD}

echo "step start: validate input parameters"
if [ $# -lt 7 ];then
    echo "Missing parameters: arg1:$1,arg2:$2,arg3:$3,arg4:$4,arg5:$5,arg6:$6,arg7:$7"
    exit 1
else
    echo "Parameter validation passed successfully"
fi
echo "step end: validate input parameters"


for i in $(seq 1 $NO_OF_SCANNERS);do 
docker run --name scanner${i}-$(hostname | awk -F'-' ' { print $NF } ') -d \
-v /var/run/docker.sock:/var/run/docker.sock \
${AQUA_REGISTRY}/scanner-cli:${AQUA_VERSION} daemon \
--direct-cc --user administrator --password $AQUA_ADMIN_PASSWORD --host $AQUA_SERVER_IP 
done
