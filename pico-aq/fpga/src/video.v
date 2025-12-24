`default_nettype none
`timescale 1 ns / 1 ps

module video(
    input  wire        clk,
    input  wire        reset,

    output wire        irq_vblank,

    // Text RAM interface
    input  wire [10:0] tram_addr,
    output wire [31:0] tram_rddata,
    input  wire [31:0] tram_wrdata,
    input  wire  [3:0] tram_bytesel,
    input  wire        tram_wren,

    // Char RAM interface
    input  wire [10:0] chram_addr,
    output wire  [7:0] chram_rddata,
    input  wire  [7:0] chram_wrdata,
    input  wire        chram_wren,

    // Palette RAM interface
    input  wire  [6:0] pal_addr,
    output wire [11:0] pal_rddata,
    input  wire [11:0] pal_wrdata,
    input  wire        pal_wren,

    // VGA output
    input  wire  [9:0] video_hpos,
    input  wire        video_hlast,
    input  wire  [9:0] video_vpos,
    input  wire        video_vlast,
    output wire  [3:0] video_r,
    output wire  [3:0] video_g,
    output wire  [3:0] video_b
);

    wire hblank = !(video_hpos < 10'd640);
    wire vblank = !(video_vpos < 10'd480);
    wire blank  = hblank || vblank;
    wire vnext  = video_vpos[0] && video_hlast;

    wire [8:0] vpos9 = video_vpos[9:1];

    reg q_vblank;
    always @(posedge clk) q_vblank <= vblank;

    reg q_blank;
    always @(posedge clk) q_blank <= blank;

    reg q2_blank;
    always @(posedge clk) q2_blank <= q_blank;

    wire [7:0] rddata_sprattr;

    assign irq_vblank = !q_vblank && vblank;

    reg [9:0] q_hpos, q2_hpos;
    always @(posedge clk) q_hpos  <= video_hpos;
    always @(posedge clk) q2_hpos <= q_hpos;

    //////////////////////////////////////////////////////////////////////////
    // Character address
    //////////////////////////////////////////////////////////////////////////
    reg         q_mode80         = 1'b0;
    reg  [11:0] q_row_addr       = 12'd0;
    reg  [11:0] q_char_addr      = 12'd0;
    wire        next_row         = vnext && (vpos9[2:0] == 3'd7);
    wire [11:0] d_row_addr       = q_row_addr + (q_mode80 ? 12'd80 : 12'd40);
    wire [11:0] border_char_addr = 12'h7FF;

    always @(posedge(clk))
        if (vblank) begin
            q_mode80   <= 1'd1;
            q_row_addr <= 12'd0;
        end else if (next_row) begin
            q_row_addr <= d_row_addr;
        end

    wire next_char    = q_mode80 ? (video_hpos[2:0] == 3'd0) : (video_hpos[3:0] == 4'd0);
    wire start_active = q_blank && !blank;

    reg  [11:0] d_char_addr;
    always @* begin
        if      (start_active) d_char_addr = q_row_addr;
        else if (next_char)    d_char_addr = q_char_addr + 12'd1;
        else                   d_char_addr = q_char_addr;
    end

    always @(posedge(clk)) q_char_addr <= d_char_addr;

    //////////////////////////////////////////////////////////////////////////
    // Text RAM
    //////////////////////////////////////////////////////////////////////////
    wire [31:0] textram_rddata;

    dpram8k textram(
        .a_clk(clk),
        .a_addr(tram_addr),
        .a_wrdata(tram_wrdata),
        .a_wrsel(tram_bytesel), 
        .a_wren(tram_wren),
        .a_rddata(tram_rddata),

        .b_clk(clk),
        .b_addr(d_char_addr[11:1]),
        .b_wrdata(32'b0),
        .b_wrsel(4'b0), 
        .b_wren(1'b0),
        .b_rddata(textram_rddata));

    wire [15:0] textram_color_text = q_char_addr[0] ? textram_rddata[31:16] : textram_rddata[15:0];
    wire  [7:0] text_data  = textram_color_text[7:0];
    wire  [7:0] color_data = textram_color_text[15:8];

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
    // Compositing
    //////////////////////////////////////////////////////////////////////////
    wire [6:0] pixel_colidx = {3'b0, text_colidx};

    //////////////////////////////////////////////////////////////////////////
    // Palette
    //////////////////////////////////////////////////////////////////////////
    wire [3:0] pal_r, pal_g, pal_b;

    distram128d #(.WIDTH(12)) palette(
        .clk(clk),
        .a_addr(pal_addr),
        .a_rddata(pal_rddata),
        .a_wrdata(pal_wrdata),
        .a_wren({12{pal_wren}}),
        .b_addr(pixel_colidx),
        .b_rddata({pal_r, pal_g, pal_b}));

    //////////////////////////////////////////////////////////////////////////
    // Output registers
    //////////////////////////////////////////////////////////////////////////
    assign video_r = pal_r;
    assign video_g = pal_g;
    assign video_b = pal_b;

endmodule
