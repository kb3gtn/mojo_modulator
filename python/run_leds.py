#!/usr/bin/env python2.7
# This is a simple python script to write data into the LED register
# and make the LEDS blink in different forms
#
# On mojo_modulator design, led_reg is address 0

import serial
import io
import struct
import time

def main():
    ser = serial.Serial('/dev/ttyUSB0', 115200, timeout=1)

    # run a simple counter
    #simple_counter(ser)

    # run led pwm demo via rapid register updating..
    brightness_testing(ser)


#################################
## brightness pwm demo stuff

def pwm_state(pwm_counter, level):
    if ( level == 0 ):
        # always off, return 0
        return 0

    if ( level == 1 ):
        if not ( pwm_counter % 64 ):
            return 1
        else:
            return 0

    if ( level == 2 ):
        if not ( pwm_counter % 48 ):
            return 1
        else:
            return 0

    if ( level == 2 ):
        if not ( pwm_counter % 32 ):
            return 1
        else:
            return 0

    if ( level == 3 ):
        if not ( pwm_counter % 24 ):
            return 1
        else:
            return 0

    if ( level == 4 ):
        if not ( pwm_counter % 16 ):
            return 1
        else:
            return 0

    if ( level == 5 ):
        if not ( pwm_counter % 10 ):
            return 1
        else:
            return 0

    if ( level == 6 ):
        if not ( pwm_counter % 5 ):
            return 1
        else:
            return 0

    if ( level == 7 ):
        if not ( pwm_counter % 3 ):
            return 1
        else:
            return 0

    if ( level == 8 ):
        return 1

# bits is a vector a 1's and 0's, 8 in length..
def bits_2_byte( bits ):
    return (bits[0]*1)+(bits[1]*2)+(bits[2]*4)+(bits[3]*8)+(bits[4]*16)+(bits[5]*32)+(bits[6]*64)+(bits[7]*128)


def brightness_testing(ser):
    pwm_counter = 0   # counter used for PWM period tracking
    bits = [0,0,0,0,0,0,0,0]; 
    while (1):   
        try:
            # roll over counter at 256
            if ( pwm_counter >= 256 ):
                pwm_counter = 0;
        
            # figure out if each bit is on
            bits[0] = pwm_state(pwm_counter, 1)  #dim
            bits[1] = pwm_state(pwm_counter, 2) 
            bits[2] = pwm_state(pwm_counter, 3) 
            bits[3] = pwm_state(pwm_counter, 4) 
            bits[4] = pwm_state(pwm_counter, 5) 
            bits[5] = pwm_state(pwm_counter, 6) 
            bits[6] = pwm_state(pwm_counter, 7) 
            bits[7] = pwm_state(pwm_counter, 8)  # 100% bright

            byte = bits_2_byte( bits )
            #print "byte = "+str(byte)
            buf = struct.pack('BB', 0x00, byte )
            ser.write(buf)
            pwm_counter = pwm_counter + 1 
        except KeyboardInterrupt:
            buf = struct.pack('BB', 0x00, 0x00 )
            ser.write(buf)
            print "Shutting down.."
            time.sleep(1)  # wait for serial buffer to flush, before program exits..
            return 0


############################################
# performs a simple counter on the LEDs
def simple_counter(ser):
    count = 0
    while (1):
        if ( count == 256 ):
            count = 0;
        else:
            buf = struct.pack('BB', x00, count) 
            ser.write(buf);
            count=count+1
            time.sleep(0.01)


# Entry point for this python script,
# runs main()
if __name__ == "__main__":
    main()

