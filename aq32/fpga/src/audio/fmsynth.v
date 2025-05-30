`default_nettype none
`timescale 1 ns / 1 ps

module fmsynth(
    input  wire        clk,
    input  wire        reset,

    // input  wire  [8:0] addr,
    // output reg  [31:0] rddata

    output wire [15:0] audio_l,
    output wire [15:0] audio_r
);

    localparam
        StLogSin = 2'd0,
        StExp    = 2'd1,
        StResult = 2'd2;

    reg  [1:0] d_state,    q_state;
    reg [20:0] d_phase,    q_phase;
    reg  [8:0] d_lut_idx,  q_lut_idx;
    reg [12:0] d_val,      q_val;
    reg [12:0] d_result,   q_result;
    reg        d_invert,   q_invert;
    reg        d_mute,     q_mute;
    reg  [2:0] d_waveform, q_waveform;
    reg [11:0] d_atten,    q_atten;
    reg  [2:0] d_block,    q_block;
    reg  [9:0] d_fnum,     q_fnum;
    reg  [3:0] d_mult,     q_mult;

    assign audio_l = {d_result, 3'b0};
    assign audio_r = {d_result, 3'b0};

    reg  [4:0] multiplier;
    always @* case (q_mult)
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

    wire [16:0] fw1       = {7'b0, q_fnum} << q_block;
    wire [20:0] phase_inc = fw1[15:0] * multiplier;
    wire  [9:0] phase     = q_phase[18:9];

    wire [11:0] lut_data;
    fmlut fmlut(.clk(clk), .addr(d_lut_idx), .rddata(lut_data));

    always @* begin
        d_state    = q_state;
        d_phase    = q_phase;
        d_lut_idx  = q_lut_idx;
        d_val      = q_val;
        d_result   = q_result;
        d_invert   = q_invert;
        d_waveform = q_waveform;
        d_mute     = q_mute;
        d_atten    = q_atten;
        d_block    = q_block;
        d_fnum     = q_fnum;
        d_mult     = q_mult;

        case (q_state)
            StLogSin: begin
                d_lut_idx[8]   = 0;
                d_lut_idx[7:0] = phase[7:0] ^ {8{phase[8]}};
                d_invert       = phase[9];
                d_mute         = 0;
                d_state        = StExp;

                // Alterations for different type of waveforms
                case (q_waveform)
                    default: begin end
                    3'd1: begin d_mute = phase[9];               end
                    3'd2: begin                    d_invert = 0; end
                    3'd3: begin d_mute = phase[8]; d_invert = 0; end
                    3'd4: begin d_mute = phase[9]; d_invert = phase[8]; d_lut_idx[7:0] = {phase[6:0], 1'b0} ^ {8{phase[7]}}; end
                    3'd5: begin d_mute = phase[9]; d_invert = 0;        d_lut_idx[7:0] = {phase[6:0], 1'b0} ^ {8{phase[7]}}; end
                    3'd6: begin                                         d_lut_idx[7:0] = 8'hFF; end
                endcase
            end

            StExp: begin
                d_val          = (q_waveform == 3'd7) ? {1'b0, phase[8:0] ^ {9{phase[9]}}, 3'b0} : {1'b0, lut_data};
                d_val          = d_val + q_atten;
                d_lut_idx[8]   = 1;
                d_lut_idx[7:0] = ~d_val[7:0];
                d_state        = StResult;
            end

            StResult: begin
                d_result = ({2'b01, lut_data[9:0], 1'b0} >> q_val[12:8]);
                if (d_result != 13'd0)
                    d_result = d_result ^ {13{q_invert}};
                if (q_mute)
                    d_result = 0;

                d_phase = q_phase + phase_inc;  //10'd1;
                // if (q_phase == 10'h3FF) begin
                //     d_waveform = q_waveform + 3'd1;

                //     if (q_waveform == 3'd7)
                //         d_atten = q_atten + 12'd128;
                // end

                d_state = StLogSin;
            end

            default: begin end
        endcase

    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q_state    <= StLogSin;
            q_phase    <= 0;
            q_lut_idx  <= 0;
            q_val      <= 0;
            q_result   <= 0;
            q_invert   <= 0;
            q_waveform <= 0;
            q_mute     <= 0;
            q_atten    <= 0;
            q_block    <= 3'd0;
            q_fnum     <= 10'd100;
            q_mult     <= 4'd8;

        end else begin
            q_state    <= d_state;
            q_phase    <= d_phase;
            q_lut_idx  <= d_lut_idx;
            q_val      <= d_val;
            q_result   <= d_result;
            q_invert   <= d_invert;
            q_waveform <= d_waveform;
            q_mute     <= d_mute;
            q_atten    <= d_atten;
            q_block    <= d_block;
            q_fnum     <= d_fnum;
            q_mult     <= d_mult;
        end
    end

endmodule
