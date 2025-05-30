`timescale 1 ns / 1 ps

module tb_fmsynth();

    reg clk   = 0;
    reg reset = 1;

    always #20 clk = !clk;
    always #200 reset = 0;

    wire [15:0] audio_l;
    wire [15:0] audio_r;

    fmsynth fmsynth(
        .clk(clk),
        .reset(reset),

        // input  wire  [8:0] addr,
        // output reg  [31:0] rddata

        .audio_l(audio_l),
        .audio_r(audio_r)
    );

endmodule
