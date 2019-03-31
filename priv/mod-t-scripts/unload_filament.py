#!/usr/bin/env python

#Just tells the mod-t to enter unload filament mode. It also polls the mod-t for status
#This status information can be used to prompt the user to proceed as intended.

import sys
import os
import usb.core
import usb.backend.libusb1
import usb.util
import time

# Read pending data from MOD-t (bulk reads of 64 bytes)
def read_modt(ep):
 text=''.join(map(chr, dev.read(ep, 64)))
 fulltext = text
 while len(text)==64:
        text=''.join(map(chr, dev.read(ep, 64)))
        fulltext = fulltext + text
 return fulltext

#Find the Mod-T - we should probably see if it's in DFU mode, too
#That way we can do emergency flashes from recovery mode
backend = usb.backend.libusb1.get_backend(find_library=lambda x: "/usr/lib/libusb-1.0.so")
dev = usb.core.find(idVendor=0x2b75, idProduct=0x0002, backend=backend)

#If we didn't find a Mod-T we need to throw an error
if dev is None:
	raise ValueError('No Mod-T detected')

#Set active configuration (first is default)
dev.set_configuration()

#Same as all the other files, this packet is not readable
#The second packet however, is

dev.write(2, bytearray.fromhex('246c0093ff'))
dev.write(2, '{"transport":{"attrs":["request","twoway"],"id":11},"data":{"command":{"idx":51,"name":"unload_initiate"}}};')
