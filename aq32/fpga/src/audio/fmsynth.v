`default_nettype none
`timescale 1 ns / 1 ps

module fmsynth(
    input  wire        clk,
    input  wire        reset,

    input  wire  [7:0] addr,
    input  wire [31:0] wrdata,
    input  wire        wren,
    output reg  [31:0] rddata,

    output wire [15:0] audio_l,
    output wire [15:0] audio_r
);

    wire [31:0] ch_attr_rddata;
    wire [31:0] op_attr_rddata;

    wire        sel_ch_attr = addr[7:5] == 3'b011;
    wire        sel_op_attr = addr[7];

    always @* begin
        rddata = 32'b0;
        if (sel_ch_attr) rddata = ch_attr_rddata;
        if (sel_op_attr) rddata = op_attr_rddata;
    end


    reg  [11:0] q_atten;
    reg  [20:0] q_phase;
    reg  [12:0] q_result;
    wire  [9:0] phase = q_phase[18:9];

    assign audio_l = {q_result, 3'b0};
    assign audio_r = {q_result, 3'b0};

    //////////////////////////////////////////////////////////////////////////
    // Operator attributes
    //////////////////////////////////////////////////////////////////////////
    wire  [5:0] op_sel = 0;
    wire  [2:0] op_ws;
    wire        op_am, op_vib, op_egt, op_ksr;
    wire  [3:0] op_mult;
    wire  [1:0] op_ksl;
    wire  [5:0] op_tl;
    wire  [3:0] op_ar, op_dr, op_sl, op_rr;

    fm_op_attr fm_op_attr(
        .clk(clk),
        .addr(addr[6:0]),
        .wrdata(wrdata),
        .wren(sel_op_attr && wren),
        .rddata(op_attr_rddata),
        
        .op_sel(op_sel),
        .op_ws(op_ws),
        .op_am(op_am),
        .op_vib(op_vib),
        .op_egt(op_egt),
        .op_ksr(op_ksr),
        .op_mult(op_mult),
        .op_ksl(op_ksl),
        .op_tl(op_tl),
        .op_ar(op_ar),
        .op_dr(op_dr),
        .op_sl(op_sl),
        .op_rr(op_rr)
    );

    //////////////////////////////////////////////////////////////////////////
    // Channel attributes
    //////////////////////////////////////////////////////////////////////////
    wire  [4:0] ch_sel = op_sel[5:1];
    wire        ch_chb;
    wire        ch_cha;
    wire  [2:0] ch_fb;
    wire        ch_cnt;
    wire        ch_kon;
    wire  [2:0] ch_block;
    wire  [9:0] ch_fnum;

    fm_ch_attr fm_ch_attr(
        .clk(clk),
        .addr(addr[4:0]),
        .wrdata(wrdata),
        .wren(sel_ch_attr && wren),
        .rddata(ch_attr_rddata),

        .ch_sel(ch_sel),
        .ch_chb(ch_chb),
        .ch_cha(ch_cha),
        .ch_fb(ch_fb),
        .ch_cnt(ch_cnt),
        .ch_kon(ch_kon),
        .ch_block(ch_block),
        .ch_fnum(ch_fnum)
    );

    reg  [4:0] multiplier;
    always @* case (op_mult)
        4'd0:  multiplier = 5'd1;
        4'd1:  multiplier = 5'd2;
        4'd2:  multiplier = 5'd4;
        4'd3:  multiplier = 5'd6;
        4'd4:  multiplier = 5'd8;
        4'd5:  multiplier = 5'd10;
        4'd6:  multiplier = 5'd12;
        4'd7:  multiplier = 5'd14;
        4'd8:  multiplier = 5'd16;
        4'd9:  multiplier = 5'd18;
        4'd10: multiplier = 5'd20;
        4'd11: multiplier = 5'd20;
        4'd12: multiplier = 5'd24;
        4'd13: multiplier = 5'd24;
        4'd14: multiplier = 5'd30;
        4'd15: multiplier = 5'd30;
    endcase

    wire [16:0] fw1       = {7'b0, ch_fnum} << ch_block;
    wire [20:0] phase_inc = fw1[15:0] * multiplier;

    //////////////////////////////////////////////////////////////////////////
    // Log sin lookup table
    //////////////////////////////////////////////////////////////////////////
    reg   [7:0] logsin_idx;
    wire [11:0] logsin_value;
    lut_logsin lut_logsin(.clk(clk), .idx(logsin_idx), .value(logsin_value));

    reg invert;
    reg mute;

    always @* begin
        logsin_idx = phase[7:0] ^ {8{phase[8]}};
        invert     = phase[9];
        mute       = 0;

        // Alterations for different type of waveforms
        case (op_ws)
            default: begin end
            3'd1: begin mute = phase[9];                                                                     end
            3'd2: begin                  invert = 0;                                                         end
            3'd3: begin mute = phase[8]; invert = 0;                                                         end
            3'd4: begin mute = phase[9]; invert = phase[8]; logsin_idx = {phase[6:0], 1'b0} ^ {8{phase[7]}}; end
            3'd5: begin mute = phase[9]; invert = 0;        logsin_idx = {phase[6:0], 1'b0} ^ {8{phase[7]}}; end
            3'd6: begin                                     logsin_idx = 8'd255;                             end
        endcase
    end

    //////////////////////////////////////////////////////////////////////////
    // Exponent lookup table
    //////////////////////////////////////////////////////////////////////////
    reg   [7:0] exp_idx;
    wire  [9:0] exp_value;
    lut_exp lut_exp(.clk(clk), .idx(exp_idx), .value(exp_value));

    reg [12:0] val;
    always @* begin
        val     = (op_ws == 3'd7) ? {1'b0, phase[8:0] ^ {9{phase[9]}}, 3'b0} : {1'b0, logsin_value};
        val     = val + q_atten;
        exp_idx = ~val[7:0];
    end

    reg [12:0] result;
    always @* begin
        result = ({2'b01, exp_value, 1'b0} >> val[12:8]);
        if (result != 13'd0)
            result = result ^ {13{invert}};
        if (mute)
            result = 0;
    end

    //////////////////////////////////////////////////////////////////////////
    // State machine
    //////////////////////////////////////////////////////////////////////////
    localparam
        StLogSin = 2'd0,
        StExp    = 2'd1,
        StResult = 2'd2;

    reg [1:0] q_state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q_state  <= StLogSin;
            q_phase  <= 0;
            q_result <= 0;
            q_atten  <= 0;

        end else begin
            case (q_state)
                StLogSin: begin
                    q_state <= StExp;
                end

                StExp: begin
                    q_state <= StResult;
                end

                StResult: begin
                    q_result <= result;
                    q_phase  <= q_phase + phase_inc;
                    q_state  <= StLogSin;
                end

                default: begin end
            endcase
        end
    end

endmodule
