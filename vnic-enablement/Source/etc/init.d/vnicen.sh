#!/bin/sh 
# chkconfig: on 90 90


#--------1---------2---------3---------4---------5---------6---------7---------8
#
#  file: vnicen.sh
#
#  Virtual NIC is enabled when the server is started 
#  Virtual NIC is disabled when the server is shutdown
#
#--------1---------2---------3---------4---------5---------6---------7---------8
  
HW_PCILIST=/tmp/look_for_iLO_in_pcihwlist.txt
iPrintMsg=1

myPID=$$
VNIC_RUNNING_PID_FILE=/tmp/current_vnic_enablment_pid.data
CURRENT_RUNNING_PROCESS=/tmp/current_running_processes.data
CURRENT_RUNNING_PID=0

#

check_installer()  {
   RC=1;
   /sbin/bootOption -roC | grep runweasel > /dev/null 2>&1; RC=$?
   if [ "$RC" -eq "0" ]; then
         logger "$0: detected OS installer running. exit script."
         exit 0
   else
         logger "$0: runtime check ok."
   fi

}


vnic_wait()
{
  if [ "$iPrintMsg" == "1" ]; then
     logger "$0:Virtual NIC:  in wait loop"
  fi
  # wait 30 seconds
  i=30
  while [ $i -gt 0 ]
  do
    sleep 1
    i=`expr $i - 1`
  done
}

check_Execution()
{

   iResult=0

#   ifound_PIDFILE=` ls $VNIC_RUNNING_PID_FILE `

#   if [ "$ifound_PIDFILE" == "" ]; then 
    if [ ! -f  $VNIC_RUNNING_PID_FILE ]; then
      logger "$0:start execution of script with PID $myPID due to no script already running "
#     echo   "$0:start execution of script with PID $myPID due to no script already running "
      echo $myPID > $VNIC_RUNNING_PID_FILE
      iResult=0
   else
      logger "$0:checking if script is actually running or not"
#     echo   "$0:checking if script is actually running or not"

      CURRENT_PID_VALUE=`cat $VNIC_RUNNING_PID_FILE `
      localcli system process list > $CURRENT_RUNNING_PROCESS
      fResults_PID=`grep $CURRENT_PID_VALUE $CURRENT_RUNNING_PROCESS `

#     echo "$0: fResults_PID [ $fResults_PID ] "

      if [ "$fResults_PID" == "" ]; then 
         logger "$0:start execution of script with PID $myPID "
#        echo   "$0:start execution of script with PID $myPID "
         echo $myPID > $VNIC_RUNNING_PID_FILE
         iResult=0
      else
         logger "$0:VIRTUAL NIC: script already running with PID [ $CURRENT_PID_VALUE ], so just exit this one. PID [ $myPID ] "
         iResult=1
      fi

      return $iResult
   fi
}

local_getMPHWver()
{

#
#    Get the PCI list to be able to search for iLO
#

    /sbin/localcli hardware pci list > $HW_PCILIST 
#
#    walk thru the hw list and get the iLO info
#    when iLO info found
#       return the iLO verion
#
#    end of script

#    Stage 1 = Found Vendor ID
#    Stage 2 = Found Device ID
#    Stage 3 = Found SubVendor ID
#    Stage 4 = Found SubDevice ID
#

#echo "*** Execute script $0 ****"
#logger "$0: Execute the script "

        iCount=1
        iFound=0
        iStage=0
        iLO=0


	while read line 
	do
#	  echo [$iCount - $iStage ] - $line
          iCount=`expr $iCount + 1`
         
          if [ "$iStage" == "0" ]; then

             iFound=`echo $line | grep "Vendor ID:"  `

             if [ "$iFound" == "" ]; then
                iStage=0
                iLO=0
             else
               iStage=1
               iFound=`echo $line | grep "0x103c" `
               if [ "$iFound" == "" ]; then 
                  iStage=0
                  iLO=0
               else
#                echo "passed Vendor ID"
                 iFoundVendor=$iFound
#                sleep 5
               fi
            fi
            continue
         fi


        if [ "$iStage" == "1" ]; then
             iFound=`echo $line | grep "Device ID:"  `

             if [ "$iFound" == "" ]; then
                iStage=0
                iLO=0
             else
               iStage=2
               iFound=`echo $line | grep "0x3306" `
               if [ "$iFound" == "" ]; then 
                  iStage=0
                  iLO=0
               else
#                echo "passed Device ID"
                 iFoundDevice=$iFound
#                sleep 5
               fi
            fi
            continue
        fi

        if [ "$iStage" == "2" ]; then
             iFound=`echo $line | grep "SubVendor ID:"  `
             if [ "$iFound" == "" ]; then
                iStage=0
                iLO=0
             else
               iStage=3

               ## 0x103c is iLO4
               iFound=`echo $line | grep "0x103c" `
               if [ "$iFound" == "" ]; then
                  #logger "$0: check if iLO 5"
                  iLO=0
               else
                  iLO=4
#                 echo "Passed SubVendor status "	
                  iFoundSubVendor=$iFound
#               sleep 5
                  continue
               fi

	       ## 0x1590 is iLO5 
               iFound=`echo $line | grep "0x1590" `
               if [ "$iFound" == "" ]; then
                  echo " neither iLO4 or iLO5 .. so start again"
                  iStage=0
                  iLO=0
               else
                  iLO=5
#                 echo "Passed SubVendor status .."	
#                 sleep 5
#                 echo "Get the next line..."
                  iFoundSubVendor=$line
                  continue
               fi
           fi
        fi

        if [ "$iStage" == "3" ]; then
             iFound=`echo $line | grep "SubDevice ID:"  `

## check if iLO4
             if [ "$iLO" == "4" ]; then

                if [ "$iFound" == "" ]; then
                    echo "."
                   iStage=0
                   iLO=0
               else
                   iStage=4
                  iFound=`echo $line | grep "0x3381" `
                  if [ "$iFound" == "" ]; then 
                      echo "."
                      iStage=0
                      iLO=0
                  else
#                     echo "..should be iLO4 "
#                     echo " Is iLO4 ..."
                      iFoundSubDevice=$iFound
                      return $iLO
                  fi
               fi
               continue
            fi

## check if iLO5

            if [ "$iLO" == "5" ]; then

                if [ "$iFound" == "" ]; then
                   iStage=0
                   iLO=0
               else
                  iStage=4

                  iFound=`echo $line | grep "0x00e4" `
                  iFound_1=`echo $line | grep "0x027f" `

                  if [ "$iFound" == "" ]; then 
                    
                     if [ "$iFound_1" == "" ]; then
                        iStage=0
                        iLO=0
                        continue
                     else
                        iFoundSubDevice=$iFound_1
#                       echo " Is ILO5 ... "
                        return $iLO
                     fi
                  else
                        iFoundSubDevice=$iFound
#                       echo " Is iLO [ $iLO ] "
                        return $iLO
                  fi

                  iStage=0
                  iLO=0
              fi
               continue
            fi
   fi

     done < $HW_PCILIST

     return $iLO
}


check_iLO()
{
      valid_iLO=0

      #logger "$0: check which ILO found on system ... "

      MPHW=0;
      local_getMPHWver ; MPHW=$?

      #logger "$0: Values found when checking for iLO: "
      logger "$0: Found iLO [ $iFoundVendor $iFoundDevice $iFoundSubVendor $iFoundSubDevice ]"

      if [ "$MPHW" -eq "5" ]; then
         logger "$0: Detected Supported Management Processor HW version 5.  (iLO 5)"
         echo "$0: Detected Supported Management Processor HW version 5.  (iLO 5)"
         valid_iLO=1
      else
         if [ "$MPHW" -eq "4" ]; then
            logger "$0: Detected Unsupported Management Processor HW version 4.  (iLO 4)"
            echo "$0: Detected Unsupported Management Processor HW version 4.  (iLO 4)"
         else
            logger "$0: Detected Unsupported Management Processor HW version. Value for iLO [$MPHW]"
            echo "$0: Detected Unsupported Management Processor HW version. Value returned [$MPHW] "
         fi
     fi
     return $valid_iLO
}

check_OS()
{
#
#  Get the VMware version number from command vmware -v
#  Expected format of vmware -v = VMware ESXi x.y.z 
#
#  Set valid flag to 0  
#
#  The expected valid versions are:
#  - 7.0.1
#  - 7.0.2
#  - 7.0.3
#
#  Compare the value of x.y.z to valid versions 
#  If valid version 
#     set valid flag to 1
#  
#
#

   valid_OS=0
   iVersion=x.y.z
   iVersion=`vmware -v | cut -d' ' -f3 `

   if [ "$iVersion" == "7.0.1" ]; then 
      valid_OS=1
   fi

   if [ "$iVersion" == "7.0.2" ]; then
      valid_OS=1
   fi

   if [ "$iVersion" == "7.0.3" ]; then
      valid_OS=1
   fi

   logger " $0: check_OS - ESXi version [ $iVersion ] valid_OS flag [ $valid_OS ] "

   return $valid_OS
}


check_vusb()
{
  #
  # vusb nic may not be available at initialization...wait 1 cycle and retry
  #
  retries=1

  #
  #  flag to represent a supported OS and iLO version
  #  initialized to 'not present'
  #

  valid=0
  iValid_OS=0
  iValid_iLO=0
  retries=0

  #
  #  Check if valid iLO and OS verions
  #  NOTE: checking the OS first 
  #        if not correct OS, then no need to check for iLO 
  #

  check_OS
  iValid_OS=$?

#  logger "$0: check_OS returns $iValid_OS"

  if [ "$iValid_OS" == "1" ]; then 
     check_iLO
     iValid_iLO=$?

##    logger "$0: check_ILO returns $iValid_iLO "

  fi

  #logger  "$0: OS[$iVersion] .. Valid_OS[$iValid_OS] .. iLO[$iValid_iLO] "

  valid=0
  if [ "$iValid_OS" == "0" ]; then
    retries=0
  else
    if [ "$iValid_iLO" == "0" ]; then
       retries=0
    else
      valid=1
      retries=1
    fi
  fi


#
# iCount is used to trying waiting for the VNIC to initilaiize
# Will attempt to try 5 times and then stop printing messages 
# The 5 tries allows for 2 and 1/2 minutes 
# NOTE: vnic_wait() is set for 30 seconds
#

  iCount=0
  while [ $retries -gt 0 ]
  do

    if [ $iCount -gt 5 ]; then 
       iPrintMsg=0
       if [ "$iCount" == "6" ]; then
          logger "$0:VIRTUAL NIC: Will continue to monitor for vusb nic ... "
       fi
    fi

    if [ "$iPrintMsg" == "1" ]; then
       logger "$0: Attempt $iCount to check if vusb nic is present "
    fi

    #
    #  check if the vusb nic is present
    #
    vusb=$(localcli network nic list|grep -i vusb)
    if [ "$vusb" == "" ]; then

       if [ "$iPrintMsg" == "1" ]; then 
          logger "$0:vusb results: [$vusb]"
          logger "$0:VIRTUAL NIC:****NO VUSB AVAILABLE"
          logger "$0:Call wait loop"
       fi
       vnic_wait
       retries=`expr $retries + 1`
       iCount=`expr $iCount + 1`
    else
       logger "$0:vusb results: [$vusb]"
       name_vusb=$( echo $vusb | cut -d " " -f1 )
       logger "$0:VIRTUAL NIC:****VUSB FOUND name is [ $name_vusb ] *****"
       valid=1
       retries=0
    fi

  done

  return $valid

}  ## end of check_vusb()


vnic_config()
{
  logger "$0:VIRTUAL NIC::vnicen configuration script - configure virtual nic..."

  my_vusb=$(localcli network nic list|grep -i vusb)
  name_vusb=$(echo $my_vusb | cut -d " " -f1 )
  logger "$0:VIRTUAL NIC: use [ $name_vusb ] as name to configure virtual nic "

  #------------------------------
  # Set up the virtual switch
  #  Check if vNIC network stack already setup
  
  switch=$(esxcfg-vswitch -l |grep vSwitchUSB)
  if [ "$switch" == "" ]; then 
      logger "$0: VIRTUAL NIC: Configuring vSwitchUSB... "
      esxcfg-vswitch -a vSwitchUSB 
  fi
  
  #------------------------------ 
  # Add the physical virtual nic to the virtual switch
   
  vnic=$(esxcfg-vswitch -l |grep vSwitchUSB| grep $name_vusb )
  if [ "$vnic" == "" ]; then
      logger "$0: VIRTUAL NIC: Adding uplink [ $name_vusb] to vSwitchUSB... "
      esxcfg-vswitch -L $name_vusb  vSwitchUSB
  fi
  
  #------------------------------
  #Set up the port group and add to the TCP/IP stack
  
  pg=$(esxcfg-vswitch -C pgUSB)
  if [ "$pg" != "1" ]; then
      logger "$0: VIRTUAL NIC: Adding portgroup pgUSB to  vSwitchUSB... "
      esxcfg-vswitch -A pgUSB  vSwitchUSB
  fi
  
  #------------------------------
  #add the virtual nic to the default tcpip stack
  
  stack=$(esxcfg-vmknic -l |grep pgUSB)
  if [ "$pg" != "1" ]; then
      logger "$0: VIRTUAL NIC: Configuring vmk interface for portgroup pgUSB... "
      esxcfg-vmknic -a -i DHCP -p pgUSB -N defaultTcpipStack
  fi
  
  #------------------------------
  #open the http port to enable data transfer over virtual nic
  
  localcli network firewall ruleset set --ruleset-id=httpClient --enabled=true

}  ## end of vnic_config()

  
vnic_deconfig()
{
  logger "$0: VIRTUAL NIC::vnicen init script - deconfigure virtual nic..."

  #------------------------------
  #close the http port that enables data transfer over virtual nic
  
  localcli network firewall ruleset set --ruleset-id=httpClient --enabled=false
  
  #------------------------------
  #remove the virtual nic to the default tcpip stack
  
  stack=$(esxcfg-vmknic -l |grep pgUSB)
  
  if [ "$stack" != "" ]; then
      logger "$0: VIRTUAL NIC: Deleting vmk interface for portgroup pgUSB... "
      esxcfg-vmknic -d -p pgUSB
  fi
  
  #------------------------------
  #Remove the port group from the TCP/IP stack
  
  pg=$(esxcfg-vswitch -C pgUSB)
  
  if [ "$pg" == "1" ]; then
      logger "$0: VIRTUAL NIC: Deleting portgroup pgUSB... "
      esxcfg-vswitch -D pgUSB  vSwitchUSB
  fi
  
  #------------------------------
  # Remove up the virtual switch
  #  Check if vNIC network stack already setup
  
  switch=$(esxcfg-vswitch -l |grep vSwitchUSB)
  
  if [ "$switch" != "" ]; then
      logger "$0: VIRTUAL NIC: Deleting vSwitchUSB... "
      esxcfg-vswitch -d vSwitchUSB
  fi

}  ## end of vnic_deconfig()

###-------------------------------------------------------
###
###   main 
###
###-------------------------------------------------------


logger "$0:VIRTUAL NIC: execute command  [ $0 $1 ] PID[ $myPID ] ] "

check_Execution
iAlreadyRunning=$?


if [ "$iAlreadyRunning" == "1" ]; then
   logger "$0: Detected script already running. Just exit "

else
  
   case $1 in
      start)
         check_installer
         check_vusb
         ret=$?
         if [ "$ret" == 1 ]; then
           vnic_config
         fi
         ;;

      stop)
         vnic_deconfig
         ;;

      *)
         echo "$0: start|stop"
         ;;

   esac
   rm -f  $VNIC_RUNNING_PID_FILE

fi

logger "$0:VIRTUAL NIC: complete command [ $0 $1 - PID[ $myPID ] ]"

