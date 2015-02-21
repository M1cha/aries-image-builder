#!/usr/bin/python

from xml.dom.minidom import parse, parseString
import sys
import os
import subprocess

def do_program(package, device):
	print "Programming "+device+" with "+package
	device_size = int(os.popen("lsblk -ndbo SIZE "+device).read())

	#   <program SECTOR_SIZE_IN_BYTES="512" file_sector_offset="0" filename="NON-HLOS.bin" 
	# label="modem" num_partition_sectors="174080" physical_partition_number="0" size_in_KB="87040.0"
	# sparse="false" start_byte_hex="0x4400" start_sector="34"/>
	dom = parse('out/images/rawprogram_core.xml')
	for node in dom.getElementsByTagName('program'):
		ns = {'__builtins__': None, 'NUM_DISK_SECTORS':device_size/512}

		# file
		file_sector_offset = int(node.attributes["file_sector_offset"].value)
		filename = node.attributes["filename"].value
		# part: size
		sector_size = int(node.attributes["SECTOR_SIZE_IN_BYTES"].value)
		sector_num = int(node.attributes["num_partition_sectors"].value)
		size = float(node.attributes["size_in_KB"].value)
		# part: options
		label = node.attributes["label"].value
		partition_num = int(node.attributes["physical_partition_number"].value)
		sparse = bool(node.attributes["sparse"].value)
		# part: position
		start_sector = int(eval(node.attributes["start_sector"].value, ns))
		start_byte = eval(node.attributes["start_byte_hex"].value, ns)

		# validate size
		if sector_size*sector_num/1024.0 != size:
			print "Given Partition size is wrong!"
			print str(sector_size*sector_num/1024.0)+"!="+str(size)
			print node.toxml()
			sys.exit(1)

		# validate position
		if start_sector*sector_size != start_byte:
			print "Given start byte is wrong!"
			print str(start_sector*sector_size)+"!="+str(start_byte)
			print node.toxml()
			sys.exit(1)

		# TODO: implement file offset
		if file_sector_offset!=0:
			print "file_sector_offset!=0 is not yet supported!"
			print node.toxml()
			sys.exit(1)

		# unique vars:
		# start_byte
		# size
		# filename
		# file_sector_offset
		# label, partition_num, sparse

		# translate filename
		if filename == "":
			filename = "/dev/zero"
		else: filename = package+"/images/"+filename
		
		if subprocess.call("dd if="+filename+" of="+device+" bs="+str(sector_size)+" seek="+str(start_sector)+" count="+str(sector_num), shell=True)!=0:
			print "Error writing!"
			print node.toxml()
			sys.exit(1)

if __name__ == "__main__":
	do_program(sys.argv[1], sys.argv[2])
