`default_nettype none
`timescale 1 ns / 1 ps

module fm_op(
    input  wire        clk,
    input  wire  [2:0] ws,
    input  wire  [9:0] phase,
    input  wire  [8:0] env,
    output reg  [12:0] result
);

    //////////////////////////////////////////////////////////////////////////
    // Log sin lookup table
    //////////////////////////////////////////////////////////////////////////
    reg [7:0] logsin_idx;
    reg [2:0]           q_ws;
    reg [9:0]           q_phase;
    reg [8:0]           q_env;
    reg       d_invert, q_invert;
    reg       d_mute,   q_mute;

    always @* begin
        logsin_idx = phase[7:0] ^ {8{phase[8]}};
        d_invert   = phase[9];
        d_mute     = 0;

        // Alterations for different type of waveforms
        case (ws)
            default: begin end
            3'd1: begin d_mute = phase[9];                                                                       end
            3'd2: begin                    d_invert = 0;                                                         end
            3'd3: begin d_mute = phase[8]; d_invert = 0;                                                         end
            3'd4: begin d_mute = phase[9]; d_invert = phase[8]; logsin_idx = {phase[6:0], 1'b0} ^ {8{phase[7]}}; end
            3'd5: begin d_mute = phase[9]; d_invert = 0;        logsin_idx = {phase[6:0], 1'b0} ^ {8{phase[7]}}; end
            3'd6: begin                                         logsin_idx = 8'd255;                             end
        endcase
    end

    always @(posedge clk) begin
        q_ws     <= ws;
        q_phase  <= phase;
        q_env    <= env;
        q_invert <= d_invert;
        q_mute   <= d_mute;
    end

    wire [11:0] logsin_value;
    lut_logsin lut_logsin(.clk(clk), .idx(logsin_idx), .value(logsin_value));

    //////////////////////////////////////////////////////////////////////////
    // Exponent lookup table
    //////////////////////////////////////////////////////////////////////////
    reg q2_invert;
    reg q2_mute;

    always @(posedge clk) begin
        q2_invert <= q_invert;
        q2_mute   <= q_mute;
    end

    reg  [7:0] exp_idx;
    reg [12:0] val;
    always @* begin
        val     = {1'b0, logsin_value};
        if (q_ws == 3'd7)
            val = {1'b0, q_phase[8:0] ^ {9{q_phase[9]}}, 3'b0};

        val     = val + {q_env, 3'b0};
        exp_idx = ~val[7:0];
    end

    reg [4:0] q_shift;
    always @(posedge clk) q_shift <= val[12:8];

    wire [9:0] exp_value;
    lut_exp lut_exp(.clk(clk), .idx(exp_idx), .value(exp_value));

    always @* begin
        result = ({2'b01, exp_value, 1'b0} >> q_shift);
        if (result != 13'd0)
            result = result ^ {13{q2_invert}};
        if (q2_mute)
            result = 0;
    end

endmodule
