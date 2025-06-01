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

    // TODO: op_am, op_ksr, op_ksl

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
    // Operator phase counter
    //////////////////////////////////////////////////////////////////////////
    reg        q_next;
    reg        q_op_reset;
    wire [9:0] phase;

    fm_phase fm_phase(
        .clk(clk),
        .reset(reset),

        .op_sel(q_op_sel),
        .next(q_next),

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

        .env(env)
    );

    //////////////////////////////////////////////////////////////////////////
    // Operator
    //////////////////////////////////////////////////////////////////////////
    wire [12:0] result;
    fm_op fm_op(
        .clk(clk),
        .ws(op_ws),
        .phase(phase),
        .env(env),
        .result(result));

    //////////////////////////////////////////////////////////////////////////
    // State machine
    //////////////////////////////////////////////////////////////////////////
    localparam
        StReset  = 3'd0,
        StReset2 = 3'd1,
        StLogSin = 3'd2,
        StExp    = 3'd3,
        StResult = 3'd4,
        StDone   = 3'd5;

    reg [2:0] q_state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q_state       <= StReset;
            q_result      <= 0;
            q_next        <= 0;
            q_op_sel      <= 0;
            q_op_reset    <= 0;

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
                        q_state    <= StLogSin;
                    end
                end

                StLogSin: begin
                    q_state <= StExp;
                end

                StExp: begin
                    q_state <= StResult;
                end

                StResult: begin
                    q_result      <= result;
                    q_state       <= StDone;
                    q_next        <= 1;
                end

                StDone: begin
                    q_state       <= StLogSin;
                    // q_op_sel      <= q_op_sel + 6'd1;
                end

                default: begin end
            endcase
        end
    end

endmodule
