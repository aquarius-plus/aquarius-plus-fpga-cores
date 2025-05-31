`default_nettype none
`timescale 1 ns / 1 ps

module palette(
    input  wire        clk,
    input  wire  [5:0] addr,
    output wire [15:0] rddata,
    input  wire [15:0] wrdata,
    input  wire        wren,

    input  wire  [5:0] palidx,
    output wire  [3:0] pal_r,
    output wire  [3:0] pal_g,
    output wire  [3:0] pal_b);

    parameter [16*12-1:0] PALETTE_INIT = {
        12'h111, 12'hF11, 12'h1F1, 12'hFF1, 12'h22E, 12'hF1F, 12'h3CC, 12'hFFF,
        12'hCCC, 12'h3BB, 12'hC2C, 12'h419, 12'hFF7, 12'h2D4, 12'hB22, 12'h333
    };

    wire [11:0] pal_rddata, pal_color;
    assign rddata = {4'h0, pal_rddata};
    assign pal_r  = pal_color[11:8];
    assign pal_g  = pal_color[7:4];
    assign pal_b  = pal_color[3:0];

    wire palram_wren_l = wren && !addr[0];
    wire palram_wren_h = wren &&  addr[0];

    generate
        genvar i;
        for (i=0; i<12; i=i+1) begin: palram_gen
            RAM64X1D #(
                .INIT({
                    PALETTE_INIT[ 0*12+i], PALETTE_INIT[ 1*12+i], PALETTE_INIT[ 2*12+i], PALETTE_INIT[ 3*12+i],
                    PALETTE_INIT[ 4*12+i], PALETTE_INIT[ 5*12+i], PALETTE_INIT[ 6*12+i], PALETTE_INIT[ 7*12+i],
                    PALETTE_INIT[ 8*12+i], PALETTE_INIT[ 9*12+i], PALETTE_INIT[10*12+i], PALETTE_INIT[11*12+i],
                    PALETTE_INIT[12*12+i], PALETTE_INIT[13*12+i], PALETTE_INIT[14*12+i], PALETTE_INIT[15*12+i],

                    PALETTE_INIT[ 0*12+i], PALETTE_INIT[ 1*12+i], PALETTE_INIT[ 2*12+i], PALETTE_INIT[ 3*12+i],
                    PALETTE_INIT[ 4*12+i], PALETTE_INIT[ 5*12+i], PALETTE_INIT[ 6*12+i], PALETTE_INIT[ 7*12+i],
                    PALETTE_INIT[ 8*12+i], PALETTE_INIT[ 9*12+i], PALETTE_INIT[10*12+i], PALETTE_INIT[11*12+i],
                    PALETTE_INIT[12*12+i], PALETTE_INIT[13*12+i], PALETTE_INIT[14*12+i], PALETTE_INIT[15*12+i],

                    PALETTE_INIT[ 0*12+i], PALETTE_INIT[ 1*12+i], PALETTE_INIT[ 2*12+i], PALETTE_INIT[ 3*12+i],
                    PALETTE_INIT[ 4*12+i], PALETTE_INIT[ 5*12+i], PALETTE_INIT[ 6*12+i], PALETTE_INIT[ 7*12+i],
                    PALETTE_INIT[ 8*12+i], PALETTE_INIT[ 9*12+i], PALETTE_INIT[10*12+i], PALETTE_INIT[11*12+i],
                    PALETTE_INIT[12*12+i], PALETTE_INIT[13*12+i], PALETTE_INIT[14*12+i], PALETTE_INIT[15*12+i],

                    PALETTE_INIT[ 0*12+i], PALETTE_INIT[ 1*12+i], PALETTE_INIT[ 2*12+i], PALETTE_INIT[ 3*12+i],
                    PALETTE_INIT[ 4*12+i], PALETTE_INIT[ 5*12+i], PALETTE_INIT[ 6*12+i], PALETTE_INIT[ 7*12+i],
                    PALETTE_INIT[ 8*12+i], PALETTE_INIT[ 9*12+i], PALETTE_INIT[10*12+i], PALETTE_INIT[11*12+i],
                    PALETTE_INIT[12*12+i], PALETTE_INIT[13*12+i], PALETTE_INIT[14*12+i], PALETTE_INIT[15*12+i]
                }))
            
            palram(
                .WCLK(clk),
                .D(wrdata[i]),
                .WE(wren),

                .A5(addr[5]),
                .A4(addr[4]),
                .A3(addr[3]),
                .A2(addr[2]),
                .A1(addr[1]),
                .A0(addr[0]),
                .SPO(pal_rddata[i]),

                .DPRA5(palidx[5]),
                .DPRA4(palidx[4]),
                .DPRA3(palidx[3]),
                .DPRA2(palidx[2]),
                .DPRA1(palidx[1]),
                .DPRA0(palidx[0]),
                .DPO(pal_color[i]));
        end
    endgenerate

endmodule
