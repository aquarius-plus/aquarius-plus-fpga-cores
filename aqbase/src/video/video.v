`default_nettype none
`timescale 1 ns / 1 ps

module video(
    input  wire        clk,
    input  wire        reset,

    input  wire        vclk,            // 28.63636MHz (video_mode = 0) or 25.175MHz (video_mode = 1)
    input  wire        video_mode,

    // IO register interface
    input  wire  [3:0] io_addr,
    output reg   [7:0] io_rddata,
    input  wire  [7:0] io_wrdata,
    input  wire        io_wren,
    output wire        irq,

    // Text RAM interface
    input  wire [10:0] tram_addr,
    output wire  [7:0] tram_rddata,
    input  wire  [7:0] tram_wrdata,
    input  wire        tram_wren,

    // Char RAM interface
    input  wire [10:0] chram_addr,
    output wire  [7:0] chram_rddata,
    input  wire  [7:0] chram_wrdata,
    input  wire        chram_wren,

    // VGA output
    output reg   [3:0] video_r,
    output reg   [3:0] video_g,
    output reg   [3:0] video_b,
    output reg         video_de,
    output reg         video_hsync,
    output reg         video_vsync,
    output wire        video_newframe,
    output reg         video_oddline,

    // Register $FD value
    output wire        reg_fd_val);

    // Sync reset to vclk domain
    wire vclk_reset;
    reset_sync ressync_vclk(.async_rst_in(reset), .clk(vclk), .reset_out(vclk_reset));

    wire [7:0] vpos;
    wire       vblank;

    reg q_vblank;
    always @(posedge vclk) q_vblank <= vblank;

    wire [7:0] rddata_vpaldata;

    reg        q_vctrl_tram_page;       // IO $E0 [7]
    reg        q_vctrl_80_columns;      // IO $E0 [6]
    reg        q_vctrl_border_remap;    // IO $E0 [5]
    reg  [6:0] q_vpalsel;               // IO $EA
    reg  [7:0] q_virqline;              // IO $ED
    reg        q_irqmask_line;          // IO $EE [0]
    reg        q_irqmask_vblank;        // IO $EE [1]
    reg        q_irqstat_line;          // IO $EF [0]
    reg        q_irqstat_vblank;        // IO $EF [1]

    wire irqline_match = (vpos == q_virqline);
    reg q_irqline_match;
    always @(posedge vclk) q_irqline_match <= irqline_match;

    wire irq_line, irq_vblank;
    pulse2pulse p2p_irq_line(  .in_clk(vclk), .in_pulse(!q_irqline_match && irqline_match), .out_clk(clk), .out_pulse(irq_line));
    pulse2pulse p2p_irq_vblank(.in_clk(vclk), .in_pulse(!q_vblank        && vblank),        .out_clk(clk), .out_pulse(irq_vblank));

    assign irq = ({q_irqstat_line, q_irqstat_vblank} & {q_irqmask_line, q_irqmask_vblank}) != 2'b00;

    //////////////////////////////////////////////////////////////////////////
    // IO registers
    //////////////////////////////////////////////////////////////////////////
    wire sel_io_vctrl    = (io_addr == 4'h0);
    wire sel_io_vpalsel  = (io_addr == 4'hA);
    wire sel_io_vpaldata = (io_addr == 4'hB);
    wire sel_io_vline    = (io_addr == 4'hC);
    wire sel_io_virqline = (io_addr == 4'hD);
    wire sel_io_irqmask  = (io_addr == 4'hE);
    wire sel_io_irqstat  = (io_addr == 4'hF);

    always @* begin
        io_rddata = 8'h00;
        if (sel_io_vctrl)    io_rddata = {q_vctrl_tram_page, q_vctrl_80_columns, q_vctrl_border_remap, 5'b0};
        if (sel_io_vpalsel)  io_rddata = {1'b0, q_vpalsel};                        // IO $EA
        if (sel_io_vpaldata) io_rddata = rddata_vpaldata;                          // IO $EB
        if (sel_io_vline)    io_rddata = vpos;                                     // IO $EC
        if (sel_io_virqline) io_rddata = q_virqline;                               // IO $ED
        if (sel_io_irqmask)  io_rddata = {6'b0, q_irqmask_line, q_irqmask_vblank}; // IO $EE
        if (sel_io_irqstat)  io_rddata = {6'b0, q_irqstat_line, q_irqstat_vblank}; // IO $EF
    end

    always @(posedge clk or posedge reset)
        if (reset) begin
            q_vctrl_tram_page      <= 0;
            q_vctrl_80_columns     <= 0;
            q_vctrl_border_remap   <= 0;
            q_vpalsel              <= 0;
            q_virqline             <= 0;
            q_irqmask_line         <= 0;
            q_irqmask_vblank       <= 0;
            q_irqstat_line         <= 0;
            q_irqstat_vblank       <= 0;

        end else begin
            if (io_wren) begin
                if (sel_io_vctrl) begin
                    q_vctrl_tram_page      <= io_wrdata[7];
                    q_vctrl_80_columns     <= io_wrdata[6];
                    q_vctrl_border_remap   <= io_wrdata[5];
                end
                if (sel_io_vpalsel)  q_vpalsel    <= io_wrdata[6:0];
                if (sel_io_virqline) q_virqline   <= io_wrdata;
                if (sel_io_irqmask) begin
                    q_irqmask_line   <= io_wrdata[1];
                    q_irqmask_vblank <= io_wrdata[0];
                end
                if (sel_io_irqstat) begin
                    q_irqstat_line   <= q_irqstat_line   & !io_wrdata[1];
                    q_irqstat_vblank <= q_irqstat_vblank & !io_wrdata[0];
                end
            end

            if (irq_line)   q_irqstat_line   <= 1'b1;
            if (irq_vblank) q_irqstat_vblank <= 1'b1;
        end

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
        .mode(video_mode),

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

    wire hborder = video_mode ? blank : (hpos < 10'd32 || hpos >= 10'd672);
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
    wire [10:0] border_char_addr = q_vctrl_border_remap ? (q_mode80 ? 11'h7FF : 11'h3FF) : 11'h0;

    always @(posedge(vclk))
        if (vblank) begin
            q_mode80   <= q_vctrl_80_columns;
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
            d_char_addr[10] = q_vctrl_tram_page;
    end

    always @(posedge(vclk)) q_char_addr <= d_char_addr;

    //////////////////////////////////////////////////////////////////////////
    // Text RAM
    //////////////////////////////////////////////////////////////////////////
    wire [15:0] textram_rddata;
    wire [11:0] tram_p1_addr = q_vctrl_80_columns ? {tram_addr[10:0], q_vctrl_tram_page} : {q_vctrl_tram_page, tram_addr[9:0], tram_addr[10]};

    textram textram(
        // First port - CPU access
        .p1_clk(clk),
        .p1_addr(tram_p1_addr),
        .p1_rddata(tram_rddata),
        .p1_wrdata(tram_wrdata),
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
    // Compositing
    //////////////////////////////////////////////////////////////////////////
    wire [5:0] pixel_colidx = {2'b0, text_colidx};
    wire       active = !vborder;

    assign reg_fd_val = !vborder;

    //////////////////////////////////////////////////////////////////////////
    // Palette
    //////////////////////////////////////////////////////////////////////////
    wire [3:0] pal_r, pal_g, pal_b;

    palette palette(
        .clk(clk),
        .addr(q_vpalsel),
        .rddata(rddata_vpaldata),
        .wrdata(io_wrdata),
        .wren(io_wren && sel_io_vpaldata),

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
