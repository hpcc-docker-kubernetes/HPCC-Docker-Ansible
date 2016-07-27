#!/bin/bash

if [ -z "$1" ] || [ -z [ "$2"]
the
   echo "Usage:  $(basename @0) <mount point> <link dir>"
   echo "  For example:  ./link_var.sh   /disk1  /var/lib/HPCCSystems" 
   echo ""
   exit 1
fi

user=hpcc
[ -n "$3" ] && user=$3
mount_point=$1
hpcc_dir=$2
link=$(readlink $envxml)
if [ "$link" != "${mount_point}/${hpcc_dir}" ]
then
  [ -d $hpcc_dir ] &&  rm -rf $hpcc_dir
  mkdir -p ${mount_point}/${hpcc_dir}
  chown -R ${user}:${user}  ${mount_point}/${hpcc_dir}
  ln -s  ${mount_point}/${hpcc_dir} ${hpcc_dir} 
  chown -R ${user}:${user} ${hpcc_dir}
fi
