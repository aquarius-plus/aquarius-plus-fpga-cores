#!/bin/bash
set -e
ninja -C build
curl -X DELETE http://aqplus-minivz.local/cores/pico-aq/pico-aq.bin
curl -X PUT -T build/pico-aq.bin http://aqplus-minivz.local/cores/pico-aq/pico-aq.bin
printf '\x1E' | curl --data-binary @- http://aqplus-minivz.local/keyboard
