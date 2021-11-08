### DLC Docker ###

This project is used for containerize disconnect log collector

#### Pre-requisition

Before either build or run DLC container, please ensure both **docker** and **docker-compose** will be installed on the local system

#### Build DLC ####

To build the container, the script build-docker-dlc.sh needs to be used. The build-docker-dlc.sh can be trigged with below command line argument
```shell
    Usage: build-docker-dlc.sh <options>

    Options:
    -h          Display help menu
    -d          Use dev version from artifactory
    -l          Tag the build with latest tag
    -b <Build Directory>        Build directory that contains the Dockerfile
    -r <DLC Rpm file>           DLC rpm file. If empty, download the artifact based on DLC_TAG from .env file
    -D <DLC Version>            DLC version for DLC container tag. If empty, use the DLC_TAG from .env file
    -R <DLC Release>            DLC Release to use. Default is 1
    -L <Log Run Version>        Logrun version for logrun container tag. If empty, use the LOGRUN_TAG from .env file
    -u <Artifactory user>       Artifactory user passed from the command line. If empty, using artifactory user configuration from gradle.properties
    -a <Artifactory API Key>    Artifactory API key passed from the command line. using artifactory api key configuration from gradle.properties
    -r <Docker repo>            Docker Repository to push
```

The build directory for this project could be either dlc or logrun. The dlc build directory is used to build DLC container, while the logrun directory is used to build the logrun container, which is using for sending logs through logrun script

User don't need to specify their artifactory user and artifactory API key to the build script, if they have their artifactory user, artifactory api key and artifactory context URL in their ~/.gradle/gradle.properties, like listed below (the property name should be exactly same as the list below). The argument for artifactory related is mainly used for CI/CD integration

```shell
artifactory_user=xxx.xxx@ibm.com
artifactory_contextUrl=https://q1artifactory-dev.secintel.intranet.ibm.com
artifactory_apikey=xxxxx
```

Similarly, the version information can be passed in as well, which is from either DLC_TAG or LOGRUN_TAG in the .env file. Those tags can be overwritten with the command line parameters passed over through -D or -L depends on buiding DLC and LOGRUN

If user has already had the artifactory information in their gradle.properties file and have version specified in the .env file mentioned above, they could start build the container with below commands

- Build a DLC container from development build

  ```shell
  ./build-docker-dlc.sh -b dlc -d
  ```

- Build a DLC container from release build

  ```shell
  ./build-docker-dlc.sh -b dlc
  ```

- Build a DLC container from development build and tag with latest tag

  ```shell
  ./build-docker-dlc.sh -b dlc -l -d
  ```

- Build a DLC container from release build with a specific version like 1.5.0

  ```shell
  ./build-docker-dlc.sh -b dlc -D 1.5.0
  ```

- Build a Logrun container

  ```shell
  ./build-docker-dlc.sh -b logrun
  ```

If we only need to build the container for DLC instead of the build base, the below command could be used:

```shell
docker build . -t docker-dev.secintel.intranet.ibm.com/ibm-si-dlc:0.0.1 --build-arg DLC_MODE=<dlc mode, either udp, tls or kafka> --target dlc-docker-prod
```

The following dlc and logrun container has already in internal secintel artifactory, which is listed below

- docker-dev.secintel.intranet.ibm.com/ibm-si-dlc:latest
- docker-dev.secintel.intranet.ibm.com/ibm-si-dlc:1.6.0.dev.223911
- docker-dev.secintel.intranet.ibm.com/ibm-si-dlc:1.5.0
- docker-dev.secintel.intranet.ibm.com/ibm-si-logrun:1.0.0

#### Environment File Explained

Before run the docker compose command, please copy all the environment file from example directory to the root directory of the dlc-docker project. For example, assume user is on the root directory of the project, they could copy the tls environment variable using command below:

```shell
cp -f example/tls.env tls.env
```

The environment file for Kafka mode is pretty straightforward and doesn't need any customization. However, for TLS and UDP destination mode, some customization needs to be made based on where users would like to send the events to and how they would like to configure their certicates. Below are the detailed explain on both files

- tls.env

  ```shell
  DLC_DESTINATION_MODE=tls
  DLC_DESTINATION_IP=localhost -> This is used to configure the destination IP, which is the IP of qradar Console/EP/EC that planning to receive the events from DLC
  DLC_DESTINATION_PORT=32500 -> Desitnation port that configured in the IBM DLC protocol
  DLC_CA_SERVER=simple-ca -> This is fixed and DO NOT customize. It is the CA server name for simple-ca container used inside docker-compose
  DLC_CERT_COUNTRY=TestCountry -> Country for DLC CSR
  DLC_CERT_PROVINCE=TestProvince -> Province for DLC CSR
  DLC_CERT_CITY=TestCity -> City for DLC CSR
  DLC_CERT_ORG=TestOrg -> Organization for DLC CSR
  DLC_CERT_UNIT=TestOrgUnit -> Organization Unit for DLC CSR
  ```

- udp.env

  ```shell
  DLC_DESTINATION_MODE=udp
  DLC_DESTINATION_IP=localhost -> This is used to configure the destination IP, which is the IP of qradar Console/EP/EC that planning to receive the events from DLC
  DLC_DESTINATION_PORT=32500 -> Desitnation port that configured in the IBM DLC protocol
  ```

  

#### Run DLC container ####

Once user get all the container built and get environment file created properly, user could setup all the required local directory layout based on the each mapping yaml file for docker-compose that will be used here, which can be docker-compose-udp,yaml, docker-compose-tls.yaml or docker-compose-kafka.yaml. For each yaml file, there will be a local directory required to hold the configuration file like logSources.json, persistent queue and ssl information. So the below is a list of local directory that created for various testing

```shell
➜  ~ ls -la ~/dlc-docker
total 16
drwxr-xr-x   6 marshall.yang  staff   192  7 May 22:42 .
drwxr-xr-x+ 90 marshall.yang  staff  2880 10 May 06:01 ..
drwxr-xr-x@  3 marshall.yang  staff    96  4 May 13:00 persistent_queue
drwxr-xr-x   8 marshall.yang  staff   256  7 May 23:54 ssl
```

For the logrun container used inside the docker-compose as well, alonged with the DLC container, a local directory is needed as well to hold any sample syslog file that can be used for testing. The root directory of the local DLC directory and local logrun directory can be configured under .env file through LOCAL_DLC_MOUNT_DIR and LOCAL_LOGRUN_MOUNT_DIR, respectively

Once all the prep work finished, the container can be started based on the command below:

- Starting up the DLC container in Kafka mode, to test sending syslog to CP4S vis Kafka

  Before running docker-compose command to start the container, the user needs to use below project to generate kafka related information

  https://gitlab.secintel.intranet.ibm.com/osprey/irony/kafka-deploy

  Once finished the step 5 or step 6 from the instruction of that project (From README.md on the kafka-deploy project), user could copy all the content other than config.json from either ssl-output or sasl-output to <LOCAL_DLC_MOUNT_DIR>/ssl directory and then start up the container using command:

  ```shell
  docker-compose -f docker-compose-kafka.yaml up -d
  ```

  To test the kafka connection, user could either start up the test harness inside the DLC container or send the events from logrun container. User could then further verify if message has been received properly either using kafkacat or kafka-console-consumer utility

- Starting up the DLC container in TLS mode, to test sending syslog to QRadar vis TLS

  ```shell
  docker-compose -f docker-compose-tls.yaml up -d
  ```

  Note all the TLS connection information including certificate and further log source information will be sent over to dlc-server-<DLC UUID>.txt. The content inside the text file including all the further instructions on how to setup the DLC certificate and log sources on the QRadar side

  In a more detailed context, the docker-compose will hold up a simple-ca container, which is a CA container that can be sign certificate. The certificate signing request for DLC client (on dlc side) and the DLC server key store will be both created from the dlc_setup.sh script and dlc_config.sh script. The information used by the CSR can be configured in the tls.env file with all the environment variable started with DLC_CERT.

  Once all the certificate has been generated, the server keystore file will be output to the directory that has been mounted from a local container, so it has the local access. The password along with the keystore (The password has been generated randomly from openssl) will be output to the text file mentioned above that can be used for further configuring the DLC log sources.

  User could then use log run to send events from log run container and user will receive those events in QRadar through IBM DLC Protocol with specific uuid attached.

- Start up the DLC container in UDP mode, to test sending syslog to QRadar via UDP. 

  ```shell
  docker-compose -f docker-compose-udp.yaml up -d
  ```

  This command is straight forward, user just need to configure a log source with IBM DLC protocol and using UDP as destination mode, then use log run to send events from log run container. The user could receive those events from QRadar as a regular syslog

  

#### Debug DLC Container ####

If user would like to just explore how the DLC container works (like debugging the entry script for DLC container), the below command can be used to stand up a DLC container without the context of docker-compose. User then get into the container and start to explore different DLC configuration settings and so on.

```shell
./run-docker-dlc.sh <dlc mode, can be udp, tls or kafka> <dlc container tag>
```



### Development Note ###

In the development environment, the kafka bootstrap server is not public routable as the DNS couldn't discover the bootstrap server. Please ensure the bootstrap server to be added to the /etc/hosts of you DLC container. To simplify the process, please ensure the hosts file under the local directory (~/dlc-docker in above example) to have the line that contains the bootstrap server. The example of <local directory>/hosts file can be seen below

```bash
x.x.x.x	api.crc.testing oauth-openshift.apps-crc.testing console-openshift-console.apps-crc.testing osprey-cluster-kafka-bootstrap-cp4s.apps-crc.testing osprey-cluster-kafka-0-cp4s.apps-crc.testing
```

The x.x.x.x above is the IP address of either the CRC VM IP or Fyre cluster IP for infrastructure node.

