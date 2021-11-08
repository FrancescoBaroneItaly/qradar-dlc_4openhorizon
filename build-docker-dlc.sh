#! /bin/bash
source $(dirname $0)/.env
GRADLE_PROPERTIES="$HOME/.gradle/gradle.properties"
ret_code=0

buildDir="dlc"
rpmFile=""
dlcVersion=""
dlcRelease=1
logrunVersion=""
artifactoryUser=""
artifactoryApi=""
dockerRepo="docker-dev.secintel.intranet.ibm.com"

function Usage() {
    SCRIPT=$(echo $0 | awk -F "/" '{print $NF}')
    __usage="
    Usage: $SCRIPT <options>

    Options:
    -h \t\tDisplay help menu
    -d \t\tUse dev version from artifactory
    -l \t\tTag the build with latest tag
    -b <Build Directory>\t\tBuild directory that contains the Dockerfile
    -r <DLC Rpm file>\t\tDLC rpm file. If empty, download the artifact based on DLC_TAG from .env file
    -D <DLC Version>\t\tDLC version for DLC container tag. If empty, use the DLC_TAG from .env file
    -R <DLC Release>\t\tDLC Release to use. Default is 1
    -L <Log Run Version>\t\tLogrun version for logrun container tag. If empty, use the LOGRUN_TAG from .env file
    -u <Artifactory user>\t\tArtifactory user passed from the command line. If empty, using artifactory user configuration from gradle.properties
    -a <Artifactory API Key>\t\tArtifactory API key passed from the command line. using artifactory api key configuration from gradle.properties
    -r <Docker repo>\t\tDocker Repository to push
  "
    echo -e "${__usage}" >&2
}
__cmd_opts=":b:r:D:L:u:a:R:hdr:l"

while getopts "${__cmd_opts}" opt ; do
    case "$opt" in
        b)
            buildDir="${OPTARG}"
            echo "buildDir = '${buildDir}'"
            ;;
        r)
            rpmFile="${OPTARG}"
            echo "rpmFile = '${rpmFile}'"
            ;;
        D)
            dlcVersion="${OPTARG}"
            echo "dlcVersion = '${dlcVersion}'"
            ;;
        R)
            dlcRelease="${OPTARG}"
            echo "dlcRelease = '${dlcRelease}'"
            ;;
        L)
            logrunVersion="${OPTARG}"
            echo "logrunVersion = '${logrunVersion}'"
            ;;
        u)
            artifactoryUser="${OPTARG}"
            echo "artifactoryUser = '${artifactoryUser}'"
            ;;
        a)
            artifactoryApi="${OPTARG}"
            echo "artifactoryApi = '${artifactoryApi}'"
            ;;
        r)
            dockerRepo="${OPTARG}"
            echo "dockerRepo = '${dockerRepo}'"
            ;;
        d)
            isDev="dev/"
            ;;
        l)
            isLatest="true"
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

if [ "${buildDir}" == "dlc" ]; then
  [[ -z "${dlcVersion}" ]] && dlcVersion=${DLC_TAG}
  if [ -z "${rpmFile}" ]; then
    # 1. Set artifactory user and apikey using environment variable
    [[ -z "${artifactoryUser}" ]] && artifactoryUser=${ARTIFACTORY_USER}
    [[ -z "${artifactoryApi}" ]] && artifactoryApi=${ARTIFACTORY_APIKEY}
    # 2. Set artifactory user and apikey from gradle.properties file in $HOME/.gradle directory
    [[ -z "${artifactoryUser}" ]] && artifactoryUser=$(grep "^artifactory_user=" ${GRADLE_PROPERTIES} | cut -d'=' -f2)
    [[ -z "${artifactoryApi}" ]] && artifactoryApi=$(grep "^artifactory_apikey=" ${GRADLE_PROPERTIES} | cut -d'=' -f2)
    artifactoryContextUrl=$(grep "^artifactory_contextUrl=" ${GRADLE_PROPERTIES} | cut -d'=' -f2)
    if [ -z "${artifactoryUser}" ] || [ -z "${artifactoryApi}" ] || [ -z "${artifactoryContextUrl}" ]; then
      echo "Artifactory configuration is not set up properly with user: ${artifactoryUser} and apikey ${artifactoryApi} and context url ${artifactoryContextUrl}"
      ret_code=1
    fi
    mkdir -p $(dirname $0)/dlc/build
    curl -u ${artifactoryUser}:${artifactoryApi} ${artifactoryContextUrl}/all-snapshot-local/${isDev}com/ibm/si/dlc/dlc-service/${dlcVersion}/dlc-service-${dlcVersion}-${dlcRelease}.noarch.rpm -o "$(dirname $0)/dlc/build/dlc-service.rpm"
    rc=$?
    if [ $rc -ne 0 ]; then
      ret_code=$rc
    fi
    if [ ! -z $retcode ] && [ $retcode -ne 0 ]; then
      exit ret_code
    fi
    rpmFile="build/dlc-service.rpm"
  fi
  # Disable using build kit
  DOCKER_BUILDKIT=0 docker build $(dirname $0)/dlc -t ${dockerRepo}/ibm-si-dlc:${dlcVersion} --build-arg DLC_RPM_FILE=${rpmFile}
  if [ ! -z ${isLatest} ]; then
    docker tag ${dockerRepo}/ibm-si-dlc:${dlcVersion} ${dockerRepo}/ibm-si-dlc:latest
  fi
elif [ "${buildDir}" == "logrun" ]; then
  [[ -z "${logrunVersion}" ]] && logrunVersion=${LOGRUN_TAG}
  DOCKER_BUILDKIT=0 docker build $(dirname $0)/logrun -t ${dockerRepo}/ibm-si-logrun:${logrunVersion}
  if [ ! -z ${isLatest} ]; then
    docker tag ${dockerRepo}/ibm-si-logrun:${logrunVersion} ${dockerRepo}/ibm-si-logrun:latest
  fi
fi
exit 0