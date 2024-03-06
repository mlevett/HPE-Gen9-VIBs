#!/bin/sh
# chkconfig: on 110 110
#
# (c) Copyright 2002-2015 Hewlett Packard Enterprise Development LP
#
# description: Agentless Management Service Watchdog for Gen9. 
#
#
### BEGIN INIT INFO
# Provides:            amshelpr-wd
# Required-Stop:       
# Description:         watchdog
### END INIT INFO

PATH=/sbin:/usr/sbin:/bin:/usr/bin:/opt/amshelpr
NAME="Agentless Management Service Watchdog for Gen9" 
AMS_SH=/etc/init.d/amshelpr.sh
PTRAPRESTART=/opt/amshelpr/ptrap.text
STOPWD=/opt/amshelpr/stopwd.text
#use same memlimit for CIM providers
#mem units in KB (max=70MB)
MEMLIMIT=71680
#loop count is 24hrs/2min (sleep is in 2min interval)
LOOPCOUNT24HR=720
#for debug-devtest: reduce memlimit to check to 20min
#MEMLIMIT=4000
#LOOPCOUNT24HR=10



restart_ams()  {
    $AMS_SH stop-ams
    sleep 5
    logger "amshelpr-wd: amshelpr start..."
    $AMS_SH start-ams
}

check_memusage() {
  AMSMAINGID=$(/sbin/memstats -r group-stats -s gid:name | grep ams-main 2>/dev/null | awk '$2 ~ /ams-main/ { print $1 }')
  AMSMAINeMin=$(/sbin/memstats -r group-stats -g ${AMSMAINGID} -s name:eMin | grep ams-main 2>/dev/null | awk '$2 ~ /ams-main/ { print $3 }')
  AMSMAINeMinPeak=$(/sbin/memstats -r group-stats -g ${AMSMAINGID} -s name:eMinPeak | grep ams-main 2>/dev/null | awk '$2 ~ /ams-main/ { print $3 }')
  #logger "ams-wd: AMS eMin ${AMSMAINeMin}  eMinPeak  ${AMSMAINeMinPeak}"
  if [ "$AMSMAINeMin" -gt "$MEMLIMIT" ]; then
     logger "ams-helpr: AMS eMin ${AMSMAINeMin}  eMinPeak  ${AMSMAINeMinPeak}"
     restart_ams
     return 0
  else
     return 1
  fi
}


check_ams()   {
    #echo "check_ams"
    local ams_processes=0
    # the grep expression searches for all ams processes
    ams_processes=$(ps | grep "ams" | wc -l)
    #starting with ver 10.3.0, there should always be 3 ams processes running, and occasionally more than 3
    if [ "$ams_processes" -lt "3" ]; then
       return 0
    else
       return 1
    fi
}


run_ams_watchdog() {

   local ESXi60U0=0
   local loop_count=0
   #check memusage every 24hrs
   local loopm_count=0

   if [ $? -eq 1 ] ; then
      ESXi60U0=1
      /opt/amshelpr/./get-data.sh
      sleep 60
   fi

   while true
   do

      sleep 120

      if [ $ESXi60U0 -eq 1 ] ; then
           #logger "amshelpr-wd: Performing 2-minute interval data collection for SAS and SATA..."
           #logger "amshelpr-wd: Executing get-data.sh..."
           /opt/amshelpr/./get-data.sh
      fi

      if [ -f "$PTRAPRESTART" ]; then
           logger "amshelpr-wd: Detected AHS Logging Interval Change. Restarting AMS..."
           rm -f $PTRAPRESTART
           restart_ams
           loopm_count=0
           loop_count=0
      fi

      if [ "${loop_count}" -eq "5" ]; then
         #logger "amshelpr-wd: Performing 10-minute interval check on AMS processes..."
         loop_count=0
         check_ams
         if [ $? -eq 0 ] ; then
             logger "amshelpr-wd: Detected one or more AMS process(es) have stopped running.  Restarting..."
             restart_ams
             loopm_count=0
         fi
      fi

      if [ "${loopm_count}" -eq "$LOOPCOUNT24HR" ]; then
            #logger "amshelpr-wd: Performing 24-hr interval check on AMS memusage..."
            check_memusage
            loopm_count=0
      fi

      let loop_count=${loop_count#0}+1
      let loopm_count=${loopm_count#0}+1
      #logger "amshelpr-wd: loop count is " ${loop_count}

   done
}

start_ams_child_p(){
        run_ams_watchdog
}

GetAMSPid() {
   PIDS=$(ps -cu 2> /dev/null | awk "!/$$/ && /amshelpr-wd/  { print \$1 }")
   #AMSPID=`echo $PIDS | cut -d ' ' -f 1`
   AMSPID=$PIDS
   if [ -n "${AMSPID}" ] ; then
       echo ${AMSPID}
   else
       echo "" 
   fi
}


case "$1" in
   start)
      #gen9-only amshelpr detects incompatible amsd so must stop running including this script
      if [ -f "$STOPWD" ]; then
           logger "amshelpr-wd:  Stopping amshelpr-wd..."
           rm -f $STOPWD
           $0 stop
           exit 0
      fi

      #logger "ams-watchdog start."
      #echo "ams-watchdog start."
      #AMSWDPID=$(GetAMSPid)
      #if [ -z "${AMSWDPID}" ] ; then
      #if [ "${AMSWDPID}" -eq "0" ]; then
         start_ams_child_p
      #else
      #   echo "ams-wd: AMS watchdog is already running."
      #   #logger "ams-wd: AMS watchdog is already running."
      #fi
   ;;
   stop)
      logger "amshelpr-wd: amshelpr  watchdog stop."

      AMSWDPID=$(GetAMSPid)
      if [ -z "${AMSWDPID}" ]; then
      #if [ "${AMSWDPID}" -eq "0" ]; then
          MSG="amshelpr-wd: Unable to terminate amshelpr-watchdog. No running amshelpr-watchdog process."
          logger "$MSG"
          echo "$MSG"
      else
          MSG="amshelpr-wd: Terminating amshelpr-watchdog process with PID $AMSWDPID"
          logger "$MSG"
          echo "$MSG"
          kill -KILL ${AMSWDPID} > /dev/null 2>&1
      fi

      exit 0
   ;;
   restart)
      logger "amshelpr-watchdog restart..."
      $0 stop
      sleep 5
      $0 start
   ;;
   *)
     echo "Usage: `basename "$0"` {start|stop|restart}"
     exit 1
esac

exit 0

