#!/bin/bash

SCRIPT_DIR=$(dirname $0)

function create_ips_string()
{
   IPS=
   [ ! -e "$1" ] &&  return
   while read ip
   do
      ip=$(echo $ip | sed 's/[[:space:]]//g') 
      [ -n "$ip" ] && IPS="${IPS}${ip}\;"
   done < $1
}

#------------------------------------------
# Need root or sudo
#
SUDOCMD=
[ $(id -u) -ne 0 ] && SUDOCMD=sudo


#------------------------------------------
# LOG
#
LOG_FILE=/tmp/config_hpcc.log
touch ${LOG_FILE}
exec 2>$LOG_FILE
set -x


#------------------------------------------
# Start sshd
#
ps -efa | grep -v sshd |  grep -q sshd
[ $? -ne 0 ] && $SUDOCMD mkdir -p /var/run/sshd; $SUDOCMD  /usr/sbin/sshd -D &

#------------------------------------------
# Collect conainters' ips
#

if [ -z "$1" ] || [ "$1" != "-x" ]
then
   trials=3
    while [ $trials -gt 0 ]
    do
       ${SCRIPT_DIR}/get_ips.sh
       ${SCRIPT_DIR}/get_ips.py
       [ $? -eq 0 ] && break  
       trials=$(expr $trials \- 1)
       sleep 5
    done
fi

#------------------------------------------
# Setup Ansible hosts
#
${SCRIPT_DIR}/ansible/setup.sh -d /tmp/ips

thor_ips=/etc/ansible/ips/thor
roxie_ips=/etc/ansible/ips/roxie
esp_ips=/etc/ansible/ips/esp
dali_ip=/etc/ansible/ips/dali

#------------------------------------------
# Restore HPCC configuration files /etc/HPCCSystems
# which is NFS share
#
if [ ! -e /etc/HPCCSystems/environment.conf ]; then
   cp -r /etc/HPCCSystems.kb/* /etc/HPCCSystems/ 
   chown -R hpcc:hpcc /etc/HPCCSystems/
fi


#------------------------------------------
# Parameters to envgen
#
HPCC_HOME=/opt/HPCCSystems
CONFIG_DIR=/etc/HPCCSystems
ENV_XML_FILE=environment.xml


[ -e ${thor_ips} ] && thor_nodes=$(cat ${thor_ips} | wc -l)
[ -e ${roxie_ips} ] && roxie_nodes=$(cat ${roxie_ips} | wc -l)
[ -e ${esp_ips} ] && esp_nodes=$(cat ${esp_ips} | wc -l)
support_nodes=1
slaves_per_node=1
[ -n "$SLAVES_PER_NODE" ] && slaves_per_node=${SLAVES_PER_NODE}
[ -z "$thor_nodes" ] && thor_nodes=0
[ -z "$roxie_nodes" ] && roxie_nodes=0
[ -z "$esp_nodes" ] && esp_nodes=0


cmd="$SUDOCMD ${HPCC_HOME}/sbin/envgen -env ${CONFIG_DIR}/${ENV_XML_FILE}   \
-override roxie,@roxieMulticastEnabled,false -override thor,@replicateOutputs,true \
-override esp,@method,htpasswd -override thor,@replicateAsync,true                  \
-thornodes ${thor_nodes} -slavesPerNode ${slaves_per_node} -espnodes ${esp_nodes}       \
-roxienodes ${roxie_nodes} -supportnodes ${support_nodes} -roxieondemand 1" 

HPCC_VERSION=$(${HPCC_HOME}/bin/eclcc --version | cut -d' ' -f1)
HPCC_MAJOR=${HPCC_VERSION%%.*}
dali_ip=$(cat ${dali_ip})
if [ $HPCC_MAJOR -gt 5 ]
then
    cmd="$cmd -ip $dali_ip" 
    if [ $thor_nodes -gt 0 ]
    then
       create_ips_string ${thor_ips}
       cmd="$cmd -assign_ips thor ${dali_ip}\;${IPS}"
    fi

    if [ $roxie_nodes -gt 0 ]
    then
       create_ips_string ${roxie_ips}
       cmd="$cmd -assign_ips roxie $IPS"
    fi

    if [ $esp_nodes -gt 0 ]
    then
       create_ips_string ${esp_ips}
       cmd="$cmd -assign_ips esp $IPS"
    fi
else
    echo "Must HPCC 6.0.4 and later"
    return 1
fi

#------------------------------------------
# Generate environment.xml
#
echo "$cmd" 
eval "$cmd"

#------------------------------------------
# Transfer environment.xml to cluster 
# containers
#
#$SUDOCMD   su - hpcc -c "/opt/HPCCSystems/sbin/hpcc-push.sh \
#-s /etc/HPCCSystems/environment.xml -t /etc/HPCCSystems/environment.xml -x"

#------------------------------------------
# Start hpcc 
#
# Need force to use sudo for now since $USER is not defined:
# Should fix it in Platform code to use id instead of $USER
# Need stop first since if add contaners other thor and roxie containers are already up.
# Force them to read environemnt.xml by stop and start
#$SUDOCMD su - hpcc -c  "${HPCC_HOME}/sbin/hpcc-run.sh stop"
#$SUDOCMD su - hpcc -c  "${HPCC_HOME}/sbin/hpcc-run.sh start"



set +x
$SUDOCMD /opt/HPCCSystems/sbin/configgen -env /etc/HPCCSystems/environment.xml -listall2
echo "HPCC cluster configuration is done."
