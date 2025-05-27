#!/bin/sh
set -e

PROJECTS=$(cat projects)

for i in $PROJECTS; do
    rm -rf $i/build
    cmake -S $i -B $i/build -G Ninja
    ninja -C $i/build

    cp $i/build/$i.aq32 ../../../../EndUser/sdcard/cores/aq32/

done
