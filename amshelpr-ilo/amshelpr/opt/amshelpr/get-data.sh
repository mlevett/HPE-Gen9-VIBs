#!/bin/sh
#
# (c) Copyright 2015 Hewlett Packard Enterprise Development LP
#
# description: Agentless Management Service script
#
#


sataFile=/tmp/ams-sata.txt
sataDevFile=/tmp/ams-sata-dev.txt
sataStatFile=/tmp/ams-sata-stat.txt
sasFile=/tmp/ams-sas.txt
IDEdone=/tmp/amside.done
SASdone=/tmp/amssas.done



#execute only if SASdone file does not exist
if [ ! -f "$SASdone" ]; then
  #/sbin/logger "ams-wd script collecting system data for cpqSas..."
  /sbin/localcli storage core path list > ${sasFile} 2>/dev/null
fi

#execute only if IDEdone file does not exist
#it won't exist in systems without iDE/SATA so no need
if [ ! -f "$IDEdone" ]; then
  if [ ! -f /opt/ams/ams-no-ide.done ]; then
     #/sbin/logger "ams-wd script collecting system data for cpqIde..."
     /sbin/localcli storage core device list > ${sataDevFile} 2>/dev/null
     /sbin/localcli storage core path list > ${sataStatFile} 2>/dev/null
     /sbin/localcli storage core adapter list | grep sata > ${sataFile} 2>/dev/null
  fi
fi


exit 0

