`default_nettype none
`timescale 1 ns / 1 ps

module fpga_core(
    input  wire         clk_25_175,
    input  wire         clk_28_63636,

    // Core information
    output wire   [7:0] core_type,
    output wire   [7:0] core_flags,
    output wire  [15:0] core_version,
    output wire [127:0] core_name,

    // Interface for core specific messages
    input  wire         spi_msg_end,
    input  wire   [7:0] spi_cmd,
    input  wire  [63:0] spi_rxdata,
    output wire  [63:0] spi_txdata,
    output wire         spi_txdata_valid,

    // Memory interface
    output wire  [18:0] sram_a,
    output wire         sram_ce_n,
    output wire         sram_oe_n,
    output wire         sram_we_n,
    inout  wire   [7:0] sram_dq,

    // Video output
    input  wire   [9:0] video_hpos,
    input  wire         video_hlast,
    input  wire   [9:0] video_vpos,
    input  wire         video_vlast,
    output wire   [3:0] video_r,
    output wire   [3:0] video_g,
    output wire   [3:0] video_b,

    // PWM audio outputs
    output wire         audio_l,
    output wire         audio_r,

    // ESP32 serial interface
    output wire         esp_tx,
    input  wire         esp_rx,
    output wire         esp_rts,
    input  wire         esp_cts
);

    //////////////////////////////////////////////////////////////////////////
    // Core information
    //////////////////////////////////////////////////////////////////////////
    assign core_type    = 8'h02;
    assign core_flags   = 8'h00;
    assign core_version = {8'd0, 8'd01};
    assign core_name    = "My32            ";

    //////////////////////////////////////////////////////////////////////////
    // Generate reset signal
    //////////////////////////////////////////////////////////////////////////
    wire reset_req = 0;

    reg [4:0] q_reset_cnt = 0;
    always @(posedge clk_25_175)
        if (!q_reset_cnt[4]) q_reset_cnt <= q_reset_cnt + 5'b1;
        else if (reset_req)  q_reset_cnt <= 5'b0;

    wire reset = !q_reset_cnt[4];

    //////////////////////////////////////////////////////////////////////////
    // Interface for core specific messages
    //////////////////////////////////////////////////////////////////////////
    assign spi_txdata = 0;
    assign spi_txdata_valid = 0;

    //////////////////////////////////////////////////////////////////////////
    // Memory
    //////////////////////////////////////////////////////////////////////////
    wire [18:0] mem_addr;
    wire  [7:0] mem_wrdata = 0;
    wire        mem_wren = 0;
    wire        mem_strobe;
    wire        mem_wait;
    wire  [7:0] mem_rddata;
    wire        mem_rddata_valid;

    sram_ctrl sram_ctrl(
        .clk(clk_25_175),
        .reset(reset),

        // Memory interface (pipelined)
        .mem_addr(mem_addr),
        .mem_wrdata(mem_wrdata),
        .mem_wren(mem_wren),
        .mem_strobe(mem_strobe),
        .mem_wait(mem_wait),
        .mem_rddata(mem_rddata),
        .mem_rddata_valid(mem_rddata_valid),

        // SRAM memory interface
        .sram_a(sram_a),
        .sram_oe_n(sram_oe_n),
        .sram_ce_n(sram_ce_n),
        .sram_we_n(sram_we_n),
        .sram_dq(sram_dq)
    );

    //////////////////////////////////////////////////////////////////////////
    // Video
    //////////////////////////////////////////////////////////////////////////

    // Palette interface
    wire   [7:0] palette_idx    = 0;
    wire  [11:0] palette_wrdata = 0;
    wire         palette_wren   = 0;
    wire  [11:0] palette_rddata;

    // Register interface
    wire         video_mode = 0;
    wire  [18:0] base_addr = 0;

    wire  [18:0] next_line_addr_wrdata = 0;
    wire         next_line_addr_wren = 0;
    wire  [18:0] next_line_addr_rddata;

    video video(
        .clk(clk_25_175),
        .reset(reset),

        // Palette interface
        .palette_idx(palette_idx),
        .palette_wrdata(palette_wrdata),
        .palette_wren(palette_wren),
        .palette_rddata(palette_rddata),

        // Register interface
        .video_mode(video_mode),
        .base_addr(base_addr),

        .next_line_addr_wrdata(next_line_addr_wrdata),
        .next_line_addr_wren(next_line_addr_wren),
        .next_line_addr_rddata(next_line_addr_rddata),

        // Memory interface (pipelined)
        .mem_addr(mem_addr),
        .mem_strobe(mem_strobe),
        .mem_wait(mem_wait),
        .mem_rddata(mem_rddata),
        .mem_rddata_valid(mem_rddata_valid),

        // Video output
        .video_hpos(video_hpos),
        .video_hlast(video_hlast),
        .video_vpos(video_vpos),
        .video_vlast(video_vlast),
        .video_r(video_r),
        .video_g(video_g),
        .video_b(video_b)
    );

    //////////////////////////////////////////////////////////////////////////
    // Audio
    //////////////////////////////////////////////////////////////////////////
    assign audio_l = 0;
    assign audio_r = 0;

    //////////////////////////////////////////////////////////////////////////
    // ESP32 serial interface
    //////////////////////////////////////////////////////////////////////////
    assign esp_tx  = 1;
    assign esp_rts = 1;

endmodule
