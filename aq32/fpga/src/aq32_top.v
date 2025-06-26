`default_nettype none
`timescale 1 ns / 1 ps

module aq32_top(
    input  wire        sysclk,          // 14.31818MHz

    // Z80 bus interface
    inout  wire        ebus_reset_n,
    output wire        ebus_phi,        // 3.579545MHz
    output wire [15:0] ebus_a,
    inout  wire  [7:0] ebus_d,
    output wire        ebus_rd_n,
    output wire        ebus_wr_n,
    output wire        ebus_mreq_n,
    output wire        ebus_iorq_n,
    output wire        ebus_int_n,      // Open-drain output
    output wire        ebus_busreq_n,   // Open-drain output
    input  wire        ebus_busack_n,
    output wire  [4:0] ebus_ba,
    output wire        ebus_ram_ce_n,   // 512KB RAM
    output wire        ebus_cart_ce_n,  // Cartridge
    output wire        ebus_ram_we_n,

    // PWM audio outputs
    output wire        audio_l,
    output wire        audio_r,

    // Other
    output wire        cassette_out,
    input  wire        cassette_in,
    output wire        printer_out,
    input  wire        printer_in,

    // Misc
    output wire  [8:0] exp,
    input  wire        has_z80,

    // Hand controller interface
    inout  wire  [8:0] hc1,
    inout  wire  [8:0] hc2,

    // VGA output
    output wire  [3:0] vga_r,
    output wire  [3:0] vga_g,
    output wire  [3:0] vga_b,
    output wire        vga_hsync,
    output wire        vga_vsync,

    // ESP32 serial interface
    output wire        esp_tx,
    input  wire        esp_rx,
    output wire        esp_rts,
    input  wire        esp_cts,

    // ESP32 SPI interface (also used for loading FPGA image)
    input  wire        esp_ssel_n,
    input  wire        esp_sclk,
    input  wire        esp_mosi,
    output wire        esp_miso,
    output wire        esp_notify
);

    assign exp            = 9'b0;
    assign hc1[7:0]       = 8'bZ;
    assign hc2[7:0]       = 8'bZ;
    assign hc1[8]         = 1'b0;
    assign hc2[8]         = 1'b0;
    assign cassette_out   = 1'b0;
    assign printer_out    = 1'b0;
    assign ebus_cart_ce_n = 1'b1;
    assign ebus_reset_n   = 1'bZ;
    assign ebus_wr_n      = 1'b1;
    assign ebus_a[15:14]  = 2'bZ;
    assign ebus_mreq_n    = 1'b1;
    assign ebus_iorq_n    = 1'b1;
    assign ebus_int_n     = 1'bZ;
    assign ebus_busreq_n  = 1'b0;

    wire        spi_reset_req;
    wire        reset_req_cold;

    wire irq_uart;
    wire irq_keybuf;
    wire irq_pcm;
    wire irq_line, irq_vblank;

    //////////////////////////////////////////////////////////////////////////
    // Clock synthesizer
    //////////////////////////////////////////////////////////////////////////
    wire clk;
    aqp_clkctrl clkctrl(
        .clk_in(sysclk),        // 14.31818MHz
        .clk_out(clk)           // 25.175MHz
    );

    //////////////////////////////////////////////////////////////////////////
    // System controller (reset and clock generation)
    //////////////////////////////////////////////////////////////////////////
    wire reset_req = spi_reset_req;
    wire ebus_phi_clken;
    wire reset;

    aqp_sysctrl sysctrl(
        .sysclk(clk),
        .reset_req(reset_req),

        .ebus_phi(ebus_phi),
        .ebus_phi_clken(ebus_phi_clken),
        .reset(reset));

    //////////////////////////////////////////////////////////////////////////
    // CPU
    //////////////////////////////////////////////////////////////////////////
    wire [31:0] cpu_addr;
    wire [31:0] cpu_wrdata;
    wire  [3:0] cpu_bytesel;
    wire        cpu_wren;
    wire        cpu_strobe;
    reg         cpu_wait;
    reg  [31:0] cpu_rddata;

    wire [15:0] cpu_irq = {11'b0, irq_uart, irq_keybuf, irq_pcm, irq_line, irq_vblank};

    cpu #(.VEC_RESET(32'h00000000)) cpu(
        .clk(clk),
        .reset(reset),

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
    assign ebus_a[13:0] = ebus_sram_a[13:0];
    assign ebus_ba      = ebus_sram_a[18:14];

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
        .sram_a(ebus_sram_a),
        .sram_ce_n(ebus_ram_ce_n),
        .sram_oe_n(ebus_rd_n),
        .sram_we_n(ebus_ram_we_n),
        .sram_dq(ebus_d));


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
    wire [8:0] esp_tx_data;
    wire       esp_tx_wr;
    wire       esp_tx_fifo_full;
    wire [8:0] esp_rx_data;
    wire       esp_rx_rd;
    wire       esp_rx_empty;
    wire       esp_rx_fifo_overflow;
    wire       esp_rx_framing_error;

    aqp_esp_uart esp_uart(
        .clk(clk),
        .reset(reset),

        .txfifo_data(esp_tx_data),
        .txfifo_wr(esp_tx_wr),
        .txfifo_full(esp_tx_fifo_full),

        .rxfifo_data(esp_rx_data),
        .rxfifo_rd(esp_rx_rd),
        .rxfifo_empty(esp_rx_empty),
        .rxfifo_overflow(esp_rx_fifo_overflow),
        .rx_framing_error(esp_rx_framing_error),

        .esp_rx(esp_rx),
        .esp_tx(esp_tx),
        .esp_cts(esp_cts),
        .esp_rts(esp_rts));

    assign irq_uart = !esp_rx_empty;

    //////////////////////////////////////////////////////////////////////////
    // ESP SPI slave interface
    //////////////////////////////////////////////////////////////////////////
    wire        spi_msg_end;
    wire  [7:0] spi_cmd;
    wire [63:0] spi_rxdata;
    wire [63:0] spi_txdata;
    wire        spi_txdata_valid;

    wire  [9:0] ovl_text_addr;
    wire [15:0] ovl_text_wrdata;
    wire        ovl_text_wr;

    wire [10:0] ovl_font_addr;
    wire  [7:0] ovl_font_wrdata;
    wire        ovl_font_wr;

    wire  [3:0] ovl_palette_addr;
    wire [15:0] ovl_palette_wrdata;
    wire        ovl_palette_wr;

    assign spi_txdata       = 64'b0;
    assign spi_txdata_valid = 1'b0;

    aqp_esp_spi esp_spi(
        .clk(clk),
        .reset(reset),

        // System information
        .sysinfo_core_type(8'h02),
        .sysinfo_flags({
            1'b0,       // Core type 01 specific: unused
            1'b0,       // Core type 01 specific: unused
            1'b0,       // Core type 01 specific: unused
            1'b0,       // Core type 01 specific: show force turbo mode
            1'b0,       // Core type 01 specific: show Aquarius+ options
            1'b0,       // Core type 01 specific: show video timing switch
            1'b1,       // Core type 01 specific: show mouse support
            1'b0        // Z80 present
        }),
        .sysinfo_version_major(8'h00),
        .sysinfo_version_minor(8'h01),

        .core_name("Aquarius32      "),

        // Interface for core specific messages
        .spi_msg_end(spi_msg_end),
        .spi_cmd(spi_cmd),
        .spi_rxdata(spi_rxdata),
        .spi_txdata(spi_txdata),
        .spi_txdata_valid(spi_txdata_valid),

        // Display overlay interface
        .ovl_text_addr(ovl_text_addr),
        .ovl_text_wrdata(ovl_text_wrdata),
        .ovl_text_wr(ovl_text_wr),

        .ovl_font_addr(ovl_font_addr),
        .ovl_font_wrdata(ovl_font_wrdata),
        .ovl_font_wr(ovl_font_wr),

        .ovl_palette_addr(ovl_palette_addr),
        .ovl_palette_wrdata(ovl_palette_wrdata),
        .ovl_palette_wr(ovl_palette_wr),

        // ESP SPI slave interface
        .esp_ssel_n(esp_ssel_n),
        .esp_sclk(esp_sclk),
        .esp_mosi(esp_mosi),
        .esp_miso(esp_miso),
        .esp_notify(esp_notify));


    //////////////////////////////////////////////////////////////////////////
    // SPI interface
    //////////////////////////////////////////////////////////////////////////
    wire [63:0] keys;

    wire [15:0] kbbuf_data;
    wire        kbbuf_wren;

    spiregs spiregs(
        .clk(clk),
        .reset(reset),

        .spi_msg_end(spi_msg_end),
        .spi_cmd(spi_cmd),
        .spi_rxdata(spi_rxdata),
        .spi_txdata(spi_txdata),
        .spi_txdata_valid(spi_txdata_valid),

        .reset_req(spi_reset_req),
        .reset_req_cold(reset_req_cold),
        .keys(keys),

        .kbbuf_data(kbbuf_data),
        .kbbuf_wren(kbbuf_wren));

    //////////////////////////////////////////////////////////////////////////
    // Keyboard buffer
    //////////////////////////////////////////////////////////////////////////
    wire        kbbuf_rst;
    wire [15:0] kbbuf_rddata;
    wire        kbbuf_rden;
    wire        kbbuf_empty;

    kbbuf kbbuf(
        .clk(clk),
        .rst(kbbuf_rst),

        .wrdata(kbbuf_data),
        .wr_en(kbbuf_wren),

        .rddata(kbbuf_rddata),
        .rd_en(kbbuf_rden),
        .rd_empty(kbbuf_empty)
    );

    assign irq_keybuf = !kbbuf_empty;

    //////////////////////////////////////////////////////////////////////////
    // PCM playback
    //////////////////////////////////////////////////////////////////////////
    wire        pcm_strobe;
    wire [31:0] pcm_rddata;
    wire        pcm_wait;
    wire [15:0] pcm_audio_l;
    wire [15:0] pcm_audio_r;

    pcm pcm(
        .clk(clk),
        .reset(reset),

        .bus_addr(cpu_addr[3:2]),
        .bus_wrdata(cpu_wrdata),
        .bus_wren(pcm_strobe && cpu_wren),
        .bus_rddata(pcm_rddata),

        .irq(irq_pcm),

        .audio_l(pcm_audio_l),
        .audio_r(pcm_audio_r)
    );

    //////////////////////////////////////////////////////////////////////////
    // FM synthesizer
    //////////////////////////////////////////////////////////////////////////
    wire        fmsynth_strobe;
    wire [31:0] fmsynth_rddata;
    wire        fmsynth_wait;
    wire [15:0] fmsynth_audio_l;
    wire [15:0] fmsynth_audio_r;

    fmsynth fmsynth(
        .clk(clk),
        .reset(reset),

        .bus_addr(cpu_addr[9:2]),
        .bus_wrdata(cpu_wrdata),
        .bus_wren(fmsynth_strobe && cpu_wren),
        .bus_rddata(fmsynth_rddata),
        .bus_wait(fmsynth_wait),

        .audio_l(fmsynth_audio_l),
        .audio_r(fmsynth_audio_r)
    );

    //////////////////////////////////////////////////////////////////////////
    // PWM DAC
    //////////////////////////////////////////////////////////////////////////
    wire [16:0] summed_l = {pcm_audio_l[15], pcm_audio_l} + {fmsynth_audio_l[15], fmsynth_audio_l};
    wire [16:0] summed_r = {pcm_audio_r[15], pcm_audio_r} + {fmsynth_audio_r[15], fmsynth_audio_r};

    reg  [15:0] common_audio_l;
    reg  [15:0] common_audio_r;

    always @* begin
        // Clamp output signal
        common_audio_l = summed_l[15:0];
        if (summed_l[16:15] == 2'b10)
            common_audio_l = 16'h8000;
        else if (summed_l[16:15] == 2'b01)
            common_audio_l = 16'h7FFF;

        // Clamp output signal
        common_audio_r = summed_r[15:0];
        if (summed_r[16:15] == 2'b10)
            common_audio_r = 16'h8000;
        else if (summed_r[16:15] == 2'b01)
            common_audio_r = 16'h7FFF;
    end

    aqp_pwm_dac pwm_dac(
        .clk(clk),
        .reset(reset),

        // Sample input
        .next_sample(1'b1),
        .left_data(common_audio_l),
        .right_data(common_audio_r),

        // PWM audio output
        .audio_l(audio_l),
        .audio_r(audio_r));

    //////////////////////////////////////////////////////////////////////////
    // Video
    //////////////////////////////////////////////////////////////////////////
    wire [3:0] video_r;
    wire [3:0] video_g;
    wire [3:0] video_b;
    wire       video_de;
    wire       video_hsync;
    wire       video_vsync;
    wire       video_newframe;
    wire       video_oddline;

    wire       video_irq;

    wire       sprattr_strobe;
    wire       tram_strobe;
    wire       chram_strobe;
    wire       pal_strobe;
    wire       vram_strobe;
    wire       vram4bpp_strobe;

    wire       sprattr_wren  = cpu_wren && sprattr_strobe;
    wire       tram_wren     = cpu_wren && tram_strobe;
    wire       chram_wren    = cpu_wren && chram_strobe;
    wire       pal_wren      = cpu_wren && pal_strobe;

    wire [31:0] sprattr_rddata;
    wire [15:0] tram_rddata;
    wire  [7:0] chram_rddata;
    wire [15:0] pal_rddata;
    wire [31:0] vram_rddata;
    wire [31:0] vram4bpp_rddata;

    reg        q_vctrl_text_mode80;
    reg        q_vctrl_text_priority;
    reg        q_vctrl_gfx_tilemode;
    reg        q_vctrl_sprites_enable;
    reg        q_vctrl_gfx_enable;
    reg        q_vctrl_text_enable;
    reg  [8:0] q_vscrx;
    reg  [7:0] q_vscry;
    wire [8:0] vline;
    reg  [8:0] q_virqline;

    wire [12:0] vram_addr = vram4bpp_strobe ? cpu_addr[15:3] : cpu_addr[14:2];
    reg  [31:0] vram_wrdata;
    reg   [7:0] vram_wrsel;
    wire        vram_wren = cpu_wren && (vram_strobe || vram4bpp_strobe);

    always @* begin
        vram_wrdata = cpu_wrdata;
        vram_wrsel = {
            cpu_bytesel[3], cpu_bytesel[3],
            cpu_bytesel[2], cpu_bytesel[2],
            cpu_bytesel[1], cpu_bytesel[1],
            cpu_bytesel[0], cpu_bytesel[0]
        };

        if (vram4bpp_strobe) begin
            vram_wrdata = {
                cpu_wrdata[19:16], cpu_wrdata[27:24], cpu_wrdata[3:0], cpu_wrdata[11:8],
                cpu_wrdata[19:16], cpu_wrdata[27:24], cpu_wrdata[3:0], cpu_wrdata[11:8]
            };
            vram_wrsel = cpu_addr[2] ?
                {      cpu_bytesel[2], cpu_bytesel[3], cpu_bytesel[0], cpu_bytesel[1], 4'b0} :
                {4'b0, cpu_bytesel[2], cpu_bytesel[3], cpu_bytesel[0], cpu_bytesel[1]      };
        end
    end

    reg    q_vram_addr0;
    always @(posedge clk) q_vram_addr0 <= cpu_addr[2];
    assign vram4bpp_rddata = q_vram_addr0 ?
        {4'b0, vram_rddata[27:24], 4'b0, vram_rddata[31:28], 4'b0, vram_rddata[19:16], 4'b0, vram_rddata[23:20]} :
        {4'b0, vram_rddata[11: 8], 4'b0, vram_rddata[15:12], 4'b0, vram_rddata[ 3: 0], 4'b0, vram_rddata[ 7: 4]};

    video video(
        .clk(clk),
        .reset(reset),

        .reg_sprites_enable(q_vctrl_sprites_enable),
        .reg_gfx_tilemode(q_vctrl_gfx_tilemode),
        .reg_gfx_enable(q_vctrl_gfx_enable),
        .reg_text_priority(q_vctrl_text_priority),
        .reg_text_mode80(q_vctrl_text_mode80),
        .reg_text_enable(q_vctrl_text_enable),
        .reg_scroll_x(q_vscrx),
        .reg_scroll_y(q_vscry),
        .reg_irqline(q_virqline),
        .vline(vline),

        .sprattr_addr(cpu_addr[8:2]),
        .sprattr_rddata(sprattr_rddata),
        .sprattr_wrdata(cpu_wrdata),
        .sprattr_wren(sprattr_wren),

        .irq_line(irq_line),
        .irq_vblank(irq_vblank),

        .tram_addr(cpu_addr[11:1]),
        .tram_rddata(tram_rddata),
        .tram_wrdata(cpu_wrdata[15:0]),
        .tram_bytesel(cpu_bytesel[3:2] | cpu_bytesel[1:0]),
        .tram_wren(tram_wren),

        .chram_addr(cpu_addr[10:0]),
        .chram_rddata(chram_rddata),
        .chram_wrdata(cpu_wrdata[7:0]),
        .chram_wren(chram_wren),

        .pal_addr(cpu_addr[6:1]),
        .pal_rddata(pal_rddata),
        .pal_wrdata(cpu_wrdata[15:0]),
        .pal_wren(pal_wren),

        .vram_addr(vram_addr),
        .vram_wrdata(vram_wrdata),
        .vram_wrsel(vram_wrsel),
        .vram_wren(vram_wren),
        .vram_rddata(vram_rddata),

        .video_r(video_r),
        .video_g(video_g),
        .video_b(video_b),
        .video_de(video_de),
        .video_hsync(video_hsync),
        .video_vsync(video_vsync),
        .video_newframe(video_newframe),
        .video_oddline(video_oddline));

    //////////////////////////////////////////////////////////////////////////
    // Display overlay
    //////////////////////////////////////////////////////////////////////////
    aqp_overlay overlay(
        // Core video interface
        .video_clk(clk),
        .video_r(video_r),
        .video_g(video_g),
        .video_b(video_b),
        .video_de(video_de),
        .video_hsync(video_hsync),
        .video_vsync(video_vsync),
        .video_newframe(video_newframe),
        .video_oddline(video_oddline),
        .video_mode(1'b1),

        // Overlay interface
        .ovl_clk(clk),

        .ovl_text_addr(ovl_text_addr),
        .ovl_text_wrdata(ovl_text_wrdata),
        .ovl_text_wr(ovl_text_wr),

        .ovl_font_addr(ovl_font_addr),
        .ovl_font_wrdata(ovl_font_wrdata),
        .ovl_font_wr(ovl_font_wr),

        .ovl_palette_addr(ovl_palette_addr),
        .ovl_palette_wrdata(ovl_palette_wrdata),
        .ovl_palette_wr(ovl_palette_wr),

        // VGA signals
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync)
    );

    //////////////////////////////////////////////////////////////////////////
    // CPU bus interconnect
    //////////////////////////////////////////////////////////////////////////
    wire   bootrom_strobe   = cpu_strobe && cpu_addr[31:12] == 20'h00000;
    wire   regs_strobe      = cpu_strobe && cpu_addr[31:10] == {20'h00002, 2'b00};
    assign pcm_strobe       = cpu_strobe && cpu_addr[31:10] == {20'h00002, 2'b01};
    assign fmsynth_strobe   = cpu_strobe && cpu_addr[31:11] == {20'h00002, 1'b1};
    assign sprattr_strobe   = cpu_strobe && cpu_addr[31:12] == 20'h00003;
    assign pal_strobe       = cpu_strobe && cpu_addr[31:12] == 20'h00004;
    assign chram_strobe     = cpu_strobe && cpu_addr[31:12] == 20'h00005;
    assign tram_strobe      = cpu_strobe && cpu_addr[31:12] == 20'h00006;
    assign vram_strobe      = cpu_strobe && cpu_addr[31:15] == {16'h0000, 1'b1};
    assign vram4bpp_strobe  = cpu_strobe && cpu_addr[31:16] == 16'h0001;
    assign sram_strobe      = cpu_strobe && cpu_addr[31:19] == {12'h000, 1'b1};

    reg [31:0] regs_rddata;

    reg [31:0] q_cpu_addr;
    always @(posedge clk) q_cpu_addr <= cpu_addr;

    always @* begin
        cpu_wait = 0;
        if (bootrom_strobe)   cpu_wait = !cpu_wren && q_cpu_addr[11:2] != cpu_addr[11:2];
        if (fmsynth_strobe)   cpu_wait = fmsynth_wait;
        if (sprattr_strobe)   cpu_wait = !cpu_wren && q_cpu_addr[11:0] != cpu_addr[11:0];
        if (chram_strobe)     cpu_wait = !cpu_wren && q_cpu_addr[11:0] != cpu_addr[11:0];
        if (tram_strobe)      cpu_wait = !cpu_wren && q_cpu_addr[11:0] != cpu_addr[11:0];
        if (vram_strobe)      cpu_wait = !cpu_wren && q_cpu_addr[14:0] != cpu_addr[14:0];
        if (vram4bpp_strobe)  cpu_wait = !cpu_wren && q_cpu_addr[15:0] != cpu_addr[15:0];
        if (sram_strobe)      cpu_wait = sram_wait;
    end

    always @* begin
        cpu_rddata = 0;
        if (bootrom_strobe)   cpu_rddata = bootrom_rddata;
        if (pcm_strobe)       cpu_rddata = pcm_rddata;
        if (fmsynth_strobe)   cpu_rddata = fmsynth_rddata;
        if (regs_strobe)      cpu_rddata = regs_rddata;
        if (pal_strobe)       cpu_rddata = {pal_rddata, pal_rddata};
        if (sprattr_strobe)   cpu_rddata = sprattr_rddata;
        if (chram_strobe)     cpu_rddata = {chram_rddata, chram_rddata, chram_rddata, chram_rddata};
        if (tram_strobe)      cpu_rddata = {tram_rddata, tram_rddata};
        if (vram_strobe)      cpu_rddata = vram_rddata;
        if (vram4bpp_strobe)  cpu_rddata = vram4bpp_rddata;
        if (sram_strobe)      cpu_rddata = sram_rddata;
    end

    //////////////////////////////////////////////////////////////////////////
    // Registers
    //////////////////////////////////////////////////////////////////////////
    wire sel_reg_espctrl  = regs_strobe && (cpu_addr[7:2] == 6'h00);    // 0x02000
    wire sel_reg_espdata  = regs_strobe && (cpu_addr[7:2] == 6'h01);    // 0x02004
    wire sel_reg_vctrl    = regs_strobe && (cpu_addr[7:2] == 6'h02);    // 0x02008
    wire sel_reg_vscrx    = regs_strobe && (cpu_addr[7:2] == 6'h03);    // 0x0200C
    wire sel_reg_vscry    = regs_strobe && (cpu_addr[7:2] == 6'h04);    // 0x02010
    wire sel_reg_vline    = regs_strobe && (cpu_addr[7:2] == 6'h05);    // 0x02014
    wire sel_reg_virqline = regs_strobe && (cpu_addr[7:2] == 6'h06);    // 0x02018
    wire sel_reg_keybuf   = regs_strobe && (cpu_addr[7:2] == 6'h07);    // 0x0201C

    reg q_esp_rx_fifo_overflow, q_esp_rx_framing_error;

    always @* begin
        regs_rddata = 0;
        if (sel_reg_espctrl)  regs_rddata = {27'b0, q_esp_rx_fifo_overflow, q_esp_rx_framing_error, 1'b0, esp_tx_fifo_full, !esp_rx_empty};
        if (sel_reg_espdata)  regs_rddata = {23'b0, esp_rx_data};
        if (sel_reg_vctrl)    regs_rddata = {
            24'b0,
            2'b0,
            q_vctrl_sprites_enable,
            q_vctrl_gfx_tilemode,
            q_vctrl_gfx_enable,
            q_vctrl_text_priority,
            q_vctrl_text_mode80,
            q_vctrl_text_enable
        };

        if (sel_reg_vscrx)    regs_rddata = {23'b0, q_vscrx};
        if (sel_reg_vscry)    regs_rddata = {24'b0, q_vscry};
        if (sel_reg_vline)    regs_rddata = {23'b0, vline};
        if (sel_reg_virqline) regs_rddata = {23'b0, q_virqline};
        if (sel_reg_keybuf)   regs_rddata = {kbbuf_empty, 15'b0, kbbuf_rddata};
    end

    assign esp_tx_data = cpu_wrdata[8:0];
    assign esp_tx_wr   =  cpu_wren && sel_reg_espdata;
    assign esp_rx_rd   = !cpu_wren && sel_reg_espdata;

    assign kbbuf_rst  = (cpu_wren && sel_reg_keybuf) || reset;
    assign kbbuf_rden = !cpu_wren && sel_reg_keybuf;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q_esp_rx_fifo_overflow <= 0;
            q_esp_rx_framing_error <= 0;
            q_vctrl_sprites_enable <= 0;
            q_vctrl_gfx_tilemode   <= 0;
            q_vctrl_gfx_enable     <= 0;
            q_vctrl_text_priority  <= 0;
            q_vctrl_text_mode80    <= 0;
            q_vctrl_text_enable    <= 0;
            q_vscrx                <= 0;
            q_vscry                <= 0;
            q_virqline             <= 0;

        end else begin
            if (cpu_wren) begin
                if (sel_reg_espctrl) begin
                    q_esp_rx_fifo_overflow <= q_esp_rx_fifo_overflow & ~cpu_wrdata[4];
                    q_esp_rx_framing_error <= q_esp_rx_framing_error & ~cpu_wrdata[3];
                end
                if (sel_reg_vctrl) begin
                    q_vctrl_sprites_enable <= cpu_wrdata[5];
                    q_vctrl_gfx_tilemode   <= cpu_wrdata[4];
                    q_vctrl_gfx_enable     <= cpu_wrdata[3];
                    q_vctrl_text_priority  <= cpu_wrdata[2];
                    q_vctrl_text_mode80    <= cpu_wrdata[1];
                    q_vctrl_text_enable    <= cpu_wrdata[0];
                end
                if (sel_reg_vscrx) q_vscrx    <= cpu_wrdata[8:0];
                if (sel_reg_vscry) q_vscry    <= cpu_wrdata[7:0];
                if (sel_reg_vscry) q_virqline <= cpu_wrdata[8:0];
            end

            if (esp_rx_fifo_overflow) q_esp_rx_fifo_overflow <= 1'b1;
            if (esp_rx_framing_error) q_esp_rx_framing_error <= 1'b1;
        end
    end

endmodule
