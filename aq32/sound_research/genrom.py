#!/usr/bin/env python3
import argparse
import struct
import math

bsl = [
    round(-256 * math.log2(math.sin((x + 0.5) / 256 * (math.pi / 2))))
    for x in range(256)
]

bsp = [round((math.pow(2, x / 256) - 1) * 1024) for x in range(256)]


f = open("fmlut.v", "wt")

print(
    """`default_nettype none
`timescale 1 ns / 1 ps

module fmlut(
    input  wire        clk,
    input  wire  [8:0] addr,
    output reg  [11:0] rddata
);

    always @(posedge clk) case (addr)""",
    file=f,
)

for i in range(256):
    print(f"        9'h{i:03X}:  rddata <= 12'd{bsl[i]};", file=f)

for i in range(256):
    print(f"        9'h{i+256:03X}:  rddata <= 12'd{bsp[i]};", file=f)

print("        default: rddata <= 12'd0;", file=f)

print("    endcase", file=f)
print("\nendmodule", file=f)
