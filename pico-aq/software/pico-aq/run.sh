#!/bin/sh
set -e
ninja -C build
mkdir -p ~/Work/aquarius-plus/EndUser/sdcard/cores/pico-aq
cp build/pico-aq.bin ~/Work/aquarius-plus/EndUser/sdcard/cores/pico-aq/pico-aq.bin
~/Work/aquarius-plus/System/emulator/build/aqplus-emu -t ' run pico-aq.core\n'
