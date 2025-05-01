#!/bin/sh
set -e
ninja -C build
cp build/aq32rom.bin ~/Work/aquarius-plus/EndUser/sdcard/aq32.rom
~/Work/aquarius-plus/System/emulator/build/aqplus-emu -t ' run aq32.core\n'

