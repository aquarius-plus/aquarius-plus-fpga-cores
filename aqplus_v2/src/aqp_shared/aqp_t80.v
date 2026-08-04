`default_nettype none
`timescale 1 ns / 1 ps

module aqp_t80(
    input  wire        clk,
    input  wire        reset,

    output wire [15:0] bus_addr,
    output wire  [7:0] bus_wrdata,
    output wire        bus_wren,
    output wire        bus_iorq,
    output wire        bus_strobe,
    input  wire        bus_wait,
    input  wire  [7:0] bus_rddata,

    input  wire        irq,
    input  wire        nmi
);

    wire       t80_noread;
    wire [2:0] t80_mcycle;
    wire [2:0] t80_tstate;
    wire       t80_irq_cycle;

    reg t80_wait;

    t80 #(
        .Mode(0)
    ) t80(
        .clk         ( clk           ),
        .reset       ( reset         ),

        .clk_en      ( 1'b1          ),

        .bus_addr    ( bus_addr      ),
        .bus_wrdata  ( bus_wrdata    ),
        .bus_wren    ( bus_wren      ),
        .bus_iorq    ( bus_iorq      ),

        .bus_wait    ( t80_wait      ),
        .bus_rddata  ( bus_rddata    ),

        .irq         ( irq           ),
        .irq_vector  ( 8'h00         ),
        .nmi         ( nmi           ),
        .bus_no_read ( t80_noread    ),

        .mcycle      ( t80_mcycle    ),
        .tstate      ( t80_tstate    ),
        .irq_cycle   ( t80_irq_cycle )
    );

    reg d_strobe, q_strobe;
    always @* begin
        d_strobe = q_strobe;
        t80_wait = 1;

        if ((!bus_wren && t80_tstate == 3'd1 && !t80_noread) ||
            ( bus_wren && t80_tstate == 3'd2))
            d_strobe = 1;

        if (q_strobe && !bus_wait) begin
            t80_wait = 0;
            d_strobe = 0;
        end
    end
    always @(posedge clk)
        if (reset) begin
            q_strobe <= 0;
        end else begin
            q_strobe <= d_strobe;
        end

    assign bus_strobe = q_strobe;

`ifdef MODEL_TECH
    initial begin
        forever begin
            @(posedge clk);
            if (bus_strobe && !bus_wait) begin
                if (bus_iorq) begin
                    if (bus_wren)
                        $display("%0t IO  WR   %02h=%02h", $time, bus_addr[7:0], bus_wrdata);
                    else
                        $display("%0t IO  RD   %02h:%02h", $time, bus_addr[7:0], bus_rddata);
                end else begin
                    if (bus_wren)
                        $display("%0t MEM WR %04h=%02h", $time, bus_addr, bus_wrdata);
                    else
                        $display("%0t MEM RD %04h:%02h", $time, bus_addr, bus_rddata);
                end
            end
        end
    end
`endif


endmodule
