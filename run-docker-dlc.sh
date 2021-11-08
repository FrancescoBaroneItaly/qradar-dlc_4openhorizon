#! /bin/bash

source $(dirname $0)/.env
dlcMode=$1
containerversion=$2

currentDir=$(dirname $0)

dlcEnvfile="${currentDir}/${dlcMode}.env"
docker run -d --tmpfs /tmp --tmpfs /run \
  --name dlc-docker-test \
  -p 1514:1514/udp \
  -p 1514:1514/tcp \
  --env-file ${dlcEnvfile} \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  -v ~/dlc-docker/persistent_queue:/store/persistent_queue \
  -v ~/dlc-docker/logSources.json:/opt/ibm/si/services/dlc/conf/logSources.json:z \
  -v ~/dlc-docker/ssl:/etc/dlc/ssl:Z --cap-add=sys_nice docker-dev.secintel.intranet.ibm.com/ibm-si-dlc:${containerversion}