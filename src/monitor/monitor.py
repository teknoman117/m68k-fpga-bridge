#!/usr/bin/env python

import serial

interface = serial.Serial('/dev/ttyACM0', 500000, timeout=60)

while (True):
    # read address for bus cycle
    address_in = interface.read(3)
    address = int.from_bytes(address_in, byteorder='big', signed=False)

    # bus cycle
    op = int(interface.read(1)[0])
    data_in = interface.read(2)

    fc = (op >> 0x3) & 0x7

    if (op & 0x04) == 0:
        # write cycle
        # low byte cycle
        if (op & 0x3) == 0x1:
            print("Address 0x{:06x}: Wrote Byte: 0x{:02x}".format(address, data_in[1]))
        # high byte cycle
        elif (op & 0x3) == 0x2:
            print("Address 0x{:06x}: Wrote Byte: 0x{:02x}".format(address+1, data_in[0]))
        # word cycle
        elif (op & 0x3) == 0x3:
            word = int.from_bytes(data_in, byteorder='big', signed=False)
            print("Address 0x{:06x}: Wrote Word: 0x{:04x}".format(address, word))
        # response
        response = bytes('D', 'ascii')
    else:
        # read cycle
        # low byte cycle
        if (op & 0x3) == 0x1:
            data = input("Address 0x{:06x}: Read Byte: ".format(address))
            value = int(data, 16)
            response = bytearray('L', 'ascii')
            response.extend(value.to_bytes(1, byteorder='little', signed=False))
        elif (op & 0x3) == 0x2:
            data = input("Address 0x{:06x}: Read Byte: ".format(address+1))
            value = int(data, 16)
            response = bytearray('H', 'ascii')
            response.extend(value.to_bytes(1, byteorder='little', signed=False))
        elif (op & 0x3) == 0x3:
            data = input("Address 0x{:06x}: Read Word: ".format(address))
            value = int(data, 16)
            response = bytearray('B', 'ascii')
            response.extend(value.to_bytes(2, byteorder='little', signed=False))
        # response
        response.extend(bytes('D', 'ascii'))

    # write response
    interface.write(response)
