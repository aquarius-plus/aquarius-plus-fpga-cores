#!/bin/sh
set -e
make -C ../fpgarom
./genrom.py ../fpgarom/zout/fpgarom.cim rom.v
