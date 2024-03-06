#!/bin/sh
# chkconfig: on 100 100
#
# (c) Copyright 2002-2015 Hewlett Packard Enterprise Development LP
#
# description: Agentless Management Service. 
#
#
### BEGIN INIT INFO
# Provides:            amshelper
# Required-Stop:       
# Description:         starts OS helper for AMS
### END INIT INFO

AMSPATH=/opt/amshelpr
PATH=/sbin:/usr/sbin:/bin:/usr/bin:$AMSPATH
NAME="Agentless Management Service for Gen9"
SNAME=amshelpr
AMSBIN=$AMSPATH/$SNAME
AMSRG=amshelpr
PLUGINSRP=host/vim/vmvisor/plugins
AMSPLUGINSRP=${PLUGINSRP}/${AMSRG}
PLUGINSDIR=/usr/lib/vmware/esxcli/int
AMSPARAM="++group=${AMSPLUGINSRP}"


check_installer()  {
   RC=1;
   /sbin/bootOption -roC | grep runweasel > /dev/null 2>&1; RC=$?
   if [ "$RC" -eq "0" ]; then
         logger "amshelpr.sh: installer check ok."
         exit 0
   else
         logger "amshelpr.sh: runtime check ok."
   fi

}

delete_rg()
{
   #delete resource group at shutdown
   logger "amshelpr.sh: Deleting AMS resource group " $AMSPLUGINSRP
   localcli --plugin-dir $PLUGINSDIR sched group delete -g $AMSPLUGINSRP
}

create_rg()
{
   RC=1
   #check if resource group is already created
   localcli --plugin-dir $PLUGINSDIR sched group list | grep 'plugins/amshelpr'
   RC=$?
   if [ "$RC" -eq "0" ]; then
      logger "amshelpr.sh: amshelpr resource group already exists."
   else
      logger "amshelpr.sh: Creating resource group..."
      #if not, create new resource group
      localcli --plugin-dir $PLUGINSDIR sched group add -n $AMSRG -g $PLUGINSRP
      RC=$?
      if [ "$RC" -eq "0" ]; then
         logger "amshelpr.sh: Successfully created resource group."
         #set resource limits
         localcli --plugin-dir $PLUGINSDIR sched group setmemconfig -g $AMSPLUGINSRP --min 100 --minlimit=-1 --max 100000 --units kb
         RC=$?
         if [ "$RC" -eq "0" ]; then
            logger "amshelpr.sh: Successfully set resource group mem config."
         else
            logger "amshelpr.sh: Failed to set resource group mem config."
         fi
      else
         logger "amshelpr.sh: Failed to create resource group."
      fi
   fi
}

cleanup_rg()
{
   RC=1
   #check if resource group is already created from previous installs that didn't cleanup
   localcli --plugin-dir $PLUGINSDIR sched group list | grep 'plugins/amshelpr'
   RC=$?
   if [ "$RC" -eq "0" ]; then
      logger "amshelpr.sh: amshelpr resource group already exists.  Cleaning up..."
      delete_rg
   fi
}

start_ams_nowd()  {
      RC=0;
      HELPER_PID=$(pidof ${SNAME})
      kill -0 $HELPER_PID > /dev/null 2>&1; RC=$?
      if [ "$RC" -eq "0" ]; then
         echo "$SNAME is already running."
         logger  "amshelpr start: $SNAME is already running."
         #exit 0
      else
         create_rg
         echo "Starting $SNAME service..."
         #echo "amshelpr start"
         logger "amshelpr start service..."
         $AMSBIN ${AMSPARAM}; RC=$?
         #echo $RC
      fi
}

start_ams()  {
      RC=0;
      HELPER_PID=$(pidof ${SNAME})
      kill -0 $HELPER_PID > /dev/null 2>&1; RC=$?
      if [ "$RC" -eq "0" ]; then
         echo "$SNAME is already running."
         logger  "amshelpr start: $SNAME is already running."
         #exit 0
      else
         create_rg
         echo "Starting $SNAME service..."
         #echo "amshelpr start"
         logger "amshelpr start service..."
         $AMSBIN ${AMSPARAM}; RC=$?
         #echo $RC
         sleep 5
         logger "amshelpr start watchdog..."
         setsid $AMSPATH/amshelpr-wd.sh start &
      fi
}

stop_ams()  {
      logger "amshelpr stop service..."
      RC=0;
      #HELPER_PID=$(ps -u | grep ${SNAME} 2> /dev/null | awk "{ print \$1 }")
      HELPER_PID=$(pidof ${SNAME})
      echo "Stopping process $HELPER_PID..."
      kill -KILL $HELPER_PID > /dev/null 2>&1; RC=$?
      #echo $RC
      sleep 2
      RC=0;
      while true
      do
        HELPER_PID=$(pidof ${SNAME})
        kill -0 $HELPER_PID > /dev/null 2>&1; RC=$?
        if [ "$RC" -eq "0" ]; then
           echo "Process $HELPER_PID still running..."
           echo "Stopping process $HELPER_PID..."
           kill -KILL $HELPER_PID > /dev/null 2>&1; RC=$?
           sleep 2
        else
           echo "$SNAME process is now stopped."
           break
        fi
      done
      #cleanup interface files
      rm -f /tmp/ams*.txt
      rm -f /tmp/ams*.done
      rm -f /tmp/bb*
      rm -f $AMSPATH/ams*.done
}


case "$1" in
   start)
      check_installer
      cleanup_rg
      SUPPORTED=0;
      #check if server has iLO4
      /sbin/localcli hardware pci list > $AMSPATH/pcilist.txt 2>/dev/null
      $AMSBIN -S ; RC=$?
      if [ "$RC" -eq "0" ]; then
         SUPPORTED=1;
      fi 
      #check if compatible gen10 amsd is installed by checking install path for AMS with both gen9 and gen10 binaries included
      if [ -d /opt/ams ];  then
         if [ "$SUPPORTED" -eq "1" ]; then
            logger "amshelpr: ERROR: Incompatible version of amsd VIB found. Please upgrade to amsd VIB to version 11.6.0 or newer or install the HPE Management Bundle version 3.6.0 or newer."
         fi
         exit 0
      fi
      if [ "$SUPPORTED" -eq "1" ]; then
         #logger "[amshelpr] Agentless Management Service for Gen9 is supported on this platform." 
         start_ams
      else
         logger "[amshelpr] Agentless Management Service for Gen9 is not supported on this server."
      fi
      exit $RC
   ;;
   stop)
      logger "amshelpr stop watchdog..."
      $AMSPATH/amshelpr-wd.sh stop
      sleep 2
      stop_ams
      delete_rg
      exit 0
   ;;
   restart)
      #echo "amshelpr restart"
      logger "amshelpr restart..."
      $0 stop
      sleep 5
      $0 start
   ;;
   start-ams)
      start_ams_nowd
      exit 0
   ;;
   stop-ams)
      stop_ams
      delete_rg
      exit 0
   ;;
   status)
      RC=0;
      HELPER_PID=$(pidof ${SNAME})
      kill -0 $HELPER_PID > /dev/null 2>&1; RC=$?
      if [ "$RC" -eq "0" ]; then
         echo "$SNAME is running."
         exit 0
      else
         echo "$SNAME is stopped."
         exit 0
      fi
   ;;
   *)
     echo "Usage: /etc/init.d/amshelpr.sh {start|stop|restart|status}"
     exit 1
esac

exit 0 
