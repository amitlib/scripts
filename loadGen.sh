#!/bin/bash

echo "step start: run base containers"
docker run -d --name=grafana -p 3000:3000 grafana/grafana
docker run --name postgres -e POSTGRES_PASSWORD=postgres -d postgres
docker run -d --hostname $(hostname)-rabbit --name $(hostname)-rabbit rabbitmq:3
docker run --name gcc -d -it gcc
docker run -d -p 5000:5000 --restart=always --name registry registry:2
echo "step end: run base containers"

echo "step start: run mix "
container_array=(alpine:2.7 nginx:latest nginx:1.12-alpine nginx:1.13 nginx:stable-alpine nginx:1.12.2-alpine alpine:2.7 alpine:3.1 alpine:3.2 alpine:3.3 alpine:3.4 alpine:3.5 alpine:3.6 alpine:3.7 alpine:latest alpine:edge ubuntu:xenial ubuntu:trusty ubuntu:zesty ubuntu:16.04 ubuntu:14.04 debian fedora)
lFlag="0"
for i in ${container_array[@]};do
    lImageName=$(echo $i | awk -F: '{print $1}')
    echo "starting container: $i"
    docker run --name ${lImageName}_${lFlag} -it -e NAME1={aqua.secret1} -e NAME2={aqua.secret2} -e AQUA_SERVICE=srv-$(hostname) -d $i
    lFlag=$(($lFlag+1))
done
echo "step end: run mix "

echo "step start:run commands"

while true;do
    for i in $(sudo docker ps -a -q);do 
        sudo docker inspect $i
        sudo docker logs $i
        sudo docker ps
        docker image ls
        sleep 1
    done
    for a in $(sudo docker ps | awk '!/agent/ && !/cadvisor/ && !/logspout/ && !/CONTAINER/ && !/registry/ {print $1}');do
        sudo docker stop $a
    done
    sleep 30
    for i in $(sudo docker ps -a | awk '!/agent/ && !/cadvisor/ && !/logspout/ && !/CONTAINER/ && !/registry/ {print $1}');do
        sudo docker start $i
    done
    sleep 180
    
done
echo "step end:run commands"

