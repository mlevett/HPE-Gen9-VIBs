#!/bin/bash

set -euo pipefail

#CUSTOM_VIB_TEMP_DIR=/tmp/vib-temp-$$
CUSTOM_VIB_NAME=Gen9-amshelpr-ilo
CUSTOM_VIB_VERSION="0.1"
CUSTOM_VIB_VENDOR="chimera-labs.com"
CUSTOM_VIB_VENDOR_URL="https://chimera-labs.com"
CUSTOM_VIB_SUMMARY="Custom VIB to re-add HPE Proliant Gen9 amshelpr and ilo driver"
CUSTOM_VIB_DESCRIPTION="HPE removed support for Gen9, this should readd it"
CUSTOM_VIB_BUILD_DATE=$(date '+%Y-%m-%dT%H:%I:%S')
CUSTOM_PAYLOAD_NAME="amshelpr-ilo"

# clean up any prior builds
CUSTOM_VIB_FILE_NAME=${CUSTOM_VIB_NAME}.vib
rm -f ${CUSTOM_VIB_FILE_NAME}

# Setting up VIB spec confs
#VIB_DESC_FILE=${CUSTOM_VIB_TEMP_DIR}/descriptor.xml
#VIB_PAYLOAD_DIR=${CUSTOM_VIB_TEMP_DIR}/payloads/asmhelpr
VIB_DESC_FILE=descriptor.xml

# Create VIB temp & spec payload directory
#mkdir -p ${CUSTOM_VIB_TEMP_DIR}
#mkdir -p ${VIB_PAYLOAD_DIR}

# Create ESXi folder structure for file(s) placement
#CUSTOM_VIB_ETC_DIR=${VIB_PAYLOAD_DIR}/etc/{init.d,shutdown.d,vmware/daemon/config}
#CUSTOM_VIB_OPT_DIR=${VIB_PAYLOAD_DIR}/opt/amshelpr/{bin,data}
#CUSTOM_VIB_USR_DIR=${VIB_PAYLOAD_DIR}/usr/lib/vmware/{daemonMgnt/esxcliPligins/amshelpr,esxcli/ext}
#mkdir -p ${CUSTOM_VIB_ETC_DIR}
#mkdir -p ${CUSTOM_VIB_OPT_DIR}
#mkdir -p ${CUSTOM_VIB_USR_DIR}

# Copy file(s) to destination folder
# cp amshelpr ${CUSTOM_VIB_BIN_DIR}

# Create tgz with payload
# tar czf ${CUSTOM_VIB_TEMP_DIR}/asmhelpr -C ${VIB_PAYLOAD_DIR} etc opt usr
tar czf ${CUSTOM_PAYLOAD_NAME} -C . etc opt usr

# Calculate payload size/hash
#PAYLOAD_FILES=$(tar tf ${CUSTOM_VIB_TEMP_DIR}/asmhelpr | grep -v -E '/$' | sed -e 's/^/    <file>/' -e 's/$/<\/file>/')
#PAYLOAD_SIZE=$(stat -c %s ${CUSTOM_VIB_TEMP_DIR}/asmhelpr)
#PAYLOAD_SHA256=$(sha256sum ${CUSTOM_VIB_TEMP_DIR}/asmhelpr | awk '{print $1}')
#PAYLOAD_SHA256_ZCAT=$(zcat ${CUSTOM_VIB_TEMP_DIR}/asmhelpr | sha256sum | awk '{print $1}')
#PAYLOAD_SHA1_ZCAT=$(zcat ${CUSTOM_VIB_TEMP_DIR}/asmhelpr | sha1sum | awk '{print $1}')

PAYLOAD_FILES=$(tar tf ${CUSTOM_PAYLOAD_NAME} | grep -v -E '/$' | sed -e 's/^/    <file>/' -e 's/$/<\/file>/')
PAYLOAD_SIZE=$(stat -c %s ${CUSTOM_PAYLOAD_NAME})
PAYLOAD_SHA256=$(sha256sum ${CUSTOM_PAYLOAD_NAME} | awk '{print $1}')
PAYLOAD_SHA256_ZCAT=$(zcat ${CUSTOM_PAYLOAD_NAME} | sha256sum | awk '{print $1}')
PAYLOAD_SHA1_ZCAT=$(zcat ${CUSTOM_PAYLOAD_NAME} | sha1sum | awk '{print $1}')

# Create descriptor.xml
cat > ${VIB_DESC_FILE} << __VIB_DESC__
<vib version="5.0">
  <type>bootbank</type>
  <name>${CUSTOM_VIB_NAME}</name>
  <version>${CUSTOM_VIB_VERSION}</version>
  <vendor>${CUSTOM_VIB_VENDOR}</vendor>
  <summary>${CUSTOM_VIB_SUMMARY}</summary>
  <description>${CUSTOM_VIB_DESCRIPTION}</description>
  <release-date>${CUSTOM_VIB_BUILD_DATE}</release-date>
  <urls>
    <url key="website">${CUSTOM_VIB_VENDOR_URL}</url>
  </urls>
  <relationships>
    <depends>
    </depends>
    <conflicts/>
    <replaces/>
    <provides/>
    <compatibleWith/>
  </relationships>
  <software-tags>
  </software-tags>
  <system-requires>
    <maintenance-mode>false</maintenance-mode>
  </system-requires>
  <file-list>
  ${PAYLOAD_FILES}
  </file-list>
  <acceptance-level>community</acceptance-level>
  <live-install-allowed>false</live-install-allowed>
  <live-remove-allowed>false</live-remove-allowed>
  <cimom-restart>false</cimom-restart>
  <stateless-ready>true</stateless-ready>
  <overlay>false</overlay>
  <payloads>
    <payload name="${CUSTOM_PAYLOAD_NAME}" type="tgz" size="${PAYLOAD_SIZE}">
        <checksum checksum-type="sha-256">${PAYLOAD_SHA256}</checksum>
        <checksum checksum-type="sha-256" verify-process="gunzip">${PAYLOAD_SHA256_ZCAT}</checksum>
        <checksum checksum-type="sha-1" verify-process="gunzip">${PAYLOAD_SHA1_ZCAT}</checksum>
    </payload>
  </payloads>
</vib>
__VIB_DESC__

# Create VIB using ar utility
#touch ${CUSTOM_VIB_TEMP_DIR}/sig.pkcs7
#ar r ${CUSTOM_VIB_FILE_NAME} ${VIB_DESC_FILE} ${CUSTOM_VIB_TEMP_DIR}/sig.pkcs7 ${CUSTOM_VIB_TEMP_DIR}/asmhelpr
touch sig.pkcs7
ar r ${CUSTOM_VIB_FILE_NAME} ${VIB_DESC_FILE} sig.pkcs7 ${CUSTOM_PAYLOAD_NAME}
