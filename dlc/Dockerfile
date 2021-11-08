FROM registry.access.redhat.com/ubi8/ubi:8.3 AS dlc-docker-base
ENV JAVA_VERSION=8.0-5.27 JAVA_SHORT_VER=80
ENV JAVA_HOME=/opt/ibm/java-x86_64-${JAVA_SHORT_VER}
ENV PATH=${PATH}:${JAVA_HOME}/bin
ARG YQ_VERSION=v4.7.0
ARG YQ_BINARY=yq_linux_amd64
ARG DLC_RPM_FILE=dlc-service.rpm
ARG JAVA_IBM_BIN_FILE=ibm-java-x86_64-sdk-8.0-6.36.bin
COPY ${JAVA_IBM_BIN_FILE} /tmp/ibm-java-x86_64-sdk-8.0-6.36.bin
COPY java_response.file /tmp/java_response.file
RUN chmod +x /tmp/ibm-java-x86_64-sdk-8.0-6.36.bin && \
	/tmp/ibm-java-x86_64-sdk-8.0-6.36.bin -f /tmp/java_response.file -i silent

LABEL maintainer="Marhall Yang <marshall.yang@ibm.com>"

RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in ; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done);

RUN rm -rf /lib/systemd/system/multi-user.target.wants/ \
    && rm -rf /etc/systemd/system/.wants/ \
    && rm -rf /lib/systemd/system/local-fs.target.wants/ \
    && rm -f /lib/systemd/system/sockets.target.wants/udev \
    && rm -f /lib/systemd/system/sockets.target.wants/initctl \
    && rm -rf /lib/systemd/system/basic.target.wants/ \
    && rm -f /lib/systemd/system/anaconda.target.wants/*
RUN yum install -y procps
COPY artifactory-centos.repo /etc/yum.repos.d/artifactory-centos.repo
#RUN dnf install -y ibm-java-x86_64-sdk-${JAVA_VERSION}.x86_64 jq wget expect openssl
RUN dnf install -y jq wget expect openssl
RUN echo -e "export JAVA_HOME=${JAVA_HOME}\nPATH=\$PATH:${JAVA_HOME}/bin" > /etc/profile.d/java.sh
RUN ln -f /etc/pki/java/cacerts ${JAVA_HOME}/jre/lib/security/cacerts
COPY ${DLC_RPM_FILE} /tmp/dlc-service.rpm
#RUN wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}.tar.gz -O - |\
#      tar xz && mv ${YQ_BINARY} /usr/bin/yq && chmod +x /usr/bin/yq
COPY yq_linux_amd64 /usr/bin/yq 
RUN chmod +x /usr/bin/yq
RUN dnf install -y /tmp/dlc-service.rpm && \
    rm -f /etc/yum.repos.d/artifactory-centos.repo && \
    rm -f /tmp/dlc-service.rpm && \
    dnf clean all

FROM dlc-docker-base AS dlc-docker-prod
ARG DLC_MODE=udp
ARG DLC_DEST_IP=192.168.64.28
ARG DLC_DEST_PORT=32500
ENV DLC_DESTINATION_MODE=${DLC_MODE} DLC_DESTINATION_IP=${DLC_DEST_IP} DLC_DESTINATION_PORT=${DLC_DEST_PORT} DLC_CONFIGOPTION=1 DLC_CA_SERVER=simple-ca
COPY dlc_setup.sh /root/dlc_setup.sh
COPY dlc_config.sh /root/dlc_config.sh
COPY logSources.json /root/logSources.json
EXPOSE 1514/tcp
EXPOSE 1514/udp
VOLUME /store/persistent_queue
RUN chmod +x /root/dlc_setup.sh /root/dlc_config.sh
CMD /root/dlc_setup.sh -m ${DLC_DESTINATION_MODE} -i ${DLC_DESTINATION_IP} -p ${DLC_DESTINATION_PORT} && "/sbin/init"