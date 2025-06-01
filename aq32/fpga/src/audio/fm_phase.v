`default_nettype none
`timescale 1 ns / 1 ps

module fm_phase(
    input  wire        clk,
    input  wire        reset,

    input  wire  [5:0] op_sel,
    input  wire        next,
    input  wire        restart,

    input  wire  [2:0] block,
    input  wire  [9:0] fnum,
    input  wire  [3:0] mult,
    input  wire        nts,
    input  wire        ksr,
    input  wire        dvb,
    input  wire        vib,

    output wire  [9:0] phase
);

    // Translate MULT parameter to multiplier value
    reg [4:0] fw_multiplier;
    always @* case (mult)
        4'd0:  fw_multiplier = 5'd1;
        4'd1:  fw_multiplier = 5'd2;
        4'd2:  fw_multiplier = 5'd4;
        4'd3:  fw_multiplier = 5'd6;
        4'd4:  fw_multiplier = 5'd8;
        4'd5:  fw_multiplier = 5'd10;
        4'd6:  fw_multiplier = 5'd12;
        4'd7:  fw_multiplier = 5'd14;
        4'd8:  fw_multiplier = 5'd16;
        4'd9:  fw_multiplier = 5'd18;
        4'd10: fw_multiplier = 5'd20;
        4'd11: fw_multiplier = 5'd20;
        4'd12: fw_multiplier = 5'd24;
        4'd13: fw_multiplier = 5'd24;
        4'd14: fw_multiplier = 5'd30;
        4'd15: fw_multiplier = 5'd30;
    endcase

    // Vibrato counter
    reg  [12:0] q_vibrato_cnt;
    always @(posedge clk or posedge reset)
        if      (reset) q_vibrato_cnt <= 0;
        else if (next)  q_vibrato_cnt <= q_vibrato_cnt + 13'd1;

    // Vibration
    wire [16:0] fw        = {7'b0, fnum} << block;
    wire [20:0] fw_scaled = fw[15:0] * fw_multiplier;
    reg   [2:0] vib_delta;
    reg  [18:0] vib_inc;

    always @* begin
        vib_delta = fnum[9:7];
        if (q_vibrato_cnt[11:10] == 2'd3)
            vib_delta = {1'b0, vib_delta[2:1]};
        if (!dvb)
            vib_delta = {1'b0, vib_delta[2:1]};

        vib_inc = {16'b0, vib_delta};
        vib_inc = q_vibrato_cnt[12] ? ~vib_inc : vib_inc;
    end
    
    wire [18:0] fw_inc = fw_scaled[18:0] + (vib ? vib_inc : 19'd0);

    wire [18:0] d_op_phase, q_op_phase;

    fm_op_data_phase fm_op_data_phase(
        .clk(clk),
        .idx(op_sel),
        .wrdata(d_op_phase),
        .wren(next),
        .rddata(q_op_phase));

    assign d_op_phase = (restart ? 19'd0 : q_op_phase) + fw_inc;

    assign phase = q_op_phase[18:9];

endmodule
