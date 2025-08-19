`default_nettype none
`timescale 1 ns / 1 ps

module aqp_top(
    input  wire        sysclk,          // 14.31818MHz

    // Z80 bus interface
    output wire        ebus_reset_n,
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
    assign cassette_out   = 1'b0;
    assign printer_out    = 1'b0;

    wire        clk;
    wire [15:0] cpu_addr;
    wire  [7:0] cpu_wrdata;
    reg   [7:0] cpu_rddata;
    wire        cpu_iorq;
    wire        cpu_memrq;
    wire        cpu_rd;
    wire        cpu_wr;
    wire        t80_dq_oe;
    wire [19:0] bus_addr;

    reg q_cpu_rd;
    reg q_cpu_wr;
    always @(posedge clk) q_cpu_rd <= cpu_rd;
    always @(posedge clk) q_cpu_wr <= cpu_wr;

    wire cpu_read  = cpu_rd & !q_cpu_rd;
    wire cpu_write = cpu_wr & !q_cpu_wr;

    assign ebus_ba        = bus_addr[18:14];
    assign ebus_a[15:14]  = 2'bZ;
    assign ebus_a[13:0]   = bus_addr[13:0];
    assign ebus_rd_n      = !cpu_rd;
    assign ebus_d         = t80_dq_oe ? cpu_wrdata : 8'bZ;
    assign ebus_ram_ce_n  = 0;
    assign ebus_cart_ce_n = 1;
    assign ebus_reset_n   = 1'bZ;
    assign ebus_wr_n      = 1;
    assign ebus_mreq_n    = 1;
    assign ebus_iorq_n    = 1;
    assign ebus_int_n     = 1'bZ;
    assign ebus_busreq_n  = 0;

    //////////////////////////////////////////////////////////////////////////
    // Clock synthesizer
    //////////////////////////////////////////////////////////////////////////
    aqp_clkctrl clkctrl(
        .clk_in(sysclk),    // 14.31818MHz
        .clk_out(clk));     // 25.175MHz

    //////////////////////////////////////////////////////////////////////////
    // System controller (reset and clock generation)
    //////////////////////////////////////////////////////////////////////////
    wire reset_req;
    wire reset;

    aqp_sysctrl sysctrl(
        .sysclk(clk),
        .reset_req(reset_req),

        .ebus_phi(ebus_phi),
        .reset(reset));

    //////////////////////////////////////////////////////////////////////////
    // ESP32 UART
    //////////////////////////////////////////////////////////////////////////
    wire [8:0] esp_tx_data;
    wire       esp_tx_wr;
    wire       esp_tx_fifo_full;
    wire [8:0] esp_rx_data;
    wire       esp_rx_rd;
    wire       esp_rx_empty;

    aqp_esp_uart esp_uart(
        .clk(clk),
        .reset(reset),

        .txfifo_data(esp_tx_data),
        .txfifo_wr(esp_tx_wr),
        .txfifo_full(esp_tx_fifo_full),

        .rxfifo_data(esp_rx_data),
        .rxfifo_rd(esp_rx_rd),
        .rxfifo_empty(esp_rx_empty),

        .esp_rx(esp_rx),
        .esp_tx(esp_tx),
        .esp_cts(esp_cts),
        .esp_rts(esp_rts));

    //////////////////////////////////////////////////////////////////////////
    // Hand controller interface
    //////////////////////////////////////////////////////////////////////////
    wire  [7:0] hc1_in = hc1[7:0];
    wire  [7:0] hc1_out;
    wire        hc1_oe;

    wire  [7:0] hc2_in = hc2[7:0];
    wire  [7:0] hc2_out;
    wire        hc2_oe;

    assign hc1[7:0] = hc1_oe ? hc1_out : 8'bZ;
    assign hc2[7:0] = hc2_oe ? hc2_out : 8'bZ;
    assign hc1[8]   = 1'b0;
    assign hc2[8]   = 1'b0;

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

    aqp_esp_spi esp_spi(
        .clk(clk),
        .reset(reset),

        // System information
        .sysinfo_core_type(8'h01),
        .sysinfo_flags({
            1'b0,       // Core type 01 specific: unused
            1'b0,       // Core type 01 specific: unused
            1'b1,       // Core type 01 specific: alternate baud rate
            1'b0,       // Core type 01 specific: show force turbo mode
            1'b1,       // Core type 01 specific: show Aquarius+ options
            1'b0,       // Core type 01 specific: show video timing switch
            1'b1,       // Core type 01 specific: show mouse support
            has_z80     // Z80 present
        }),
        .sysinfo_version_major(8'h02),
        .sysinfo_version_minor(8'h00),

        .core_name("Aquarius+ v2    "),

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
    // PWM DAC
    //////////////////////////////////////////////////////////////////////////
    reg [15:0] common_audio_l;
    reg [15:0] common_audio_r;

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
    // Core common
    //////////////////////////////////////////////////////////////////////////
    wire [3:0] video_r;
    wire [3:0] video_g;
    wire [3:0] video_b;
    wire       video_de;
    wire       video_hsync;
    wire       video_vsync;
    wire       video_newframe;
    wire       video_oddline;

    wire       reg_fd_val;

    wire [7:0] rddata_tram;         // MEM $3000-$37FF
    wire [7:0] rddata_chram;
    wire [7:0] rddata_vram;
    wire [7:0] rddata_rom;

    wire [7:0] rddata_io_video;     // IO $E0-$EF
    wire [7:0] rddata_espctrl;      // IO $F4
    wire [7:0] rddata_espdata;      // IO $F5
    wire [7:0] rddata_ay8910;       // IO $F6/F7
    wire [7:0] rddata_ay8910_2;     // IO $F8/F9
    wire [7:0] rddata_kbbuf;        // IO $FA
    wire [7:0] rddata_keyboard;     // IO $FF:R

    reg  [7:0] q_audio_dac;         // IO $EC
    reg  [7:0] q_reg_bank0;         // IO $F0
    reg  [7:0] q_reg_bank1;         // IO $F1
    reg  [7:0] q_reg_bank2;         // IO $F2
    reg  [7:0] q_reg_bank3;         // IO $F3

    wire       spi_reset_req;
    wire       reset_req_cold;
    reg        q_sysctrl_warm_boot = 1'b0;
    reg        q_sysctrl_reset_req = 1'b0;

    always @(posedge clk) if (reset_req) begin
        q_sysctrl_warm_boot <= !reset_req_cold;
    end

    assign reset_req = spi_reset_req || q_sysctrl_reset_req;

    //////////////////////////////////////////////////////////////////////////
    // Bus interface
    //////////////////////////////////////////////////////////////////////////

    // Select banking register based on upper address bits
    reg [7:0] reg_bank;
    always @* case (cpu_addr[15:14])
        2'd0: reg_bank = q_reg_bank0;
        2'd1: reg_bank = q_reg_bank1;
        2'd2: reg_bank = q_reg_bank2;
        2'd3: reg_bank = q_reg_bank3;
    endcase

    wire [5:0] reg_bank_page    = reg_bank[5:0];
    wire       reg_bank_ro      = reg_bank[7];
    wire       reg_bank_overlay = reg_bank[6];

    assign bus_addr = {reg_bank_page, cpu_addr[13:0]};

    // Memory space decoding
    wire sel_mem_tram    = cpu_memrq && reg_bank_overlay && bus_addr[13:11] == 3'b110;   // $3000-$37FF
    wire sel_mem_sysram  = cpu_memrq && reg_bank_overlay && bus_addr[13:11] == 3'b111;   // $3800-$3FFF
    wire sel_mem_vram    = cpu_memrq && reg_bank_page == 6'd20;                          // Page 20
    wire sel_mem_chram   = cpu_memrq && reg_bank_page == 6'd21;                          // Page 21
    wire sel_mem_rom     = cpu_memrq && reg_bank_page <= 6'd3;                           // Page 0-3

    // IO space decoding
    wire sel_io_video     = cpu_iorq &&  bus_addr[7:4] == 4'hE;
    wire sel_io_audio_dac = cpu_iorq &&  bus_addr[7:0] == 8'hEC;
    wire sel_io_bank0     = cpu_iorq &&  bus_addr[7:0] == 8'hF0;
    wire sel_io_bank1     = cpu_iorq &&  bus_addr[7:0] == 8'hF1;
    wire sel_io_bank2     = cpu_iorq &&  bus_addr[7:0] == 8'hF2;
    wire sel_io_bank3     = cpu_iorq &&  bus_addr[7:0] == 8'hF3;
    wire sel_io_espctrl   = cpu_iorq &&  bus_addr[7:0] == 8'hF4;
    wire sel_io_espdata   = cpu_iorq &&  bus_addr[7:0] == 8'hF5;
    wire sel_io_ay8910    = cpu_iorq && (bus_addr[7:0] == 8'hF6 || bus_addr[7:0] == 8'hF7);
    wire sel_io_ay8910_2  = cpu_iorq && (bus_addr[7:0] == 8'hF8 || bus_addr[7:0] == 8'hF9);
    wire sel_io_kbbuf     = cpu_iorq &&  bus_addr[7:0] == 8'hFA;
    wire sel_io_sysctrl   = cpu_iorq &&  bus_addr[7:0] == 8'hFB;
    wire sel_io_cassette  = cpu_iorq &&  bus_addr[7:0] == 8'hFC;
    wire sel_io_vsync     = cpu_iorq &&  bus_addr[7:0] == 8'hFD;
    wire sel_io_keyb      = cpu_iorq &&  bus_addr[7:0] == 8'hFF;

    wire sel_internal =
        sel_mem_tram | sel_mem_vram | sel_mem_chram | sel_mem_rom |
        sel_io_video |
        sel_io_bank0 | sel_io_bank1 | sel_io_bank2 | sel_io_bank3 |
        sel_io_espctrl | sel_io_espdata | sel_io_ay8910 | sel_io_ay8910_2 | sel_io_kbbuf | sel_io_sysctrl |
        sel_io_cassette | sel_io_vsync | sel_io_keyb;

    wire sel_mem_ram = cpu_memrq && !sel_internal && reg_bank_page[5];  // Page 32-63

    assign ebus_ram_we_n = !(sel_mem_ram && cpu_wr && (!reg_bank_ro || sel_mem_sysram));

    always @* begin
        cpu_rddata = 8'hFF;

        if (sel_mem_rom)     cpu_rddata = rddata_rom;
        if (sel_mem_tram)    cpu_rddata = rddata_tram;                 // TRAM $3000-$37FF
        if (sel_mem_vram)    cpu_rddata = rddata_vram;
        if (sel_mem_chram)   cpu_rddata = rddata_chram;
        if (sel_mem_ram)     cpu_rddata = ebus_d;

        if (sel_io_video)    cpu_rddata = rddata_io_video;             // IO $E0-$EF
        if (sel_io_bank0)    cpu_rddata = q_reg_bank0;                 // IO $F0
        if (sel_io_bank1)    cpu_rddata = q_reg_bank1;                 // IO $F1
        if (sel_io_bank2)    cpu_rddata = q_reg_bank2;                 // IO $F2
        if (sel_io_bank3)    cpu_rddata = q_reg_bank3;                 // IO $F3
        if (sel_io_espctrl)  cpu_rddata = rddata_espctrl;              // IO $F4
        if (sel_io_espdata)  cpu_rddata = rddata_espdata;              // IO $F5
        if (sel_io_ay8910)   cpu_rddata = rddata_ay8910;               // IO $F6/F7
        if (sel_io_ay8910_2) cpu_rddata = rddata_ay8910_2;             // IO $F8/F9
        if (sel_io_kbbuf)    cpu_rddata = rddata_kbbuf;                // IO $FA
        if (sel_io_sysctrl)  cpu_rddata = {q_sysctrl_warm_boot, 7'b0}; // IO $FB
        if (sel_io_vsync)    cpu_rddata = {7'b0, reg_fd_val};          // IO $FD
        if (sel_io_keyb)     cpu_rddata = rddata_keyboard;             // IO $FF
    end

    reg q_beep;

    always @(posedge clk or posedge reset)
        if (reset) begin
            q_audio_dac <= 8'b0;
            q_reg_bank0 <= {2'b00, 6'd0};
            q_reg_bank1 <= {2'b00, 6'd0};
            q_reg_bank2 <= {2'b00, 6'd0};
            q_reg_bank3 <= {2'b00, 6'd0};
            q_beep      <= 0;

        end else begin
            if (sel_io_audio_dac && cpu_write) q_audio_dac <= cpu_wrdata;
            if (sel_io_bank0     && cpu_write) q_reg_bank0 <= cpu_wrdata;
            if (sel_io_bank1     && cpu_write) q_reg_bank1 <= cpu_wrdata;
            if (sel_io_bank2     && cpu_write) q_reg_bank2 <= cpu_wrdata;
            if (sel_io_bank3     && cpu_write) q_reg_bank3 <= cpu_wrdata;
            if (sel_io_cassette  && cpu_write) q_beep      <= cpu_wrdata[0];
        end

    always @(posedge clk) q_sysctrl_reset_req <= (sel_io_sysctrl && cpu_write && cpu_wrdata[7]);

    //////////////////////////////////////////////////////////////////////////
    // Boot ROM
    //////////////////////////////////////////////////////////////////////////
    rom rom(
        .clk(clk),
        .addr(bus_addr[7:0]),
        .rddata(rddata_rom)
    );

    //////////////////////////////////////////////////////////////////////////
    // ESP32 UART
    //////////////////////////////////////////////////////////////////////////
    assign esp_tx_data = sel_io_espctrl ? 9'b100000000 : {1'b0, cpu_wrdata};
    assign esp_tx_wr   = cpu_write && (sel_io_espdata || (sel_io_espctrl && cpu_wrdata[7]));
    assign esp_rx_rd   = cpu_read  &&  sel_io_espdata;

    assign rddata_espctrl = {5'b0, esp_rx_data[8], esp_tx_fifo_full, !esp_rx_empty};
    assign rddata_espdata = esp_rx_data[7:0];

    //////////////////////////////////////////////////////////////////////////
    // Video
    //////////////////////////////////////////////////////////////////////////
    wire tram_wren     = sel_mem_tram  && cpu_write;
    wire vram_wren     = sel_mem_vram  && cpu_write;
    wire chram_wren    = sel_mem_chram && cpu_write;
    wire io_video_wren = sel_io_video  && cpu_write;

    wire video_irq;

    video video(
        .clk(clk),
        .reset(reset),

        .vclk(clk),
        .video_mode(1'b1),

        .io_addr(bus_addr[3:0]),
        .io_rddata(rddata_io_video),
        .io_wrdata(cpu_wrdata),
        .io_wren(io_video_wren),
        .irq(video_irq),

        .tram_addr(bus_addr[10:0]),
        .tram_rddata(rddata_tram),
        .tram_wrdata(cpu_wrdata),
        .tram_wren(tram_wren),

        .chram_addr(bus_addr[10:0]),
        .chram_rddata(rddata_chram),
        .chram_wrdata(cpu_wrdata),
        .chram_wren(chram_wren),

        .vram_addr(bus_addr[13:0]),
        .vram_rddata(rddata_vram),
        .vram_wrdata(cpu_wrdata),
        .vram_wren(vram_wren),

        .video_r(video_r),
        .video_g(video_g),
        .video_b(video_b),
        .video_de(video_de),
        .video_hsync(video_hsync),
        .video_vsync(video_vsync),
        .video_newframe(video_newframe),
        .video_oddline(video_oddline),

        .reg_fd_val(reg_fd_val));

    //////////////////////////////////////////////////////////////////////////
    // Hand controller interface
    //////////////////////////////////////////////////////////////////////////
    wire [7:0] spi_hctrl1, spi_hctrl2;

    wire [7:0] hctrl1 = hc1_in[7:0];
    wire [7:0] hctrl2 = hc2_in[7:0];

    // Synchronize inputs
    reg [7:0] q_hctrl1, q2_hctrl1;
    reg [7:0] q_hctrl2, q2_hctrl2;
    always @(posedge clk) q_hctrl1  <= hctrl1;
    always @(posedge clk) q2_hctrl1 <= q_hctrl1;
    always @(posedge clk) q_hctrl2  <= hctrl2;
    always @(posedge clk) q2_hctrl2 <= q_hctrl2;

    // Combine data from ESP with data from handcontroller input
    wire [7:0] hctrl1_data = q2_hctrl1 & spi_hctrl1;
    wire [7:0] hctrl2_data = q2_hctrl2 & spi_hctrl2;

    //////////////////////////////////////////////////////////////////////////
    // SPI interface
    //////////////////////////////////////////////////////////////////////////
    wire [63:0] keys;

    wire  [7:0] kbbuf_data;
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
        .hctrl1(spi_hctrl1),
        .hctrl2(spi_hctrl2),

        .kbbuf_data(kbbuf_data),
        .kbbuf_wren(kbbuf_wren));

    //////////////////////////////////////////////////////////////////////////
    // Keyboard
    //////////////////////////////////////////////////////////////////////////
    assign rddata_keyboard =
        (cpu_addr[15] ? 8'hFF : keys[63:56]) &
        (cpu_addr[14] ? 8'hFF : keys[55:48]) &
        (cpu_addr[13] ? 8'hFF : keys[47:40]) &
        (cpu_addr[12] ? 8'hFF : keys[39:32]) &
        (cpu_addr[11] ? 8'hFF : keys[31:24]) &
        (cpu_addr[10] ? 8'hFF : keys[23:16]) &
        (cpu_addr[ 9] ? 8'hFF : keys[15: 8]) &
        (cpu_addr[ 8] ? 8'hFF : keys[ 7: 0]);

    //////////////////////////////////////////////////////////////////////////
    // Keyboard buffer
    //////////////////////////////////////////////////////////////////////////
    wire [7:0] kbbuf_rddata;
    wire       kbbuf_rden = (sel_io_kbbuf && cpu_read);
    wire       kbbuf_rst  = (sel_io_kbbuf && cpu_write) || reset;

    kbbuf kbbuf(
        .clk(clk),
        .rst(kbbuf_rst),

        .wrdata(kbbuf_data),
        .wr_en(kbbuf_wren),

        .rddata(rddata_kbbuf),
        .rd_en(kbbuf_rden)
    );

    //////////////////////////////////////////////////////////////////////////
    // AY-3-8910
    //////////////////////////////////////////////////////////////////////////
    wire       ay8910_wren   = sel_io_ay8910   && cpu_write;
    wire       ay8910_2_wren = sel_io_ay8910_2 && cpu_write;
    wire [9:0] ay8910_ch_a,   ay8910_ch_b,   ay8910_ch_c;
    wire [9:0] ay8910_2_ch_a, ay8910_2_ch_b, ay8910_2_ch_c;

    wire [9:0] beep = q_beep ? 10'd1023 : 10'd0;

    wire [7:0] ay8190_2_ioa_out_data;
    wire       ay8190_2_ioa_oe;
    wire [7:0] ay8190_2_iob_out_data;
    wire       ay8190_2_iob_oe;

    ay8910 ay8910(
        .clk(clk),
        .reset(reset),

        .a0(bus_addr[0]),
        .wren(ay8910_wren),
        .wrdata(cpu_wrdata),
        .rddata(rddata_ay8910),

        .ioa_in_data(hctrl1_data),
        .ioa_out_data(hc1_out),
        .ioa_oe(hc1_oe),

        .iob_in_data(hctrl2_data),
        .iob_out_data(hc2_out),
        .iob_oe(hc2_oe),

        .ch_a(ay8910_ch_a),
        .ch_b(ay8910_ch_b),
        .ch_c(ay8910_ch_c));

    ay8910 ay8910_2(
        .clk(clk),
        .reset(reset),

        .a0(bus_addr[0]),
        .wren(ay8910_2_wren),
        .wrdata(cpu_wrdata),
        .rddata(rddata_ay8910_2),

        .ioa_in_data(8'h00),
        .ioa_out_data(ay8190_2_ioa_out_data),
        .ioa_oe(ay8190_2_ioa_oe),

        .iob_in_data(8'h00),
        .iob_out_data(ay8190_2_iob_out_data),
        .iob_oe(ay8190_2_iob_oe),

        .ch_a(ay8910_2_ch_a),
        .ch_b(ay8910_2_ch_b),
        .ch_c(ay8910_2_ch_c));

    // Create stereo mix of output channels and system beep (cassette output)
    wire [13:0] mix_l =
        {2'b0, ay8910_ch_a,   1'b0} + {2'b0, ay8910_ch_b,   1'b0} + {4'b0, ay8910_ch_c  } +
        {2'b0, ay8910_2_ch_a, 1'b0} + {2'b0, ay8910_2_ch_b, 1'b0} + {4'b0, ay8910_2_ch_c} +
        {2'b0, q_audio_dac,   4'b0} + {4'b0, beep};

    wire [13:0] mix_r =
        {4'b0, ay8910_ch_a  }     + {2'b0, ay8910_ch_b,   1'b0} + {2'b0, ay8910_ch_c,   1'b0} +
        {4'b0, ay8910_2_ch_a}     + {2'b0, ay8910_2_ch_b, 1'b0} + {2'b0, ay8910_2_ch_c, 1'b0} +
        {2'b0, q_audio_dac, 4'b0} + {4'b0, beep};

    always @(posedge clk) common_audio_l <= {~mix_l[13], mix_l[12:0], 2'b0};
    always @(posedge clk) common_audio_r <= {~mix_r[13], mix_r[12:0], 2'b0};

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
    // T80 CPU core
    //////////////////////////////////////////////////////////////////////////
    wire cpu_wait = 0;
    wire cpu_irq  = video_irq;

    aqp_t80 aqp_t80(
        .clk(clk),
        .reset(reset),

        .bus_addr(cpu_addr),
        .bus_wrdata(cpu_wrdata),
        .bus_rddata(cpu_rddata),
        .dq_oe(t80_dq_oe),

        .bus_memrq(cpu_memrq),
        .bus_iorq(cpu_iorq),
        .bus_rd(cpu_rd),
        .bus_wr(cpu_wr),
        .bus_wait(cpu_wait),

        .irq(cpu_irq)
    );

endmodule
