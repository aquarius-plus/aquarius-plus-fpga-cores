`default_nettype none
`timescale 1 ns / 1 ps

module fm_eg(
    input  wire        clk,

    input  wire  [5:0] op_sel,
    input  wire        next,

    input  wire  [3:0] ar,
    input  wire  [3:0] dr,
    input  wire  [3:0] sl,
    input  wire  [3:0] rr,

    input  wire  [2:0] block,
    input  wire  [9:0] fnum,
    input  wire        nts,
    input  wire        ksr,
    input  wire        kon,
    input  wire        egt,

    output wire  [8:0] env
);

    localparam
        StageAttack  = 2'd0,
        StageDecay   = 2'd1,
        StageSustain = 2'd2,
        StageRelease = 2'd3;
    
    reg   [1:0] d_eg_stage;
    wire  [1:0] q_eg_stage;
    reg  [23:0] d_eg_env_cnt;
    wire [23:0] q_eg_env_cnt;

    fm_op_data_eg fm_op_data_eg(
        .clk(clk),
        .idx(op_sel),
        .wren(next),
        
        .i_stage(d_eg_stage),
        .i_env_cnt(d_eg_env_cnt),
        
        .o_stage(q_eg_stage),
        .o_env_cnt(q_eg_env_cnt)
    );

    // Rate offset (based on key split and key scaling)
    reg [3:0] rof;
    always @* begin
        rof = {block, nts ? fnum[8] : fnum[9]};
        if (ksr)
            rof = {2'b0, rof[3:2]};
    end

    // Rate value
    reg [3:0] stage_rate;
    always @* case (q_eg_stage)
        StageAttack:  stage_rate = ar;
        StageDecay:   stage_rate = dr;
        StageSustain: stage_rate = 4'd0;
        StageRelease: stage_rate = rr;
    endcase

    // Actual value
    reg [6:0] actual_rate;
    always @* begin
        actual_rate = {3'b0, rof} + {1'b0, stage_rate, 2'b0};
        if (actual_rate > 7'd60)
            actual_rate = 7'd60;
    end

    reg  [24:0] eg_env_cnt_inc;
    always @* begin
        eg_env_cnt_inc = {22'b0, 1'b1, actual_rate[1:0]} << actual_rate[5:2];
        if (q_eg_stage == StageAttack)
            eg_env_cnt_inc = eg_env_cnt_inc << 3;
    end
    reg  [24:0] eg_env_cnt_next;
    always @* begin
        eg_env_cnt_next = {1'b0, q_eg_env_cnt};
        if (stage_rate != 4'd0)
            eg_env_cnt_next = eg_env_cnt_next + (q_eg_stage == StageAttack ? eg_env_cnt_inc : ~eg_env_cnt_inc);
    end

    always @* begin
        d_eg_env_cnt = eg_env_cnt_next[23:0];
        d_eg_stage   = q_eg_stage;

        case (q_eg_stage)
            StageAttack: begin
                if (eg_env_cnt_next[24]) begin
                    d_eg_env_cnt = ~0;
                    d_eg_stage   = StageDecay;
                end
            end
            StageDecay: begin
                if (eg_env_cnt_next[24] || eg_env_cnt_next[23:20] < sl) begin
                    d_eg_env_cnt = {sl, 20'd0};
                    d_eg_stage   = StageSustain;
                end
            end
            StageSustain: begin
                if (!egt || !kon) begin
                    d_eg_stage = StageRelease;
                end
            end
            StageRelease: begin
                if (eg_env_cnt_next[24]) begin
                    d_eg_env_cnt = 0;
                end
            end
        endcase
    end

    assign env = ~q_eg_env_cnt[23:15];

endmodule
