#!/bin/sh
#
# Init file for HPTools server daemon
#
# chkconfig: on 103 103
# description: HPTools server daemon
#
# processname: sutd
# pidfile: /var/run/sutd.pid

ln -s /opt/sut/bin/sut /bin/sut

CHMOD=chmod
TOUCH=touch

$TOUCH $SUT_DB_DIR/sut.pdb
$TOUCH $SUT_DB_DIR/sut_aes
$TOUCH $SUT_DB_DIR/backup_cfg.dat
$TOUCH $SUT_DB_DIR/CSUTData.json
$TOUCH $SUT_DB_DIR/CSUTSettingsData.json
$TOUCH $SUT_DB_DIR/CSystemInventory.json
$TOUCH $SUT_DB_DIR/COVData.json
$TOUCH $SUT_DB_DIR/CSUTiLODetails.json
$CHMOD 666 $SUT_DB_DIR/sut.pdb
$CHMOD 666 $SUT_DB_DIR/sut_aes
$CHMOD 666 $SUT_DB_DIR/backup_cfg.dat
$CHMOD 666 $SUT_DB_DIR/CSUTData.json
$CHMOD 666 $SUT_DB_DIR/CSUTSettingsData.json
$CHMOD 666 $SUT_DB_DIR/CSystemInventory.json
$CHMOD 666 $SUT_DB_DIR/COVData.json
$CHMOD 666 $SUT_DB_DIR/CSUTiLODetails.json
$CHMOD +t $SUT_DB_DIR/sut.pdb
$CHMOD +t $SUT_DB_DIR/sut_aes
$CHMOD +t $SUT_DB_DIR/backup_cfg.dat
$CHMOD +t $SUT_DB_DIR/CSUTData.json
$CHMOD +t $SUT_DB_DIR/CSUTSettingsData.json
$CHMOD +t $SUT_DB_DIR/CSystemInventory.json
$CHMOD +t $SUT_DB_DIR/COVData.json
$CHMOD +t $SUT_DB_DIR/CSUTiLODetails.json


