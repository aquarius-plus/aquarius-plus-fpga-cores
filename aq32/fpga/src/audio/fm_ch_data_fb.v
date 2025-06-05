`default_nettype none
`timescale 1 ns / 1 ps

module fm_ch_data_fb(
    input  wire        clk,
    input  wire  [4:0] idx,
    input  wire [25:0] wrdata,
    input  wire        wren,
    output wire [25:0] rddata
);

    localparam NUMBITS = 26;

    generate
        genvar i;
        for (i=0; i<NUMBITS; i=i+1) begin: ram_gen
            RAM32X1S ram(
                .WCLK(clk),
                .D(wrdata[i]),
                .WE(wren),

                .A4(idx[4]),
                .A3(idx[3]),
                .A2(idx[2]),
                .A1(idx[1]),
                .A0(idx[0]),
                .O(rddata[i]));
        end
    endgenerate

endmodule
