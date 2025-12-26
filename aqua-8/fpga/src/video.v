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

    wire        pal_strobe             = bus_strobe && {bus_addr[16: 5],  5'b0} == 17'h00000;   // 00-1F
    wire        remap_strobe           = bus_strobe && {bus_addr[16: 4],  4'b0} == 17'h00020;   // 20-2F
    wire        reg_posx_strobe        = bus_strobe && {bus_addr[16: 2],  2'b0} == 17'h00100;
    wire        reg_posy_strobe        = bus_strobe && {bus_addr[16: 2],  2'b0} == 17'h00104;
    wire        reg_color_strobe       = bus_strobe && {bus_addr[16: 2],  2'b0} == 17'h00108;
    wire        reg_flags_strobe       = bus_strobe && {bus_addr[16: 2],  2'b0} == 17'h0010C;
    wire        reg_wr1bpp_strobe      = bus_strobe && {bus_addr[16: 2],  2'b0} == 17'h00110;
    wire        reg_wr4bpp_strobe      = bus_strobe && {bus_addr[16: 2],  2'b0} == 17'h00114;
    wire        reg_remap_t_strobe        = bus_strobe && {bus_addr[16: 2],  2'b0} == 17'h00118;
    wire        vram_strobe            = bus_strobe && {bus_addr[16:15], 15'b0} == 17'h08000;
    wire        vram4bpp_strobe        = bus_strobe && {bus_addr[16],    16'b0} == 17'h10000;


    wire [11:0] pal_rddata;

    //////////////////////////////////////////////////////////////////////////
    // Color remapping
    //////////////////////////////////////////////////////////////////////////
    wire [31:0] remapped_data;
    wire  [3:0] remap0_rddata;
    wire  [3:0] remap1_rddata;  // unused
    wire  [3:0] remap2_rddata;  // unused
    wire  [3:0] remap3_rddata;  // unused
    wire  [3:0] remap4_rddata;  // unused
    wire  [3:0] remap5_rddata;  // unused
    wire  [3:0] remap6_rddata;  // unused
    wire  [3:0] remap7_rddata;  // unused

    distram16d #(.WIDTH(4)) remap0(.clk(clk), .a_addr(bus_addr[3:0]), .a_rddata(remap0_rddata), .a_wrdata(bus_wrdata[3:0]), .a_wren({4{bus_wren && remap_strobe}}), .b_addr(bus_wrdata[ 3: 0]), .b_rddata(remapped_data[ 3: 0]));
    distram16d #(.WIDTH(4)) remap1(.clk(clk), .a_addr(bus_addr[3:0]), .a_rddata(remap1_rddata), .a_wrdata(bus_wrdata[3:0]), .a_wren({4{bus_wren && remap_strobe}}), .b_addr(bus_wrdata[ 7: 4]), .b_rddata(remapped_data[ 7: 4]));
    distram16d #(.WIDTH(4)) remap2(.clk(clk), .a_addr(bus_addr[3:0]), .a_rddata(remap2_rddata), .a_wrdata(bus_wrdata[3:0]), .a_wren({4{bus_wren && remap_strobe}}), .b_addr(bus_wrdata[11: 8]), .b_rddata(remapped_data[11: 8]));
    distram16d #(.WIDTH(4)) remap3(.clk(clk), .a_addr(bus_addr[3:0]), .a_rddata(remap3_rddata), .a_wrdata(bus_wrdata[3:0]), .a_wren({4{bus_wren && remap_strobe}}), .b_addr(bus_wrdata[15:12]), .b_rddata(remapped_data[15:12]));
    distram16d #(.WIDTH(4)) remap4(.clk(clk), .a_addr(bus_addr[3:0]), .a_rddata(remap4_rddata), .a_wrdata(bus_wrdata[3:0]), .a_wren({4{bus_wren && remap_strobe}}), .b_addr(bus_wrdata[19:16]), .b_rddata(remapped_data[19:16]));
    distram16d #(.WIDTH(4)) remap5(.clk(clk), .a_addr(bus_addr[3:0]), .a_rddata(remap5_rddata), .a_wrdata(bus_wrdata[3:0]), .a_wren({4{bus_wren && remap_strobe}}), .b_addr(bus_wrdata[23:20]), .b_rddata(remapped_data[23:20]));
    distram16d #(.WIDTH(4)) remap6(.clk(clk), .a_addr(bus_addr[3:0]), .a_rddata(remap6_rddata), .a_wrdata(bus_wrdata[3:0]), .a_wren({4{bus_wren && remap_strobe}}), .b_addr(bus_wrdata[27:24]), .b_rddata(remapped_data[27:24]));
    distram16d #(.WIDTH(4)) remap7(.clk(clk), .a_addr(bus_addr[3:0]), .a_rddata(remap7_rddata), .a_wrdata(bus_wrdata[3:0]), .a_wren({4{bus_wren && remap_strobe}}), .b_addr(bus_wrdata[31:28]), .b_rddata(remapped_data[31:28]));

    //////////////////////////////////////////////////////////////////////////
    // Video RAM interface
    //////////////////////////////////////////////////////////////////////////
    reg  [15:0] q_reg_posx;
    reg  [15:0] q_reg_posy;
    reg   [3:0] q_reg_color;
    reg   [3:0] q_reg_flags;
    reg  [15:0] q_reg_remap_t;  // Remapping transparency

    reg   [2:0] vram_offset;
    reg  [12:0] vram_addr;
    reg  [31:0] vram_wrdata;
    reg   [7:0] vram_wrsel;
    reg         vram_wren;

    wire [31:0] vram_rddata;
    wire [31:0] vram4bpp_rddata;

    // y*24+x
    wire [12:0] pos_addr = {1'b0, q_reg_posy[7:0], 4'b0} + {2'b0, q_reg_posy[7:0], 3'b0} + {8'b0, q_reg_posx[7:3]};

    // Flags:
    // 0:increment y by 1 after write
    // 1:increment x by 8 after write

    always @* begin
        vram_offset = 0;
        vram_addr   = 0;
        vram_wrdata = 0;
        vram_wrsel  = 0;
        vram_wren   = 0;

        if (reg_wr1bpp_strobe) begin
            // Position based 1bpp -> 4bpp conversion (8 pixels at a time)
            vram_offset = q_reg_posx[2:0];
            vram_addr   = pos_addr;
            vram_wrdata = {8{q_reg_color}};
            vram_wrsel  = bus_wrdata[7:0];
            vram_wren   = bus_wren;

        end else if (reg_wr4bpp_strobe) begin
            // Position based 32-bit access (8 pixels at a time)
            vram_offset = q_reg_posx[2:0];
            vram_addr   = pos_addr;
            vram_wrdata = remapped_data;
            vram_wrsel  = ~{
                q_reg_remap_t[remapped_data[31:28]],
                q_reg_remap_t[remapped_data[27:24]],
                q_reg_remap_t[remapped_data[23:20]],
                q_reg_remap_t[remapped_data[19:16]],
                q_reg_remap_t[remapped_data[15:12]],
                q_reg_remap_t[remapped_data[11: 8]],
                q_reg_remap_t[remapped_data[ 7: 4]],
                q_reg_remap_t[remapped_data[ 3: 0]]
            };
            vram_wren   = bus_wren;

        end else if (vram_strobe) begin
            // Address-based 32-bit access (8 pixels at at time)
            vram_addr   = bus_addr[14:2];
            vram_wrdata = bus_wrdata;
            vram_wrsel  = {{2{bus_bytesel[3]}}, {2{bus_bytesel[2]}}, {2{bus_bytesel[1]}}, {2{bus_bytesel[0]}}};
            vram_wren   = bus_wren;
            
        end else if (vram4bpp_strobe) begin
            // Address-based 4bpp -> 8bpp conversion access (4 pixels at a time)
            vram_addr   = bus_addr[15:3];
            vram_wrdata = {2{bus_wrdata[27:24], bus_wrdata[19:16], bus_wrdata[11:8], bus_wrdata[3:0]}};
            vram_wrsel  = bus_addr[2] ?
                {      bus_bytesel[3], bus_bytesel[2], bus_bytesel[1], bus_bytesel[0], 4'b0} :
                {4'b0, bus_bytesel[3], bus_bytesel[2], bus_bytesel[1], bus_bytesel[0]      };
            vram_wren   = bus_wren;
        end
    end

    assign vram4bpp_rddata = q_bus_addr[2] ?
        {4'b0, vram_rddata[31:28], 4'b0, vram_rddata[27:24], 4'b0, vram_rddata[23:20], 4'b0, vram_rddata[19:16]} :
        {4'b0, vram_rddata[15:12], 4'b0, vram_rddata[11: 8], 4'b0, vram_rddata[ 7: 4], 4'b0, vram_rddata[ 3: 0]};

    always @(posedge clk or posedge reset)
        if (reset) begin
            q_reg_posx    <= 0;
            q_reg_posy    <= 0;
            q_reg_flags   <= 0;
            q_reg_color   <= 0;
            q_reg_remap_t <= 0;

        end else if (bus_wren) begin
            if (bus_wren && (reg_wr1bpp_strobe || reg_wr4bpp_strobe)) begin
                if (q_reg_flags[0]) q_reg_posy <= q_reg_posy + 16'd1;
                if (q_reg_flags[1]) q_reg_posx <= q_reg_posx + 16'd8;
            end

            if (reg_posx_strobe)    q_reg_posx    <= bus_wrdata[31:16];
            if (reg_posy_strobe)    q_reg_posy    <= bus_wrdata[31:16];
            if (reg_flags_strobe)   q_reg_flags   <= bus_wrdata[3:0];
            if (reg_color_strobe)   q_reg_color   <= bus_wrdata[3:0];
            if (reg_remap_t_strobe) q_reg_remap_t <= bus_wrdata[15:0];
        end

    //////////////////////////////////////////////////////////////////////////
    // Bus interface
    //////////////////////////////////////////////////////////////////////////
    wire common_wait = !bus_wren && (q_bus_addr != bus_addr);

    assign bus_wait = (vram_strobe || vram4bpp_strobe) && common_wait;

    always @* begin
        bus_rddata = 0;
        if (pal_strobe)             bus_rddata = {2{4'b0, pal_rddata}};
        if (remap_strobe)           bus_rddata = {4{4'b0, remap0_rddata}};
        if (reg_posx_strobe)        bus_rddata = {q_reg_posx, 16'b0};
        if (reg_posy_strobe)        bus_rddata = {q_reg_posy, 16'b0};
        if (reg_flags_strobe)       bus_rddata = {28'b0, q_reg_flags};
        if (reg_color_strobe)       bus_rddata = {28'b0, q_reg_color};
        if (reg_remap_t_strobe)     bus_rddata = {16'b0, q_reg_remap_t};
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
