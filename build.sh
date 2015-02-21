#!/bin/bash

set -e

PARTXML="partition.xml"
[[ -n "$1" ]] && PARTXML="$1"

ROOT="$(pwd)"
OUT="$ROOT/out"
FILES="$ROOT/files"
PREBUILTS="$ROOT/prebuilts"
SCRIPTS="$PREBUILTS/scripts"

PARTITIONS_ALL="tz.mbn sbl1.mbn sbl2.mbn sbl3.mbn rpm.mbn emmc_appsboot.mbn misc.img NON-HLOS.bin system.img cache.img userdata.img storage.img recovery.img boot.img"
PARTITIONS_CORE="tz.mbn sbl1.mbn sbl2.mbn sbl3.mbn rpm.mbn emmc_appsboot.mbn misc.img NON-HLOS.bin recovery.img"

copy_file() {
	if [ "$2" == "1" ]; then
		cp "$1" "$OUT/images/"
	else
		cp "$PREBUILTS/$1" "$OUT/images/"
	fi
}

create_raw_image() {
	dd if=/dev/zero of="$OUT/images/$1.img" bs=$2 count=1
}

create_ext4_fs() {
	create_raw_image "$1" "$2"
	mkfs.ext4 -F "$OUT/images/$1.img"
}

get_partname() {
	partname=${1%.*}

	[ "$partname" == "emmc_appsboot" ] && partname="aboot"
	[ "$partname" == "NON-HLOS" ] && partname="modem+modem1"
	[ "$partname" == "system" ] && partname="system+system1"
	[ "$partname" == "boot" ] && partname="boot+boot1"
	[ "$partname" == "gpt_both0" ] && partname="partition"

	echo "$partname"
}

create_script_linux() {
	outfile="$OUT/$1.sh"
	partitions="$2"
	
	rm -f "$outfile"
	touch "$outfile"
	chmod +x "$outfile"
	echo "fastboot \$* getvar soc-id 2>&1 | grep \"^soc-id: *109\$\"" >> "$outfile"
	echo "if [ \$? -ne 0 ] ; then echo \"Missmatching image and device\"; exit 1; fi" >> "$outfile"
	for file in $partitions ; do
		partname=$(get_partname "$file")

		echo "fastboot \$* flash $partname \"\`dirname \$0\`/images/$file\"" >> "$outfile"
		echo "if [ \$? -ne 0 ] ; then echo \"Flash $(echo $partname | cut -d+ -f1) error\"; exit 1; fi" >> "$outfile"
	done
	echo "fastboot \$* reboot" >> "$outfile"
	echo "if [ \$? -ne 0 ] ; then echo \"Reboot error\"; exit 1; fi" >> "$outfile"
}

create_script_windows() {
	outfile="$OUT/$1.bat"
	partitions="$2"
	
	rm -f "$outfile"
	touch "$outfile"
	chmod +x "$outfile"
	echo "fastboot %* getvar soc-id 2>&1 | findstr /r /c:\"^soc-id: *109\" || echo Missmatching image and device" >> "$outfile"
	echo "fastboot %* getvar soc-id 2>&1 | findstr /r /c:\"^soc-id: *109\" || exit /B 1" >> "$outfile"
	for file in $partitions ; do
		partname=$(get_partname "$file")
		echo "fastboot %* flash $partname \"%~dp0images\\$file\" || @echo \"Flash $(echo $partname | cut -d+ -f1) error\" && exit /B 1" >> "$outfile"
	done
	echo "fastboot %* reboot || @echo \"Reboot error\" && exit /B 1" >> "$outfile"
}

create_script() {
	create_script_linux "$1" "$2"
	create_script_windows "$1" "$2"
}

rm -rf "$OUT"
mkdir "$OUT"
mkdir "$OUT/images"

# scripts
#create_script flash_all "$PARTITIONS_ALL"
#create_script flash_all_except_data_storage "$(echo "$PARTITIONS_ALL" | sed -e 's/\<storage.img\>//g' | sed -e 's/\<userdata.img\>//g')"
#create_script flash_all_except_storage "$(echo "$PARTITIONS_ALL" | sed -e 's/\<storage.img\>//g')"
create_script flash_core "$PARTITIONS_CORE"
create_script flash_partition_table_and_core "gpt_both0.bin $PARTITIONS_CORE"

# generate partition table
mkdir "$OUT/ptool"
cd "$OUT/ptool"
perl "$ROOT/ptool.py" -x "$ROOT/$PARTXML" -p0 -f gpt
cd "$ROOT"

# remove persist from rawprogram - for some reason Xiaomi does that too
sed -i '/"persist"/d' out/ptool/rawprogram0.xml

cp out/ptool/rawprogram0.xml out/ptool/rawprogram_core.xml
sed -i '/"system"/d' out/ptool/rawprogram_core.xml
sed -i '/"system1"/d' out/ptool/rawprogram_core.xml
sed -i '/"cache"/d' out/ptool/rawprogram_core.xml
sed -i '/"userdata"/d' out/ptool/rawprogram_core.xml
sed -i '/"storage"/d' out/ptool/rawprogram_core.xml
sed -i '/"boot"/d' out/ptool/rawprogram_core.xml
sed -i '/"boot1"/d' out/ptool/rawprogram_core.xml

# DLOAD
#copy_file out/ptool/rawprogram0.xml 1
copy_file out/ptool/rawprogram_core.xml 1
copy_file out/ptool/patch0.xml 1
copy_file out/ptool/gpt_both0.bin 1
copy_file out/ptool/gpt_main0.bin 1
copy_file out/ptool/gpt_backup0.bin 1
copy_file dload/MPRG8064.hex
copy_file dload/8064_msimage.mbn

# remove cleanup ptool directory
rm -R "$OUT/ptool"

# bootloaders
copy_file bootloaders/sbl1.mbn
copy_file bootloaders/sbl2.mbn
copy_file bootloaders/sbl3.mbn
copy_file bootloaders/rpm.mbn
copy_file bootloaders/tz.mbn
copy_file bootloaders/emmc_appsboot.mbn

# misc
copy_file NON-HLOS.bin
copy_file persist.img
copy_file recovery.img

# generate common partitions
create_raw_image dummy 8192
create_raw_image misc 8192
#create_raw_image cache 33554432
#create_ext4_fs userdata 536870912 # needs extend
#create_ext4_fs storage 320864256  # needs extend
