`default_nettype none
`timescale 1 ns / 1 ps

module t80_reg(
    input  wire       Clk,
    input  wire       CEN,
    input  wire       WEH,
    input  wire       WEL,
    input  wire [2:0] AddrA,
    input  wire [2:0] AddrB,
    input  wire [2:0] AddrC,
    input  wire [7:0] DIH,
    input  wire [7:0] DIL,
    output wire [7:0] DOAH,
    output wire [7:0] DOAL,
    output wire [7:0] DOBH,
    output wire [7:0] DOBL,
    output wire [7:0] DOCH,
    output wire [7:0] DOCL);

    reg [7:0] RegsH [7:0] /* synthesis syn_ramstyle = "distributed_ram" */;
    reg [7:0] RegsL [7:0] /* synthesis syn_ramstyle = "distributed_ram" */;

    always @(posedge Clk) if (CEN && WEH) RegsH[AddrA] = DIH; 
    always @(posedge Clk) if (CEN && WEL) RegsL[AddrA] = DIL; 

    assign DOAH = RegsH[AddrA];
    assign DOAL = RegsL[AddrA];

    assign DOBH = RegsH[AddrB];
    assign DOBL = RegsL[AddrB];

    assign DOCH = RegsH[AddrC];
    assign DOCL = RegsL[AddrC];

endmodule
