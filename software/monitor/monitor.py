import serial

interface = serial.Serial('/dev/ttyACM0', 500000, timeout=60)

while (True):
    # get a cmd value
    op = interface.read(1)[0]
    
    # op[7:4] is the op type, op[3:0] depends on the command
    if (op & 0xf0) == 0x10:
        # A operation
        data = interface.read(3)
        address = int.from_bytes(data, byteorder='big', signed=False)
        print("Address: 0x{:06x}".format(address))

    elif (op & 0xf0) == 0x20:
        # D operation
        uds = (op & 0x02) != 0;
        lds = (op & 0x01) != 0;
        if (op & 0x04) != 0:
            # read operation
            data = input("Read Data (high = {}, low = {}) = ".format(uds, lds))
            value = int(data, 16)
            if (uds and lds):
                data = value.to_bytes(2, byteorder='big', signed=False)
                interface.write(data)
            else:
                data = value.to_bytes(1, byteorder='big', signed=False)
                interface.write(data)

        else:
            # write operation
            print("Write Data (high = {}, low = {}) = ".format(uds, lds))
            if (uds and lds):
                data = interface.read(2)
                value = int.from_bytes(data, byteorder='big', signed=False)
                print("0x{:04x}".format(value))
            else:
                data = interface.read(1)
                value = int.from_bytes(data, byteorder='big', signed=False)
                print("0x{:02x}".format(0))

    # write ack
    interface.write(bytearray([0xaa]))

