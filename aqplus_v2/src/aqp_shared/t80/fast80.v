`default_nettype none
`timescale 1 ns / 1 ps

module fast80(
    input  wire        clk,
    input  wire        reset,

    // Bus interface
    output wire [15:0] bus_addr,
    output wire  [7:0] bus_wrdata,
    output wire        bus_wren,
    output wire        bus_iorq,
    output wire        bus_strobe,
    input  wire        bus_wait,
    input  wire  [7:0] bus_rddata,

    // Interrupt
    input  wire        irq,
    input  wire        nmi
);

    reg [15:0] d_pc,   q_pc;

    // Bus interface
    reg [15:0] d_addr,   q_addr;
    reg  [7:0] d_wrdata, q_wrdata;
    reg        d_wren,   q_wren;
    reg        d_iorq,   q_iorq;
    reg        d_stb,    q_stb;

    assign bus_addr     = q_addr;
    assign bus_wrdata   = q_wrdata;
    assign bus_wren     = q_wren;
    assign bus_iorq     = q_iorq;
    assign bus_strobe   = q_stb;

    always @* begin
        d_pc     = q_pc;
        d_addr   = q_addr;
        d_wrdata = q_wrdata;
        d_wren   = q_wren;
        d_iorq   = q_iorq;
        d_stb    = q_stb;
    end

    always @(posedge clk or posedge reset)
        if (reset) begin
            q_pc     <= 0;
            q_addr   <= 0;
            q_wrdata <= 0;
            q_wren   <= 0;
            q_iorq   <= 0;
            q_stb    <= 0;

        end else begin
            q_pc     <= d_pc;
            q_addr   <= d_addr;
            q_wrdata <= d_wrdata;
            q_wren   <= d_wren;
            q_iorq   <= d_iorq;
            q_stb    <= d_stb;
       end

endmodule
