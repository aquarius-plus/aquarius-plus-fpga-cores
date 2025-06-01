`default_nettype none
`timescale 1 ns / 1 ps

module fm_op_data_eg(
    input  wire        clk,
    input  wire  [5:0] idx,
    input  wire        wren,
    
    input  wire  [1:0] i_stage,
    input  wire [23:0] i_env_cnt,
    
    output wire  [1:0] o_stage,
    output wire [23:0] o_env_cnt
);

    localparam NUMBITS = 26;

    wire [(NUMBITS-1):0] rddata;
    wire [(NUMBITS-1):0] wrdata = {i_stage, i_env_cnt};

    assign {o_stage, o_env_cnt} = rddata;

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
