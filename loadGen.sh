#!/bin/bash
container_array=(alpine:2.7 nginx:latest nginx:1.12-alpine nginx:1.13 nginx:stable-alpine nginx:1.12.2-alpine alpine:2.7 alpine:3.1 alpine:3.2 alpine:3.3 alpine:3.4 alpine:3.5 alpine:3.6 alpine:3.7 alpine:latest alpine:edge ubuntu:xenial ubuntu:trusty ubuntu:zesty ubuntu:16.04 ubuntu:14.04)
lFlag="0"
for i in ${container_array[@]};do
    lImageName=$(echo $i | awk -F: '{print $1}')
    docker run --rm --name ${lImageName}_${lFlag} -it -e NAME1={aqua.secret1} -e NAME2={aqua.secret2} -e AQUA_SERVICE=${DND_NAME} -v /tmp/scripts/logs:/tmp -d $i
    lFlag=$(($lFlag+1))
done
