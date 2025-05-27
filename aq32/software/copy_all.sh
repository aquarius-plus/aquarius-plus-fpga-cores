#!/bin/sh
set -e
./compile_all.sh

PROJECTS=$(cat projects)
for i in $PROJECTS; do
    echo Copying $i
    cp -f $i/build/$i.aq32 ../../../../EndUser/sdcard/cores/aq32/
done

cp -f basic/help/content/basic.hlp ../../../../EndUser/sdcard/cores/aq32/

echo Done.
