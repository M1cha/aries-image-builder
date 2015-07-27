#!/bin/bash

rm -Rf ./packages
mkdir ./packages
for xml in *.xml
do
	# cleanup
	rm -Rf ./out

	# build
	./build.sh "$xml"

	# create name
	NAME=$(echo "$xml" | sed 's/partition/aries_core/g')
	NAME="${NAME%.*}"
	ZIP="../packages/${NAME}.zip"

	# remove old zip
	rm -f "$ZIP"

	# build new zip
	cd ./out
	touch "$NAME"
	zip -r "$ZIP" .
	cd ..
done
