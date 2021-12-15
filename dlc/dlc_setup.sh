#! /bin/bash

# Source Dependencies
for _ in /opt/ibm/si/services/dlc/current/script/core-funcs.sh ; do
    source $_ || {
        [[ ${0} != ${BASH_SOURCE} ]] || exit 1
        return 1
    }
done

declare -A __dlc_opts=(
    [dlcMode]="tls"
    [dlcUUID]=""
    [dlcIP]="localhost"
    [dlcPort]="32500"
    [dlcSslMount]="/etc/dlc/ssl"
)
logDir="/var/log/dlc"
dlcConfigDir="/opt/ibm/si/services/dlc/conf"
configJson="${dlcConfigDir}/config.json"
dlcRpm="/root/dlc-service.rpm"

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function Usage() {
    SCRIPT=$(echo $0 | awk -F "/" '{print $NF}')
    __usage="
    Usage: $SCRIPT <options>

    Options:
    -m <DLC Mode>\t\t\DLC Mode to select: would be either tls (default), udp or kafka
    -u <DLC UUID>\t\t\DLC UUID to use
    -i <DLC Destination IP>\t\t\DLC Destination IP to use
    -p <DLC Destination Port>\t\t\DLC Destination Port to use
    -M <DLC SSL Mount>\t\t\DLC SSL mount. This option is mainly using for DLC kafka mode
  "
    echo -e "${__usage}" >&2
}
__cmd_opts=":m:hu:i:p:M:"

while getopts "${__cmd_opts}" opt ; do
    case "$opt" in
        m)
            __dlc_opts[dlcMode]="${OPTARG}"
            echo "__dlc_opts[dlcMode] = '${__dlc_opts[dlcMode]}'"
            ;;
        u)
            __dlc_opts[dlcUUID]="${OPTARG}"
            echo "__dlc_opts[dlcUUID] = '${__dlc_opts[dlcUUID]}'"
            ;;
        i)
            __dlc_opts[dlcIP]="${OPTARG}"
            echo "__dlc_opts[dlcIP] = '${__dlc_opts[dlcIP]}'"
            ;;
        p)
            __dlc_opts[dlcPort]="${OPTARG}"
            echo "__dlc_opts[dlcPort] = '${__dlc_opts[dlcPort]}'"
            ;;
        M)
            __dlc_opts[dlcSslMount]="${OPTARG}"
            echo "__dlc_opts[dlcSslMount] = '${__dlc_opts[dlcSslMount]}'"
            ;;
        h)
            Usage
            exit 0
            ;;
        \?)
            echo "Invalid option -$OPTARG"
            Usage
            exit 255
            ;;
        :)
            echo "Option -$OPTARG requires an argument"
            Usage
            exit 255
    esac
done
InitLog ${logDir}/$(basename ${0} .sh).log || \
    ErrorExit 'Failed to initialize logging'

LogMessage "Starting: ${0} ${@}"

#FB wait config from MMS
RunAndLog /root/dlc_ieam.sh
RunAndLog /root/dlc_ieam_trigger_mms.sh

if [[ -z "${__dlc_opts[dlcMode]}" ]]; then
    ErrorMessage "Please specify the proper dlc mode!"
    Usage
    exit 255
fi

[[ -f "/root/hosts" ]] && cat /root/hosts >> /etc/hosts

RunAndLog cp -pfv ${configJson} /tmp
Run sed -i 's@#.*@@' ${configJson}
tmpConfigFile=$(mktemp)

if [ "${__dlc_opts[dlcMode]}" == "tls" ]; then
    LogMessage "DLC is under the TLS mode"
    RunAndLog /root/dlc_config.sh tls 2>/dev/null
    [[ -z ${__dlc_opts[dlcUUID]} ]] && __dlc_opts[dlcUUID]=$(ls /etc/dlc/instance/ | awk '{print $1}')
    keystoreDir="/opt/ibm/si/services/dlc/keystore/${__dlc_opts[dlcUUID]}"
    [[ -z ${keystoreDir} ]] && ErrorExit "The directory has not been created"
    dlcCsrPath="${keystoreDir}/dlc-client.csr"
    dlcCertPath="${keystoreDir}/dlc-client.crt"
    dlcCN=$(openssl req -in "${dlcCsrPath}" -noout -subject | awk '{print $NF}')
    curl -fk --data-binary @${dlcCsrPath} -o ${dlcCertPath} "https://${DLC_CA_SERVER}:8443/sign?cn=${dlcCN}"
    curl -fk -o /etc/pki/ca-trust/source/anchors/dlc-ca-${__dlc_opts[dlcUUID]}.crt "https://${DLC_CA_SERVER}:8443/ca"
    RunAndLog update-ca-trust
    dlcClientPass=$(/usr/bin/openssl rand -hex 12)
    /root/dlc_config.sh p12 ${dlcCertPath} ${dlcClientPass} 2>/dev/null
    ( cat ${configJson} | jq '.Destination."destination.type"="TLS"' |\
      jq ".Destination.\"destination.ip\"=\"${__dlc_opts[dlcIP]}\"" |\
      jq ".Destination.\"destination.port\"=\"${__dlc_opts[dlcPort]}\"" ) > ${tmpConfigFile}
    RunAndLog cp -fvp ${tmpConfigFile} ${configJson}
    LogMessage "Generate server certificate and trust store for ${__dlc_opts[dlcIP]}"
    RunAndLog openssl req -new -newkey rsa:4096 -keyout ${__dlc_opts[dlcSslMount]}/dlc-server.key -nodes -out ${__dlc_opts[dlcSslMount]}/dlc-server.csr -subj "/"
    if valid_ip ${__dlc_opts[dlcIP]}; then
      curl -fk --data-binary @${__dlc_opts[dlcSslMount]}/dlc-server.csr -o ${__dlc_opts[dlcSslMount]}/dlc-server.crt "https://${DLC_CA_SERVER}:8443/sign?cn=${__dlc_opts[dlcIP]}&ip=${__dlc_opts[dlcIP]}"
    else
      curl -fk --data-binary @${__dlc_opts[dlcSslMount]}/dlc-server.csr -o ${__dlc_opts[dlcSslMount]}/dlc-server.crt "https://${DLC_CA_SERVER}:8443/sign?cn=${__dlc_opts[dlcIP]}&ns=${__dlc_opts[dlcIP]}"
    fi
    RunAndLog cp -fv /etc/pki/ca-trust/source/anchors/dlc-ca-${__dlc_opts[dlcUUID]}.crt ${__dlc_opts[dlcSslMount]}/
    dlcServerPass=$(/usr/bin/openssl rand -hex 12)
    /root/dlc_config.sh server ${__dlc_opts[dlcSslMount]} ${dlcServerPass} ${__dlc_opts[dlcUUID]} 2>/dev/null
    RunAndLog rm -f ${__dlc_opts[dlcSslMount]}/dlc-server.csr ${__dlc_opts[dlcSslMount]}/dlc-server.key ${__dlc_opts[dlcSslMount]}/dlc-server.crt
    cat > ${__dlc_opts[dlcSslMount]}/dlc-server-${__dlc_opts[dlcUUID]}.txt <<- END
Please follow below steps to setup the DLC on the QRadar Side:
1. Copy <local dlc mount directory>/ssl/dlc-server-${__dlc_opts[dlcUUID]}.pfx to /opt/qradar/conf/key_stores/
2. Copy <local dlc mount directory>/ssl/dlc-ca-${__dlc_opts[dlcUUID]}.crt to /etc/pki/ca-trust/source/anchors/
3. Run command: update-ca-trust
4. Input below information when configuration IBM QRadar DLC protocol
Key Store File Name: dlc-server-${__dlc_opts[dlcUUID]}.pfx
Key Store Password: ${dlcServerPass}
CN/Alias Whitelist: ${__dlc_opts[dlcUUID]}
Check Revocation: No
Trust Store Password: changeit
END
elif [ "${__dlc_opts[dlcMode]}" == "udp" ]; then
    LogMessage "DLC is under the UDP mode"
    ( cat ${configJson} | jq '.Destination."destination.type"="UDP"' |\
      jq ".Destination.\"destination.ip\"=\"${__dlc_opts[dlcIP]}\"" |\
      jq ".Destination.\"destination.port\"=\"${__dlc_opts[dlcPort]}\"" ) > ${tmpConfigFile}
    RunAndLog cp -fvp ${tmpConfigFile} ${configJson}
elif [ "${__dlc_opts[dlcMode]}" == "kafka" ]; then
    LogMessage "DLC is under the KAFKA mode"
    if [ -d "${__dlc_opts[dlcSslMount]}" ] && [ ! -z "$(ls -A ${__dlc_opts[dlcSslMount]})" ]; then
      cp -fvp ${__dlc_opts[dlcSslMount]}/* ${dlcConfigDir}
    fi
    topicName=$(yq eval '.topic.[0].name' ${dlcConfigDir}/cp4s_kafka_topics.yaml)
    ( cat ${configJson} | jq '.Destination."destination.type"="KAFKA"' |\
     jq ".TOPIC=\"${topicName}\"" ) > ${tmpConfigFile}
    RunAndLog cp -fvp ${tmpConfigFile} ${configJson}
    RunAndLog /root/dlc_config.sh kafka 2>/dev/null
fi
LogMessage "DLC has finished configuration for ${__dlc_opts[dlcMode]}. Performing final cleanup"
[[ -f "${tmpConfigFile}" ]] && RunAndLog rm -fv ${tmpConfigFile}
[[ -f "/root/logSources.json" ]] && RunAndLog cp -fv /root/logSources.json ${dlcConfigDir}/
Run chmod 640 ${configJson}
Run chown -R root:dlc ${dlcConfigDir}
Run chown -R dlc:dlc /store/persistent_queue
