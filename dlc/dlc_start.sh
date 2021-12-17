#!/bin/bash

DEBUG=1

if [[ $DEBUG == 1 ]]; then echo "DEBUG: LAUCH MMS SCRIPTS"; fi
nohup /root/dlc_ieam.sh &
nohup /root/dlc_ieam_trigger_mms.sh &


INSTANCE="/dlcInstance/instance.json"

if [[ $DEBUG == 1 ]]; then echo "DEBUG: CHECK ${INSTANCE}"; fi
if [ -e ${INSTANCE} ]; then

    if [[ $DEBUG == 1 ]]; then echo "DEBUG: INSTANCE CONFIGURED"; fi

    UUID=$(cat $INSTANCE | jq -r ".uuid")
    DLC_DESTINATION_MODE=udp
    DLC_DESTINATION_IP=$(cat $INSTANCE | jq -r ".endpoint_udp")
    DLC_DESTINATION_PORT=$(cat $INSTANCE | jq -r ".port_udp")

    if [[ $UUID != null && $DLC_DESTINATION_IP != null && $DLC_DESTINATION_PORT != null ]]; then

    	if [[ $DEBUG == 1 ]]; then echo "DEBUG: SET UUID=${UUID}"; fi

        rm -f /etc/dlc/instance/*
        touch /etc/dlc/instance/${UUID}
    	
	if [[ $DEBUG == 1 ]]; then echo "DEBUG: Set ENDPOINT=${DLC_DESTINATION_IP}:${DLC_DESTINATION_PORT} MODE ${DLC_DESTINATION_MODE}"; fi
     	/root/dlc_setup.sh -m ${DLC_DESTINATION_MODE} -i ${DLC_DESTINATION_IP} -p ${DLC_DESTINATION_PORT}
    fi

fi

if [[ $DEBUG == 1 ]]; then echo "DEBUG: REWORK GENERATE_ENV "; fi
sed -i '/USER=$(systemctl -p User show ${APP_ID} | cut -d= -f2)/c\USER=dlc' /opt/ibm/si/services/dlc/current/systemd/bin/generate_environment.sh

export SERVICENAME=dlc
export SERVICEPATH=/opt/ibm/si/services/dlc
export PROTOCOLPATH=/opt/ibm/si/services/dlc/eventgnosis/lib/q1labs
export SERVICEMAINCLASS=com.ibm.si.service.dlc.ServiceRunner

if [[ $DEBUG == 1 ]]; then echo "DEBUG: GENERATE ENVIRONMENT "; fi
. /opt/ibm/si/services/dlc/current/systemd/bin/generate_environment.sh ${SERVICENAME} ${SERVICEPATH}
. /store/dlc/dlc.env

#while true
#do
#	echo "DLC"
#	sleep 10
#done
if [[ $DEBUG == 1 ]]; then echo "DEBUG: LAUNCH DLC JAVA PROCESS "; fi

/usr/bin/env ${JAVAHOME}/bin/java \
$JOPTS_MS \
$GC_OPTS \
$RMI_GC_OPTS \
$CLASSLOADER_UNLOADING \
$GC_THREADS \
$MEM_OPTS \
$DUMPOPTS \
$REMOTE_DEBUG_OPTS \
-Dcom.q1labs.frameworks.jmx.port=${JMXPORT} \
-cp ${SERVICEPATH}/current/bin/*:${SERVICEPATH}/current/lib/*:${PROTOCOLPATH}/* \
${SERVICEMAINCLASS} \
${SERVICEPATH}/current/ \
${SERVICEPATH}/current/eventgnosis \
ecs-dlc.ecs \
220 \
noconsole


exit 0
