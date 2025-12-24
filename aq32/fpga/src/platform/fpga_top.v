`default_nettype none
`timescale 1 ns / 1 ps

module fpga_top(
    input  wire        sysclk,

    // Z80 bus interface
    inout  wire        ebus_reset_n,
    output wire        ebus_phi,
    output wire [15:0] ebus_a,
    inout  wire  [7:0] ebus_d,
    output wire        ebus_rd_n,
    output wire        ebus_wr_n,
    output wire        ebus_mreq_n,
    output wire        ebus_iorq_n,
    output wire        ebus_int_n,
    output wire        ebus_busreq_n,
    input  wire        ebus_busack_n,
    output wire  [4:0] ebus_ba,
    output wire        ebus_ram_ce_n,
    output wire        ebus_cart_ce_n,
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

    //////////////////////////////////////////////////////////////////////////
    // Clock generator
    //////////////////////////////////////////////////////////////////////////
    wire clk_25_175;
    wire clk_28_63636;

    fpga_clkgen fpga_clkgen(
        .sysclk(sysclk),
        .clk_25_175(clk_25_175),
        .clk_28_63636(clk_28_63636));

    //////////////////////////////////////////////////////////////////////////
    // Handle unused external Z80 and peripherals
    //////////////////////////////////////////////////////////////////////////
    reg [2:0] q_clk_div = 0;
    always @(posedge(clk_25_175)) q_clk_div <= q_clk_div + 1;

    assign ebus_phi       = q_clk_div[2];
    assign ebus_reset_n   = 0;
    assign ebus_busreq_n  = 0;
    assign ebus_mreq_n    = 1;
    assign ebus_iorq_n    = 1;
    assign ebus_wr_n      = 1;
    assign ebus_a[15:14]  = 2'bZ;
    assign ebus_int_n     = 1'bZ;
    assign ebus_cart_ce_n = 1;

    assign cassette_out   = 0;
    assign printer_out    = 0;
    assign exp            = 0;

    //////////////////////////////////////////////////////////////////////////
    // ESP32 SPI interface (also used for loading FPGA image)
    //////////////////////////////////////////////////////////////////////////
    wire   [7:0] core_type;
    wire   [7:0] core_flags;
    wire  [15:0] core_version;
    wire [127:0] core_name;

    //////////////////////////////////////////////////////////////////////////
    // FPGA core
    //////////////////////////////////////////////////////////////////////////
    fpga_core fpga_core(
        .clk_25_175(clk_25_175),
        .clk_28_63636(clk_28_63636),

        // Core information
        .core_type(core_type),
        .core_flags(core_flags),
        .core_version(core_version),
        .core_name(core_name),

        // Memory interface
        .sram_a({ebus_ba, ebus_a[13:0]}),
        .sram_ce_n(ebus_ram_ce_n),
        .sram_oe_n(ebus_rd_n),
        .sram_we_n(ebus_ram_we_n),
        .sram_dq(ebus_d),

        // PWM audio outputs
        .audio_l(audio_l),
        .audio_r(audio_r),

        // Hand controller interface
        .hc1(hc1),
        .hc2(hc2),

        // VGA output
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),

        // ESP32 serial interface
        .esp_tx(esp_tx),
        .esp_rx(esp_rx),
        .esp_rts(esp_rts),
        .esp_cts(esp_cts),

        // ESP32 SPI interface (also used for loading FPGA image)
        .esp_ssel_n(esp_ssel_n),
        .esp_sclk(esp_sclk),
        .esp_mosi(esp_mosi),
        .esp_miso(esp_miso),
        .esp_notify(esp_notify)
    );

endmodule
