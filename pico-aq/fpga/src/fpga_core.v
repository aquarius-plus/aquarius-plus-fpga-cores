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
    assign core_name    = "pico-aq         ";

    wire        irq_uart;
    wire        irq_keybuf;

    wire [31:0] cpu_addr;
    wire [31:0] cpu_wrdata;
    wire  [3:0] cpu_bytesel;
    wire        cpu_wren;
    wire        cpu_strobe;

    //////////////////////////////////////////////////////////////////////////
    // Time tick generation (1ms)
    //////////////////////////////////////////////////////////////////////////
    wire       reg_mtime_strobe;
    wire       reg_mtimeh_strobe;
    wire       reg_mtimecmp_strobe;
    wire       reg_mtimecmph_strobe;

    reg [14:0] q_time_tick_cnt;
    reg        q_time_tick;
    reg [63:0] q_mtime;
    reg [63:0] q_mtimecmp;
    reg        q_mtimeirq;

    always @(posedge clk or posedge reset)
        if (reset) begin
            q_time_tick_cnt <= 0;
            q_time_tick     <= 0;
        end else begin
            q_time_tick <= 0;

            if (q_time_tick_cnt == 15'd25174) begin
                q_time_tick_cnt <= 0;
                q_time_tick     <= 1;
            end else begin
                q_time_tick_cnt <= q_time_tick_cnt + 15'd1;
            end
        end

    always @(posedge clk or posedge reset)
        if (reset) begin
            q_mtime    <= 0;
            q_mtimecmp <= 0;
            q_mtimeirq <= 0;

        end else begin
            if (q_time_tick)
                q_mtime <= q_mtime + 64'd1;

            q_mtimeirq <= q_mtimecmp <= q_mtime;

            if (reg_mtime_strobe     && cpu_wren) q_mtime[31:0]     <= cpu_wrdata;
            if (reg_mtimeh_strobe    && cpu_wren) q_mtime[63:32]    <= cpu_wrdata;
            if (reg_mtimecmp_strobe  && cpu_wren) q_mtimecmp[31:0]  <= cpu_wrdata;
            if (reg_mtimecmph_strobe && cpu_wren) q_mtimecmp[63:32] <= cpu_wrdata;
        end

    //////////////////////////////////////////////////////////////////////////
    // CPU
    //////////////////////////////////////////////////////////////////////////
    reg         cpu_wait;
    reg  [31:0] cpu_rddata;
    reg  [31:0] cpu_irq;

    always @* begin
        cpu_irq = 32'b0;
        cpu_irq[20] = irq_uart;
        cpu_irq[19] = irq_keybuf;
        cpu_irq[16] = irq_vblank;
        cpu_irq[ 7] = q_mtimeirq;
    end

    cpu #(
        .VEC_RESET(32'h00000000),
        .IRQ_USED(32'h001F0080),
        .IRQ_LATCHING(32'h00030000)
    ) cpu(
        .clk(clk),
        .reset(reset),

        .mtime(q_mtime),

        // Bus interface
        .bus_addr(cpu_addr),
        .bus_wrdata(cpu_wrdata),
        .bus_bytesel(cpu_bytesel),
        .bus_wren(cpu_wren),
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
    wire  [3:0] sram_m_bytesel;
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
        .bus_bytesel(sram_m_bytesel),
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


`define USE_CACHE
`ifdef USE_CACHE
    assign sram_m_bytesel = 4'b1111;

    sram_cache sram_cache(
        .clk(clk),
        .reset(reset),

        // Slave bus interface (from CPU)
        .s_addr(cpu_addr[18:2]),
        .s_wrdata(cpu_wrdata),
        .s_bytesel(cpu_bytesel),
        .s_wren(cpu_wren),
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

`else

    assign sram_m_addr    = cpu_addr[18:2];
    assign sram_m_wrdata  = cpu_wrdata;
    assign sram_m_bytesel = cpu_bytesel;
    assign sram_m_wren    = cpu_wren;
    assign sram_m_strobe  = sram_strobe;
    assign sram_wait      = sram_m_wait;
    assign sram_rddata    = sram_m_rddata;

`endif

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
        .rd_empty(kbbuf_empty)
    );

    assign irq_keybuf = !kbbuf_empty;

    //////////////////////////////////////////////////////////////////////////
    // Video
    //////////////////////////////////////////////////////////////////////////
    wire        irq_vblank;

    wire        tram_strobe;
    wire        chram_strobe;
    wire        pal_strobe;

    wire        tram_wren     = cpu_wren && tram_strobe;
    wire        chram_wren    = cpu_wren && chram_strobe;
    wire        pal_wren      = cpu_wren && pal_strobe;

    wire [31:0] tram_rddata;
    wire  [7:0] chram_rddata;
    wire [11:0] pal_rddata;

    video video(
        .clk(clk),
        .reset(reset),

        .irq_vblank(irq_vblank),

        .tram_addr(cpu_addr[12:2]),
        .tram_rddata(tram_rddata),
        .tram_wrdata(cpu_wrdata),
        .tram_bytesel(cpu_bytesel),
        .tram_wren(tram_wren),

        .chram_addr(cpu_addr[10:0]),
        .chram_rddata(chram_rddata),
        .chram_wrdata(cpu_wrdata[7:0]),
        .chram_wren(chram_wren),

        .pal_addr(cpu_addr[7:1]),
        .pal_rddata(pal_rddata),
        .pal_wrdata(cpu_wrdata[11:0]),
        .pal_wren(pal_wren),

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

    assign reg_mtime_strobe      = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h02080;
    assign reg_mtimeh_strobe     = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h02084;
    assign reg_mtimecmp_strobe   = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h02088;
    assign reg_mtimecmph_strobe  = cpu_strobe && {cpu_addr[31: 2],  2'b0} == 32'h0208C;

    assign pal_strobe            = cpu_strobe && {cpu_addr[31: 8],  8'b0} == 32'h04000;
    assign chram_strobe          = cpu_strobe && {cpu_addr[31:11], 11'b0} == 32'h05000;
    assign tram_strobe           = cpu_strobe && {cpu_addr[31:13], 13'b0} == 32'h06000;
    assign sram_strobe           = cpu_strobe && {cpu_addr[31:19], 19'b0} == 32'h80000;

    reg [31:0] q_cpu_addr;
    always @(posedge clk) q_cpu_addr <= cpu_addr;

    wire common_wait = !cpu_wren && (q_cpu_addr != cpu_addr);

    always @* begin
        cpu_wait = 0;
        if (bootrom_strobe)   cpu_wait = common_wait;
        if (chram_strobe)     cpu_wait = common_wait;
        if (tram_strobe)      cpu_wait = common_wait;
        if (sram_strobe)      cpu_wait = sram_wait;
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

        if (reg_mtime_strobe)      cpu_rddata = q_mtime[31:0];
        if (reg_mtimeh_strobe)     cpu_rddata = q_mtime[63:32];
        if (reg_mtimecmp_strobe)   cpu_rddata = q_mtimecmp[31:0];
        if (reg_mtimecmph_strobe)  cpu_rddata = q_mtimecmp[63:32];

        if (pal_strobe)            cpu_rddata = {4'b0, pal_rddata, 4'b0, pal_rddata};
        if (chram_strobe)          cpu_rddata = {chram_rddata, chram_rddata, chram_rddata, chram_rddata};
        if (tram_strobe)           cpu_rddata = tram_rddata;
        if (sram_strobe)           cpu_rddata = sram_rddata;
    end

endmodule
