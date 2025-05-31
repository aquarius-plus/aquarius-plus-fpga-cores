`default_nettype none
`timescale 1 ns / 1 ps

module fm_op_attr(
    input  wire        clk,
    input  wire  [6:0] addr,
    input  wire [31:0] wrdata,
    input  wire        wren,
    output wire [31:0] rddata,

    input  wire  [5:0] op_sel,
    output wire  [2:0] op_ws,
    output wire        op_am,
    output wire        op_vib,
    output wire        op_egt,
    output wire        op_ksr,
    output wire  [3:0] op_mult,
    output wire  [1:0] op_ksl,
    output wire  [5:0] op_tl,
    output wire  [3:0] op_ar,
    output wire  [3:0] op_dr,
    output wire  [3:0] op_sl,
    output wire  [3:0] op_rr
);

    localparam NUMBITS = 35;

    wire [(NUMBITS-1):0] a_rddata;
    wire [(NUMBITS-1):0] a_wrdata = {wrdata[2:0], wrdata};
    wire [(NUMBITS-1):0] a_wren   = {{3{wren && addr[0]}}, {32{wren && !addr[0]}}};

    assign rddata = addr[0] ? {29'b0, a_rddata[34:32]} : a_rddata[31:0];

    wire [(NUMBITS-1):0] b_rddata;
    assign {
        op_ws,
        op_am, op_vib, op_egt, op_ksr, op_mult,
        op_ksl, op_tl,
        op_ar, op_dr, op_sl, op_rr
    } = b_rddata;

    generate
        genvar i;
        for (i=0; i<NUMBITS; i=i+1) begin: ram_gen
            RAM64X1D ram(
                .WCLK(clk),
                .D(a_wrdata[i]),
                .WE(a_wren[i]),

                .A5(addr[6]),
                .A4(addr[5]),
                .A3(addr[4]),
                .A2(addr[3]),
                .A1(addr[2]),
                .A0(addr[1]),
                .SPO(a_rddata[i]),

                .DPRA5(op_sel[5]),
                .DPRA4(op_sel[4]),
                .DPRA3(op_sel[3]),
                .DPRA2(op_sel[2]),
                .DPRA1(op_sel[1]),
                .DPRA0(op_sel[0]),
                .DPO(b_rddata[i]));
        end
    endgenerate

endmodule
