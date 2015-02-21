#!/usr/bin/python

from xml.dom.minidom import parse, parseString
import sys
import os
import subprocess
import struct
import ctypes

DEVICE_PATH = ""
SECTOR_SIZE_IN_BYTES = 0

# A8h reflected is 15h, i.e. 10101000 <--> 00010101
def reflect(data,nBits):

    reflection = 0x00000000
    bit = 0

    for bit in range(nBits):
        if(data & 0x01):
            reflection |= (1 << ((nBits - 1) - bit))
        data = (data >> 1);

    return reflection

def CalcCRC32(array,Len):
   k        = 8;            # length of unit (i.e. byte)
   MSB      = 0;
   gx	    = 0x04C11DB7;   # IEEE 32bit polynomial
   regs     = 0xFFFFFFFF;   # init to all ones
   regsMask = 0xFFFFFFFF;   # ensure only 32 bit answer

   ##print "Calculating CRC over byte length of %i" % Len

   for i in range(Len):
      DataByte = array[i]
      DataByte = reflect( DataByte, 8 );
   
      for j in range(k):
        MSB  = DataByte>>(k-1)  ## get MSB
        MSB &= 1                ## ensure just 1 bit
   
        regsMSB = (regs>>31) & 1

        regs = regs<<1          ## shift regs for CRC-CCITT
   
        if regsMSB ^ MSB:       ## MSB is a 1
            regs = regs ^ gx    ## XOR with generator poly
   
        regs = regs & regsMask; ## Mask off excess upper bits

        DataByte <<= 1          ## get to next bit

   
   regs          = regs & regsMask ## Mask off excess upper bits
   ReflectedRegs = reflect(regs,32) ^ 0xFFFFFFFF;

   #print "CRC is 0x%.8X\n" % ReflectedRegs
   
   return ReflectedRegs

def xml_crc32(offset, length):
	data = [0]*length
	pos = 0

	f = open(DEVICE_PATH, "rb")
	f.seek(offset*SECTOR_SIZE_IN_BYTES, 0)
	try:
		data = bytearray(f.read(length))
	finally:
		f.close()

	return CalcCRC32(data, length)

def do_program(package, device):
	global DEVICE_PATH
	global SECTOR_SIZE_IN_BYTES
	DEVICE_PATH = device

	print "Patching "+device+" with "+package
	device_size = int(os.popen("lsblk -ndbo SIZE "+device).read())

	# <patch SECTOR_SIZE_IN_BYTES="512" byte_offset="296" filename="gpt_main0.bin" physical_partition_number="0"
	# size_in_bytes="8" start_sector="8" value="NUM_DISK_SECTORS-34." what="Update..."/>
	dom = parse('out/images/patch0.xml')
	for node in dom.getElementsByTagName('patch'):
		ns = {'__builtins__': None, 'NUM_DISK_SECTORS':device_size/512, 'CRC32':xml_crc32}

		sector_size = int(node.attributes["SECTOR_SIZE_IN_BYTES"].value)
		SECTOR_SIZE_IN_BYTES = sector_size

		byte_offset = int(node.attributes["byte_offset"].value)
		filename = node.attributes["filename"].value
		partition_num = int(node.attributes["physical_partition_number"].value)
		size = int(node.attributes["size_in_bytes"].value)
		start_sector = int(eval(node.attributes["start_sector"].value, ns))
		value = int(eval(node.attributes["value"].value, ns))
		what = node.attributes["what"].value

		# skip file patching
		if filename!="DISK":
			continue

		# Print message
		print what

		# open device
		f = open(device, "wb")

		# seek to target position
		f.seek(start_sector*sector_size + byte_offset, 0)

		# write value
		f.write(struct.pack("<Q", value))

		# close device
		f.close()


if __name__ == "__main__":
	do_program(sys.argv[1], sys.argv[2])
