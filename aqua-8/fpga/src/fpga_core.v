`default_nettype none
`timescale 1 ns / 1 ps

module fpga_core(
    input  wire         clk_25_175,
    input  wire         reset_25_175,

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

    // Audio outputs (signed 16-bits)s
    output wire  [15:0] audio_l,
    output wire  [15:0] audio_r,

    // Input peripherals
    input  wire   [7:0] hctrl1,
    input  wire   [7:0] hctrl2,
    input  wire  [63:0] keys,
    input  wire  [63:0] gamepad1,
    input  wire  [63:0] gamepad2,
    input  wire  [15:0] kbbuf16_wrdata,
    input  wire         kbbuf16_wren,

    // ESP32 UART
    output wire   [8:0] uart_txfifo_data,
    output wire         uart_txfifo_wren,
    input  wire         uart_txfifo_full,
    input  wire   [8:0] uart_rxfifo_data,
    output wire         uart_rxfifo_rden,
    input  wire         uart_rxfifo_empty
);

    wire clk   = clk_25_175;
    wire reset = reset_25_175;

    assign spi_txdata       = 0;
    assign spi_txdata_valid = 0;

    assign audio_l = 0;
    assign audio_r = 0;

    //////////////////////////////////////////////////////////////////////////
    // Core information
    //////////////////////////////////////////////////////////////////////////
    assign core_type    = 8'h02;
    assign core_flags   = 8'h02;
    assign core_version = {8'd0, 8'd01};
    assign core_name    = "aqua-8          ";

    //////////////////////////////////////////////////////////////////////////
    // CPU
    //////////////////////////////////////////////////////////////////////////
    wire        irq_uart;
    wire        irq_keybuf;
    wire        irq_vblank;

    wire [31:0] cpu_addr;
    wire [31:0] cpu_wrdata;
    wire  [3:0] cpu_bytesel;
    wire        cpu_wren;
    wire        cpu_flush;
    wire        cpu_strobe;
    reg         cpu_wait;
    reg  [31:0] cpu_rddata;
    reg  [31:0] cpu_irq;

    always @* begin
        cpu_irq = 32'b0;
        cpu_irq[20] = irq_uart;
        cpu_irq[19] = irq_keybuf;
        cpu_irq[16] = irq_vblank;
    end

    cpu #(
        .VEC_RESET(32'h00000000),
        .IRQ_USED(32'h001F0080),
        .IRQ_LATCHING(32'h00030000)
    ) cpu(
        .clk(clk),
        .reset(reset),

        // Bus interface
        .bus_addr(cpu_addr),
        .bus_wrdata(cpu_wrdata),
        .bus_bytesel(cpu_bytesel),
        .bus_wren(cpu_wren),
        .bus_flush(cpu_flush),
        .bus_strobe(cpu_strobe),
        .bus_wait(cpu_wait),
        .bus_rddata(cpu_rddata),

        // Interrupt input
        .irq(cpu_irq));

    //////////////////////////////////////////////////////////////////////////
    // Boot ROM
    //////////////////////////////////////////////////////////////////////////
    wire [31:0] bootrom_rddata;

    bootrom bootrom(
        .clk(clk),
        .addr(cpu_addr[10:2]),
        .rddata(bootrom_rddata));

    //////////////////////////////////////////////////////////////////////////
    // SRAM controller
    //////////////////////////////////////////////////////////////////////////
    wire        sram_strobe;
    wire        sram_wait;
    wire [31:0] sram_rddata;

    wire [16:0] sram_m_addr;
    wire [31:0] sram_m_wrdata;
    wire        sram_m_wren;
    wire        sram_m_strobe;
    wire        sram_m_wait;
    wire [31:0] sram_m_rddata;

    wire [18:0] ebus_sram_a;

    sram_ctrl sram_ctrl(
        .clk(clk),
        .reset(reset),

        // Command interface
        .bus_addr(sram_m_addr),
        .bus_wrdata(sram_m_wrdata),
        .bus_wren(sram_m_wren),
        .bus_strobe(sram_m_strobe),
        .bus_wait(sram_m_wait),
        .bus_rddata(sram_m_rddata),

        // SRAM interface
        .sram_a(sram_a),
        .sram_ce_n(sram_ce_n),
        .sram_oe_n(sram_oe_n),
        .sram_we_n(sram_we_n),
        .sram_dq(sram_dq));

    sram_cache sram_cache(
        .clk(clk),
        .reset(reset),

        // Slave bus interface (from CPU)
        .s_addr(cpu_addr[18:2]),
        .s_wrdata(cpu_wrdata),
        .s_bytesel(cpu_bytesel),
        .s_wren(cpu_wren),
        .s_flush(cpu_flush),
        .s_strobe(sram_strobe),
        .s_wait(sram_wait),
        .s_rddata(sram_rddata),

        // Memory command interface
        .m_addr(sram_m_addr),
        .m_wrdata(sram_m_wrdata),
        .m_wren(sram_m_wren),
        .m_strobe(sram_m_strobe),
        .m_wait(sram_m_wait),
        .m_rddata(sram_m_rddata));

    //////////////////////////////////////////////////////////////////////////
    // ESP32 UART
    //////////////////////////////////////////////////////////////////////////
    wire   reg_esp_data_strobe;
    assign uart_txfifo_data = cpu_wrdata[8:0];
    assign uart_txfifo_wren =  cpu_wren && reg_esp_data_strobe;
    assign uart_rxfifo_rden = !cpu_wren && reg_esp_data_strobe;
    assign irq_uart         = !uart_rxfifo_empty;

    //////////////////////////////////////////////////////////////////////////
    // Keyboard buffer
    //////////////////////////////////////////////////////////////////////////
    wire        reg_keybuf_strobe;
    wire        kbbuf_rst  = (cpu_wren && reg_keybuf_strobe) || reset;
    wire        kbbuf_rden = !cpu_wren && reg_keybuf_strobe;
    wire [15:0] kbbuf_rddata;
    wire        kbbuf_empty;

    kbbuf kbbuf(
        .clk(clk),
        .rst(kbbuf_rst),

        .wrdata(kbbuf16_wrdata),
        .wr_en(kbbuf16_wren),

        .rddata(kbbuf_rddata),
        .rd_en(kbbuf_rden),
        .rd_empty(kbbuf_empty));

    assign irq_keybuf = !kbbuf_empty;

    //////////////////////////////////////////////////////////////////////////
    // Video
    //////////////////////////////////////////////////////////////////////////
    wire        video_strobe;
    wire        video_wait;
    wire [31:0] video_rddata;

    video video(
        .clk(clk),
        .reset(reset),

        .irq_vblank(irq_vblank),

        .bus_addr(cpu_addr[16:0]),
        .bus_wrdata(cpu_wrdata),
        .bus_bytesel(cpu_bytesel),
        .bus_wren(cpu_wren),
        .bus_strobe(video_strobe),
        .bus_wait(video_wait),
        .bus_rddata(video_rddata),

        .video_hpos(video_hpos),
        .video_hlast(video_hlast),
        .video_vpos(video_vpos),
        .video_vlast(video_vlast),
        .video_r(video_r),
        .video_g(video_g),
        .video_b(video_b));

    //////////////////////////////////////////////////////////////////////////
    // CPU bus interconnect
    //////////////////////////////////////////////////////////////////////////
    wire   bootrom_strobe        = cpu_strobe && {cpu_addr[31:11], 11'b0} == 32'h00000;
    wire   reg_esp_status_strobe = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h02000;
    assign reg_esp_data_strobe   = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h02004;
    assign reg_keybuf_strobe     = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h02010;
    wire   reg_hctrl_strobe      = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h02014;
    wire   reg_keys_l_strobe     = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h02018;
    wire   reg_keys_h_strobe     = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h0201C;
    wire   reg_gamepad1_l_strobe = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h02020;
    wire   reg_gamepad1_h_strobe = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h02024;
    wire   reg_gamepad2_l_strobe = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h02028;
    wire   reg_gamepad2_h_strobe = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h0202C;
    assign video_strobe          = cpu_strobe && {cpu_addr[31:17], 17'b0} == 32'h20000;
    assign sram_strobe           = cpu_strobe && {cpu_addr[31:19], 19'b0} == 32'h80000;

    reg [31:0] q_cpu_addr;
    always @(posedge clk) q_cpu_addr <= cpu_addr;
    wire common_wait = !cpu_wren && (q_cpu_addr != cpu_addr);

    always @* begin
        cpu_wait = 0;
        if (bootrom_strobe) cpu_wait = common_wait;
        if (video_strobe)   cpu_wait = video_wait;
        if (sram_strobe)    cpu_wait = sram_wait;
    end

    always @* begin
        cpu_rddata = 0;
        if (bootrom_strobe)        cpu_rddata = bootrom_rddata;
        if (reg_esp_status_strobe) cpu_rddata = {30'b0, uart_txfifo_full, !uart_rxfifo_empty};
        if (reg_esp_data_strobe)   cpu_rddata = {23'b0, uart_rxfifo_data};
        if (reg_keybuf_strobe)     cpu_rddata = {kbbuf_empty, 15'b0, kbbuf_rddata};
        if (reg_hctrl_strobe)      cpu_rddata = {16'b0, hctrl2, hctrl1};
        if (reg_keys_l_strobe)     cpu_rddata = keys[31:0];
        if (reg_keys_h_strobe)     cpu_rddata = keys[63:32];
        if (reg_gamepad1_l_strobe) cpu_rddata = gamepad1[31:0];
        if (reg_gamepad1_h_strobe) cpu_rddata = gamepad1[63:32];
        if (reg_gamepad2_l_strobe) cpu_rddata = gamepad2[31:0];
        if (reg_gamepad2_h_strobe) cpu_rddata = gamepad2[63:32];
        if (video_strobe)          cpu_rddata = video_rddata;
        if (sram_strobe)           cpu_rddata = sram_rddata;
    end

endmodule
