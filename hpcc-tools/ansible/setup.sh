#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

usage()
{
    echo ""
    echo "Usage ${SCRIPT_NAME} options "
    echo "  -a <ansible config file>: If omitted the default is /etc/ansible/ansible.cfg"
    echo "  -c <cofig file>: <key>=<value> of the cluster configuration and HPCC products version, etc" 
    echo "  -d <directory>: contains node ips in files named as node types. For example,  "
    echo "                  dali, support, thor, roxie, etc"
    echo "  -w <work dir>:  this will be ansible hosts directory. If omitted the -d value will be used"
    echo ""
    exit 1
}

disable_host_key_check()
{
   cat $ansible_config_file | grep -q "^[[:space:]]*host_key_checking[[:space:]]*=[[:space:]]*False"  
   if [ $? -ne 0 ]; then
      echo "host_key_check is enabled"
      cat $ansible_config_file | grep -v "host_key_checking[[:space:]]*=" > /tmp/ansible.cfg 
      echo "Disable host_key_check."
      echo "host_key_checking = False"   >> /tmp/ansible.cfg
      mv /tmp/ansible.cfg $ansible_config_file
   fi
}


add_ips_to_hosts_file()
{
   echo "node_type: $node_type"
   #distro_name=$(cat ${ip_files_dir}/${node_type} | head -n 1 | sed 's/[[:space:]]//g'))  
   [ -s ${ANSIBLE_HOSTS_FILE} ] && echo "" >> ${ANSIBLE_HOSTS_FILE}
   i=0  
   while read ip
   do
       ip=$(echo $ip | sed 's/[[:space:]]//g')  
       echo "ip: $ip"
       [ -z "$ip" ] && continue 
       echo $ip | grep -q -e "^#"
       [ $? -eq 0 ] && continue 
       ip=${ip%%#;}
       ansible_ip=$(echo $ip | sed 's/\([[:digit:]]*\)-\([[:digit:]]*\)/\[\1:\2\]/g')
       [ $i -eq 0 ] && echo "[${node_type}]" >> ${ANSIBLE_HOSTS_FILE} 
       echo "$ip" >> ${ANSIBLE_HOSTS_FILE} 
       echo "${ip};" >>  ${HPCC_IPS_DIR}/${node_type}
       i=$(expr $i \+ 1)
   done < ${ip_files_dir}/${node_type}  
   if [ $i -gt 0 ]
   then
       [ -n ${processed_platform_node_types} ] && processed_platform_node_types="${processed_platform_node_types},"
       processed_platform_node_types="${processed_platform_node_types}{node_type}"
   fi
}

process_cassandra_server()
{
  echo "todo"
}

process_kafka_server()
{
  echo "todo"
}

process_kafka_zookeeper()
{
  echo "todo"
}

process_redis_server()
{
  echo "todo"
}

process_platform_nodes()
{
    if [ ! -e ${ip_files_dir}/${node_type} ]  
    then
        echo "$node_type ip file doesn't exist"
        return
    fi
    add_ips_to_hosts_file
}


ip_files_dir=
hosts_dir=/etc/ansible
config_file=
ansible_config_file=/etc/ansible/ansible.cfg

while getopts "*hc:d:w:" arg
do
    case "$arg" in
       a) ansible_config_file="$OPTARG"
          ;;
       c) config_file="$OPTARG"
          ;;
       d) ip_files_dir="$OPTARG"
          ;;
       w) hosts_dir="$OPTARG"
          ;;
       ?) usage
          ;;
    esac
done


if [ -z "$ip_files_dir" ] || [ -z "$config_file" ] 
then
    usage
fi

[ -z "$hosts_dir" ] && hosts_dir=$ip_files_dir  

disable_host_key_check

#
# Preperation
#---------------------------------------
ANSIBLE_HOSTS_FILE=${hosts_dir}/hosts 
ANSIBLE_GROUP_VARS_DIR=${hosts_dir}/group_vars
ANSIBLE_HOST_VARS_DIR=${hosts_dir}/host_vars
HPCC_IPS_DIR=${hosts_dir}/ips

[ -e ${ANSIBLE_HOSTS_FILE} ] && rm -rf ${ANSIBLE_HOSTS_FILE}
[ -d ${ANSIBLE_GROUP_VARS_DIR} ] && rm -rf ${ANSIBLE_GROUP_VARS_DIR}
[ -d ${ANSIBLE_HOST_VARS_DIR} ] && rm -rf ${ANSIBLE_HOST_VARS_DIR}
[ -d ${HPCC_IPS_DIR} ] && rm -rf ${HPCC_IPS_DIR}

mkdir -p  ${HPCC_IPS_DIR}
mkdir -p  ${hosts_dir}/group_vars
mkdir -p  ${hosts_dir}/host_vars

#
# Generate ansible hosts file under
# $hosts_dir 
#---------------------------------------
processed_platform_node_types=
cluster_node_types=$(cat $config_file | grep -i "cluster_node_types" | cut -d'=' -f2)
echo $cluster_node_types
for node_type in $(echo ${cluster_node_types} | sed 's/,/ /g')
do
    case "$node_type" in
       cassandra_server) 
          process_cassandra_server
          ;;
       kafka_server_) 
          process_kafka_server
          ;;
       kafka_zookeeper) 
          process_kafka_zookeeper
          ;;
       redis_server) 
          process_redis_server
          ;;
       support|dali|sasha|dfuserver|eclagent|eclccserver|eclscheduler|esp|roxie|thor) 
          process_platform_nodes
          ;;
       *)
          echo "Unknown cluster node type: $node_type"
          ;;
    esac
done

echo "" >> ${ANSIBLE_HOSTS_FILE} 
echo "[non-dali]" >> ${ANSIBLE_HOSTS_FILE} 
for node_type in $(echo ${cluster_node_types} | sed 's/,/ /g')
do
    case "$node_type" in
       support|sasha|dfuserver|eclagent|eclccserver|eclscheduler|esp|roxie|thor) 
       echo "$node_type" >> ${ANSIBLE_HOSTS_FILE} 
       ;;
    esac
done

