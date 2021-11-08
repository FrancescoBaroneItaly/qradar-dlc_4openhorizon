FROM registry.access.redhat.com/ubi8/ubi:8.3
LABEL maintainer="Marhall Yang <marshall.yang@ibm.com>"
COPY artifactory-centos.repo /etc/yum.repos.d/artifactory-centos.repo
COPY logrun.pl /usr/local/bin/logrun.pl
RUN mkdir -p /usr/local/lib/perl && chmod +x /usr/local/bin/logrun.pl && \
 dnf install -y vim perl tcpdump perl-TimeDate net-tools iputils procps traceroute
COPY Syslog.pm /usr/local/lib/perl/Syslog.pm
CMD "/sbin/init"