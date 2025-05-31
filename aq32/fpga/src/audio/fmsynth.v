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

    reg         q_dam;
    reg         q_dvb;
    reg         q_nts;
    reg  [15:0] q_4op;
    wire [31:0] ch_attr_rddata;
    wire [31:0] op_attr_rddata;

    wire        sel_reg0    = addr == 8'd0;
    wire        sel_reg1    = addr == 8'd1;
    wire        sel_ch_attr = addr[7:5] == 3'b011;
    wire        sel_op_attr = addr[7];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q_dam <= 0;
            q_dvb <= 0;
            q_nts <= 0;
            q_4op <= 0;
            
        end else begin
            if (sel_reg0 && wren)
                q_4op <= wrdata[15:0];
            if (sel_reg1 && wren) begin
                q_nts <= wrdata[14];
                q_dam <= wrdata[7];
                q_dvb <= wrdata[6];
            end
        end
    end

    always @* begin
        rddata = 32'b0;
        if (sel_reg0)    rddata = {16'b0, q_4op};
        if (sel_reg1)    rddata = {17'b0, q_nts, 6'b0, q_dam, q_dvb, 6'b0};
        if (sel_ch_attr) rddata = ch_attr_rddata;
        if (sel_op_attr) rddata = op_attr_rddata;
    end

    reg  [12:0] q_result;
    reg  [12:0] q_vibrato_cnt;

    assign audio_l = {q_result, 3'b0};
    assign audio_r = {q_result, 3'b0};

    //////////////////////////////////////////////////////////////////////////
    // Operator attributes
    //////////////////////////////////////////////////////////////////////////
    reg   [5:0] q_op_sel;
    wire  [2:0] op_ws;
    wire        op_am, op_vib, op_egt, op_ksr;
    wire  [3:0] op_mult;
    wire  [1:0] op_ksl;
    wire  [5:0] op_tl;
    wire  [3:0] op_ar, op_dr, op_sl, op_rr;

    // TODO: op_am, op_egt, op_ksr, op_ksl, op_tl, op_ar, op_dr, op_sl, op_rr

    fm_op_attr fm_op_attr(
        .clk(clk),
        .addr(addr[6:0]),
        .wrdata(wrdata),
        .wren(sel_op_attr && wren),
        .rddata(op_attr_rddata),
        
        .op_sel(q_op_sel),
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

    reg  [4:0] fw_multiplier;
    always @* case (op_mult)
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

    

    //////////////////////////////////////////////////////////////////////////
    // Channel attributes
    //////////////////////////////////////////////////////////////////////////
    wire  [4:0] ch_sel = q_op_sel[5:1];
    wire        ch_chb;
    wire        ch_cha;
    wire  [2:0] ch_fb;
    wire        ch_cnt;
    wire        ch_kon;
    wire  [2:0] ch_block;
    wire  [9:0] ch_fnum;

    // TODO: ch_chb, ch_cha, ch_fb, ch_cnt, ch_kon

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

    //////////////////////////////////////////////////////////////////////////
    // Channel phase counters
    //////////////////////////////////////////////////////////////////////////
    wire [16:0] fw        = {7'b0, ch_fnum} << ch_block;
    wire [20:0] fw_scaled = fw[15:0] * fw_multiplier;
    reg   [2:0] vib_delta;
    reg  [18:0] vib_inc;

    always @* begin
        vib_delta = ch_fnum[9:7];
        if (q_vibrato_cnt[11:10] == 2'd3)
            vib_delta = {1'b0, vib_delta[2:1]};
        if (!q_dvb)
            vib_delta = {1'b0, vib_delta[2:1]};

        vib_inc = {16'b0, vib_delta};
        vib_inc = q_vibrato_cnt[12] ? ~vib_inc : vib_inc;
    end
    
    wire [18:0] fw_inc = fw_scaled[18:0] + (op_vib ? vib_inc : 19'd0);

    wire [18:0] d_op_phase, q_op_phase;
    reg         q_op_phase_wr;

    fm_op_data_phase fm_op_data_phase(
        .clk(clk),
        .idx(q_op_sel),
        .wrdata(d_op_phase),
        .wren(q_op_phase_wr),
        .rddata(q_op_phase));

    assign d_op_phase = q_op_phase + fw_inc;

    wire  [9:0] phase = q_op_phase[18:9];

    //////////////////////////////////////////////////////////////////////////
    // Channel envelope generator
    //////////////////////////////////////////////////////////////////////////
    localparam
        StageAttack  = 2'd0,
        StageDecay   = 2'd1,
        StageSustain = 2'd2,
        StageRelease = 2'd3;
    
    reg   [1:0] d_eg_stage;
    wire  [1:0] q_eg_stage;
    reg   [8:0] d_eg_env;
    wire  [8:0] q_eg_env;
    reg  [14:0] d_eg_counter;
    wire [14:0] q_eg_counter;

    fm_op_data_eg fm_op_data_eg(
        .clk(clk),
        .idx(q_op_sel),
        .wren(q_op_phase_wr),
        
        .i_stage(d_eg_stage),
        .i_env(d_eg_env),
        .i_counter(d_eg_counter),
        
        .o_stage(q_eg_stage),
        .o_env(q_eg_env),
        .o_counter(q_eg_counter)
    );

    always @* begin
        d_eg_stage   = q_eg_stage;
        d_eg_env     = q_eg_env;
        d_eg_counter = q_eg_counter;

        case (q_eg_stage)
            StageAttack: begin
                
            end
            StageDecay: begin
                
            end
            StageSustain: begin
                
            end
            StageRelease: begin
                
            end
        endcase
    end

    // Rate offset (based on key split and key scaling)
    reg [3:0] rof;
    always @* begin
        rof = {ch_block, q_nts ? ch_fnum[8] : ch_fnum[9]};
        if (op_ksr)
            rof = {2'b0, rof[3:2]};
    end

    // Rate value
    reg [3:0] stage_rate;
    always @* case (q_eg_stage)
        StageAttack:  stage_rate = op_ar;
        StageDecay:   stage_rate = op_dr;
        StageSustain: stage_rate = 4'd0;
        StageRelease: stage_rate = op_rr;
    endcase

    // Actual value
    reg   [6:0] actual_rate;
    always @* begin
        actual_rate = {3'b0, rof} + {1'b0, stage_rate, 2'b0};
        if (actual_rate > 7'd60)
            actual_rate = 7'd60;
    end

    wire [17:0] eg_counter_inc  = {15'b0, 1'b1, actual_rate[1:0]} << actual_rate[5:2];
    wire [17:0] eg_counter_next = {3'b0, q_eg_counter} + eg_counter_inc;

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
        val     = val + {q_eg_env, 3'b0};
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
        StResult = 2'd2,
        StDone   = 2'd3;

    reg [1:0] q_state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q_state       <= StLogSin;
            q_result      <= 0;
            q_vibrato_cnt <= 0;
            q_op_phase_wr <= 0;
            q_op_sel      <= 0;

        end else begin
            q_op_phase_wr <= 0;

            case (q_state)
                StLogSin: begin
                    q_state <= StExp;
                end

                StExp: begin
                    q_state <= StResult;
                end

                StResult: begin
                    q_result      <= result;
                    q_state       <= StDone;
                    q_op_phase_wr <= 1;
                    q_vibrato_cnt <= q_vibrato_cnt + 13'd1;
                end

                StDone: begin
                    q_state       <= StLogSin;
                    q_op_sel      <= q_op_sel + 6'd1;
                end

                default: begin end
            endcase
        end
    end

endmodule
