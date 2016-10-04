#!/bin/bash

SCRIPT_DIR=$(dirname $0)

function usage()
{
    cat <<EOF 
    Usage: $(basename $0) 

EOF
   exit 1
}


function collect_ips()
{
  if [ -z "$1" ] || [ "$1" != "-x" ]
  then
    trials=3
    while [ $trials -gt 0 ]
    do
       ${SCRIPT_DIR}/get_ips.sh
       ${SCRIPT_DIR}/get_ips.py -i $ips_dir -l $lbs_dir
       [ $? -eq 0 ] && break  
       trials=$(expr $trials \- 1)
       sleep 5
    done
  fi
}


function log()
{
   echo "$(date "+%Y-%m-%d_%H-%M-%S") $1 " >> $LOG_FILE 2>&1
}

#------------------------------------------
# Need root or sudo
#
SUDOCMD=
[ $(id -u) -ne 0 ] && SUDOCMD=sudo

#------------------------------------------
# Runtime parameters
#
HPCC_MGR_DIR=/var/lib/hpcc_manager
enabled=${HPCC_MGR_DIR}/enabled
ips_dir=${HPCC_MGR_DIR}/hosts/ips
lbs_dir=${HPCC_MGR_DIR}/hosts/lb-ips
mkdir -p $ips_dir
mkdir -p $lbs_dir
rm -rf ${ips_dir}/*
rm -rf ${lbs_dir}/*


conf_pod_ips=/etc/HPCCSystems/ips
conf_svc_ips=/etc/HPCCSystems/lb-ips


#------------------------------------------
# LOG
#
LOG_DIR=/var/log/hpcc-tools
mkdir -p $LOG_DIR
LOG_DATE=$(date "+%Y-%m-%d")
LOG_FILE=${LOG_DIR}/mon_ips.log
touch ${LOG_FILE}
#exec 2>$LOG_FILE
#set -x


if [ -n "$KUBE_PROVIDER" ] && [ "$RUN_PROVIDER_SCRIPT" -eq 1 ]
then
  cmd="${SCRIPT_DIR}/providers/$KUBE_PROVIDER" 
  if [ -e $cmd ]
  then 
      echo "run $cmd"
      eval "$cmd" 
  fi
   
fi
while [ 1 ]
do
  sleep 5

  CUR_LOG_DATE=$(date "+%Y-%m-%d")
  if [ "$CUR_LOG_DATE" != "$LOG_DATE" ]
  then
     mv $LOG_FILE ${LOG_DIR}/mon_ips_${LOG_DATE}.log
     LOG_DATE=$CUR_LOG_DATE
     touch $LOG_FILE
  fi

  # Monitor is not enabled, ignored
  [ ! -e $enabled ] && sleep 2 && continue 
  
  # First time configuration
  #if [ ! -e /etc/HPCCSystems/real/environment.xml ]
  if [ ! -e /etc/ansible/ips ]
  then
    log "Configure HPCC cluster at the first time ... "
    ${SCRIPT_DIR}/config_hpcc.sh >> $LOG_FILE 2>&1
    continue 
  fi

  # Collect cluster ips
  collect_ips

  # Check if any ip changed
  diff $conf_pod_ips $ips_dir > /tmp/pod_ips_diff.txt
  pod_diff_size=$(ls -s /tmp/pod_ips_diff.txt | cut -d' ' -f1)
  pod_diff_str=$(cat /tmp/pod_ips_diff.txt | grep diff | grep -v -i esp | grep -v -i roxie)

  svc_diff_size=0
  if [ -z "$USE_SVR_IPS" ] ||  [ $USE_SVR_IPS -ne 1 ]
  then
    diff $conf_svc_ips $lbs_dir > /tmp/svc_ips_diff.txt
    svc_diff_size=$(ls -s /tmp/svc_ips_diff.txt | cut -d' ' -f1)
  fi

  reconfig_hpcc=0
  if [ -n "$USE_SVR_IPS" ] &&  [ $USE_SVR_IPS -ne 0 ] && [ $pod_diff_size -ne 0 ]
  then
    log "IP(s) changed. Re-configure HPCC cluster ... "
    reconfig_hpcc=1
  elif [ -n "$pod_diff_str" ] || [ $svc_diff_size -ne 0 ]
  then
    log "Non esp/roxie ip(s) changed. Re-configure HPCC cluster ... "
    reconfig_hpcc=1
  fi


  # Re-configure
  if [ $reconfig_hpcc -ne 0 ]
  then
    ${SCRIPT_DIR}/config_hpcc.sh >> $LOG_FILE 2>&1
  elif [ $pod_diff_size -ne 0 ]
  then
    log "Only esp/roxie ip(s) changed. Just update Ansible host file ... "
    ${SCRIPT_DIR}/ansible/setup.sh -d $ips_dir -c /etc/HPCCSystems/hpcc.conf >> $LOG_FILE 2>&1
    cp -r $ips_dir/roxie $conf_pod_ips/
    cp -r $ips_dir/esp $conf_pod_ips/
  fi
  
done
