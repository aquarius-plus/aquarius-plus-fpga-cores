`default_nettype none
`timescale 1 ns / 1 ps

module video(
    input  wire        clk,
    input  wire        reset,

    output wire        irq_vblank,

    // Palette RAM interface
    input  wire  [3:0] pal_addr,
    output wire [11:0] pal_rddata,
    input  wire [11:0] pal_wrdata,
    input  wire        pal_wren,

    // Video RAM interface
    input  wire  [2:0] vram_offset,

    input  wire [12:0] vram_addr,
    input  wire [31:0] vram_wrdata,
    input  wire  [7:0] vram_wrsel,
    input  wire        vram_wren,
    output wire [31:0] vram_rddata,

    // VGA output
    input  wire  [9:0] video_hpos,
    input  wire        video_hlast,
    input  wire  [9:0] video_vpos,
    input  wire        video_vlast,
    output reg   [3:0] video_r,
    output reg   [3:0] video_g,
    output reg   [3:0] video_b
);

    wire hblank = !(video_hpos < 10'd640);
    wire vblank = !(video_vpos < 10'd480);

    reg q_vblank;
    always @(posedge clk) q_vblank <= vblank;

    assign irq_vblank = !q_vblank && vblank;

    //////////////////////////////////////////////////////////////////////////
    // Video RAM (192x160)
    //////////////////////////////////////////////////////////////////////////
    reg         q_vpage = 0;

    reg  [14:0] q_line_addr;
    reg  [14:0] q_pixel_addr;
    reg   [1:0] q_sub_pixel_cnt;
    reg   [1:0] q_sub_line_cnt;
    reg         q_border;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q_line_addr     <= 0;
            q_pixel_addr    <= 0;
            q_sub_pixel_cnt <= 0;
            q_sub_line_cnt  <= 0;
            q_border        <= 0;

        end else begin
            q_border <= 0;

            if (q_sub_pixel_cnt == 2'd2) begin
                q_sub_pixel_cnt <= 0;
                q_pixel_addr    <= q_pixel_addr + 15'd1;
            end else begin
                q_sub_pixel_cnt <= q_sub_pixel_cnt + 2'd1;
            end

            if (video_hpos < 10'd32 || video_hpos >= 10'd608) begin
                q_sub_pixel_cnt <= 0;
                q_border        <= 1;
            end

            if (video_hlast) begin
                if (q_sub_line_cnt == 2'd2) begin
                    q_sub_line_cnt <= 0;
                    q_line_addr <= q_pixel_addr;
                end else begin
                    q_sub_line_cnt <= q_sub_line_cnt + 2'd1;
                    q_pixel_addr <= q_line_addr;
                end
            end

            if (video_vlast) begin
                q_line_addr     <= 0;
                q_sub_pixel_cnt <= 0;
                q_pixel_addr    <= 0;
                q_sub_line_cnt  <= 0;
            end
        end
    end

    reg [2:0] q_pixsel;
    always @(posedge clk) q_pixsel <= q_pixel_addr[2:0];

    wire [31:0] vdata;
    vram vram(
        .clk(clk),

        .a_offset(vram_offset),

        .a_addr(vram_addr),
        .a_wrdata(vram_wrdata),
        .a_wrsel(vram_wrsel),
        .a_wren(vram_wren),
        .a_rddata(vram_rddata),

        .b_addr({q_vpage, q_pixel_addr[14:3]}),
        .b_rddata(vdata)
    );

    reg [3:0] pix_colidx;
    always @* case (q_pixsel)
        3'd7: pix_colidx = vdata[31:28];
        3'd6: pix_colidx = vdata[27:24];
        3'd5: pix_colidx = vdata[23:20];
        3'd4: pix_colidx = vdata[19:16];
        3'd3: pix_colidx = vdata[15:12];
        3'd2: pix_colidx = vdata[11: 8];
        3'd1: pix_colidx = vdata[ 7: 4];
        3'd0: pix_colidx = vdata[ 3: 0];
    endcase

    //////////////////////////////////////////////////////////////////////////
    // Palette
    //////////////////////////////////////////////////////////////////////////
    wire [3:0] pal_r, pal_g, pal_b;

    distram16d #(.WIDTH(12)) palette(
        .clk(clk),
        .a_addr(pal_addr),
        .a_rddata(pal_rddata),
        .a_wrdata(pal_wrdata),
        .a_wren({12{pal_wren}}),
        .b_addr(pix_colidx),
        .b_rddata({pal_r, pal_g, pal_b}));

    //////////////////////////////////////////////////////////////////////////
    // Output registers
    //////////////////////////////////////////////////////////////////////////
    always @(posedge clk) begin
        video_r <= q_border ? 4'b0 : pal_r;
        video_g <= q_border ? 4'b0 : pal_g;
        video_b <= q_border ? 4'b0 : pal_b;
    end

endmodule
