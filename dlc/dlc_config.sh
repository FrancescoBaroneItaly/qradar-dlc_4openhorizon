#!/usr/bin/expect -f

set mode [lindex $argv 0]
set certpath [lindex $argv 1]
set certpass [lindex $argv 2]
set dlcuuid [lindex $argv 3]
set timeout -1

if { $mode == "kafka"} {
  spawn /opt/ibm/si/services/dlc/current/script/configure_CP4S.sh
  expect "Please enter your choice:" {send "$env(DLC_CONFIGOPTION)\n"}
  expect eof
} elseif { $mode == "tls" } {
  spawn /opt/ibm/si/services/dlc/current/script/generateCertificate.sh -csr -4k
  expect "Enter 2-letter Country Code:" {send "$env(DLC_CERT_COUNTRY)\n"}
  expect "Enter State or Province Name:" {send "$env(DLC_CERT_PROVINCE)\n"}
  expect "Enter City Name:" {send "$env(DLC_CERT_CITY)\n"}
  expect "Enter Organization Name:" {send "$env(DLC_CERT_ORG)\n"}
  expect "Enter Organization Unit Name:" {send "$env(DLC_CERT_UNIT)\n"}
  expect eof
} elseif { $mode == "p12" } {
  spawn /opt/ibm/si/services/dlc/current/script/generateCertificate.sh -p12 $certpath
  expect "Enter Export Password:" {send "$certpass\n"}
  expect "Verifying - Enter Export Password:" {send "$certpass\n"}
  expect eof
} elseif { $mode == "server" } {
  spawn openssl pkcs12 -export -out ${certpath}/dlc-server-${dlcuuid}.pfx -inkey ${certpath}/dlc-server.key -in ${certpath}/dlc-server.crt
  expect "Enter Export Password:" {send "$certpass\n"}
  expect "Verifying - Enter Export Password:" {send "$certpass\n"}
  expect eof
}