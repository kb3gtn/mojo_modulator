#!/usr/bin/env python2.7
# This script programs the NCO register to output a particular frequency
#
# PRF
#

import serial
import io
import struct
import time
import sys

# constant
sample_rate = 80e6
reg0_addr = 8
reg1_addr = 9
reg2_addr = 10
reg3_addr = 11
serial_device = "/dev/ttyUSB0"

# write to a register on the fpga
# ser: serial object
# addr: 0 -> 127
# value: 0 -> 255
def write_addr( ser, addr, value ):
    print "Debug: writing to address "+str(addr)+" the value 0x"+hex(value)+"."
    buf = struct.pack('BB', addr, value )
    ser.write(buf)

# test to see if string is a number
def is_number(s):
    try:
        float(s)
        return True
    except ValueError:
        return False

# program DDS frequency in Hz
# serial port object
# frequency (Hz)
# sample_rate (Hz)
def set_nco_freq( ser, frequency, sample_rate ):
    fs_over_2 = sample_rate / 2

    if float(frequency) > float(fs_over_2):
        print "Frequency ("+str(frequency)+") can't be > 1/2 of the sample rate of "+str(fs_over_2)
        return -1

    # compute nco freq tunning word
    nco_ftw = int( ( float(frequency)/float(fs_over_2) )/2.0 * (2**32)-1)
    #print "Debug: freq/fs_over_2 = "+str( float(frequency) / float(fs_over_2) )+" nco_ftw = "+str(nco_ftw)
    actual_freq = ( float(nco_ftw) / float((2**32)-1) ) * float(fs_over_2)
    #print "Debug: nco_ftw / 2^32-1 = "+str( ( float(nco_ftw) / float( (2**32)-1) ))
   
    print "setting nco to frequency "+str(actual_freq)+" (FTW: "+hex(nco_ftw)+" )"
 
    # break up frequency tunning word into 4 bytes
    reg3 = (nco_ftw & 0xFF000000) >> 24
    reg2 = (nco_ftw & 0x00FF0000) >> 16
    reg1 = (nco_ftw & 0x0000FF00) >> 8
    reg0 = (nco_ftw & 0x000000FF)

    print "new register value: "+hex(reg3)+" "+hex(reg2)+" "+hex(reg1)+" "+hex(reg0)

    write_addr( ser, reg0_addr, reg0 )
    write_addr( ser, reg1_addr, reg1 )
    write_addr( ser, reg2_addr, reg2 )
    write_addr( ser, reg3_addr, reg3 )


# sarguments: <serial_device> <frequency>
if __name__ == "__main__":
    if ( len(sys.argv) > 2 ):
        # serial device is arg 1
        try:
            ser = serial.Serial(sys.argv[1], 115200, timeout=1)
        except serial.serialutil.SerialException:
            print "failed to open serial port.."
            sys.exit()
  
        frequency = sys.argv[2]
        if ( is_number(frequency) ):
            set_nco_freq( ser, frequency, sample_rate )
        else:
            print "frequency ("+str(frequency)+") is expected to be a number.."
    else:
        print "Wrong number of arguments.  Got: "+str(sys.argv) 
   
   


