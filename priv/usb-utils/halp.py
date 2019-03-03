import os
os.environ['PYUSB_DEBUG'] = 'debug'
import usb.core
import usb.backend.libusb1

backend = usb.backend.libusb1.get_backend(find_library=lambda x: "/usr/lib/libusb-1.0.so")
usb.core.find(backend=backend)
