#!/bin/bash

# args
DIR="$1"
SCRIPTDIR="$(dirname $0)"

[[ -z "$DIR" ]] && DIR="."

# defines
DLOADID="05c6:9008"
SDMODE="05c6:9006"
DEVICE=`ls -lah /dev/disk/by-id/ | grep usb\-Qualcomm_MMC | head -n 1 | awk '{ print $11 }' | sed 's/\..\/..//'`

# usb info
USBNAME="$(lsusb | grep Qualcomm)"
USBID="$(lsusb | grep Qualcomm  | awk '{ print $6 }')"

# get mode
MODE="unknown"
if [ "$USBID" == "$DLOADID" ]; then
	MODE="dload"
elif [ "$USBID" == "$SDMODE" ]; then
	MODE="sd"
else
	echo "No compatible devices found!";
	exit 1
fi

flash_dload() {
	"$SCRIPTDIR/hex2bin" $DIR/images/MPRG8064.hex || (echo "Error in hex2bin";exit 1)
	"$SCRIPTDIR/qdload.pl" -pfile $DIR/images/MPRG8064.bin -lfile $DIR/images/8064_msimage.mbn -lreset || (echo "Error in qdload";exit 1)
}

flash_sd() {
	"$SCRIPTDIR/program.py" "$DIR" "/dev$DEVICE"
	"$SCRIPTDIR/patch.py" "$DIR" "/dev$DEVICE"
}

echo "DEVICES:"
echo "$USBNAME" | awk '$0="\t"$0'
echo -e "\nWould flash to $USBID(/dev$DEVICE) in $MODE mode"
	
echo -e -n "\nContinue? [y/n]: "
read choice
if [ $choice == "y" ]; then
	[[ "$MODE" == "dload" ]] && flash_dload
	[[ "$MODE" == "sd" ]] && flash_sd
	echo "Done."
	exit 0
else
	echo "Stop."
	exit 1
fi
