`default_nettype none
`timescale 1 ns / 1 ps

module t80_alu(
    input  wire        Arith16,
    input  wire        Z16,
    input  wire [15:0] WZ,
    input  wire  [1:0] XY_State,
    input  wire  [3:0] ALU_Op,
    input  wire  [5:0] IR,
    input  wire  [1:0] ISet,
    input  wire  [7:0] BusA,
    input  wire  [7:0] BusB,
    input  wire  [7:0] F_In,
    output wire  [7:0] Q,
    output reg   [7:0] F_Out);

    localparam
        Flag_C = 0,
        Flag_N = 1,
        Flag_P = 2,
        Flag_X = 3,
        Flag_H = 4,
        Flag_Y = 5,
        Flag_Z = 6,
        Flag_S = 7;

    reg [7:0] bitmask;
    always @* case (IR[5:3])
        3'b000:  bitmask = 8'b00000001;
        3'b001:  bitmask = 8'b00000010;
        3'b010:  bitmask = 8'b00000100;
        3'b011:  bitmask = 8'b00001000;
        3'b100:  bitmask = 8'b00010000;
        3'b101:  bitmask = 8'b00100000;
        3'b110:  bitmask = 8'b01000000;
        default: bitmask = 8'b10000000;
    endcase

    wire       do_sub        = ALU_Op[1];
    wire       cin           = (do_sub ^ ((!ALU_Op[2] & ALU_Op[0]) & F_In[Flag_C]));
    wire [5:0] addsub_l      = {1'b0, BusA[3:0], cin}         + {1'b0, (do_sub ? ~BusB[3:0] : BusB[3:0]), 1'b1};
    wire [4:0] addsub_m      = {1'b0, BusA[6:4], addsub_l[5]} + {1'b0, (do_sub ? ~BusB[6:4] : BusB[6:4]), 1'b1};
    wire [2:0] addsub_h      = {1'b0, BusA[7],   addsub_m[4]} + {1'b0, (do_sub ? ~BusB[7]   : BusB[7]),   1'b1};
    wire       half_carry    = addsub_l[5];
    wire       carry7        = addsub_m[4];
    wire       carry         = addsub_h[2];
    wire [7:0] addsub_result = {addsub_h[1], addsub_m[3:1], addsub_l[4:1]};
    wire       overflow      = carry ^ carry7;

    reg [7:0] result;
    reg [8:0] daa_tmp;

    always @* begin
        result  = 0;
        F_Out   = F_In;
        daa_tmp = 0;

        case (ALU_Op)
            4'b0000, 4'b0001, 4'b0010, 4'b0011, 4'b0100, 4'b0101, 4'b0110, 4'b0111: begin
                F_Out[Flag_N] = 0;
                F_Out[Flag_C] = 0;

                case (ALU_Op[2:0])
                    3'b000, 3'b001: begin           // ADD, ADC
                        result        = addsub_result;
                        F_Out[Flag_C] = carry;
                        F_Out[Flag_H] = half_carry;
                        F_Out[Flag_P] = overflow;
                    end

                    3'b010, 3'b011, 3'b111: begin   // SUB, SBC, CP
                        result        = addsub_result;
                        F_Out[Flag_N] = 1;
                        F_Out[Flag_C] = !carry;
                        F_Out[Flag_H] = !half_carry;
                        F_Out[Flag_P] = overflow;
                    end

                    3'b100:  begin result = BusA & BusB; F_Out[Flag_H] = 1; end // AND
                    3'b101:  begin result = BusA ^ BusB; F_Out[Flag_H] = 0; end // XOR
                    default: begin result = BusA | BusB; F_Out[Flag_H] = 0; end // OR (110)
                endcase

                if (ALU_Op[2:0] == 3'b111) begin    // CP
                    F_Out[Flag_X] = BusB[3];
                    F_Out[Flag_Y] = BusB[5];
                end else begin
                    F_Out[Flag_X] = result[3];
                    F_Out[Flag_Y] = result[5];
                end

                F_Out[Flag_Z] = Z16 ? F_In[Flag_Z] : (result == 8'b0);
                F_Out[Flag_S] = result[7];

                case (ALU_Op[2:0])
                    3'b000, 3'b001, 3'b010, 3'b011, 3'b111: begin   // ADD, ADC, SUB, SBC, CP
                    end
                    default: begin
                        F_Out[Flag_P] = !(result[0] ^ result[1] ^ result[2] ^ result[3] ^ result[4] ^ result[5] ^ result[6] ^ result[7]);
                    end
                endcase

                if (Arith16) begin
                    F_Out[Flag_S] = F_In[Flag_S];
                    F_Out[Flag_Z] = F_In[Flag_Z];
                    F_Out[Flag_P] = F_In[Flag_P];
                end
            end

            4'b1100: begin  // DAA
                F_Out[Flag_H] = F_In[Flag_H];
                F_Out[Flag_C] = F_In[Flag_C];
                daa_tmp       = {1'b0, BusA};

                if (!F_In[Flag_N]) begin
                    // After addition
                    // A_low > 9 or H = 1
                    if (daa_tmp[3:0] > 4'd9 || F_In[Flag_H]) begin
                        F_Out[Flag_H] = (daa_tmp[3:0] > 4'd9);
                        daa_tmp       = daa_tmp + 9'd6;
                    end

                    // new A_high > 9 or C = 1
                    if (daa_tmp[8:4] > 5'd9 || F_In[Flag_C])
                        daa_tmp = daa_tmp + 9'h60;

                end else begin
                    // After subtraction
                    if (daa_tmp[3:0] > 4'd9 || F_In[Flag_H]) begin
                        if (daa_tmp[3:0] > 4'd5)
                            F_Out[Flag_H] = 0;

                        daa_tmp[7:0] = daa_tmp[7:0] - 8'd6;
                    end

                    if (BusA > 8'd153 || F_In[Flag_C])
                        daa_tmp = daa_tmp - 9'h160;
                end

                result        = daa_tmp[7:0];
                F_Out[Flag_X] = daa_tmp[3];
                F_Out[Flag_Y] = daa_tmp[5];
                F_Out[Flag_C] = F_In[Flag_C] | daa_tmp[8];
                F_Out[Flag_Z] = (daa_tmp[7:0] == 8'b0);
                F_Out[Flag_S] = daa_tmp[7];
                F_Out[Flag_P] = !(daa_tmp[0] ^ daa_tmp[1] ^ daa_tmp[2] ^ daa_tmp[3] ^ daa_tmp[4] ^ daa_tmp[5] ^ daa_tmp[6] ^ daa_tmp[7]);
            end

            4'b1101, 4'b1110: begin     // RLD, RRD
                result        = {BusA[7:4], ALU_Op[0] ? BusB[7:4] : BusB[3:0]};
                F_Out[Flag_H] = 0;
                F_Out[Flag_N] = 0;
                F_Out[Flag_X] = result[3];
                F_Out[Flag_Y] = result[5];
                F_Out[Flag_Z] = (result == 8'b0);
                F_Out[Flag_S] = result[7];
                F_Out[Flag_P] = !(result[0] ^ result[1] ^ result[2] ^ result[3] ^ result[4] ^ result[5] ^ result[6] ^ result[7]);
            end

            4'b1001: begin      // BIT
                result        = BusB & bitmask;
                F_Out[Flag_S] = result[7];
                F_Out[Flag_Z] = (result == 8'b0);
                F_Out[Flag_P] = (result == 8'b0);
                F_Out[Flag_H] = 1;
                F_Out[Flag_N] = 0;
                if (IR[2:0] == 3'b110 || XY_State != 2'b00) begin
                    F_Out[Flag_X] = WZ[11];
                    F_Out[Flag_Y] = WZ[13];
                end else begin
                    F_Out[Flag_X] = BusB[3];
                    F_Out[Flag_Y] = BusB[5];
                end
            end

            4'b1010: begin      // SET
                result = BusB | bitmask;
            end

            4'b1011: begin      // RES
                result = BusB & ~bitmask;
            end

            4'b1000: begin      // ROT
                case (IR[5:3])
                    3'b000:  begin result = {BusA[6:0],    BusA[7]};      F_Out[Flag_C] = BusA[7]; end // RLC
                    3'b010:  begin result = {BusA[6:0],    F_In[Flag_C]}; F_Out[Flag_C] = BusA[7]; end // RL
                    3'b001:  begin result = {BusA[0],      BusA[7:1]};    F_Out[Flag_C] = BusA[0]; end // RRC
                    3'b011:  begin result = {F_In[Flag_C], BusA[7:1]};    F_Out[Flag_C] = BusA[0]; end // RR
                    3'b100:  begin result = {BusA[6:0],    1'b0};         F_Out[Flag_C] = BusA[7]; end // SLA
                    3'b110:  begin result = {BusA[6:0],    1'b1};         F_Out[Flag_C] = BusA[7]; end // SLL (Undocumented) / SWAP
                    3'b101:  begin result = {BusA[7],      BusA[7:1]};    F_Out[Flag_C] = BusA[0]; end // SRA
                    default: begin result = {1'b0,         BusA[7:1]};    F_Out[Flag_C] = BusA[0]; end // SRL
                endcase

                F_Out[Flag_H] = 0;
                F_Out[Flag_N] = 0;
                F_Out[Flag_X] = result[3];
                F_Out[Flag_Y] = result[5];
                F_Out[Flag_S] = result[7];
                F_Out[Flag_Z] = (result == 8'b0);
                F_Out[Flag_P] = !(result[0] ^ result[1] ^ result[2] ^ result[3] ^ result[4] ^ result[5] ^ result[6] ^ result[7]);
                if (ISet == 2'b00) begin
                    F_Out[Flag_P] = F_In[Flag_P];
                    F_Out[Flag_S] = F_In[Flag_S];
                    F_Out[Flag_Z] = F_In[Flag_Z];
                end
            end

            default: begin end
        endcase
    end

    assign Q = result;

endmodule
