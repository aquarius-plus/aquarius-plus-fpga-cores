#!/usr/bin/env python3
import argparse
import struct
import math

lut_logsin = [
    round(-256 * math.log2(math.sin((x + 0.5) / 256 * (math.pi / 2))))
    for x in range(256)
]

lut_exp = [round((math.pow(2, (255 - x) / 256) - 1) * 1024) for x in range(256)]


f = open("lut_logsin.v", "wt")

print(
    """`default_nettype none
`timescale 1 ns / 1 ps

(* rom_style = "distributed" *)
module lut_logsin(
    input  wire  [7:0] idx,
    output reg  [11:0] value
);

    always @* case (idx)""",
    file=f,
)

for i in range(256):
    print(f"        8'h{i:02X}: value = 12'h{lut_logsin[i]:03x};", file=f)

print("        default: value = 12'h0;", file=f)
print("    endcase", file=f)
print("\nendmodule", file=f)
f.close()


f = open("lut_exp.v", "wt")

print(
    """`default_nettype none
`timescale 1 ns / 1 ps

(* rom_style = "distributed" *)
module lut_exp(
    input  wire  [7:0] idx,
    output reg   [9:0] value
);

    always @* case (idx)""",
    file=f,
)

for i in range(256):
    print(f"        8'h{i:02X}: value = 10'h{lut_exp[i]:03x};", file=f)

print("        default: value = 10'h0;", file=f)
print("    endcase", file=f)
print("\nendmodule", file=f)
f.close()
