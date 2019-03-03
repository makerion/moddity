#!/usr/bin/python
import sys
import usb.core
# import usb.backend.libusb1

# find USB devices
# backend = usb.backend.libusb1.get_backend(find_library=lambda x: "/usr/lib/libusb-1.0.so")
dev = usb.core.find(find_all=True) #, backend=backend)
# loop through devices, printing vendor and product ids in decimal and hex
for cfg in dev:
  sys.stdout.write('Decimal VendorID=' + str(cfg.idVendor) + ' & ProductID=' + str(cfg.idProduct) + '\n')
  sys.stdout.write('Hexadecimal VendorID=' + hex(cfg.idVendor) + ' & ProductID=' + hex(cfg.idProduct) + '\n\n')
