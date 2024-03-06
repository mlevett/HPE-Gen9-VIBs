#!/bin/sh
#set -x

# get current path which includes gatherlogs.sh 
#path=$(cd "dirname $0";pwd)
path=$( cd -P "$( dirname "${SOURCE}" )" && pwd )
path2="/var/tmp"
arch=$(`echo uname -m`) 

suttablestodrop="CVcenterServerData:vcenter_password_h_STRING,vcenter_username_h_STRING \
CPartnerDataTable:password_h_STRING,username_h_STRING \
COneViewApplianceData:oneview_appliance_username_h_STRING,oneview_appliance_password_h_STRING"

if [[ "$arch" = "x86_64" ]]; then
    arch="x64"
elif [[ "$arch" = "X86_64" ]]; then
    arch="x64"
elif [[ "$arch" = "IA64" ]]; then
    arch="ia64"
elif [[ "$arch" = "ia64" ]]; then
    arch="ia64"
else
    arch="x86"
fi

if [ ! -w "$path" ]; then
path=/var/tmp
fi
datetime=`date +"%m-%d-%Y_%H-%M-%S"`
tarName="${path2}/SUM_SUT_Logs_${datetime}.tar"
tarLoc="${path2}/SUM_SUT_Logs_${datetime}"
mkdir -p $tarLoc

tmpFile=`echo "directory_listing.txt"`
sumDirListing="sum_directory_listing.txt"
syslogFile="syslog.log"
oldsyslogFile="OLDsyslog.log"
topOutput="topOutput.txt"
fsState="fsState.txt"
upTime="upTime.txt"

#determine which zip program to use, or none
gzip=`which gzip 2>/dev/null`
compress=`which compress 2>/dev/null`

if [ "x$gzip" != "x" ]; then
	zipper=$gzip
else
	if [ "x$compress" != "x" ]; then
		zipper=$compress
	else
		#no zip
		zipper="touch"
	fi
fi



export DEBUGLOGDIR=0
export LOGDIR=0
export SUTLOGS=0
ParseCmdLine()
 {
   ARGS="$@"

   for ARG in $ARGS
    do
        if [ "$ARG" == "--debuglogdir" ]; then
	   debug_dir=$ARG		   
	   DEBUGLOGDIR=1
	elif [ "$ARG" == "--logdir" ]; then  
	   log_dir=$ARGS	   
	   LOGDIR=1
	elif [ "$ARG" == "-sutlogs" ]; then   
	   SUTLOGS=1
	 fi
    done
}

# This function searches for DB files from the directory passed in the argument,
# drops the tables and/or resets the columns from the tables for the DB file 
# and gathers the modifed DB file
GatherDBFiles()
{
	directory="$1"

	# Find .pdb files and drop the tables and/or reset columns only in normal mode
	if [ "${PHOENIX}" = "1" ]; then
		return;
	fi

	# Fix for QXCR1001515420. Remove if any mod_*.pdb files exist.
	findCommand=`find "$directory" -name "mod_*.pdb"`
	for dbfilename in "$findCommand"
	do
		if [ "x${dbfilename}" != "x" ]; then
			rm -f "${dbfilename}" 2>/dev/null
		fi
	done

	if [ -f "${droptable}" ]; then
			findCommand=`find "$directory" -name "*sut*.pdb"`

		for dbfilename in "$findCommand"
		do
			if [ "x${dbfilename}" = "x" ]; then
				continue;
			fi
			#Copy the db file and drop the tables from the new db file
			dir_name=$(dirname "$dbfilename");
			file_name=$(basename "$dbfilename");
			modifiedfile="$dir_name/mod_$file_name"
			cp -p "$dbfilename" "$modifiedfile"
			# Drop the tables using drop_table and gather it
			result=`"${droptable}" "$modifiedfile" ${suttablestodrop} 2>&1`

			# If drop_table utility fails for any reason, don't gather the DB file
			if [[ $? != 0 ]]; then
				echo -e "${result}. Skipping ${dbfilename} file.\n"
				rm -f "$modifiedfile" 2>/dev/null
				continue
			fi
			cp -p "$modifiedfile" $tarLoc 2>/dev/null
			rm -f "$modifiedfile"
		done
	else
		echo "dropTable is not present. Skipping DB files."
	fi
}

ParseCmdLine "$@"
if [ $SUTLOGS -eq 0 ]; then
  #Gather system statistics
  esxtop -n 1 -b > ${topOutput}
  df > ${fsState}
  cp -p "$topOutput" $tarLoc
  cp -p "$fsState" $tarLoc
  uptime > ${upTime}
  cp -p "$upTime" $tarLoc
  rm -f ${upTime} ${fsState} ${topOutput}
fi


#new default debug logs

# User option debug log directory
if [ $DEBUGLOGDIR -eq 1 ]; then
#debuglog directory
  if [ -d "$debug_dir" ]; then
    if [ $SUTLOGS -eq 0 ]; then
      findCommand=`find "$debug_dir" -name "*.txt" -o -name "*.log" -o -name "*.xml" -o -name "*.trace" -o -name "*.ini" -o -name "*.json"`
    else
      findCommand=`find "$debug_dir" -name "node.log" -o -name "deploy.log" -o -name "Baseline.log" -o -name "inventory.log" -o -name "*sum_detail_log.txt" -o -name "*sum_log.txt" -o -name "engine.log" -o -name "root.log" -o -name "*_disc.xml"`
    fi

		echo "$findCommand" | while read file; do
		 cp -p "$file" $tarLoc 2>/dev/null
		done
    if [ $SUTLOGS -eq 0 ]; then
      GatherDBFiles "${debug_dir}" true
    fi
	found=1
 fi
fi

if [ $SUTLOGS -eq 0 ]; then
  ## User option user log directory
  if [ $LOGDIR -eq 1 ]; then
  if [ -d "$log_dir" ]; then
    cp -p "$log_dir" $tarLoc 2>/dev/null
    found=1
  fi
  fi


  #component logs
  if [ -d /var/cpq ]; then
    cp -p /var/cpq/* $tarLoc 2>/dev/null
    found=1
  fi

  #system logs
  if [ -f /var/log/syslog.log ]; then
     tail -1000 /var/log/syslog.log > "$syslogFile" 2>/dev/null
  fi
  if [ -f "$syslogFile" ]; then
	cp -p "$syslogFile" $tarLoc
	rm "$syslogFile"
  fi

  if [ -f /var/log/OLDsyslog.log ]; then
     tail -1000 /var/log/OLDsyslog.log > $oldsyslogFile 2>/dev/null
  fi
  if [ -f $oldsyslogFile ]; then
	cp -p "$oldsyslogFile" $tarLoc
 	rm "$oldsyslogFile"
  fi

  #hpsutesxi logs
  if [ -d /opt/hp/hpsutesxi/bin ]; then
    findLogsCommand=`find /opt/hp/hpsutesxi -name "*.log" -o -name "HPSUM_Combined_Report_*.xml"`
    echo $findLogsCommand | while read file; do
      cp -p $file $tarLoc 2>/dev/null
    done
    hpsutesxidb='/opt/hp/hpsutesxi'
    GatherDBFiles "${hpsutesxidb}" false
    found=1
  fi
  #sutesxi logs for versions >= 2.0
  if [ -d /opt/sut/bin ] && [ -d /var/tmp/sut ]; then
    findLogsCommand=`find /var/tmp/sut -name "*.log" -o -name "sut_service*.zip"`
    echo $findLogsCommand | while read file; do
      cp -p $file $tarLoc 2>/dev/null
    done
    hpsutesxidb='/var/tmp/sut/'
    GatherDBFiles "${hpsutesxidb}" false
    found=1
  
  #sutesxi logs for versions >= 7.0
  elif [ -d /opt/sut/bin ] && [ -d /opt/sut/tmp ]; then
    findLogsCommand=`find /opt/sut/tmp -name "*.log"`
    echo $findLogsCommand | while read file; do
      cp -p $file $tarLoc 2>/dev/null
	  cp -p /opt/sut/tmp/localhost/* $tarLoc 2>/dev/null
    done
    hpsutesxidb='/opt/sut/vital/'
    GatherDBFiles "${hpsutesxidb}" false
    found=1
	fi
else
  #flash.debug logs
  if [ -d /var/cpq ]; then
    cp -p /var/cpq/flash.debug.log $tarLoc 2>/dev/null
    found=1
  fi
fi

echo "Gathering SUT logs..."

#sut logs for versions >= 2.0
if [ -d /opt/sut/bin ] && [ -d /var/tmp/sut ]; then
   findLogsCommand=`find /var/tmp/sut -name "*sut*.log" -o -name "*inputfile.txt" -o -name "ilorest.log"`
  echo $findLogsCommand | while read file; do
    cp -p $file $tarLoc 2>/dev/null
    cp -p /var/log/sut/* $tarLoc 2>/dev/null
  done
  found=1

#sut logs for versions >= 7.0
elif [ -d /opt/sut/bin ] && [ -d /opt/sut/tmp ]; then
   findLogsCommand=`find /opt/sut/tmp -name "*sut*.log" -o -name "*inputfile.txt" -o -name "ilorest.log"`
  echo $findLogsCommand | while read file; do
    cp -p $file $tarLoc 2>/dev/null
  done
  found=1
fi

if [ -d $tarLoc ]; then
 tar -cf "$tarName" $tarLoc
 rm -rf $tarLoc 
fi

#zip if possible
if [ $found -eq 1 ]; then
  $zipper "$tarName"
  newName=`ls -1 "$tarName"*`
  echo "SUT logs are in $newName"
  exit 0
fi

rm "$tarName"
echo "No SUT logs found"
exit -1
