`default_nettype none
`timescale 1 ns / 1 ps

module fmsynth(
    input  wire        clk,
    input  wire        reset,

    input  wire  [7:0] bus_addr,
    input  wire [31:0] bus_wrdata,
    input  wire        bus_wren,
    output reg  [31:0] bus_rddata,
    output wire        bus_wait,

    output reg  [15:0] audio_l,
    output reg  [15:0] audio_r
);

    wire        bus_wr = bus_wren && !bus_wait;

    reg  [18:0] q_accum_l, q_accum_r;

    reg  [31:0] q_kon;
    reg  [31:0] q_restart;

    reg         q_dam;
    reg         q_dvb;
    reg         q_nts;
    reg  [15:0] q_4op;
    wire [31:0] ch_attr_rddata;
    wire [31:0] op_attr_rddata;

    wire        sel_reg0    = bus_addr == 8'd0;
    wire        sel_reg1    = bus_addr == 8'd1;
    wire        sel_ch_attr = bus_addr[7:5] == 3'b011;
    wire        sel_op_attr = bus_addr[7];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q_dam <= 0;
            q_dvb <= 0;
            q_nts <= 0;
            q_4op <= 0;

        end else begin
            if (sel_reg0 && bus_wr)
                q_4op <= bus_wrdata[15:0];
            if (sel_reg1 && bus_wr) begin
                q_nts <= bus_wrdata[14];
                q_dam <= bus_wrdata[7];
                q_dvb <= bus_wrdata[6];
            end
        end
    end

    always @* begin
        bus_rddata = 32'b0;
        if (sel_reg0)    bus_rddata = {16'b0, q_4op};
        if (sel_reg1)    bus_rddata = {17'b0, q_nts, 6'b0, q_dam, q_dvb, 6'b0};
        if (sel_ch_attr) bus_rddata = ch_attr_rddata;
        if (sel_op_attr) bus_rddata = op_attr_rddata;
    end

    //////////////////////////////////////////////////////////////////////////
    // Next sample signal
    //////////////////////////////////////////////////////////////////////////
    reg       q_next_sample;
    reg [8:0] q_next_sample_cnt;
    always @(posedge clk or posedge reset)
        if (reset) begin
            q_next_sample_cnt <= 0;
            q_next_sample     <= 0;

        end else begin
            q_next_sample <= 0;
            if (q_next_sample_cnt == 9'd505) begin
                q_next_sample_cnt <= 0;
                q_next_sample     <= 1;
            end else begin
                q_next_sample_cnt <= q_next_sample_cnt + 9'd1;
            end
        end

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

    // TODO: op_am, op_ksr, op_ksl

    fm_op_attr fm_op_attr(
        .clk(clk),
        .addr(bus_addr[6:0]),
        .wrdata(bus_wrdata),
        .wren(sel_op_attr && bus_wr),
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

    // TODO: ch_fb, ch_cnt, ch_kon

    fm_ch_attr fm_ch_attr(
        .clk(clk),
        .addr(bus_addr[4:0]),
        .wrdata(bus_wrdata),
        .wren(sel_ch_attr && bus_wr),
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
    // Operator phase counter
    //////////////////////////////////////////////////////////////////////////
    reg        q_next;
    reg        q_op_reset;
    wire [9:0] phase;
    wire       restart = q_restart[q_op_sel[5:1]];

    fm_phase fm_phase(
        .clk(clk),
        .reset(reset),

        .op_sel(q_op_sel),
        .next(q_next),
        .restart(restart),

        .block(ch_block),
        .fnum(ch_fnum),
        .mult(op_mult),
        .nts(q_nts),
        .ksr(op_ksr),
        .dvb(q_dvb),
        .vib(op_vib),

        .phase(phase)
    );

    //////////////////////////////////////////////////////////////////////////
    // Operator envelope generator
    //////////////////////////////////////////////////////////////////////////
    wire [8:0] env;

    fm_eg fm_eg(
        .clk(clk),

        .op_sel(q_op_sel),
        .next(q_next),
        .op_reset(q_op_reset),
        .restart(restart),

        .ar(op_ar),
        .dr(op_dr),
        .sl(op_sl),
        .rr(op_rr),
        .tl(op_tl),

        .block(ch_block),
        .fnum(ch_fnum),
        .nts(q_nts),
        .ksr(op_ksr),
        .kon(ch_kon),
        .egt(op_egt),
        .am(op_am),
        .dam(q_dam),
        .ksl(op_ksl),

        .env(env)
    );

    //////////////////////////////////////////////////////////////////////////
    // Operator
    //////////////////////////////////////////////////////////////////////////
    wire [25:0] d_fb_data,   q_fb_data;
    wire [12:0] d_op_result;
    reg  [12:0] q_op_result;
    wire [13:0] fb_sum = {1'b0, q_fb_data[25:13]} + {1'b0, q_fb_data[12:0]};
    wire [11:0] fb_mod = (ch_fb == 0) ? 0 : (fb_sum[13:2] >> (~ch_fb));

    reg [9:0] op_modulation;
    always @* begin
        op_modulation = 0;
        if (!q_op_sel[0])
            op_modulation = fb_mod[9:0];
        else if (!ch_cnt)
            op_modulation = q_op_result[9:0];
    end

    fm_op fm_op(
        .clk(clk),
        .ws(op_ws),
        .phase(phase),
        .modulation(op_modulation),
        .env(env),
        .result(d_op_result));

    assign d_fb_data = {q_fb_data[12:0], d_op_result};

    fm_ch_data_fb fm_ch_data_fb(
        .clk(clk),
        .idx(ch_sel),
        .wrdata(d_fb_data),
        .wren(q_next && !q_op_sel[0]),  // only store feedback for first operator in channel
        .rddata(q_fb_data)
    );

    always @(posedge clk) q_op_result <= d_op_result;

    //////////////////////////////////////////////////////////////////////////
    // State machine
    //////////////////////////////////////////////////////////////////////////
    localparam
        StReset  = 3'd0,
        StReset2 = 3'd1,
        StLogSin = 3'd2,
        StExp    = 3'd3,
        StResult = 3'd4,
        StDone   = 3'd5,
        StBus    = 3'd6,
        StStart  = 3'd7;

    reg [2:0] q_state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q_state      <= StReset;
            q_next       <= 0;
            q_op_sel     <= 0;
            q_op_reset   <= 0;
            q_kon        <= 0;
            q_restart    <= 0;
            q_accum_l    <= 0;
            q_accum_r    <= 0;
            audio_l      <= 0;
            audio_r      <= 0;

        end else begin
            q_next <= 0;

            case (q_state)
                StReset: begin
                    q_op_sel   <= 0;
                    q_op_reset <= 1;
                    q_next     <= 1;
                    q_state    <= StReset2;
                end

                StReset2: begin
                    q_next   <= 1;
                    q_op_sel <= q_op_sel + 6'd1;

                    if (q_op_sel == 6'd63) begin
                        q_next     <= 0;
                        q_op_reset <= 0;
                        q_state    <= StBus;
                    end
                end

                StLogSin: begin
                    q_state <= StExp;
                end

                StExp: begin
                    q_state <= StResult;
                end

                StResult: begin
                    if (q_op_sel[0] || ch_cnt) begin
                        if (ch_cha)
                            q_accum_l <= q_accum_l + {{6{d_op_result[12]}}, d_op_result};
                        if (ch_chb)
                            q_accum_r <= q_accum_r + {{6{d_op_result[12]}}, d_op_result};
                    end

                    q_state  <= StDone;
                    q_next   <= 1;
                end

                StDone: begin
                    if (q_op_sel == 6'd63) begin
                        q_restart <= 0;
                        q_state   <= StBus;

                        // Clamp output signal
                        audio_l <= q_accum_l[15:0];
                        if (q_accum_l[18] && q_accum_l[17:15] != 3'b111)
                            audio_l <= 16'h8000;
                        else if (!q_accum_l[18] && q_accum_l[17:15] != 3'b000)
                            audio_l <= 16'h7FFF;

                        // Clamp output signal
                        audio_r <= q_accum_r[15:0];
                        if (q_accum_r[18] && q_accum_r[17:15] != 3'b111)
                            audio_r <= 16'h8000;
                        else if (!q_accum_r[18] && q_accum_r[17:15] != 3'b000)
                            audio_r <= 16'h7FFF;

                        // Reset accumulator for next round
                        q_accum_l <= 0;
                        q_accum_r <= 0;

                    end else begin
                        q_op_sel <= q_op_sel + 6'd1;
                        q_state  <= StLogSin;
                    end
                end

                StBus: begin
                    if (q_next_sample)
                        q_state <= StStart;

                    if (bus_wren && sel_ch_attr) begin
                        q_kon[bus_addr[4:0]] <= bus_wrdata[13];

                        if (bus_wrdata[13] && !q_kon[bus_addr[4:0]]) begin    // Key on
                            q_restart[bus_addr[4:0]] <= 1'b1;
                        end
                    end
                end

                StStart: begin
                    q_state  <= StLogSin;
                    q_op_sel <= 0;
                end

                default: begin end
            endcase
        end
    end

    assign bus_wait = bus_wren && (q_state != StBus);

endmodule
