`timescale 1 ns / 1 ps

module tb_fmsynth();

    reg clk   = 0;
    reg reset = 1;

    always #20 clk = !clk;
    always #200 reset = 0;

    wire [15:0] audio_l;
    wire [15:0] audio_r;

    reg   [7:0] bus_addr;
    reg  [31:0] bus_wrdata;
    reg         bus_wren;
    wire [31:0] bus_rddata;

    fmsynth fmsynth(
        .clk(clk),
        .reset(reset),

        .addr(bus_addr),
        .wrdata(bus_wrdata),
        .wren(bus_wren),
        .rddata(bus_rddata),

        .audio_l(audio_l),
        .audio_r(audio_r)
    );

    task regwr;
        input  [7:0] addr;
        input [31:0] data;

        begin
            bus_addr    = addr;
            bus_wrdata  = data;
            bus_wren    = 1;
            @(posedge clk);
            bus_wren  = 0;
        end
    endtask

    initial begin
        bus_addr   = 0;
        bus_wrdata = 0;
        bus_wren   = 0;

        @(negedge(reset));
        @(posedge(clk));

        regwr(8'h60, {10'b0, 1'b0, 1'b0, 3'd0, 1'b0, 2'b0, 1'b0, 3'd0, 10'd100});
        regwr(8'h80, {1'b0, 1'b0, 1'b0, 1'b0, 4'd8, 2'd0 , 6'd0, 4'd0, 4'd0, 4'd0, 4'd0});

    end

endmodule
