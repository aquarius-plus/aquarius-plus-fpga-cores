`default_nettype none
`timescale 1 ns / 1 ps

module fm_op_data_phase(
    input  wire        clk,
    input  wire  [5:0] idx,
    input  wire [18:0] wrdata,
    input  wire        wren,
    output wire [18:0] rddata
);

    localparam NUMBITS = 19;

    generate
        genvar i;
        for (i=0; i<NUMBITS; i=i+1) begin: ram_gen
            RAM64X1S ram(
                .WCLK(clk),
                .D(wrdata[i]),
                .WE(wren),

                .A5(idx[5]),
                .A4(idx[4]),
                .A3(idx[3]),
                .A2(idx[2]),
                .A1(idx[1]),
                .A0(idx[0]),
                .O(rddata[i]));
        end
    endgenerate

endmodule
