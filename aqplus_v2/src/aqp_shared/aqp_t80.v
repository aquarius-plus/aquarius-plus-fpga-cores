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
    wire [2:0] t80_mc;
    wire [2:0] t80_ts;
    reg  [7:0] q_t80_di;
    wire       t80_int_cycle;

    T80 #(
        .Mode(0)
    ) t80(
        .RESET_n(!reset),
        .CLK_n(clk),
        .CEN(phi_rising),
        .WAIT_n(!bus_wait),
        .INT_n(!irq),
        .IORQ(t80_iorq),
        .NoRead(t80_noread),
        .Write(t80_write),
        .A(bus_addr),
        .DInst(bus_rddata),
        .DI(q_t80_di),
        .DO(bus_wrdata),
        .MC(t80_mc),
        .TS(t80_ts),
        .IntCycle(t80_int_cycle),

        .NMI_n(1'b1),
        .out0(1'b0)
    );

    always @(posedge clk) if (phi_falling && t80_ts == 3'd3) q_t80_di <= bus_rddata;

    reg q_wr_t2;
    always @(posedge clk or posedge reset)
        if (reset) begin
            q_wr_t2 <= 1'b0;

        end else if (phi_falling) begin
            if (t80_ts == 3'd2 && t80_mc != 3'd1) q_wr_t2 <= t80_write;
            if (t80_ts == 3'd3)                   q_wr_t2 <= 1'b0;
        end

    reg q_req_inhibit;
    always @(posedge clk or posedge reset)
        if (reset)           q_req_inhibit <= 1;
        else if (phi_rising) q_req_inhibit <= !(t80_mc == 3'd1 && t80_ts == 3'd2);

    reg q_mreq_inhibit;
    always @(posedge clk or posedge reset)
        if (reset)            q_mreq_inhibit <= 1;
        else if (phi_falling) q_mreq_inhibit <= !(t80_mc == 3'd1 && t80_ts == 3'd2);

    reg q_read;
    reg q_mreq;
    always @(posedge clk or posedge reset)
        if (reset) begin
            q_read <= 1'b0;
            q_mreq <= 1'b0;
        end else if (phi_falling) begin
            if (t80_mc == 3'd1) begin
                if (t80_ts == 3'd1) begin
                    q_read <= !t80_int_cycle;
                    q_mreq <= !t80_int_cycle;
                end
                if (t80_ts == 3'd3) begin
                    q_read <= 1'b0;
                    q_mreq <= 1'b1;
                end
                if (t80_ts == 3'd4) begin
                    q_mreq <= 1'b0;
                end

            end else begin
                if (t80_ts == 3'd1 && !t80_noread) begin
                    q_read <= !t80_write;
                    q_mreq <= !t80_iorq;
                end
                if (t80_ts == 3'd3) begin
                    q_read <= 1'b0;
                    q_mreq <= 1'b0;
                end
            end
        end

    reg q_iorq_int;
    always @(posedge clk or posedge reset)
        if (reset) begin
            q_iorq_int <= 0;

        end else if (phi_rising) begin
            if (t80_mc == 3'd1) begin
                if (t80_ts == 3'd1) q_iorq_int <= t80_int_cycle;
                if (t80_ts == 3'd2) q_iorq_int <= 0;
            end
        end

    reg [2:0] q_iorq_int_inhibit;
    always @(posedge clk or posedge reset)
        if (reset) begin
            q_iorq_int_inhibit <= 3'd7;
        end else if (phi_falling && t80_int_cycle) begin
            if (t80_mc == 3'd1) q_iorq_int_inhibit <= {q_iorq_int_inhibit[1:0], 1'b0};
            if (t80_mc == 3'd2) q_iorq_int_inhibit <= 3'd7;
        end

    reg q_iorq_t1;
    always @(posedge clk or posedge reset)
        if (reset) begin
            q_iorq_t1 <= 1;
        end else if (phi_falling) begin
            if (t80_ts == 3'd1) q_iorq_t1 <= t80_int_cycle;
            if (t80_ts == 3'd3) q_iorq_t1 <= 1;
        end

    reg q_iorq_t2;
    always @(posedge clk or posedge reset)
        if (reset)           q_iorq_t2 <= 1;
        else if (phi_rising) q_iorq_t2 <= q_iorq_t1;

    wire   mreq_rw = q_mreq   && (q_req_inhibit || q_mreq_inhibit);
    wire   iorq_rw = t80_iorq && !(q_iorq_t1 || q_iorq_t2);

    assign bus_memrq = mreq_rw;
    assign bus_iorq  = ((q_iorq_int && !q_iorq_int_inhibit[2]) || iorq_rw);
    assign bus_rd    = (q_read && (mreq_rw || iorq_rw));
    assign bus_wr    = (t80_write && ((q_wr_t2 && mreq_rw) || iorq_rw));
    assign dq_oe     = t80_write;

endmodule
