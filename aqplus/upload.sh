#!/bin/sh
curl -X DELETE http://aqplus-minivz/cores/aqplus/aqplus.core
curl -X PUT -T aqp_top.bit http://aqplus-minivz/cores/aqplus/aqplus.core
