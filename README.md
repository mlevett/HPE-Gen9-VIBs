# HPE Gen9 VMware vSphere VIBs

A collection of manually recreated VIB files to re-add HPE Gen9 support to vSphere after HPE stopped supporting Gen9 after ESXi HPE-7.0 U3 - Jul2022 update.

The following VIBs seem to work fine on my own homelab HPE DL380 Gen9 with the latest vanilla vSphere 8.0 Update 2 (ESXi-8.0U2b-23305546-standard)

**HPE-Gen9-VIBs/amshelpr-ilo/amshelpr/Gen9-amshelpr-ilo.vib**
 - Repackaged amshelpr (Gen9 Agentless Management Service with ilo4 drivers included)

**HPE-Gen9-VIBs/smx-provider
/HPE_bootbank_smx-provider_700.03.16.00.12-14828939.vib**
 - Original HPE smx-provider

**Other files -**
 - Not yet tested, but should work, repackaged tools from older version of vSphere ESXi that "should" work fine on vSphere ESXi 8... Will update as and when I install and test them.

## Installation

Installation of any of the original HPE VIB files is as below:

- Copy VIB file to datastore on the host (SCP/WinSCP etc)

Install with the following command
- esxcli software vib install -v "\<FULL PATH TO VIB FILE\>"

This should then install and if required ask to reboot.

To install the Repackaged versions, you will need to switch to the "CommunitySupported" Acceptance Level with the following command:

- esxcli software acceptance set --level CommunitySupported

Details of what acceptance levels are is in the VMware documentation below

[https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-security/GUID-751034F3-5337-4DB2-8272-8DAC0980EACA.html](https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-security/GUID-751034F3-5337-4DB2-8272-8DAC0980EACA.html)

This is due to me not being able to resign the VIB packages after modifying them so they are trusted like the original HPE ones.  

The original VIBs have to be extracted and the descriptor.xml files edited to remove the vSphere version checks and then re-packaged back up into a new VIB file

This unfortunately breaks the original signing as the file content has changed, and is the protection method used by vSphere to prevent loading of modified code/packages.

I am not aware of any way to get round this but if anyone knows how to do so, please let me know! I only learnt how to unpack and repack these in the last two days!  Thanks to the following blog: 

[https://www.yellow-bricks.com/2011/11/29/how-to-create-your-own-vib-files/](https://www.yellow-bricks.com/2011/11/29/how-to-create-your-own-vib-files/)

## Comments
Feel free to reach out to me at my email redstarinc@hotmail.com if you have any comments or tips or improvments.
