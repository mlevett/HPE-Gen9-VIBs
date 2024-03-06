#!/bin/sh
# chkconfig: on 90 90

FC_FILE_PATH64=/opt/fcen64
HBACONF=hba.conf
QLG_RUBAH=libqlsdm-x86_64.so
MRVL_RUBAH=libqrlapi.so
EMX_RUBAH=libemsdm.so
BRCM_RUBAH=libbrcmemsdm.so

gen_config_file() {

   logger "fchbaen init script: Generating hba config file..."
   rm -f $FC_FILE_PATH64/$HBACONF

   #7.0
   localcli system module list | grep qlnative > /dev/null 2>&1; RC=$?
   if [ "$RC" -eq "0" ]; then
         echo "qlnativefc   $FC_FILE_PATH64/libqlsdm-x86_64.so" >> $FC_FILE_PATH64/$HBACONF
   fi

   local QRL=0

   localcli system module list | grep qfle3f > /dev/null 2>&1; RC=$?
   if [ "$RC" -eq "0" ]; then
      localcli storage core adapter list | grep qfle3f > /dev/null 2>&1; RC=$?
      if [ "$RC" -eq "0" ]; then
         QRL=1
      fi
   fi

   localcli system module list | grep qedf > /dev/null 2>&1; RC=$?
   if [ "$RC" -eq "0" ]; then
      localcli storage core adapter list | grep qedf > /dev/null 2>&1; RC=$?
      if [ "$RC" -eq "0" ]; then
         QRL=1
      fi
   fi

   if [ "${QRL}" -eq "1" ]; then
         echo "qfle3f   $FC_FILE_PATH64/libqrlapi.so" >> $FC_FILE_PATH64/$HBACONF
   fi

   localcli system module list | grep lpfc > /dev/null 2>&1; RC=$?
   if [ "$RC" -eq "0" ]; then
      echo "lpfc   $FC_FILE_PATH64/libemsdm.so" >> $FC_FILE_PATH64/$HBACONF
   fi

   localcli system module list | grep brcmfcoe > /dev/null 2>&1; RC=$?
   if [ "$RC" -eq "0" ]; then
      echo "brcmfcoe   $FC_FILE_PATH64/libbrcmemsdm.so" >> $FC_FILE_PATH64/$HBACONF
   fi

}


case $1 in
   start)
      gen_config_file
      ;;
   stop)
      ;;
   *)
      echo "$0: start|stop"
      ;;
esac

