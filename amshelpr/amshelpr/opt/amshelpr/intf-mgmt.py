#!/usr/bin/python
'''
  Returns list of IP addresses by address family
  that are VMware management capable.
'''
__author__ = "Michael R. MacFaden"
__copyright__ = "VMware, Inc 2012"
__version__ = "0.2"
__license__ = '''
Copyright (c) 2012, VMware
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of VMware, Inc.
'''
import os
import subprocess  # to run esxcli commands
import xml.sax.handler   # to parse xml output from esxcli commands

esxcli_pgm = "/bin/localcli"

class SaxParser(xml.sax.handler.ContentHandler):
   '''Memory efficient, generic esxcli xml parser for esxcli structured documents'''

   def __init__(self, tags, items, debug):
       self._state = 0
       self._buffer = ""
       self._items = items
       self._kvp = []
       self._elem = {}
       self._tags = tags
       self._instance = 1
       self._debug = debug
       if self._debug:
           print "xml element tags to look for: %s " % self._tags

   def push_field(self, attributes):
       ''' return True if name field in xml attributes matches fields requested'''
       for key in self._tags['fields']:
           if key == attributes['name']:
               self._kvp.append(key)
               return True
       if self._debug:
           print "Field named '%s' ignored, not in xml element tags" % attributes['name']
       return False

   def startElement(self, name, attributes):
       ''' All esxcli commands use common structure '''
       if self._debug:
           print "startElement: name=%s attribute=%s" % (name, attributes.items())

       if self._state == 0:
           if name == "structure":
               if attributes['typeName'] == self._tags['struct']:
                   self._state = 1
                   self._kvp = []
                   self._buffer = ""
           if self._debug:
               print "state 0->1, structure typeName=%s seen" % self._tags['struct']

       elif self._state == 1:
           if name == 'field':
               if self.push_field(attributes):
                   self._state = 2
               if self._debug:
                   print "state 1->2, field seen"
       elif self._state == 2:
           if name == 'list':
               self._state = 3
           if self._debug:
               print "state 2->3, list seen"

   def characters(self, data):
       if self._state >= 2:
           self._buffer += data

   def endElement(self, name):
       if self._debug:
           print "endElement: name=%s" % name
       if self._state == 2:
           self._state = 1
           self._kvp.append(self._buffer.strip())
           self._buffer = ""
           # assert(self._kvp.size() == 2)
           self._elem[self._kvp[0]] = self._kvp[1]
           self._kvp = []
       elif self._state == 1 and name == "structure":
           self._state = 0
           self._items.append(self._elem)
           self._elem = {}
       if self._state > 2:
           self._state -= 1

class EsxCli():
   '''Process VMware esxcli command xml output
   '''
   def __init__(self, cmd, tags, debug=False):
     '''Provide the excli command as list in cmd. tags is list of xml element names to collect
        If an error occurs either on starting the command or parsing the xml output, the error
        exception is stored in self._err for reporting
     '''
     self._cmd = cmd
     self._tags = tags
     self._err = None
     self._debug = debug
     buffered = -1

     if self._debug:
       print "EsxCli: command = %s" % " ".join(self._cmd)
     try:
         pipe = subprocess.Popen(self._cmd,
                                 bufsize=buffered,
                                 stdout=subprocess.PIPE).stdout
         self._pipe = pipe
     except subprocess.CalledProcessError, err:
       self._err = err

   def parse(self):
     '''Returns a list of dicts containing key/values where keys are taken from self._tags'''
     items = []
     try:
       xml.sax.parse(self._pipe, SaxParser(self._tags, items, self._debug))
     except xml.sax.SAXParseException, err:
       self._err = err
     return items


def FetchInterfaces():
    ''' return a list of interfaces found on this system by device name and administrative state, example:
    [{'Enabled': u'true', 'Name': u'vmk0'}, {'Enabled': u'true', 'Name': u'vmk1'}]
    '''
    cmd = [esxcli_pgm, "--formatter=xml", "network", "ip", "interface", "list"]
    tags = {'struct' : 'NetworkInterface', 'fields' : ['Name', 'Enabled']}
    cli = EsxCli(cmd, tags, debug=False)
    return cli.parse()

def FetchMgmtInterfaces(vmks):
    ''' given a list of interfaces (vmks) return those that were tagged with Maagement
    '''
    ifs = []
    tags = {'struct' : 'InterfaceTag', 'fields' : ['Tags']}
    cmd = [esxcli_pgm, "--formatter=xml", "network", "ip", "interface", "tag", "get", "-i", None ]
    for intf in vmks:
      cmd[-1] = intf
      cli = EsxCli(cmd, tags, debug=False)
      results = cli.parse()
      if results:
        for item in results:
          labels = item['Tags'].split('\n')
          for item in labels:
             if item.strip() == 'Management':
                ifs.append(intf)
    return ifs

def FetchIPv4Addresses():
   '''Fetch all presently assigned IPv4 addresses on all interfaces, example:
    [{'IPv4 Address': u'10.20.100.227', 'Name': u'vmk0'}, {'IPv4 Address': u'192.0.2.1', 'Name': u'vmk1'}]
  '''
   cmd = [esxcli_pgm, "--formatter=xml", "network", "ip", "interface", "ipv4", "get"]
   tags = {'struct' : 'IPv4Interface', 'fields' : ['Name', 'IPv4 Address']}
   cli = EsxCli(cmd, tags, debug=False)
   return cli.parse()


def FetchIPv6Addresses():
   '''Fetch IPv6 addresses assigned on all interfaces, example:
   [{'Interface': u'vmk0', 'Status': u'PREFERRED', 'Address': u'fe80::250:56ff:fea5:898a'}, {'Interface': u'vmk0', 'Status': u'PREFERRED', 'Address': u'fc00:10:20:100:250:56ff:fea5:898a'}]
   '''
   cmd = [esxcli_pgm, "--formatter=xml", "network", "ip", "interface", "ipv6", "address", "list"]
   tags = {'struct' : 'IPv6Interface', 'fields' : ['Interface', 'Status', 'Address']}
   cli = EsxCli(cmd, tags, debug=False)
   return cli.parse()

def main():
   ''' Return the set of IP addresses for ESX interfaces that are up,
       tagged with Management, and have IP addresses.
   '''
   global esxcli_pgm
   if not os.path.exists(esxcli_pgm):
       esxcli_pgm = '/sbin/localcli'
       if not os.path.exists(esxcli_pgm):
           raise Exception("The program '%s' is not found" % esxcli_pgm)
       
   interfaces = FetchInterfaces()
   print "set of all interfaces and state | %s |" % interfaces
   # strip out any interfaces that are administratively down
   vmks = []
   for item in interfaces:
      if item['Enabled'] == 'true':
        vmks.append(item['Name'])
   print "set of all administratively enabled interfaces | %s |" % vmks
   mgmt_vmks = FetchMgmtInterfaces(vmks)
   print "set of interfaces having the Management | %s |" % mgmt_vmks

   v4addrs = []
   v6addrs = []
   all_addrs = FetchIPv4Addresses()
   all_v6_addrs = FetchIPv6Addresses()
   print "set of IPv4 addresses %s" % all_addrs
   print "set of IPv6 addresses %s" % all_v6_addrs
   for item in mgmt_vmks:
      for addr in all_addrs:
        if addr['Name'] == item:
          v4addrs.append(addr['IPv4 Address'])

      # find IPv6 addresses preferred DAD state from the vmk device interface'''
      for addr in all_v6_addrs:
        if addr['Interface'] == item and addr['Status'] == 'PREFERRED':
          v6addrs.append(addr['Address'])

   print "\n\nResults\n\nset of IPv4 management addresses: %s" % v4addrs
   print "set of IPv6 management addresses: %s" % v6addrs

if __name__ == "__main__":
    main()
