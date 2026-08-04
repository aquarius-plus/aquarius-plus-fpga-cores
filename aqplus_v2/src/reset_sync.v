`default_nettype none
`timescale 1 ns / 1 ps

module reset_sync /* synthesis syn_hier="hard" */ (
    input  wire rst_in,
    input  wire clk,
    output wire rst_out);

    reg [2:0] q_sync /* synthesis syn_keep=1 syn_replicate=0 */;
    always @(posedge clk)
        q_sync <= {q_sync[1:0], rst_in};


    // always @(posedge clk or posedge rst_in)
    //     if (rst_in)
    //         q_sync <= 2'b11;
    //     else
    //         q_sync <= {q_sync[0], 1'b0};

    assign rst_out = q_sync[2];

endmodule
