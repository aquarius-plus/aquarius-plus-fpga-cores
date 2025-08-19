`default_nettype none
`timescale 1 ns / 1 ps

module T80 #(
    parameter Mode   = 0
) (
    input  wire         RESET_n,
    input  wire         CLK_n,
    input  wire         CEN,
    input  wire         WAIT_n,
    input  wire         INT_n,
    input  wire         NMI_n,
    output wire         IORQ,
    output wire         NoRead,
    output wire         Write,
    output wire  [15:0] A,
    input  wire   [7:0] DInst,
    input  wire   [7:0] DI,
    output wire   [7:0] DO,
    output wire   [2:0] MC,
    output wire   [2:0] TS,
    output wire         IntCycle,
    input  wire         out0
);

endmodule
