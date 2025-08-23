`default_nettype none
`timescale 1 ns / 1 ps

module aqp_t80(
    input  wire        clk,
    input  wire        reset,

    output wire [15:0] bus_addr,
    output wire  [7:0] bus_wrdata,
    input  wire  [7:0] bus_rddata,
    output wire        dq_oe,

    output wire        bus_memrq,
    output wire        bus_iorq,
    output wire        bus_rd,
    output wire        bus_wr,
    input  wire        bus_wait,

    input  wire        irq
);

    reg q_phi;
    always @(posedge clk or posedge reset)
        if (reset) q_phi <= 0;
        else       q_phi <= !q_phi;

    wire       phi_rising  = !q_phi;
    wire       phi_falling =  q_phi;
    wire       t80_iorq;
    wire       t80_noread;
    wire       t80_write;
    wire [2:0] t80_mcycle;
    wire [2:0] t80_tstate;
    reg  [7:0] q_t80_di;
    wire       t80_irq_cycle;

    wire   clk_en = phi_rising;

    t80 #(
        .Mode(0)
    ) t80(
        .clk(clk),
        .reset(reset),

        .clk_en(clk_en),
        .bus_wait(bus_wait),
        .irq(irq),
        .nmi(1'b0),
        .bus_iorq(t80_iorq),
        .bus_no_read(t80_noread),
        .bus_write(t80_write),
        .bus_addr(bus_addr),
        .DInst(bus_rddata),
        .DI(q_t80_di),
        .bus_wrdata(bus_wrdata),
        .mcycle(t80_mcycle),
        .tstate(t80_tstate),
        .irq_cycle(t80_irq_cycle)
    );

    always @(posedge clk) if (clk_en && t80_tstate == 3'd2) q_t80_di <= bus_rddata;

    reg       q_wr_t2;
    reg       q_req_inhibit;
    reg       q_mreq_inhibit;
    reg       q_read;
    reg       q_mreq;
    reg       q_iorq_int;
    reg [2:0] q_iorq_int_inhibit;
    reg       q_iorq_t1;
    reg       q_iorq_t2;

    always @(posedge clk or posedge reset)
        if (reset) begin
            q_wr_t2            <= 0;
            q_req_inhibit      <= 1;
            q_mreq_inhibit     <= 1;
            q_read             <= 0;
            q_mreq             <= 0;
            q_iorq_int         <= 0;
            q_iorq_int_inhibit <= 3'b111;
            q_iorq_t1          <= 1;
            q_iorq_t2          <= 1;

        end else begin
            if (phi_falling) begin
                if (t80_tstate == 3'd2 && t80_mcycle != 3'd1) q_wr_t2 <= t80_write;
                if (t80_tstate == 3'd3)                       q_wr_t2 <= 1'b0;

                q_mreq_inhibit <= !(t80_mcycle == 3'd1 && t80_tstate == 3'd2);

                if (t80_mcycle == 3'd1) begin
                    if (t80_tstate == 3'd1) q_read <= !t80_irq_cycle;
                    if (t80_tstate == 3'd1) q_mreq <= !t80_irq_cycle;

                    if (t80_tstate == 3'd3) q_read <= 0;
                    if (t80_tstate == 3'd3) q_mreq <= 1;

                    if (t80_tstate == 3'd4) q_mreq <= 0;

                end else begin
                    if (t80_tstate == 3'd1 && !t80_noread) begin
                        q_read <= !t80_write;
                        q_mreq <= !t80_iorq;
                    end

                    if (t80_tstate == 3'd3) q_read <= 0;
                    if (t80_tstate == 3'd3) q_mreq <= 0;
                end

                if (t80_irq_cycle) begin
                    if (t80_mcycle == 3'd1) q_iorq_int_inhibit <= {q_iorq_int_inhibit[1:0], 1'b0};
                    if (t80_mcycle == 3'd2) q_iorq_int_inhibit <= 3'b111;
                end

                if (t80_tstate == 3'd1) q_iorq_t1 <= t80_irq_cycle;
                if (t80_tstate == 3'd3) q_iorq_t1 <= 1;
            end

            if (clk_en) begin
                q_req_inhibit <= !(t80_mcycle == 3'd1 && t80_tstate == 3'd2);

                if (t80_mcycle == 3'd1) begin
                    if (t80_tstate == 3'd1) q_iorq_int <= t80_irq_cycle;
                    if (t80_tstate == 3'd2) q_iorq_int <= 0;
                end

                q_iorq_t2 <= q_iorq_t1;
            end
        end

    wire   mreq_rw = q_mreq   && (q_req_inhibit || q_mreq_inhibit);
    wire   iorq_rw = t80_iorq && !(q_iorq_t1 || q_iorq_t2);

    assign bus_memrq = mreq_rw;
    assign bus_iorq  = (q_iorq_int && !q_iorq_int_inhibit[2]) || iorq_rw;
    assign bus_rd    = q_read && (mreq_rw || iorq_rw);
    assign bus_wr    = t80_write && ((q_wr_t2 && mreq_rw) || iorq_rw);
    assign dq_oe     = t80_write;

endmodule
