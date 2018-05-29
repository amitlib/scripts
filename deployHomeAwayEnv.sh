#!/bin/bash

#Globals
AQUA_REGISTRY="${1:-aquadev}"
AQUA_VERSION="${2:-master}"
DOCKER_HUB_REGISTRY_USER=${3}
DOCKER_HUB_REGISTRY_PASSWORD=${4}
AQUA_DB_NAME=${5}
AQUA_DB_PASSWORD=${6}
AQUA_TOKEN=${7}
AQUA_ADMIN_PASSWORD=${8}
MONITOR_POSTGRES_URL=${9}
AQUASCALE_REG_PASSWORD=${10}
AQUA_DB_USER="aquaadm@${AQUA_DB_NAME}"
AQUA_DB_SERVER="${5}.postgres.database.azure.com"
HOST_VM=$(hostname | awk -F'-' ' { print $NF } ')
DASHBOARD_NAME="Aqua Monitor - ${AQUA_REGISTRY}/${AQUA_VERSION}"

cd /home/$(whoami)/scripts
#login to private registry
echo $DOCKER_HUB_REGISTRY_PASSWORD | docker login -u $DOCKER_HUB_REGISTRY_USER --password-stdin docker.io

echo "step start: validate input parameters"
if [ $# -lt 10 ];then
    echo "Missing parameters: arg1:$1,arg2:$2,arg3:$3,arg4:$4,arg5:$5,arg6:$6,arg7:$7,arg8:$8,arg9:$9,arg10:$10"
    exit 1
else
    echo "Parameter validation passed successfully"
fi
echo "step end: validate input parameters"


#functions
function check_exit {
    cmd_output=$($@)
    local status=$?
    echo $status
    if [ $status -ne 0 ]; then
        echo "error with $1" >&2
    fi
    echo "sucess with $1, return code: $status"
    return $status
}

deployCadvisor()
{
docker run --volume=/:/rootfs:ro \
--volume=/var/run:/var/run:rw --volume=/sys:/sys:ro \
--volume=/var/lib/docker/:/var/lib/docker:ro \
--volume=/dev/disk/:/dev/disk:ro \
-p 8090:8080 \
--detach=true \
--name=cadvisor google/cadvisor:latest
}

deployAqua()
{
if [ $HOST_VM == "vm0" ];then
echo "step start:Deploying Aqua server version: $AQUA_REG/$AQUA_VER "
    docker run -d \
    --name aqua-web \
    -p 8080:8080 -p 443:8443 \
    --user=root \
    -e SCALOCK_DBUSER=${AQUA_DB_USER} \
    -e SCALOCK_DBPASSWORD=${AQUA_DB_PASSWORD} \
    -e SCALOCK_DBNAME=scalock \
    -e SCALOCK_DBHOST=$AQUA_DB_SERVER \
    -e SCALOCK_AUDIT_DBUSER=${AQUA_DB_USER} \
    -e SCALOCK_AUDIT_DBPASSWORD=${AQUA_DB_PASSWORD} \
    -e SCALOCK_AUDIT_DBNAME=slk_audit \
    -e LICENSE_TOKEN=${AQUA_TOKEN} \
    -e ADMIN_PASSWORD=${AQUA_ADMIN_PASSWORD} \
    -e SCALOCK_AUDIT_DBHOST=$AQUA_DB_SERVER \
    -v /var/run/docker.sock:/var/run/docker.sock \
    $AQUA_REGISTRY/server:$AQUA_VERSION
    
    echo "step start: monitoring server logs to validate startup"
    ( docker logs aqua-web -f & ) | grep -q "http server started"
    echo "step end: monitoring server logs to validate startup"
echo "step start:Deploying Aqua server version: $AQUA_REG/$AQUA_VER "
elif [ $HOST_VM == "vm1" ];then
    docker run -d --name aqua-gateway \
    -p 3622:3622 \
    -p 8085:8085 \
    --net=host \
    -e SCALOCK_DBUSER=${AQUA_DB_USER} \
    -e SCALOCK_DBPASSWORD=${AQUA_DB_PASSWORD} \
    -e SCALOCK_DBNAME=scalock \
    -e SCALOCK_DBHOST=$AQUA_DB_SERVER \
    -e SCALOCK_AUDIT_DBUSER=${AQUA_DB_USER} \
    -e SCALOCK_AUDIT_DBPASSWORD=${AQUA_DB_PASSWORD} \
    -e SCALOCK_AUDIT_DBNAME=slk_audit \
    -e SCALOCK_AUDIT_DBHOST=$AQUA_DB_SERVER \
    $AQUA_REGISTRY/gateway:$AQUA_VERSION
elif [ $HOST_VM == "vm2" ];then
    sudo mkdir -p /etc/prometheus
    sudo chown -R $(whoami):$(whoami) /etc/prometheus
    echo "step start:Deploying prometheus"
        docker run -d \
        -p 9090:9090 --net="host" \
        -v /etc/prometheus:/etc/prometheus \
        prom/prometheus \
        --config.file=/etc/prometheus/prometheus.yml \
        --web.enable-lifecycle \
        --web.enable-admin-api
    echo "step end:Deploying prometheus"

    echo "step start:Deploying grafana-storage volume"
    docker volume create grafana-storage
    echo "step end:Deploying grafana-storage volume"

    echo "step start:Deploying Grafana"
    docker run -d \
    -p 3000:3000 \
    --name=grafana \
    -v grafana-storage:/var/lib/grafana \
    grafana/grafana
    echo "step end:Deploying Grafana"
fi
}

deployMonitors()
{
if [ $HOST_VM == "vm2" ];then
    sleep 30
    echo "step start: add postgresql data source"
    curl -s -H 'Content-Type: application/json' -u 'admin:admin' -d '{"name":"NFT-Postgres","type":"postgres","access": "proxy","url": "'$MONITOR_POSTGRES_URL':5432","password": "Pepelib123!","user": "postgres","database": "postgres","basicAuth": false,"isDefault": false,"jsonData": {"sslmode": "disable"},"readOnly": false}' -X POST "http://$(hostname -i):3000/api/datasources"
    echo "step end: add postgresql data source"

    echo "step start: add prometheus data source"
    curl -s -H 'Content-Type: application/json' -u 'admin:admin' -d '{"name":"Prometheus","type":"prometheus","access": "proxy","url": "http://'$(hostname -i)':9090","password": "","user": "","database": "","basicAuth": false,"isDefault": true,"jsonData": {},"readOnly": false}' -X POST "http://$(hostname -i):3000/api/datasources"
    echo "step end: add prometheus data source"

    echo "step start: get Grafana dashboard from GitHub"
    wget https://raw.githubusercontent.com/amitlib/scripts/master/grafanaDashboardAquaNDockerMonitoring.json
    echo "step end: get Grafana dashboard from GitHub"

    echo "step start: change dashboard name"
    cat grafanaDashboardAquaNDockerMonitoring.json  | jq -r --arg DASHBOARD_NAME "$DASHBOARD_NAME" '.title=$DASHBOARD_NAME' | sponge grafanaDashboardAquaNDockerMonitoring.json
    echo "step end: change dashboard name"

    echo "step start: add dashboard"
    #curl -s -H 'Content-Type: application/json' -H 'Content-Type: application/json' -u 'admin:admin' -d @grafanaDashboardAquaNDockerMonitoring.json -X POST "http://$(hostname -i):3000/api/dashboards/db"
    echo "step start: add dashboard"
fi
}

addRegestries()
{
if [ $HOST_VM == "vm0" ];then
    echo "step start: add RHEL regestry"
    RHEL_REG=$(curl -s -H 'Content-Type: application/json' -u "administrator:$AQUA_ADMIN_PASSWORD" -X POST http://$(hostname -i):8080/api/v1/registries -d '{"name": "registry.access.redhat.com","type": "V1/V2","url": "https://registry.access.redhat.com","username": "","password": "","auto_pull": false}')
    echo "step end: add RHEL regestry"

    echo "step start: add scale regestry"
    SCALE_REG=$(curl -s -H 'Content-Type: application/json' -u "administrator:$AQUA_ADMIN_PASSWORD" -X POST http://$(hostname -i):8080/api/v1/registries -d '{"name": "aquascale","type": "ACR","url": "https://aquascale.azurecr.io","username": "aquascale","password": "'$AQUASCALE_REG_PASSWORD'","auto_pull": false}')
    echo "step end: add scale regestry"
fi
}

main()
{
check_exit deployCadvisor
check_exit deployAqua
check_exit deployMonitors
check_exit addRegestries
}
main