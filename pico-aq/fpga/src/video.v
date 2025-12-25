`default_nettype none
`timescale 1 ns / 1 ps

module video(
    input  wire        clk,
    input  wire        reset,

    output wire        irq_vblank,

    // Bus interface
    input  wire [16:0] bus_addr,
    input  wire [31:0] bus_wrdata,
    input  wire  [3:0] bus_bytesel,
    input  wire        bus_wren,
    input  wire        bus_strobe,
    output wire        bus_wait,
    output reg  [31:0] bus_rddata,

    // VGA output
    input  wire  [9:0] video_hpos,
    input  wire        video_hlast,
    input  wire  [9:0] video_vpos,
    input  wire        video_vlast,
    output reg   [3:0] video_r,
    output reg   [3:0] video_g,
    output reg   [3:0] video_b
);

    reg [16:0] q_bus_addr;
    always @(posedge clk) q_bus_addr <= bus_addr;

    wire        pal_strobe             = bus_strobe && {bus_addr[16: 5],  5'b0} == 17'h00000;
    wire        reg_vram_offset_strobe = bus_strobe && {bus_addr[16: 2],  2'b0} == 17'h00100;
    wire        vram_strobe            = bus_strobe && {bus_addr[16:15], 15'b0} == 17'h08000;
    wire        vram4bpp_strobe        = bus_strobe && {bus_addr[16],    16'b0} == 17'h10000;


    wire [11:0] pal_rddata;

    // Video RAM interface
    reg   [2:0] q_vram_offset;

    wire [12:0] vram_addr = vram4bpp_strobe ? bus_addr[15:3] : bus_addr[14:2];
    reg  [31:0] vram_wrdata;
    reg   [7:0] vram_wrsel;
    wire        vram_wren = bus_wren && (vram_strobe || vram4bpp_strobe);
    wire [31:0] vram_rddata;
    wire [31:0] vram4bpp_rddata;

    always @* begin
        vram_wrdata = bus_wrdata;
        vram_wrsel = {
            bus_bytesel[3], bus_bytesel[3],
            bus_bytesel[2], bus_bytesel[2],
            bus_bytesel[1], bus_bytesel[1],
            bus_bytesel[0], bus_bytesel[0]
        };

        if (vram4bpp_strobe) begin
            vram_wrdata = {
                bus_wrdata[27:24], bus_wrdata[19:16], bus_wrdata[11:8], bus_wrdata[3:0],
                bus_wrdata[27:24], bus_wrdata[19:16], bus_wrdata[11:8], bus_wrdata[3:0]
            };
            vram_wrsel = bus_addr[2] ?
                {      bus_bytesel[3], bus_bytesel[2], bus_bytesel[1], bus_bytesel[0], 4'b0} :
                {4'b0, bus_bytesel[3], bus_bytesel[2], bus_bytesel[1], bus_bytesel[0]      };
        end
    end

    assign vram4bpp_rddata = q_bus_addr[2] ?
        {4'b0, vram_rddata[31:28], 4'b0, vram_rddata[27:24], 4'b0, vram_rddata[23:20], 4'b0, vram_rddata[19:16]} :
        {4'b0, vram_rddata[15:12], 4'b0, vram_rddata[11: 8], 4'b0, vram_rddata[ 7: 4], 4'b0, vram_rddata[ 3: 0]};

    always @(posedge clk or posedge reset)
        if (reset) begin
            q_vram_offset <= 0;
        end else begin
            if (bus_wren && reg_vram_offset_strobe) q_vram_offset <= bus_wrdata[2:0];
        end

    //////////////////////////////////////////////////////////////////////////
    // Bus interface
    //////////////////////////////////////////////////////////////////////////
    wire common_wait = !bus_wren && (q_bus_addr != bus_addr);

    assign bus_wait = (vram_strobe || vram4bpp_strobe) && common_wait;

    always @* begin
        bus_rddata = 0;
        if (pal_strobe)             bus_rddata = {4'b0, pal_rddata, 4'b0, pal_rddata};
        if (reg_vram_offset_strobe) bus_rddata = {29'b0, q_vram_offset};
        if (vram_strobe)            bus_rddata = vram_rddata;
        if (vram4bpp_strobe)        bus_rddata = vram4bpp_rddata;
    end

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

        .a_offset(q_vram_offset),

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
        .a_addr(bus_addr[4:1]),
        .a_rddata(pal_rddata),
        .a_wrdata(bus_wrdata[11:0]),
        .a_wren({12{bus_wren && pal_strobe}}),
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
