#!/bin/sh
#
# Script file for executing iSUT ondemand mode 
# commands using esxcli extension 
#
# chkconfig: on 99 99
# description: HPTools server daemon
#
# processname: sutd
# pidfile: /var/run/sutd.pid

HPTOOLSD=/opt/sut/bin/sut

case $1 in
	-m) OPTIONS="-set mode=$2" ;;
	-t) OPTIONS="-set pollingintervalinminutes=$2" ;;
	-d) OPTIONS="-set stagingdirectory=$2" ;;
	-e) OPTIONS="-set enableiloqueuedupdates=$2" ;;
	-x) OPTIONS="-exportconfig $2" ;;
	-i) OPTIONS="-importconfig $2" ;;
	-u) OPTIONS="-set ilousername=$2 ilopassword=$3" ;;
	-s) OPTIONS="-start" ;;
	-o) OPTIONS="-stop" ;;
	-r) OPTIONS="-deregister" ;;
	-c) OPTIONS="-clearilocreds" ;;
	*) OPTIONS="none" ;;
esac


echo "<?xml version=\"1.0\" ?>"
echo "<output xmlns=\"http://www.vmware.com/Products/ESX/5.0/esxcli/\">"
echo "<list type = \"string\">"
echo "<string><![CDATA["
if [ $1 == "-s" -o $1 == "-m" ]
then
	setsid $HPTOOLSD $OPTIONS > /tmp/output.log 2>&1
	cat /tmp/output.log
	rm -f /tmp/output.log
else
	$HPTOOLSD $OPTIONS
fi
echo "]]></string>"
echo "</list>"
echo "</output>"







