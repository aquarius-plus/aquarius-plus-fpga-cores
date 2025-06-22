`default_nettype none
`timescale 1 ns / 1 ps

module fm_ch_attr(
    input  wire        clk,
    input  wire  [4:0] addr,
    input  wire [31:0] wrdata,
    input  wire        wren,
    output wire [31:0] rddata,

    input  wire  [4:0] ch_sel,
    output wire  [6:0] ch_pan,
    output wire  [2:0] ch_fb,
    output wire  [2:0] ch_block,
    output wire  [9:0] ch_fnum
);

    localparam NUMBITS = 23;

    wire [(NUMBITS-1):0] a_rddata;
    wire [(NUMBITS-1):0] a_wrdata = {wrdata[26:17], wrdata[12:0]};

    assign rddata = {10'b0, a_rddata[17:13], 4'b0, a_rddata[12:0]};

    wire [(NUMBITS-1):0] b_rddata;
    assign {
        ch_pan,
        ch_fb,
        ch_block,
        ch_fnum
    } = b_rddata;

    generate
        genvar i;
        for (i=0; i<NUMBITS; i=i+1) begin: ram_gen
            RAM32X1D ram(
                .WCLK(clk),
                .D(a_wrdata[i]),
                .WE(wren),

                .A4(addr[4]),
                .A3(addr[3]),
                .A2(addr[2]),
                .A1(addr[1]),
                .A0(addr[0]),
                .SPO(a_rddata[i]),

                .DPRA4(ch_sel[4]),
                .DPRA3(ch_sel[3]),
                .DPRA2(ch_sel[2]),
                .DPRA1(ch_sel[1]),
                .DPRA0(ch_sel[0]),
                .DPO(b_rddata[i]));
        end
    endgenerate

endmodule
