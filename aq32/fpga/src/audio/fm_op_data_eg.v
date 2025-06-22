`default_nettype none
`timescale 1 ns / 1 ps

module fm_op_data_eg(
    input  wire        clk,
    input  wire  [5:0] idx,
    input  wire        wren,
    
    input  wire  [1:0] i_eg_stage,
    input  wire [14:0] i_eg_cnt,
    input  wire  [8:0] i_eg_env,
    
    output wire  [1:0] o_eg_stage,
    output wire [14:0] o_eg_cnt,
    output wire  [8:0] o_eg_env
);

    localparam NUMBITS = 26;

    wire [(NUMBITS-1):0] rddata;
    wire [(NUMBITS-1):0] wrdata = {i_eg_stage, i_eg_cnt, i_eg_env};

    assign {o_eg_stage, o_eg_cnt, o_eg_env} = rddata;

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
