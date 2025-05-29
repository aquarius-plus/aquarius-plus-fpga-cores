`default_nettype none
`timescale 1 ns / 1 ps

module sprattr(
    input  wire        clk,
    input  wire        reset,

    input  wire  [6:0] sprattr_addr,
    output wire [31:0] sprattr_rddata,
    input  wire [31:0] sprattr_wrdata,
    input  wire        sprattr_wren,

    input  wire  [5:0] spr_sel,
    output wire  [8:0] spr_x,
    output wire  [7:0] spr_y,
    output wire  [9:0] spr_idx,
    output wire        spr_priority,
    output wire  [1:0] spr_palette,
    output wire        spr_h16,
    output wire        spr_vflip,
    output wire        spr_hflip
);

    localparam NUMBITS = 33;

    wire [(NUMBITS-1):0] a_rddata;
    wire [(NUMBITS-1):0] a_wrdata = {
        sprattr_wrdata[15:0],    // Attributes
        sprattr_wrdata[24:16],   // Y
        sprattr_wrdata[7:0]      // X
    };

    assign sprattr_rddata = sprattr_addr[0] ? {16'b0, a_rddata[32:17]} : {8'b0, a_rddata[16:9], 7'b0, a_rddata[8:0]};

    wire [(NUMBITS-1):0] a_wren = {
        {16{sprattr_wren &&  sprattr_addr[0]}},
        {17{sprattr_wren && !sprattr_addr[0]}}
    };

    wire [(NUMBITS-1):0] b_rddata;
    assign {
        spr_priority,
        spr_palette,
        spr_vflip,
        spr_hflip,
        spr_h16,
        spr_idx,
        spr_y,
        spr_x
    } = b_rddata;

    generate
        genvar i;
        for (i=0; i<NUMBITS; i=i+1) begin: sprattr_gen
            ram64x1d ram(
                .a_clk(clk),
                .a_addr(sprattr_addr[6:1]), .a_rddata(a_rddata[i]), .a_wrdata(a_wrdata[i]), .a_wren(a_wren[i]),
                .b_addr(spr_sel),           .b_rddata(b_rddata[i]));
        end
    endgenerate

endmodule
