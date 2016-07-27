#!/bin/bash
[ -z "$1" ] && exit 1
user=hpcc
[ -n "$$2" ] && user=$2
envxml=/etc/HPCCSystems/environment.xml
link=$(readlink $envxml)
if [ "$link" != "$1/environment.xml" ]
then
  [ -e $envxml ] &&  rm -rf $envxml
  ln -s  $1/environment.xml $envxml
  chown ${user}:${user} $envxml
fi
