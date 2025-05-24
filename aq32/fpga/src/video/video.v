`default_nettype none
`timescale 1 ns / 1 ps

module video(
    input  wire        clk,
    input  wire        reset,

    input  wire        vclk,

    // Register interface
    input  wire        vctrl_80_columns,
    input  wire        vctrl_text_priority,
    input  wire        vctrl_sprites_enable,
    input  wire  [1:0] vctrl_gfx_mode,
    input  wire        vctrl_text_enable,
    input  wire  [8:0] vscrx,
    input  wire  [7:0] vscry,
    output wire  [7:0] vline,
    input  wire  [7:0] virqline,

    output wire        irq_line,
    output wire        irq_vblank,

    // Text RAM interface
    input  wire [10:0] tram_addr,
    output wire [15:0] tram_rddata,
    input  wire [15:0] tram_wrdata,
    input  wire  [1:0] tram_bytesel,
    input  wire        tram_wren,

    // Char RAM interface
    input  wire [10:0] chram_addr,
    output wire  [7:0] chram_rddata,
    input  wire  [7:0] chram_wrdata,
    input  wire        chram_wren,

    // Palette RAM interface
    input  wire  [5:0] pal_addr,
    output wire [15:0] pal_rddata,
    input  wire [15:0] pal_wrdata,
    input  wire        pal_wren,

    // Video RAM interface
    input  wire [12:0] vram_addr,
    output wire [31:0] vram_rddata,
    input  wire [31:0] vram_wrdata,
    input  wire  [3:0] vram_bytesel,
    input  wire        vram_wren,

    // VGA output
    output reg   [3:0] video_r,
    output reg   [3:0] video_g,
    output reg   [3:0] video_b,
    output reg         video_de,
    output reg         video_hsync,
    output reg         video_vsync,
    output wire        video_newframe,
    output reg         video_oddline);

    // Sync reset to vclk domain
    wire vclk_reset;
    reset_sync ressync_vclk(.async_rst_in(reset), .clk(vclk), .reset_out(vclk_reset));

    wire [7:0] vpos;
    wire       vblank;

    assign vline = vpos;

    reg q_vblank;
    always @(posedge vclk) q_vblank <= vblank;

    wire [7:0] rddata_sprattr;

    wire irqline_match = (vpos == virqline);
    reg q_irqline_match;
    always @(posedge vclk) q_irqline_match <= irqline_match;

    pulse2pulse p2p_irq_line(  .in_clk(vclk), .in_pulse(!q_irqline_match && irqline_match), .out_clk(clk), .out_pulse(irq_line));
    pulse2pulse p2p_irq_vblank(.in_clk(vclk), .in_pulse(!q_vblank        && vblank),        .out_clk(clk), .out_pulse(irq_vblank));

    //////////////////////////////////////////////////////////////////////////
    // Video timing
    //////////////////////////////////////////////////////////////////////////
    wire [9:0] hpos;
    wire       hsync, hblank, hlast;
    wire [9:0] vpos10;
    wire       vsync, vnext;
    wire       blank;

    aqp_video_timing video_timing(
        .clk(vclk),
        .mode(1'b1),

        .hpos(hpos),
        .hsync(hsync),
        .hblank(hblank),
        .hlast(hlast),

        .vpos(vpos10),
        .vsync(vsync),
        .vblank(vblank),
        .vnext(vnext),
        .vnewframe(video_newframe),

        .blank(blank));

    always @(posedge vclk) video_oddline <= vpos10[0];

    assign vpos = vpos10[9] ? 8'd255 : vpos10[8:1];

    wire hborder = blank;
    wire vborder = vpos < 8'd16 || vpos >= 8'd216;

    reg [9:0] q_hpos, q2_hpos;
    always @(posedge vclk) q_hpos  <= hpos;
    always @(posedge vclk) q2_hpos <= q_hpos;

    reg q_blank, q_hsync, q_vsync;
    always @(posedge vclk) q_blank <= blank;
    always @(posedge vclk) q_hsync <= hsync;
    always @(posedge vclk) q_vsync <= vsync;

    reg q2_blank, q2_hsync, q2_vsync;
    always @(posedge vclk) q2_blank <= q_blank;
    always @(posedge vclk) q2_hsync <= q_hsync;
    always @(posedge vclk) q2_vsync <= q_vsync;

    //////////////////////////////////////////////////////////////////////////
    // Character address
    //////////////////////////////////////////////////////////////////////////
    reg  q_mode80 = 1'b0;

    reg  [10:0] q_row_addr  = 11'd0;
    reg  [10:0] q_char_addr = 11'd0;

    wire        next_row         = (vpos >= 8'd23) && vnext && (vpos[2:0] == 3'd7);
    wire [10:0] d_row_addr       = q_row_addr + (q_mode80 ? 11'd80 : 11'd40);
    wire [10:0] border_char_addr = 11'h7FF;

    always @(posedge(vclk))
        if (vblank) begin
            q_mode80   <= vctrl_80_columns;
            q_row_addr <= 11'd0;
        end else if (next_row) begin
            q_row_addr <= d_row_addr;
        end

    wire next_char = q_mode80 ? (hpos[2:0] == 3'd0) : (hpos[3:0] == 4'd0);

    wire border = vborder || hborder;
    reg q_border;
    always @(posedge vclk) q_border <= border;

    wire start_active = q_border && !border;

    reg  [10:0] d_char_addr;
    always @* begin
        d_char_addr = q_char_addr;
        if (border)
            d_char_addr = border_char_addr;
        else if (start_active)
            d_char_addr = q_row_addr;
        else if (next_char)
            d_char_addr = q_char_addr + 11'd1;

        if (!q_mode80)
            d_char_addr[10] = 0;
    end

    always @(posedge(vclk)) q_char_addr <= d_char_addr;

    //////////////////////////////////////////////////////////////////////////
    // Text RAM
    //////////////////////////////////////////////////////////////////////////
    wire [15:0] textram_rddata;

    textram textram(
        // First port - CPU access
        .p1_clk(clk),
        .p1_addr(tram_addr),
        .p1_rddata(tram_rddata),
        .p1_wrdata(tram_wrdata),
        .p1_bytesel(tram_bytesel),
        .p1_wren(tram_wren),

        // Second port - Video access
        .p2_clk(vclk),
        .p2_addr(d_char_addr),
        .p2_rddata(textram_rddata));

    wire [7:0] text_data  = textram_rddata[7:0];
    wire [7:0] color_data = textram_rddata[15:8];

    reg [7:0] q_color_data;
    always @(posedge vclk) q_color_data <= color_data;

    //////////////////////////////////////////////////////////////////////////
    // Character RAM
    //////////////////////////////////////////////////////////////////////////
    wire [10:0] charram_addr = {text_data, vpos[2:0]};
    wire  [7:0] charram_data;

    charram charram(
        .clk1(clk),
        .addr1(chram_addr),
        .rddata1(chram_rddata),
        .wrdata1(chram_wrdata),
        .wren1(chram_wren),

        .clk2(vclk),
        .addr2(charram_addr),
        .rddata2(charram_data));

    wire [2:0] pixel_sel    = (q_mode80 ? q2_hpos[2:0] : q2_hpos[3:1]) ^ 3'b111;
    wire       char_pixel   = charram_data[pixel_sel];
    wire [3:0] text_colidx  = char_pixel ? q_color_data[7:4] : q_color_data[3:0];

    //////////////////////////////////////////////////////////////////////////
    // Sprite attribute RAM
    //////////////////////////////////////////////////////////////////////////
    wire  [5:0] spr_sel;
    wire  [8:0] spr_x;
    wire  [7:0] spr_y;
    wire  [8:0] spr_idx;
    wire        spr_enable;
    wire        spr_priority;
    wire  [1:0] spr_palette;
    wire        spr_h16;
    wire        spr_vflip;
    wire        spr_hflip;

    sprattr sprattr(
        // First port - CPU access
        .clk(clk),
        .reset(reset),
        .io_addr(4'b0), //io_addr),
        .io_rddata(rddata_sprattr),
        .io_wrdata(8'b0),   //io_wrdata),
        .io_wren(1'b0),     //io_wren),

        // Second port - Video access
        .spr_sel(spr_sel),
        .spr_x(spr_x),
        .spr_y(spr_y),
        .spr_idx(spr_idx),
        .spr_enable(spr_enable),
        .spr_priority(spr_priority),
        .spr_palette(spr_palette),
        .spr_h16(spr_h16),
        .spr_vflip(spr_vflip),
        .spr_hflip(spr_hflip)
    );

    //////////////////////////////////////////////////////////////////////////
    // VRAM
    //////////////////////////////////////////////////////////////////////////
    wire [13:0] vram_addr2;
    wire [15:0] vram_rddata2;

    vram vram(
        // First port - CPU access
        .p1_clk(clk),
        .p1_addr(vram_addr),
        .p1_rddata(vram_rddata),
        .p1_wrdata(vram_wrdata),
        .p1_bytesel(vram_bytesel),
        .p1_wren(vram_wren),

        // Second port - Video access
        .p2_clk(vclk),
        .p2_addr(vram_addr2),
        .p2_rddata(vram_rddata2));

    //////////////////////////////////////////////////////////////////////////
    // Graphics
    //////////////////////////////////////////////////////////////////////////
    wire [5:0] linebuf_data;
    reg  [8:0] q_linebuf_rdidx;

    always @(posedge vclk) q_linebuf_rdidx <= hpos[9:1];

    reg q_hborder, q2_hborder;
    always @(posedge vclk) q_hborder  <= hborder;
    always @(posedge vclk) q2_hborder <= q_hborder;

    reg q_gfx_start;
    always @(posedge vclk) q_gfx_start <= vnext;

    gfx gfx(
        .clk(vclk),
        .reset(vclk_reset),

        // Register values
        .gfx_mode(vctrl_gfx_mode),
        .sprites_enable(vctrl_sprites_enable),
        .scrx(vscrx),
        .scry(vscry),

        // Sprite attribute interface
        .spr_sel(spr_sel),
        .spr_x(spr_x),
        .spr_y(spr_y),
        .spr_idx(spr_idx),
        .spr_enable(spr_enable),
        .spr_priority(spr_priority),
        .spr_palette(spr_palette),
        .spr_h16(spr_h16),
        .spr_vflip(spr_vflip),
        .spr_hflip(spr_hflip),

        // Video RAM interface
        .vaddr(vram_addr2),
        .vdata(vram_rddata2),

        // Render parameters
        .vline(vpos),
        .start(q_gfx_start),

        // Line buffer interface
        .linebuf_rdidx(q_linebuf_rdidx),
        .linebuf_data(linebuf_data));

    //////////////////////////////////////////////////////////////////////////
    // Compositing
    //////////////////////////////////////////////////////////////////////////
    reg  [5:0] pixel_colidx;
    wire       active = !vborder && !q2_hborder;

    always @* begin
        pixel_colidx = 6'b0;
        if (!active) begin
            if (vctrl_text_enable)
                pixel_colidx = {2'b0, text_colidx};

        end else begin
            if (vctrl_text_enable && !vctrl_text_priority)
                pixel_colidx = {2'b0, text_colidx};
            if (!vctrl_text_enable || vctrl_text_priority || linebuf_data[3:0] != 4'd0)
                pixel_colidx = linebuf_data;
            if (vctrl_text_enable && vctrl_text_priority && text_colidx != 4'd0)
                pixel_colidx = {2'b0, text_colidx};
        end
    end

    //////////////////////////////////////////////////////////////////////////
    // Palette
    //////////////////////////////////////////////////////////////////////////
    wire [3:0] pal_r, pal_g, pal_b;

    palette palette(
        .clk(clk),
        .addr(pal_addr),
        .rddata(pal_rddata),
        .wrdata(pal_wrdata),
        .wren(pal_wren),

        .palidx(pixel_colidx),
        .pal_r(pal_r),
        .pal_g(pal_g),
        .pal_b(pal_b));

    //////////////////////////////////////////////////////////////////////////
    // Output registers
    //////////////////////////////////////////////////////////////////////////
    always @(posedge(vclk))
        if (q2_blank) begin
            video_r  <= 4'b0;
            video_g  <= 4'b0;
            video_b  <= 4'b0;
            video_de <= 1'b0;

        end else begin
            video_r  <= pal_r;
            video_g  <= pal_g;
            video_b  <= pal_b;
            video_de <= 1'b1;
        end

    always @(posedge vclk) video_hsync <= q2_hsync;
    always @(posedge vclk) video_vsync <= q2_vsync;

endmodule
