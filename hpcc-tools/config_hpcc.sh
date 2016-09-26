#!/bin/bash

SCRIPT_DIR=$(dirname $0)

function usage()
{
    cat <<EOF 
    Usage: $(basename $0) <options>
      <options>:
      -u: update mode. It will only re-create dali/thor master environment.xml 
          and environment.xml with real ip. Re-generate ansible host file,
          run updtdalienv and restart thor master.

EOF
   exit 1
}

function create_ips_string()
{
   IPS=
   [ ! -e "$1" ] &&  return
   while read ip
   do
      ip=$(echo $ip | sed 's/[[:space:]]//g') 
      [ -n "$ip" ] && IPS="${IPS}${ip}\\;"
   done < $1
}

function create_envxml()
{
   [ -e ${roxie_ips} ] && roxie_nodes=$(cat ${roxie_ips} | wc -l)
   [ -e ${esp_ips} ] && esp_nodes=$(cat ${esp_ips} | wc -l)
   [ -z "$roxie_nodes" ] && roxie_nodes=0
   [ -z "$esp_nodes" ] && esp_nodes=0

   cmd="$SUDOCMD ${HPCC_HOME}/sbin/envgen -env ${CONFIG_DIR}/${ENV_XML_FILE}   \
       -override roxie,@copyResources,true \
       -override roxie,@roxieMulticastEnabled,false \
       -override thor,@replicateOutputs,true \
       -override esp,@method,htpasswd \
       -override thor,@replicateAsync,true                 \
       -thornodes ${thor_nodes} -slavesPerNode ${slaves_per_node} \
       -espnodes ${esp_nodes} -roxienodes ${roxie_nodes} \
       -supportnodes ${support_nodes} -roxieondemand 1" 

    if [ -n "$1" ]
    then
       #dafilesrv
       cmd="$cmd -assign_ips $1 ." 
    fi

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

    echo "$cmd" 
    eval "$cmd"

}

function collect_ips()
{
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
}

function setup_ansible_hosts()
{
  ${SCRIPT_DIR}/ansible/setup.sh -d /tmp/ips -c /tmp/hpcc.conf
  export ANSIBLE_HOST_KEY_CHECKING=False
}

function restore_hpcc_config()
{
  if [ ! -e /etc/HPCCSystems/environment.conf ]; then
    cp -r /etc/HPCCSystems.bk/* /etc/HPCCSystems/ 
    chown -R hpcc:hpcc /etc/HPCCSystems/
  fi

  if [ $NUM_ROXIE_LB -gt 0 ]; then 
    for i in $(seq 1 ${NUM_ROXIE_LB}) 
    do
      if [ ! -e /etc/HPCCSystems/roxie/${i}/environment.conf ]; then
        cp -r /etc/HPCCSystems.bk/* /etc/HPCCSystems/roxie/${i}/ 
        chown -R hpcc:hpcc /etc/HPCCSystems/roxie/${i}
      fi
    done
  fi

  if [ ! -e /etc/HPCCSystems/esp/environment.conf ]; then
    cp -r /etc/HPCCSystems.bk/* /etc/HPCCSystems/esp/ 
    chown -R hpcc:hpcc /etc/HPCCSystems/esp
  fi

  if [  -d /etc/HPCCSystems/thor ] && [ ! -e /etc/HPCCSystems/thor/environment.conf ]; then
    cp -r /etc/HPCCSystems.bk/* /etc/HPCCSystems/thor/ 
    chown -R hpcc:hpcc /etc/HPCCSystems/thor
  fi
}

function set_hpcc_data_owner()
{
  ansible-playbook /opt/hpcc-tools/ansible/set_hpcc_owner.yaml --extra-vars "hosts=roxie"
}

function stop_hpcc()
{
  ansible-playbook /opt/hpcc-tools/ansible/stop_hpcc.yaml --extra-vars "hosts=non-dali" 
  ansible-playbook /opt/hpcc-tools/ansible/stop_hpcc.yaml --extra-vars "hosts=dali" 
}

function start_hpcc()
{
  ansible-playbook /opt/hpcc-tools/ansible/start_hpcc.yaml --extra-vars "hosts=dali" 
  ansible-playbook /opt/hpcc-tools/ansible/start_hpcc.yaml --extra-vars "hosts=non-dali" 
}

function get_lb_ips()
{
  lb_ips=/etc/ansible/lb-ips 
  [ ! -d ${lb_ips} ] && cp -r  /etc/ansible/ips $lb_ips 
  if [ -e ${lb_ips}/roxie ] 
  then
    if [ $NUM_ROXIE_LB -gt 0 ] 
    then
      #rm -rf  ${lb_ips}/roxie  
      #touch  ${lb_ips}/roxie  
      #for i in $(seq 1 $NUM_ROXIE_LB)
      #do
      #  lb_ip=ROXIE${i}_SERVICE_HOST
      #  eval lb_ip=\$$lb_ip
      #  [ -n "$lb_ip" ] && echo  ${lb_ip} >> ${lb_ips}/roxie
      #done
      cp /tmp/lb-ips/roxie ${lb_ips}/
    fi
  fi

  if [ -e ${lb_ips}/thor ] 
  then
    if [ -n "$NUM_THOR_SV" ] && [ $NUM_THOR_SV -gt 0 ] 
    then
      #rm -rf  ${lb_ips}/thor
      #touch  ${lb_ips}/thor
      #for i in $(seq 1 $NUM_THOR_SV)
      #do
      #  padded_index=$(printf "%04d" $i)
      #  lb_ip=THOR${padded_index}_SERVICE_HOST
      #  eval lb_ip=\$$lb_ip
      #  [ -n "$lb_ip" ] && echo  ${lb_ip} >> ${lb_ips}/thor
      #done
      cp /tmp/lb-ips/thor ${lb_ips}/
    fi
  fi

  #[ -e ${lb_ips}/esp ] && [ -n "$ESP_SERVICE_HOST" ] && echo  ${ESP_SERVICE_HOST} > ${lb_ips}/esp
  [ -e ${lb_ips}/esp ] && [ -s "/tmp/lb-ips/esp" ] && cp /tmp/lb-ips/esp  ${lb_ips}/
}

function set_vars_for_envgen()
{
  HPCC_HOME=/opt/HPCCSystems
  ENV_XML_FILE=environment.xml

  if [ -n "$NUM_THOR_SV" ] && [ $NUM_THOR_SV -gt 0 ] 
  then
    thor_ips=/etc/ansible/lb-ips/thor 
  else
    thor_ips=/etc/ansible/ips/thor
  fi

  [ -e ${thor_ips} ] && thor_nodes=$(cat ${thor_ips} | wc -l)
  support_nodes=1
  slaves_per_node=1
  [ -n "$SLAVES_PER_NODE" ] && slaves_per_node=${SLAVES_PER_NODE}
  [ -z "$thor_nodes" ] && thor_nodes=0
}

function create_envxml_with_lb()
{
  CONFIG_DIR=/etc/HPCCSystems
  roxie_ips=${lb_ips}/roxie
  esp_ips=${lb_ips}/esp

  create_envxml
  chown -R hpcc:hpcc $CONFIG_DIR
}

function create_envxml_with_real_ips()
{
  esp_ips=/etc/ansible/ips/esp
  roxie_ips=/etc/ansible/ips/roxie
  thor_ips=/etc/ansible/ips/thor
  CONFIG_DIR=/etc/HPCCSystems/real
  [ ! -d $CONFIG_DIR ] && cp -r /etc/HPCCSystems.bk $CONFIG_DIR
  create_envxml
  chown -R hpcc:hpcc $CONFIG_DIR
  CONFIG_DIR=/etc/HPCCSystems
}

# This is only needed if thor using proxy service
function create_envxml_for_thor()
{
  if [ -n "$NUM_THOR_SV" ] && [ $NUM_THOR_SV -gt 0 ] 
  then
    CONFIG_DIR=/etc/HPCCSystems/thor
    cp  /etc/HPCCSystems/environment.xml ${CONFIG_DIR}/
    create_envxml dafilesrv
    chown -R hpcc:hpcc $CONFIG_DIR
 fi
}

function create_envxml_for_esp()
{
  CONFIG_DIR=/etc/HPCCSystems/esp
  cp  /etc/HPCCSystems/environment.xml ${CONFIG_DIR}/
  esp_svc_ip=$(cat ${lb_ips}/esp)
  if [ -n "$esp_svc_ip" ]; then
    sed  "s/${esp_svc_ip}/\./g"  /etc/HPCCSystems/environment.xml > ${CONFIG_DIR}/environment.xml
  fi
  chown -R hpcc:hpcc $CONFIG_DIR
}

function create_envxml_for_roxie()
{
  if [ -z "$NUM_ROXIE_LB" ] || [ $NUM_ROXIE_LB -le 0 ] 
  then  
    cp -r /etc/HPCCSystems/environment.xml /etc/HPCCSystems/roxie/
    chown hpcc:hpcc /etc/HPCCSystems/roxie/environment.xml
    return
  fi

  for i in $(seq 1 ${NUM_ROXIE_LB}) 
  do
    CONFIG_DIR=/etc/HPCCSystems/roxie/${i}
    roxie_svc_ip=$(cat ${lb_ips}/roxie | head -n ${i} | tail -n 1 )
    sed  "s/${roxie_svc_ip}/\./g"  /etc/HPCCSystems/environment.xml > ${CONFIG_DIR}/environment.xml
    chown -R hpcc:hpcc $CONFIG_DIR
  done
}

#------------------------------------------
# Need root or sudo
#
SUDOCMD=
[ $(id -u) -ne 0 ] && SUDOCMD=sudo



#------------------------------------------
# LOG
#
LOG_DIR=/log/hpcc-tools
mkdir -p $LOG_DIR
LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
LOG_FILE=${LOG_DIR}/config_hpcc_${LONG_DATE}.log
touch ${LOG_FILE}
exec 2>$LOG_FILE
set -x

update=0
while getopts "*hu" arg
do
   case $arg in
      h) usage
         ;;
      u) update=1
        ;;
      ?)
         echo "Unknown option $OPTARG"
         usage
         ;;
   esac
done


echo "update mode: $update"
#----------------------------------------o
# Start sshd
#
ps -efa | grep -v sshd |  grep -q sshd
[ $? -ne 0 ] && $SUDOCMD mkdir -p /var/run/sshd; $SUDOCMD  /usr/sbin/sshd -D &


#------------------------------------------
# Collect conainters' ips
#
collect_ips

#------------------------------------------
# Create HPCC components file
#
hpcc_config=$(ls /tmp/ips | tr '\n' ',')
echo "cluster_node_types=${hpcc_config%,}" > /tmp/hpcc.conf

#backup
[ -d /etc/HPCCSystems/ips ] rm -rf /etc/HPCCSystems/ips 
cp -r /tmp/ips /etc/HPCCSystems/

[ -d /etc/HPCCSystems/lb-ips ] rm -rf /etc/HPCCSystems/lb-ips 
cp -r /tmp/lb-ips /etc/HPCCSystems/

cp  /tmp/hpcc.conf /etc/HPCCSystems/

#------------------------------------------
# Setup Ansible hosts
#
setup_ansible_hosts
dali_ip=$(cat /etc/ansible/ips/dali)


if [ $update -eq 0 ]
then
  restore_hpcc_config
  set_hpcc_data_owner
  stop_hpcc
  get_lb_ips
fi

set_vars_for_envgen
create_envxml_with_lb

if [ $update -eq 0 ]
then
  create_envxml_for_roxie
  create_envxml_for_esp
  create_envxml_for_thor
fi

create_envxml_with_real_ips

if [ $update -eq 0 ]
then
  ansible-playbook /opt/hpcc-tools/ansible/refresh_dali.yaml 
  start_hpcc
else
  ansible-playbook /opt/hpcc-tools/ansible/refresh_dali.yaml 
  ansible-playbook /opt/hpcc-tools/ansible/start_thor.yaml --extra-vars "hosts=dali" 
fi


set +x
echo "$SUDOCMD /opt/HPCCSystems/sbin/configgen -env /etc/HPCCSystems/environment.xml -listall2"
$SUDOCMD /opt/HPCCSystems/sbin/configgen -env /etc/HPCCSystems/environment.xml -listall2
echo "HPCC cluster configuration is done."
