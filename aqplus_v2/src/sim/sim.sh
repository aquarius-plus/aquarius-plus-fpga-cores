#!/bin/sh
set -e
rm -rf work/
vlib work
vmap work work
vlog /opt/Xilinx/14.7/ISE_DS/ISE/verilog/src/glbl.v
vlog is61c5128as.v is61lv5128al.v tb.v ../*.v ../aqp_shared/*.v ../video/*.v ../wrappers/*.v
vcom ../t80/T80_Pack.vhd ../t80/T80_MCode.vhd ../t80/T80_ALU.vhd ../t80/T80_Reg.vhd ../t80/T80.vhd

vsim -voptargs="+acc=npr" -L xilinx work.glbl work.tb -do "do wave.do; run 100 us"
