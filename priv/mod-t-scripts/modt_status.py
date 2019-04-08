#!/usr/bin/env python

# Requires pyusb and permissions to read/write the mod-t via USB.
# Just polls the Mod-T for status JSON

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

# Find MOD-t usb device
backend = usb.backend.libusb1.get_backend(find_library=lambda x: "/usr/lib/libusb-1.0.so")
dev = usb.core.find(idVendor=0x2b75, idProduct=0x0002, backend=backend)

# was it found?
if dev is None:
 print('{"error": "Device not found"}')
 raise ValueError('Device not found')

dev.write(4, '{"metadata":{"version":1,"type":"status"}}')
print(read_modt(0x83))
