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
    reg  [9:0] d_phase,    q_phase;
    reg  [8:0] d_lut_idx,  q_lut_idx;
    reg [12:0] d_val,      q_val;
    reg [12:0] d_result,   q_result;
    reg        d_invert,   q_invert;
    reg        d_mute,     q_mute;
    reg  [2:0] d_waveform, q_waveform;
    reg [11:0] d_atten,    q_atten;

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

        case (q_state)
            StLogSin: begin
                d_lut_idx[8]   = 0;
                d_lut_idx[7:0] = q_phase[7:0] ^ {8{q_phase[8]}};
                d_invert       = q_phase[9];
                d_mute         = 0;

                case (q_waveform)
                    default: begin end
                    3'd1: begin
                        d_mute   = q_phase[9];
                    end
                    3'd2: begin
                        d_invert = 0;
                    end
                    3'd3: begin
                        d_mute   = q_phase[8];
                        d_invert = 0;
                    end
                    3'd4: begin
                        d_lut_idx[7:0] = {q_phase[6:0], 1'b0} ^ {8{q_phase[7]}};
                        d_invert       = q_phase[8];
                        d_mute         = q_phase[9];
                    end
                    3'd5: begin
                        d_lut_idx[7:0] = {q_phase[6:0], 1'b0} ^ {8{q_phase[7]}};
                        d_invert       = 0;
                        d_mute         = q_phase[9];
                    end
                    3'd6: begin
                        d_lut_idx[7:0] = 8'hFF;
                    end
                endcase

                d_state        = StExp;
            end

            StExp: begin
                d_val          = (q_waveform == 3'd7) ? {1'b0, q_phase[8:0] ^ {9{q_phase[9]}}, 3'b0} : {1'b0, lut_data};
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

                d_phase = q_phase + 10'd1;
                if (q_phase == 10'h3FF) begin
                    d_waveform = q_waveform + 3'd1;

                    if (q_waveform == 3'd7)
                        d_atten = q_atten + 12'd128;
                end

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
        end
    end

endmodule
