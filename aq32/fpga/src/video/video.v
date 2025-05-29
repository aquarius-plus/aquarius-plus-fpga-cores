`default_nettype none
`timescale 1 ns / 1 ps

module video(
    input  wire        clk,
    input  wire        reset,

    // Register interface
    input  wire        reg_sprites_enable,
    input  wire        reg_gfx_tilemode,
    input  wire        reg_gfx_enable,
    input  wire        reg_text_priority,
    input  wire        reg_text_mode80,
    input  wire        reg_text_enable,
    input  wire  [8:0] reg_scroll_x,
    input  wire  [7:0] reg_scroll_y,
    input  wire  [8:0] reg_irqline,
    output wire  [8:0] vline,

    output wire        irq_line,
    output wire        irq_vblank,

    // Sprite attribute interface
    input  wire  [6:0] sprattr_addr,
    output wire [31:0] sprattr_rddata,
    input  wire [31:0] sprattr_wrdata,
    input  wire        sprattr_wren,

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
    input  wire [31:0] vram_wrdata,
    input  wire  [7:0] vram_wrsel,
    input  wire        vram_wren,
    output wire [31:0] vram_rddata,

    // VGA output
    output reg   [3:0] video_r,
    output reg   [3:0] video_g,
    output reg   [3:0] video_b,
    output reg         video_de,
    output reg         video_hsync,
    output reg         video_vsync,
    output wire        video_newframe,
    output reg         video_oddline);

    wire [8:0] vpos9;
    wire       vblank;

    assign vline = vpos9;

    reg q_vblank;
    always @(posedge clk) q_vblank <= vblank;

    wire [7:0] rddata_sprattr;

    wire irqline_match = (vline == reg_irqline);
    reg q_irqline_match;
    always @(posedge clk) q_irqline_match <= irqline_match;

    assign irq_line   = !q_irqline_match && irqline_match;
    assign irq_vblank = !q_vblank        && vblank;

    //////////////////////////////////////////////////////////////////////////
    // Video timing
    //////////////////////////////////////////////////////////////////////////
    wire [9:0] hpos;
    wire       hsync, hblank, hlast;
    wire [9:0] vpos10;
    wire       vsync, vnext;
    wire       blank;

    aqp_video_timing video_timing(
        .clk(clk),
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

    always @(posedge clk) video_oddline <= vpos10[0];

    assign vpos9 = vpos10[9:1];

    wire hborder = blank;
    wire vborder = vpos9 < 9'd16 || vpos9 >= 9'd216;

    reg [9:0] q_hpos, q2_hpos;
    always @(posedge clk) q_hpos  <= hpos;
    always @(posedge clk) q2_hpos <= q_hpos;

    reg q_blank, q_hsync, q_vsync;
    always @(posedge clk) q_blank <= blank;
    always @(posedge clk) q_hsync <= hsync;
    always @(posedge clk) q_vsync <= vsync;

    reg q2_blank, q2_hsync, q2_vsync;
    always @(posedge clk) q2_blank <= q_blank;
    always @(posedge clk) q2_hsync <= q_hsync;
    always @(posedge clk) q2_vsync <= q_vsync;

    //////////////////////////////////////////////////////////////////////////
    // Character address
    //////////////////////////////////////////////////////////////////////////
    reg  q_mode80 = 1'b0;

    reg  [10:0] q_row_addr  = 11'd0;
    reg  [10:0] q_char_addr = 11'd0;

    wire        next_row         = (vpos9 >= 9'd23) && vnext && (vpos9[2:0] == 3'd7);
    wire [10:0] d_row_addr       = q_row_addr + (q_mode80 ? 11'd80 : 11'd40);
    wire [10:0] border_char_addr = 11'h7FF;

    always @(posedge(clk))
        if (vblank) begin
            q_mode80   <= reg_text_mode80;
            q_row_addr <= 11'd0;
        end else if (next_row) begin
            q_row_addr <= d_row_addr;
        end

    wire next_char = q_mode80 ? (hpos[2:0] == 3'd0) : (hpos[3:0] == 4'd0);

    wire border = vborder || hborder;
    reg q_border;
    always @(posedge clk) q_border <= border;

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

    always @(posedge(clk)) q_char_addr <= d_char_addr;

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
        .p2_clk(clk),
        .p2_addr(d_char_addr),
        .p2_rddata(textram_rddata));

    wire [7:0] text_data  = textram_rddata[7:0];
    wire [7:0] color_data = textram_rddata[15:8];

    reg [7:0] q_color_data;
    always @(posedge clk) q_color_data <= color_data;

    //////////////////////////////////////////////////////////////////////////
    // Character RAM
    //////////////////////////////////////////////////////////////////////////
    wire [10:0] charram_addr = {text_data, vpos9[2:0]};
    wire  [7:0] charram_data;

    charram charram(
        .clk1(clk),
        .addr1(chram_addr),
        .rddata1(chram_rddata),
        .wrdata1(chram_wrdata),
        .wren1(chram_wren),

        .clk2(clk),
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
    wire  [9:0] spr_idx;
    wire        spr_priority;
    wire  [1:0] spr_palette;
    wire        spr_h16;
    wire        spr_vflip;
    wire        spr_hflip;

    sprattr sprattr(
        .clk(clk),
        .reset(reset),

        // First port - CPU access
        .sprattr_addr(sprattr_addr),
        .sprattr_rddata(sprattr_rddata),
        .sprattr_wrdata(sprattr_wrdata),
        .sprattr_wren(sprattr_wren),

        // Second port - Video access
        .spr_sel(spr_sel),
        .spr_x(spr_x),
        .spr_y(spr_y),
        .spr_idx(spr_idx),
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
    wire [31:0] vram_rddata2_32;
    wire [15:0] vram_rddata2;

    reg q_vram_addr2_0;
    always @(posedge clk) q_vram_addr2_0 <= vram_addr2[0];

    dpram32k vram(
        .a_clk(clk),
        .a_addr(vram_addr),
        .a_wrdata(vram_wrdata),
        .a_wrsel(vram_wrsel),
        .a_wren(vram_wren),
        .a_rddata(vram_rddata),

        .b_clk(clk),
        .b_addr(vram_addr2[13:1]),
        .b_wrdata(32'b0),
        .b_wrsel(8'b0),
        .b_wren(1'b0),
        .b_rddata(vram_rddata2_32));

    assign vram_rddata2 = q_vram_addr2_0 ? vram_rddata2_32[31:16] : vram_rddata2_32[15:0];

    //////////////////////////////////////////////////////////////////////////
    // Graphics
    //////////////////////////////////////////////////////////////////////////
    wire [5:0] linebuf_data;
    reg  [8:0] q_linebuf_rdidx;

    always @(posedge clk) q_linebuf_rdidx <= hpos[9:1];

    reg q_hborder, q2_hborder;
    always @(posedge clk) q_hborder  <= hborder;
    always @(posedge clk) q2_hborder <= q_hborder;

    reg q_gfx_start;
    always @(posedge clk) q_gfx_start <= vnext;

    gfx gfx(
        .clk(clk),
        .reset(reset),

        // Register values
        .tilemode(reg_gfx_tilemode),
        .sprites_enable(reg_sprites_enable),
        .scroll_x(reg_scroll_x),
        .scroll_y(reg_scroll_y),

        // Sprite attribute interface
        .spr_sel(spr_sel),
        .spr_x(spr_x),
        .spr_y(spr_y),
        .spr_idx(spr_idx),
        .spr_priority(spr_priority),
        .spr_palette(spr_palette),
        .spr_h16(spr_h16),
        .spr_vflip(spr_vflip),
        .spr_hflip(spr_hflip),

        // Video RAM interface
        .vaddr(vram_addr2),
        .vdata(vram_rddata2),

        // Render parameters
        .vline(vpos9[7:0]),
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
            if (reg_text_enable)
                pixel_colidx = {2'b0, text_colidx};

        end else begin
            if (reg_text_enable && !reg_text_priority)
                pixel_colidx = {2'b0, text_colidx};
            if (reg_gfx_enable && (!reg_text_enable || reg_text_priority || linebuf_data[3:0] != 4'd0))
                pixel_colidx = linebuf_data;
            if (reg_text_enable && reg_text_priority && text_colidx != 4'd0)
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
    always @(posedge(clk))
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

    always @(posedge clk) video_hsync <= q2_hsync;
    always @(posedge clk) video_vsync <= q2_vsync;

endmodule
