#!/bin/sh
set -e
ninja -C build
curl -X DELETE http://aqplus-minivz/cores/aq32/basic.aq32
curl -X PUT -T build/basic.aq32 http://aqplus-minivz/cores/aq32/basic.aq32
# printf '\x1E' | curl --data-binary @- http://aqplus-minivz/keyboard
