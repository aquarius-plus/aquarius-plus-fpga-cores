`default_nettype none
`timescale 1 ns / 1 ps

module t80(
    input  wire        clk,
    input  wire        reset,

    input  wire        CEN,
    input  wire        WAIT_n,
    input  wire        INT_n,
    input  wire        NMI_n,
    output wire        IORQ,
    output wire        NoRead,
    output wire        Write,
    output reg  [15:0] A,
    input  wire  [7:0] DInst,
    input  wire  [7:0] DI,
    output reg   [7:0] DO,
    output wire  [2:0] MC,
    output wire  [2:0] TS,
    output wire        IntCycle,
    input  wire        out0);

    parameter [31:0] Mode = 0;
    // 0 => Z80, 1 => Fast Z80
    // 0 => OUT(C),0, 1 => OUT(C),255

    localparam
        Flag_C = 0,
        Flag_N = 1,
        Flag_P = 2,
        Flag_X = 3,
        Flag_H = 4,
        Flag_Y = 5,
        Flag_Z = 6,
        Flag_S = 7;

    localparam
        aNone = 3'd7,
        aBC   = 3'd0,
        aDE   = 3'd1,
        aXY   = 3'd2,
        aIOA  = 3'd4,
        aSP   = 3'd5,
        aZI   = 3'd6;

    // Registers
    reg   [7:0] ACC;
    reg   [7:0] F;
    reg   [7:0] Ap;
    reg   [7:0] Fp;
    reg   [7:0] I;
    reg   [7:0] R;
    reg  [15:0] SP;
    reg  [15:0] PC;
    reg   [7:0] RegDIH;
    reg   [7:0] RegDIL;
    wire [15:0] RegBusA;
    wire [15:0] RegBusB;
    wire [15:0] RegBusC;
    reg   [2:0] RegAddrA_r;
    reg   [2:0] RegAddrB_r;
    reg   [2:0] RegAddrC;
    reg         RegWEH;
    reg         RegWEL;
    reg         Alternate;  // Help Registers
    reg  [15:0] WZ;  // MEMPTR register
    reg   [7:0] IR;  // Instruction register
    reg   [1:0] ISet;  // Instruction set selector
    reg  [15:0] RegBusA_r;
    wire [15:0] ID16;
    wire  [7:0] Save_Mux;
    reg   [2:0] TState;
    reg   [2:0] MCycle;
    reg         IntE_FF1;
    reg         IntE_FF2;
    reg         Halt_FF;
    wire        ClkEn;
    reg         NMI_s;
    reg   [1:0] IStatus;
    wire  [7:0] DI_Reg;
    wire        T_Res;
    reg   [1:0] XY_State;
    reg   [2:0] Pre_XY_F_M;
    wire        NextIs_XY_Fetch;
    reg         XY_Ind;
    reg         No_BTR;
    reg         BTR_r;
    wire        Auto_Wait;
    reg         Auto_Wait_t1;
    reg         Auto_Wait_t2;
    reg         IncDecZ;  // ALU signals
    reg   [7:0] BusB;
    reg   [7:0] BusA;
    wire  [7:0] ALU_Q;
    reg   [7:0] F_Out;  // Registered micro code outputs
    reg   [4:0] Read_To_Reg_r;
    reg         Arith16_r;
    reg         Z16_r;
    reg   [3:0] ALU_Op_r;
    reg         Save_ALU_r;
    reg         PreserveC_r;
    reg   [2:0] MCycles;  // Micro code outputs
    reg   [2:0] MCycles_d;
    reg   [2:0] TStates;
    reg         IntCycle_i;
    reg         NMICycle;
    reg         Inc_PC;
    reg         Inc_WZ;
    reg   [3:0] IncDec_16;
    reg   [1:0] Prefix;
    reg         Read_To_Acc;
    reg         Read_To_Reg;
    reg   [3:0] Set_BusB_To;
    reg   [3:0] Set_BusA_To;
    reg   [3:0] ALU_Op;
    reg         Save_ALU;
    reg         PreserveC;
    reg         Arith16;
    reg   [2:0] Set_Addr_To;
    reg         Jump;
    reg         JumpE;
    reg         JumpXY;
    reg         Call;
    reg         RstP;
    reg         LDZ;
    reg         LDW;
    reg         LDSPHL;
    reg         LDHLSP;
    reg         ADDSPdd;
    reg         IORQ_i;
    reg         Write_i;
    reg         NoRead_i;
    reg   [2:0] Special_LD;
    reg         ExchangeDH;
    reg         ExchangeRp;
    reg         ExchangeAF;
    reg         ExchangeRS;
    reg         ExchangeWH;
    reg         I_DJNZ;
    reg         I_CPL;
    reg         I_CCF;
    reg         I_SCF;
    reg         I_RETN;
    reg         I_BT;
    reg         I_BC;
    reg         I_BTR;
    reg         I_RLD;
    reg         I_RRD;
    reg         I_RXDD;
    reg         I_INRC;
    reg   [1:0] SetWZ;
    reg         SetDI;
    reg         SetEI;
    reg   [1:0] IMode;
    reg         Halt;
    reg         XYbit_undoc;
    reg         No_PC;
    wire        Really_Wait;

    //------------------------------------------------------------------------
    // Microcode
    //------------------------------------------------------------------------

    reg cc_is_true;
    always @* begin
        case (IR[5:3])
            3'd0:    cc_is_true = !F[Flag_Z]; // NZ
            3'd1:    cc_is_true =  F[Flag_Z]; // Z
            3'd2:    cc_is_true = !F[Flag_C]; // NC
            3'd3:    cc_is_true =  F[Flag_C]; // C
            3'd4:    cc_is_true = !F[Flag_P]; // PO
            3'd5:    cc_is_true =  F[Flag_P]; // PE
            3'd6:    cc_is_true = !F[Flag_S]; // P
            default: cc_is_true =  F[Flag_S]; // M
        endcase
    end

    reg [2:0] DDD;
    reg [2:0] SSS;
    reg [1:0] DPair;

    always @* begin
        DDD         = IR[5:3];
        SSS         = IR[2:0];
        DPair       = IR[5:4];
        MCycles_d   = 3'd1;
        TStates     = (MCycle == 3'd1) ? 3'd4 : 3'd3;
        Prefix      = 2'b00;
        Inc_PC      = 0;
        Inc_WZ      = 0;
        IncDec_16   = 4'b0000;
        Read_To_Acc = 0;
        Read_To_Reg = 0;
        Set_BusB_To = 4'b0000;
        Set_BusA_To = 4'b0000;
        ALU_Op      = {1'b0, IR[5:3]};
        Save_ALU    = 0;
        PreserveC   = 0;
        Arith16     = 0;
        IORQ_i      = 0;
        Set_Addr_To = aNone;
        Jump        = 0;
        JumpE       = 0;
        JumpXY      = 0;
        Call        = 0;
        RstP        = 0;
        LDZ         = 0;
        LDW         = 0;
        LDSPHL      = 0;
        LDHLSP      = 0;
        ADDSPdd     = 0;
        Special_LD  = 3'd0;
        ExchangeDH  = 0;
        ExchangeRp  = 0;
        ExchangeAF  = 0;
        ExchangeRS  = 0;
        ExchangeWH  = 0;
        I_DJNZ      = 0;
        I_CPL       = 0;
        I_CCF       = 0;
        I_SCF       = 0;
        I_RETN      = 0;
        I_BT        = 0;
        I_BC        = 0;
        I_BTR       = 0;
        I_RLD       = 0;
        I_RRD       = 0;
        I_INRC      = 0;
        SetDI       = 0;
        SetEI       = 0;
        IMode       = 2'b11;
        Halt        = 0;
        NoRead_i    = 0;
        Write_i     = 0;
        No_PC       = 0;
        XYbit_undoc = 0;
        SetWZ       = 2'b00;

        case (ISet)
            //----------------------------------------------------------------
            // Unprefixed instructions
            //----------------------------------------------------------------
            2'b00: begin
                case (IR)
                    // 8 BIT LOAD GROUP
                    8'h40,8'h41,8'h42,8'h43,8'h44,8'h45,8'h47,
                    8'h48,8'h49,8'h4a,8'h4b,8'h4c,8'h4d,8'h4f,
                    8'h50,8'h51,8'h52,8'h53,8'h54,8'h55,8'h57,
                    8'h58,8'h59,8'h5a,8'h5b,8'h5c,8'h5d,8'h5f,
                    8'h60,8'h61,8'h62,8'h63,8'h64,8'h65,8'h67,
                    8'h68,8'h69,8'h6a,8'h6b,8'h6c,8'h6d,8'h6f,
                    8'h78,8'h79,8'h7a,8'h7b,8'h7c,8'h7d,8'h7f: begin
                        // LD r,r'
                        Set_BusB_To[2:0] = SSS;
                        ExchangeRp       = 1;
                        Set_BusA_To[2:0] = DDD;
                        Read_To_Reg      = 1;
                    end

                    8'h06,8'h0e,8'h16,8'h1e,8'h26,8'h2e,8'h3e: begin
                        // LD r,n
                        MCycles_d = 3'd2;
                        case (MCycle)
                            3'd2: begin
                                Inc_PC           = 1;
                                Set_BusA_To[2:0] = DDD;
                                Read_To_Reg      = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'h46,8'h4e,8'h56,8'h5e,8'h66,8'h6e,8'h7e: begin
                        // LD r,(HL)
                        MCycles_d = 3'd2;
                        case (MCycle)
                        3'd1: begin
                            Set_Addr_To = aXY;
                        end
                        3'd2: begin
                            Set_BusA_To[2:0] = DDD;
                            Read_To_Reg      = 1;
                        end
                        default: begin end
                        endcase
                    end

                    8'h70,8'h71,8'h72,8'h73,8'h74,8'h75,8'h77: begin
                        // LD (HL),r
                        MCycles_d = 3'd2;
                        case (MCycle)
                        3'd1: begin
                            Set_Addr_To = aXY;
                            Set_BusB_To[2:0] = SSS;
                            Set_BusB_To[3] = 0;
                        end
                        3'd2: begin
                            Write_i = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'h36: begin
                        // LD (HL),n
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            Set_Addr_To = aXY;
                            Set_BusB_To[2:0] = SSS;
                            Set_BusB_To[3] = 0;
                        end
                        3'd3: begin
                            Write_i = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'h0a: begin
                        // LD A,(BC)
                        MCycles_d = 3'd2;
                        case (MCycle)
                        3'd1: begin
                            Set_Addr_To = aBC;
                        end
                        3'd2: begin
                            Read_To_Acc = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'h1a: begin
                        // LD A,(DE)
                        MCycles_d = 3'd2;
                        case (MCycle)
                        3'd1: begin
                            Set_Addr_To = aDE;
                        end
                        3'd2: begin
                            Read_To_Acc = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'h3a: begin
                        // LD A,(nn)
                        MCycles_d = 3'd4;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            LDZ = 1;
                        end
                        3'd3: begin
                            Set_Addr_To = aZI;
                            Inc_PC = 1;
                        end
                        3'd4: begin
                            Read_To_Acc = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'h02: begin
                        // LD (BC),A
                        MCycles_d = 3'd2;
                        case (MCycle)
                        3'd1: begin
                            Set_Addr_To = aBC;
                            Set_BusB_To = 4'b0111;
                            SetWZ = 2'b10;
                        end
                        3'd2: begin
                            Write_i = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'h12: begin
                        // LD (DE),A
                        MCycles_d = 3'd2;
                        case (MCycle)
                        3'd1: begin
                            Set_Addr_To = aDE;
                            Set_BusB_To = 4'b0111;
                            SetWZ = 2'b10;
                        end
                        3'd2: begin
                            Write_i = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'h32: begin
                        // LD (nn),A
                        MCycles_d = 3'd4;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            LDZ = 1;
                        end
                        3'd3: begin
                            Set_Addr_To = aZI;
                            SetWZ = 2'b10;
                            Inc_PC = 1;
                            Set_BusB_To = 4'b0111;
                        end
                        3'd4: begin
                            Write_i = 1;
                        end
                        default: begin end
                        endcase
                        // 16 BIT LOAD GROUP
                    end
                    8'h01,8'h11,8'h21,8'h31: begin
                        // LD dd,nn
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            Read_To_Reg = 1;
                            if (DPair == 2'b11) begin
                                Set_BusA_To[3:0] = 4'b1000;
                            end
                            else begin
                                Set_BusA_To[2:1] = DPair;
                                Set_BusA_To[0] = 1;
                            end
                        end
                        3'd3: begin
                            Inc_PC = 1;
                            Read_To_Reg = 1;
                            if (DPair == 2'b11) begin
                                Set_BusA_To[3:0] = 4'b1001;
                            end
                            else begin
                                Set_BusA_To[2:1] = DPair;
                                Set_BusA_To[0] = 0;
                            end
                        end
                        default: begin end
                        endcase
                    end
                    8'h2a: begin
                        // LD HL,(nn)
                        MCycles_d = 3'd5;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            LDZ = 1;
                        end
                        3'd3: begin
                            Set_Addr_To = aZI;
                            Inc_PC = 1;
                            LDW = 1;
                        end
                        3'd4: begin
                            Set_BusA_To[2:0] = 3'd5;
                            // L
                            Read_To_Reg = 1;
                            Inc_WZ = 1;
                            Set_Addr_To = aZI;
                        end
                        3'd5: begin
                            Set_BusA_To[2:0] = 3'd4;
                            // H
                            Read_To_Reg = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'h22: begin
                        // LD (nn),HL
                        MCycles_d = 3'd5;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            LDZ = 1;
                        end
                        3'd3: begin
                            Set_Addr_To = aZI;
                            Inc_PC = 1;
                            LDW = 1;
                            Set_BusB_To = 4'b0101;
                            // L
                        end
                        3'd4: begin
                            Inc_WZ = 1;
                            Set_Addr_To = aZI;
                            Write_i = 1;
                            Set_BusB_To = 4'b0100;
                            // H
                        end
                        3'd5: begin
                            Write_i = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'hf9: begin
                        // LD SP,HL
                        TStates = 3'd6;
                        LDSPHL = 1;
                    end
                    8'hc5,8'hd5,8'he5,8'hf5: begin
                        // PUSH qq
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd1: begin
                            TStates = 3'd5;
                            IncDec_16 = 4'b1111;
                            Set_Addr_To = aSP;
                            if (DPair == 2'b11) begin
                                Set_BusB_To = 4'b0111;
                            end
                            else begin
                                Set_BusB_To[2:1] = DPair;
                                Set_BusB_To[0] = 0;
                                Set_BusB_To[3] = 0;
                            end
                        end
                        3'd2: begin
                            IncDec_16 = 4'b1111;
                            Set_Addr_To = aSP;
                            if (DPair == 2'b11) begin
                                Set_BusB_To = 4'b1011;
                            end
                            else begin
                                Set_BusB_To[2:1] = DPair;
                                Set_BusB_To[0] = 1;
                                Set_BusB_To[3] = 0;
                            end
                            Write_i = 1;
                        end
                        3'd3: begin
                            Write_i = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'hc1,8'hd1,8'he1,8'hf1: begin
                        // POP qq
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd1: begin
                            Set_Addr_To = aSP;
                        end
                        3'd2: begin
                            IncDec_16 = 4'b0111;
                            Set_Addr_To = aSP;
                            Read_To_Reg = 1;
                            if (DPair == 2'b11) begin
                                Set_BusA_To[3:0] = 4'b1011;
                            end
                            else begin
                                Set_BusA_To[2:1] = DPair;
                                Set_BusA_To[0] = 1;
                            end
                        end
                        3'd3: begin
                            IncDec_16 = 4'b0111;
                            Read_To_Reg = 1;
                            if (DPair == 2'b11) begin
                                Set_BusA_To[3:0] = 4'b0111;
                            end
                            else begin
                                Set_BusA_To[2:1] = DPair;
                                Set_BusA_To[0] = 0;
                            end
                        end
                        default: begin end
                        endcase
                        // EXCHANGE, BLOCK TRANSFER AND SEARCH GROUP
                    end
                    8'heb: begin
                        // EX DE,HL
                        ExchangeDH = 1;
                    end
                    8'h08: begin
                        // EX AF,AF'
                        ExchangeAF = 1;
                    end
                    8'hd9: begin
                        // EXX
                        ExchangeRS = 1;
                    end
                    8'he3: begin
                        // EX (SP),HL
                        MCycles_d = 3'd5;
                        case (MCycle)
                        3'd1: begin
                            Set_Addr_To = aSP;
                        end
                        3'd2: begin
                            Set_Addr_To = aSP;
                            LDZ = 1;
                            IncDec_16 = 4'b0111;
                            // SP = SP+1
                        end
                        3'd3: begin
                            TStates = 3'd4;
                            Set_BusB_To = 4'b0100;
                            Set_Addr_To = aSP;
                            LDW = 1;
                        end
                        3'd4: begin
                            Set_BusB_To = 4'b0101;
                            Write_i = 1;
                            IncDec_16 = 4'b1111;
                            // SP = SP-1
                            Set_Addr_To = aSP;
                        end
                        3'd5: begin
                            ExchangeWH = 1;
                            // save WZ to HL
                            TStates = 3'd5;
                            Write_i = 1;
                        end
                        default: begin end
                        endcase
                        // 8 BIT ARITHMETIC AND LOGICAL GROUP
                    end
                    8'h80,8'h81,8'h82,8'h83,8'h84,8'h85,8'h87,8'h88,8'h89,8'h8a,8'h8b,8'h8c,8'h8d,8'h8f,8'h90,8'h91,8'h92,8'h93,8'h94,8'h95,8'h97,8'h98,8'h99,8'h9a,8'h9b,8'h9c,8'h9d,8'h9f,8'ha0,8'ha1,8'ha2,8'ha3,8'ha4,8'ha5,8'ha7,8'ha8,8'ha9,8'haa,8'hab,8'hac,8'had,8'haf,8'hb0,8'hb1,8'hb2,8'hb3,8'hb4,8'hb5,8'hb7,8'hb8,8'hb9,8'hba,8'hbb,8'hbc,8'hbd,8'hbf: begin
                        // ADD A,r
                        // ADC A,r
                        // SUB A,r
                        // SBC A,r
                        // AND A,r
                        // OR A,r
                        // XOR A,r
                        // CP A,r
                        Set_BusB_To[2:0] = SSS;
                        Set_BusA_To[2:0] = 3'd7;
                        Read_To_Reg = 1;
                        Save_ALU = 1;
                    end
                    8'h86,8'h8e,8'h96,8'h9e,8'ha6,8'hae,8'hb6,8'hbe: begin
                        // ADD A,(HL)
                        // ADC A,(HL)
                        // SUB A,(HL)
                        // SBC A,(HL)
                        // AND A,(HL)
                        // OR A,(HL)
                        // XOR A,(HL)
                        // CP A,(HL)
                        MCycles_d = 3'd2;
                        case (MCycle)
                        3'd1: begin
                            Set_Addr_To = aXY;
                        end
                        3'd2: begin
                            Read_To_Reg = 1;
                            Save_ALU = 1;
                            Set_BusB_To[2:0] = SSS;
                            Set_BusA_To[2:0] = 3'd7;
                        end
                        default: begin end
                        endcase
                    end
                    8'hc6,8'hce,8'hd6,8'hde,8'he6,8'hee,8'hf6,8'hfe: begin
                        // ADD A,n
                        // ADC A,n
                        // SUB A,n
                        // SBC A,n
                        // AND A,n
                        // OR A,n
                        // XOR A,n
                        // CP A,n
                        MCycles_d = 3'd2;
                        if (MCycle == 3'd2) begin
                            Inc_PC = 1;
                            Read_To_Reg = 1;
                            Save_ALU = 1;
                            Set_BusB_To[2:0] = SSS;
                            Set_BusA_To[2:0] = 3'd7;
                        end
                    end
                    8'h04,8'h0c,8'h14,8'h1c,8'h24,8'h2c,8'h3c: begin
                        // INC r
                        Set_BusB_To = 4'b1010;
                        Set_BusA_To[2:0] = DDD;
                        Read_To_Reg = 1;
                        Save_ALU = 1;
                        PreserveC = 1;
                        ALU_Op = 4'b0000;
                    end
                    8'h34: begin
                        // INC (HL)
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd1: begin
                            Set_Addr_To = aXY;
                        end
                        3'd2: begin
                            TStates = 3'd4;
                            Set_Addr_To = aXY;
                            Read_To_Reg = 1;
                            Save_ALU = 1;
                            PreserveC = 1;
                            ALU_Op = 4'b0000;
                            Set_BusB_To = 4'b1010;
                            Set_BusA_To[2:0] = DDD;
                        end
                        3'd3: begin
                            Write_i = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'h05,8'h0d,8'h15,8'h1d,8'h25,8'h2d,8'h3d: begin
                        // DEC r
                        Set_BusB_To = 4'b1010;
                        Set_BusA_To[2:0] = DDD;
                        Read_To_Reg = 1;
                        Save_ALU = 1;
                        PreserveC = 1;
                        ALU_Op = 4'b0010;
                    end
                    8'h35: begin
                        // DEC (HL)
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd1: begin
                            Set_Addr_To = aXY;
                        end
                        3'd2: begin
                            TStates = 3'd4;
                            Set_Addr_To = aXY;
                            ALU_Op = 4'b0010;
                            Read_To_Reg = 1;
                            Save_ALU = 1;
                            PreserveC = 1;
                            Set_BusB_To = 4'b1010;
                            Set_BusA_To[2:0] = DDD;
                        end
                        3'd3: begin
                            Write_i = 1;
                        end
                        default: begin end
                        endcase
                        // GENERAL PURPOSE ARITHMETIC AND CPU CONTROL GROUPS
                    end
                    8'h27: begin
                        // DAA
                        Set_BusA_To[2:0] = 3'd7;
                        Read_To_Reg = 1;
                        ALU_Op = 4'b1100;
                        Save_ALU = 1;
                    end
                    8'h2f: begin
                        // CPL
                        I_CPL = 1;
                    end
                    8'h3f: begin
                        // CCF
                        I_CCF = 1;
                    end
                    8'h37: begin
                        // SCF
                        I_SCF = 1;
                    end
                    8'h00: begin
                        if (NMICycle) begin
                            // NMI
                            MCycles_d = 3'd3;
                            case (MCycle)
                            3'd1: begin
                                TStates = 3'd5;
                                IncDec_16 = 4'b1111;
                                Set_Addr_To = aSP;
                                Set_BusB_To = 4'b1101;
                            end
                            3'd2: begin
                                Write_i = 1;
                                IncDec_16 = 4'b1111;
                                Set_Addr_To = aSP;
                                Set_BusB_To = 4'b1100;
                            end
                            3'd3: begin
                                Write_i = 1;
                            end
                            default: begin end
                            endcase
                        end
                        else if (IntCycle_i) begin
                            // INT (IM 2)
                            MCycles_d = 3'd5;
                            case (MCycle)
                            3'd1: begin
                                TStates = 3'd5;
                                IncDec_16 = 4'b1111;
                                Set_Addr_To = aSP;
                                Set_BusB_To = 4'b1101;
                            end
                            3'd2: begin
                                //TStates = "100";
                                Write_i = 1;
                                IncDec_16 = 4'b1111;
                                Set_Addr_To = aSP;
                                Set_BusB_To = 4'b1100;
                            end
                            3'd3: begin
                                //TStates = "100";
                                Write_i = 1;
                            end
                            3'd4: begin
                                Inc_PC = 1;
                                LDZ = 1;
                            end
                            3'd5: begin
                                Jump = 1;
                            end
                            default: begin end
                            endcase
                        end
                        else begin
                            // NOP
                        end
                    end
                    8'h76: begin
                        // HALT
                        Halt = 1;
                    end
                    8'hf3: begin
                        // DI
                        SetDI = 1;
                    end
                    8'hfb: begin
                        // EI
                        SetEI = 1;
                        // 16 BIT ARITHMETIC GROUP
                    end
                    8'h09,8'h19,8'h29,8'h39: begin
                        // ADD HL,ss
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd1: begin
                            No_PC = 1;
                        end
                        3'd2: begin
                            NoRead_i = 1;
                            ALU_Op = 4'b0000;
                            Read_To_Reg = 1;
                            Save_ALU = 1;
                            Set_BusA_To[2:0] = 3'd5;
                            case (IR[5:4])
                            2'b00,2'b01,2'b10: begin
                                Set_BusB_To[2:1] = IR[5:4];
                                Set_BusB_To[0] = 1;
                            end
                            default: begin
                                Set_BusB_To = 4'b1000;
                            end
                            endcase
                            TStates = 3'd4;
                            Arith16 = 1;
                            SetWZ = 2'b11;
                            No_PC = 1;
                        end
                        3'd3: begin
                            NoRead_i = 1;
                            Read_To_Reg = 1;
                            Save_ALU = 1;
                            ALU_Op = 4'b0001;
                            Set_BusA_To[2:0] = 3'd4;
                            case (IR[5:4])
                            2'b00,2'b01,2'b10: begin
                                Set_BusB_To[2:1] = IR[5:4];
                            end
                            default: begin
                                Set_BusB_To = 4'b1001;
                            end
                            endcase
                            Arith16 = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'h03,8'h13,8'h23,8'h33: begin
                        // INC ss
                        TStates = 3'd6;
                        IncDec_16[3:2] = 2'b01;
                        IncDec_16[1:0] = DPair;
                    end
                    8'h0b,8'h1b,8'h2b,8'h3b: begin
                        // DEC ss
                        TStates = 3'd6;
                        IncDec_16[3:2] = 2'b11;
                        IncDec_16[1:0] = DPair;
                        // ROTATE AND SHIFT GROUP
                        // RLCA|RLA|RRCA|RRA
                    end
                    8'h07,8'h17,8'h0f,8'h1f: begin
                        Set_BusA_To[2:0] = 3'd7;
                        ALU_Op = 4'b1000;
                        Read_To_Reg = 1;
                        Save_ALU = 1;
                        // JUMP GROUP
                    end
                    8'hc3: begin
                        // JP nn
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            LDZ = 1;
                        end
                        3'd3: begin
                            Inc_PC = 1;
                            Jump = 1;
                            LDW = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'hc2,8'hca,8'hd2,8'hda,8'he2,8'hea,8'hf2,8'hfa: begin
                        // JP cc,nn
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            LDZ = 1;
                        end
                        3'd3: begin
                            LDW = 1;
                            Inc_PC = 1;
                            if (cc_is_true) begin
                                Jump = 1;
                            end
                        end
                        default: begin end
                        endcase
                    end
                    8'h18: begin
                        // JR e
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            No_PC = 1;
                        end
                        3'd3: begin
                            NoRead_i = 1;
                            JumpE = 1;
                            TStates = 3'd5;
                        end
                        default: begin end
                        endcase
                    end
                    8'h38: begin
                        // JR C,e
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            if (!F[Flag_C]) begin
                                MCycles_d = 3'd2;
                            end
                            else begin
                                No_PC = 1;
                            end
                        end
                        3'd3: begin
                            NoRead_i = 1;
                            JumpE = 1;
                            TStates = 3'd5;
                        end
                        default: begin end
                        endcase
                    end
                    8'h30: begin
                        // JR NC,e
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            if (F[Flag_C]) begin
                                MCycles_d = 3'd2;
                            end
                            else begin
                                No_PC = 1;
                            end
                        end
                        3'd3: begin
                            NoRead_i = 1;
                            JumpE = 1;
                            TStates = 3'd5;
                        end
                        default: begin end
                        endcase
                    end
                    8'h28: begin
                        // JR Z,e
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            if (!F[Flag_Z]) begin
                                MCycles_d = 3'd2;
                            end
                            else begin
                                No_PC = 1;
                            end
                        end
                        3'd3: begin
                            NoRead_i = 1;
                            JumpE = 1;
                            TStates = 3'd5;
                        end
                        default: begin end
                        endcase
                    end
                    8'h20: begin
                        // JR NZ,e
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            if (F[Flag_Z]) begin
                                MCycles_d = 3'd2;
                            end
                            else begin
                                No_PC = 1;
                            end
                        end
                        3'd3: begin
                            NoRead_i = 1;
                            JumpE = 1;
                            TStates = 3'd5;
                        end
                        default: begin end
                        endcase
                    end
                    8'he9: begin
                        // JP (HL)
                        JumpXY = 1;
                    end
                    8'h10: begin
                        // DJNZ,e
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd1: begin
                            TStates = 3'd5;
                            I_DJNZ = 1;
                            Set_BusB_To = 4'b1010;
                            Set_BusA_To[2:0] = 3'd0;
                            Read_To_Reg = 1;
                            Save_ALU = 1;
                            ALU_Op = 4'b0010;
                        end
                        3'd2: begin
                            I_DJNZ = 1;
                            Inc_PC = 1;
                            No_PC = 1;
                        end
                        3'd3: begin
                            NoRead_i = 1;
                            JumpE = 1;
                            TStates = 3'd5;
                        end
                        default: begin end
                        endcase
                        // CALL AND RETURN GROUP
                    end
                    8'hcd: begin
                        // CALL nn
                        MCycles_d = 3'd5;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            LDZ = 1;
                        end
                        3'd3: begin
                            IncDec_16 = 4'b1111;
                            Inc_PC = 1;
                            TStates = 3'd4;
                            Set_Addr_To = aSP;
                            LDW = 1;
                            Set_BusB_To = 4'b1101;
                        end
                        3'd4: begin
                            Write_i = 1;
                            IncDec_16 = 4'b1111;
                            Set_Addr_To = aSP;
                            Set_BusB_To = 4'b1100;
                        end
                        3'd5: begin
                            Write_i = 1;
                            Call = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'hc4,8'hcc,8'hd4,8'hdc,8'he4,8'hec,8'hf4,8'hfc: begin
                        // CALL cc,nn
                        MCycles_d = 3'd5;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            LDZ = 1;
                        end
                        3'd3: begin
                            Inc_PC = 1;
                            LDW = 1;
                            if (cc_is_true) begin
                                IncDec_16 = 4'b1111;
                                Set_Addr_To = aSP;
                                TStates = 3'd4;
                                Set_BusB_To = 4'b1101;
                            end
                            else begin
                                MCycles_d = 3'd3;
                            end
                        end
                        3'd4: begin
                            Write_i = 1;
                            IncDec_16 = 4'b1111;
                            Set_Addr_To = aSP;
                            Set_BusB_To = 4'b1100;
                        end
                        3'd5: begin
                            Write_i = 1;
                            Call = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'hc9: begin
                        // RET
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd1: begin
                            //TStates = "101";
                            Set_Addr_To = aSP;
                        end
                        3'd2: begin
                            IncDec_16 = 4'b0111;
                            Set_Addr_To = aSP;
                            LDZ = 1;
                        end
                        3'd3: begin
                            Jump = 1;
                            IncDec_16 = 4'b0111;
                        end
                        default: begin end
                        endcase
                    end
                    8'hc0,8'hc8,8'hd0,8'hd8,8'he0,8'he8,8'hf0,8'hf8: begin
                        // RET cc
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd1: begin
                            if (cc_is_true) begin
                                Set_Addr_To = aSP;
                            end
                            else begin
                                MCycles_d = 3'd1;
                            end
                            TStates = 3'd5;
                        end
                        3'd2: begin
                            IncDec_16 = 4'b0111;
                            Set_Addr_To = aSP;
                            LDZ = 1;
                        end
                        3'd3: begin
                            Jump = 1;
                            IncDec_16 = 4'b0111;
                        end
                        default: begin end
                        endcase
                    end
                    8'hc7,8'hcf,8'hd7,8'hdf,8'he7,8'hef,8'hf7,8'hff: begin
                        // RST p
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd1: begin
                            TStates = 3'd5;
                            IncDec_16 = 4'b1111;
                            Set_Addr_To = aSP;
                            Set_BusB_To = 4'b1101;
                        end
                        3'd2: begin
                            Write_i = 1;
                            IncDec_16 = 4'b1111;
                            Set_Addr_To = aSP;
                            Set_BusB_To = 4'b1100;
                        end
                        3'd3: begin
                            Write_i = 1;
                            RstP = 1;
                        end
                        default: begin end
                        endcase
                        // INPUT AND OUTPUT GROUP
                    end
                    8'hdb: begin
                        // IN A,(n)
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            Set_Addr_To = aIOA;
                        end
                        3'd3: begin
                            Read_To_Acc = 1;
                            IORQ_i = 1;
                        end
                        default: begin end
                        endcase
                    end
                    8'hd3: begin
                        // OUT (n),A
                        MCycles_d = 3'd3;
                        case (MCycle)
                        3'd2: begin
                            Inc_PC = 1;
                            Set_Addr_To = aIOA;
                            Set_BusB_To = 4'b0111;
                        end
                        3'd3: begin
                            Write_i = 1;
                            IORQ_i = 1;
                        end
                        default: begin end
                        endcase
                        //----------------------------------------------------------------------------
                        //----------------------------------------------------------------------------
                        // MULTIBYTE INSTRUCTIONS
                        //----------------------------------------------------------------------------
                        //----------------------------------------------------------------------------
                    end
                    8'hcb: begin
                        Prefix = 2'b01;
                    end
                    8'hed: begin
                        Prefix = 2'b10;
                    end
                    8'hdd,8'hfd: begin
                        Prefix = 2'b11;
                    end
                    default: begin end
                endcase
            end

            //----------------------------------------------------------------
            // CB prefixed instructions
            //----------------------------------------------------------------
            2'b01: begin
                Set_BusA_To[2:0] = IR[2:0];
                Set_BusB_To[2:0] = IR[2:0];

                case (IR)
                    8'h00,8'h01,8'h02,8'h03,8'h04,8'h05,8'h07,          // RLC r
                    8'h08,8'h09,8'h0a,8'h0b,8'h0c,8'h0d,8'h0f,          // RRC r
                    8'h10,8'h11,8'h12,8'h13,8'h14,8'h15,8'h17,          // RL r
                    8'h18,8'h19,8'h1a,8'h1b,8'h1c,8'h1d,8'h1f,          // RR r
                    8'h20,8'h21,8'h22,8'h23,8'h24,8'h25,8'h27,          // SLA r
                    8'h28,8'h29,8'h2a,8'h2b,8'h2c,8'h2d,8'h2f,          // SRA r
                    8'h30,8'h31,8'h32,8'h33,8'h34,8'h35,8'h37,          // SLL r
                    8'h38,8'h39,8'h3a,8'h3b,8'h3c,8'h3d,8'h3f: begin    // SRL r
                    
                        if (XY_State == 2'b00) begin
                            if (MCycle == 3'd1) begin
                                ALU_Op      = 4'b1000;
                                Read_To_Reg = 1;
                                Save_ALU    = 1;
                            end

                        end else begin
                            // R/S (IX+d),Reg, undocumented
                            MCycles_d   = 3'd3;
                            XYbit_undoc = 1;
                            case (MCycle)
                                3'd1,3'd7: begin
                                    Set_Addr_To = aXY;
                                end
                                3'd2: begin
                                    ALU_Op      = 4'b1000;
                                    Read_To_Reg = 1;
                                    Save_ALU    = 1;
                                    Set_Addr_To = aXY;
                                    TStates     = 3'd4;
                                end
                                3'd3: begin
                                    Write_i = 1;
                                end
                                default: begin end
                            endcase
                        end
                    end

                    8'h06,8'h0e,        // RLC (HL)     RRC (HL)
                    8'h16,8'h1e,        // RL (HL)      RR (HL)
                    8'h26,8'h2e,        // SLA (HL)     SRA (HL)
                    8'h36,8'h3e: begin  // SLL (HL)     SRL (HL)
                        MCycles_d = 3'd3;
                        case (MCycle)
                            3'd1,3'd7: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                ALU_Op      = 4'b1000;
                                Read_To_Reg = 1;
                                Save_ALU    = 1;
                                Set_Addr_To = aXY;
                                TStates     = 3'd4;
                            end
                            3'd3: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'h40,8'h41,8'h42,8'h43,8'h44,8'h45,8'h47,
                    8'h48,8'h49,8'h4a,8'h4b,8'h4c,8'h4d,8'h4f,
                    8'h50,8'h51,8'h52,8'h53,8'h54,8'h55,8'h57,
                    8'h58,8'h59,8'h5a,8'h5b,8'h5c,8'h5d,8'h5f,
                    8'h60,8'h61,8'h62,8'h63,8'h64,8'h65,8'h67,
                    8'h68,8'h69,8'h6a,8'h6b,8'h6c,8'h6d,8'h6f,
                    8'h70,8'h71,8'h72,8'h73,8'h74,8'h75,8'h77,
                    8'h78,8'h79,8'h7a,8'h7b,8'h7c,8'h7d,8'h7f: begin
                        if (XY_State == 2'b00) begin
                            // BIT b,r
                            if (MCycle == 3'd1) begin
                                Set_BusB_To[2:0] = IR[2:0];
                                ALU_Op           = 4'b1001;
                            end

                        end else begin
                            // BIT b,(IX+d), undocumented
                            MCycles_d   = 3'd2;
                            XYbit_undoc = 1;
                            case (MCycle)
                                3'd1,3'd7: begin
                                    Set_Addr_To = aXY;
                                end
                                3'd2: begin
                                    ALU_Op  = 4'b1001;
                                    TStates = 3'd4;
                                end
                                default: begin end
                            endcase
                        end
                    end

                    8'h46,8'h4e,8'h56,8'h5e,8'h66,8'h6e,8'h76,8'h7e: begin
                        // BIT b,(HL)
                        MCycles_d = 3'd2;
                        case (MCycle)
                            3'd1,3'd7: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                ALU_Op  = 4'b1001;
                                TStates = 3'd4;
                            end
                            default: begin end
                        endcase
                    end

                    8'hc0,8'hc1,8'hc2,8'hc3,8'hc4,8'hc5,8'hc7,
                    8'hc8,8'hc9,8'hca,8'hcb,8'hcc,8'hcd,8'hcf,
                    8'hd0,8'hd1,8'hd2,8'hd3,8'hd4,8'hd5,8'hd7,
                    8'hd8,8'hd9,8'hda,8'hdb,8'hdc,8'hdd,8'hdf,
                    8'he0,8'he1,8'he2,8'he3,8'he4,8'he5,8'he7,
                    8'he8,8'he9,8'hea,8'heb,8'hec,8'hed,8'hef,
                    8'hf0,8'hf1,8'hf2,8'hf3,8'hf4,8'hf5,8'hf7,
                    8'hf8,8'hf9,8'hfa,8'hfb,8'hfc,8'hfd,8'hff: begin
                        // SET b,r
                        if (XY_State == 2'b00) begin
                            if (MCycle == 3'd1) begin
                                ALU_Op      = 4'b1010;
                                Read_To_Reg = 1;
                                Save_ALU    = 1;
                            end

                        end else begin
                            // SET b,(IX+d),Reg, undocumented
                            MCycles_d = 3'd3;
                            XYbit_undoc = 1;
                            case (MCycle)
                                3'd1,3'd7: begin
                                    Set_Addr_To = aXY;
                                end
                                3'd2: begin
                                    ALU_Op      = 4'b1010;
                                    Read_To_Reg = 1;
                                    Save_ALU    = 1;
                                    Set_Addr_To = aXY;
                                    TStates     = 3'd4;
                                end
                                3'd3: begin
                                    Write_i = 1;
                                end
                                default: begin end
                            endcase
                        end
                    end

                    8'hc6,8'hce,8'hd6,8'hde,8'he6,8'hee,8'hf6,8'hfe: begin
                        // SET b,(HL)
                        MCycles_d = 3'd3;
                        case (MCycle)
                            3'd1,3'd7: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                ALU_Op      = 4'b1010;
                                Read_To_Reg = 1;
                                Save_ALU    = 1;
                                Set_Addr_To = aXY;
                                TStates     = 3'd4;
                            end
                            3'd3: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'h80,8'h81,8'h82,8'h83,8'h84,8'h85,8'h87,
                    8'h88,8'h89,8'h8a,8'h8b,8'h8c,8'h8d,8'h8f,
                    8'h90,8'h91,8'h92,8'h93,8'h94,8'h95,8'h97,
                    8'h98,8'h99,8'h9a,8'h9b,8'h9c,8'h9d,8'h9f,
                    8'ha0,8'ha1,8'ha2,8'ha3,8'ha4,8'ha5,8'ha7,
                    8'ha8,8'ha9,8'haa,8'hab,8'hac,8'had,8'haf,
                    8'hb0,8'hb1,8'hb2,8'hb3,8'hb4,8'hb5,8'hb7,
                    8'hb8,8'hb9,8'hba,8'hbb,8'hbc,8'hbd,8'hbf: begin
                        // RES b,r
                        if (XY_State == 2'b00) begin
                            if (MCycle == 3'd1) begin
                                ALU_Op      = 4'b1011;
                                Read_To_Reg = 1;
                                Save_ALU    = 1;
                            end
                        end else begin
                            // RES b,(IX+d),Reg, undocumented
                            MCycles_d   = 3'd3;
                            XYbit_undoc = 1;
                            case (MCycle)
                                3'd1,3'd7: begin
                                    Set_Addr_To = aXY;
                                end
                                3'd2: begin
                                    ALU_Op      = 4'b1011;
                                    Read_To_Reg = 1;
                                    Save_ALU    = 1;
                                    Set_Addr_To = aXY;
                                    TStates     = 3'd4;
                                end
                                3'd3: begin
                                    Write_i = 1;
                                end
                                default: begin end
                            endcase
                        end
                    end

                    8'h86,8'h8e,8'h96,8'h9e,8'ha6,8'hae,8'hb6,8'hbe: begin
                        // RES b,(HL)
                        MCycles_d = 3'd3;
                        case (MCycle)
                            3'd1,3'd7: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                ALU_Op      = 4'b1011;
                                Read_To_Reg = 1;
                                Save_ALU    = 1;
                                Set_Addr_To = aXY;
                                TStates     = 3'd4;
                            end
                            3'd3: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end

                    default: begin end
                endcase
            end

            //----------------------------------------------------------------
            // ED prefixed instructions
            //----------------------------------------------------------------
            default: begin
                case (IR)
                    8'h00,8'h01,8'h02,8'h03,8'h04,8'h05,8'h06,8'h07,
                    8'h08,8'h09,8'h0a,8'h0b,8'h0c,8'h0d,8'h0e,8'h0f,
                    8'h10,8'h11,8'h12,8'h13,8'h14,8'h15,8'h16,8'h17,
                    8'h18,8'h19,8'h1a,8'h1b,8'h1c,8'h1d,8'h1e,8'h1f,
                    8'h20,8'h21,8'h22,8'h23,8'h24,8'h25,8'h26,8'h27,
                    8'h28,8'h29,8'h2a,8'h2b,8'h2c,8'h2d,8'h2e,8'h2f,
                    8'h30,8'h31,8'h32,8'h33,8'h34,8'h35,8'h36,8'h37,
                    8'h38,8'h39,8'h3a,8'h3b,8'h3c,8'h3d,8'h3e,8'h3f,
                    8'h80,8'h81,8'h82,8'h83,8'h84,8'h85,8'h86,8'h87,
                    8'h88,8'h89,8'h8a,8'h8b,8'h8c,8'h8d,8'h8e,8'h8f,
                    8'h90,8'h91,8'h92,8'h93,8'h94,8'h95,8'h96,8'h97,
                    8'h98,8'h99,8'h9a,8'h9b,8'h9c,8'h9d,8'h9e,8'h9f,
                                            8'ha4,8'ha5,8'ha6,8'ha7,
                                            8'hac,8'had,8'hae,8'haf,
                                            8'hb4,8'hb5,8'hb6,8'hb7,
                                            8'hbc,8'hbd,8'hbe,8'hbf,
                    8'hc0,      8'hc2,      8'hc4,8'hc5,8'hc6,8'hc7,
                    8'hc8,      8'hca,8'hcb,8'hcc,8'hcd,8'hce,8'hcf,
                    8'hd0,      8'hd2,8'hd3,8'hd4,8'hd5,8'hd6,8'hd7,
                    8'hd8,      8'hda,8'hdb,8'hdc,8'hdd,8'hde,8'hdf,
                    8'he0,8'he1,8'he2,8'he3,8'he4,8'he5,8'he6,8'he7,
                    8'he8,8'he9,8'hea,8'heb,8'hec,8'hed,8'hee,8'hef,
                    8'hf0,8'hf1,8'hf2,      8'hf4,8'hf5,8'hf6,8'hf7,
                    8'hf8,8'hf9,8'hfa,8'hfb,8'hfc,8'hfd,8'hfe,8'hff: begin
                        // NOP, undocumented
                    end

                    8'h77,8'h7f: begin
                        // NOP, undocumented
                        // 8 BIT LOAD GROUP
                    end

                    8'h57: begin
                        // LD A,I
                        Special_LD = 3'd4;
                        TStates    = 3'd5;
                    end

                    8'h5f: begin
                        // LD A,R
                        Special_LD = 3'd5;
                        TStates    = 3'd5;
                    end

                    8'h47: begin
                        // LD I,A
                        Special_LD = 3'd6;
                        TStates    = 3'd5;
                    end

                    8'h4f: begin
                        // LD R,A
                        Special_LD = 3'd7;
                        TStates = 3'd5;
                        // 16 BIT LOAD GROUP
                    end

                    8'h4b,8'h5b,8'h6b,8'h7b: begin
                        // LD dd,(nn)
                        MCycles_d = 3'd5;
                        case (MCycle)
                            3'd2: begin
                                Inc_PC = 1;
                                LDZ    = 1;
                            end
                            3'd3: begin
                                Set_Addr_To = aZI;
                                Inc_PC      = 1;
                                LDW         = 1;
                            end
                            3'd4: begin
                                Read_To_Reg = 1;
                                if (IR[5:4] == 2'b11) begin
                                    Set_BusA_To = 4'b1000;
                                end else begin
                                    Set_BusA_To[2:1] = IR[5:4];
                                    Set_BusA_To[0]   = 1;
                                end
                                Inc_WZ      = 1;
                                Set_Addr_To = aZI;
                            end
                            3'd5: begin
                                Read_To_Reg = 1;
                                if (IR[5:4] == 2'b11) begin
                                    Set_BusA_To = 4'b1001;
                                end else begin
                                    Set_BusA_To[2:1] = IR[5:4];
                                    Set_BusA_To[0] = 0;
                                end
                            end
                            default: begin end
                        endcase
                    end

                    8'h43,8'h53,8'h63,8'h73: begin
                        // LD (nn),dd
                        MCycles_d = 3'd5;
                        case (MCycle)
                            3'd2: begin
                                Inc_PC = 1;
                                LDZ    = 1;
                            end
                            3'd3: begin
                                Set_Addr_To = aZI;
                                Inc_PC      = 1;
                                LDW         = 1;
                                if (IR[5:4] == 2'b11) begin
                                    Set_BusB_To = 4'b1000;
                                end else begin
                                    Set_BusB_To[2:1] = IR[5:4];
                                    Set_BusB_To[0]   = 1;
                                    Set_BusB_To[3]   = 0;
                                end
                            end
                            3'd4: begin
                                Inc_WZ      = 1;
                                Set_Addr_To = aZI;
                                Write_i     = 1;
                                if (IR[5:4] == 2'b11) begin
                                    Set_BusB_To = 4'b1001;
                                end else begin
                                    Set_BusB_To[2:1] = IR[5:4];
                                    Set_BusB_To[0]   = 0;
                                    Set_BusB_To[3]   = 0;
                                end
                            end
                            3'd5: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'ha0,8'ha8,8'hb0,8'hb8: begin
                        // LDI, LDD, LDIR, LDDR
                        MCycles_d = 3'd4;
                        case (MCycle)
                            3'd1: begin
                                Set_Addr_To = aXY;
                                IncDec_16   = 4'b1100;
                                // BC
                            end
                            3'd2: begin
                                Set_BusB_To      = 4'b0110;
                                Set_BusA_To[2:0] = 3'd7;
                                ALU_Op           = 4'b0000;
                                Set_Addr_To      = aDE;
                                if (!IR[3]) begin
                                    IncDec_16 = 4'b0110;
                                    // IX
                                end else begin
                                    IncDec_16 = 4'b1110;
                                end
                            end
                            3'd3: begin
                                I_BT    = 1;
                                TStates = 3'd5;
                                Write_i = 1;
                                if (!IR[3]) begin
                                    IncDec_16 = 4'b0101;
                                    // DE
                                end else begin
                                    IncDec_16 = 4'b1101;
                                end
                                No_PC = 1;
                            end
                            3'd4: begin
                                NoRead_i = 1;
                                TStates  = 3'd5;
                            end
                            default: begin end
                        endcase
                    end

                    8'ha1,8'ha9,8'hb1,8'hb9: begin
                        // CPI, CPD, CPIR, CPDR
                        MCycles_d = 3'd4;
                        case (MCycle)
                            3'd1: begin
                                Set_Addr_To = aXY;
                                IncDec_16   = 4'b1100;
                                // BC
                            end
                            3'd2: begin
                                Set_BusB_To      = 4'b0110;
                                Set_BusA_To[2:0] = 3'd7;
                                ALU_Op           = 4'b0111;
                                Save_ALU         = 1;
                                PreserveC        = 1;
                                if (!IR[3]) begin
                                    IncDec_16 = 4'b0110;
                                end
                                else begin
                                    IncDec_16 = 4'b1110;
                                end
                                No_PC = 1;
                            end
                            3'd3: begin
                                NoRead_i = 1;
                                I_BC     = 1;
                                TStates  = 3'd5;
                                No_PC    = 1;
                            end
                            3'd4: begin
                                NoRead_i = 1;
                                TStates  = 3'd5;
                            end
                            default: begin end
                        endcase
                    end

                    8'h44,8'h4c,8'h54,8'h5c,8'h64,8'h6c,8'h74,8'h7c: begin
                        // NEG
                        ALU_Op      = 4'b0010;
                        Set_BusB_To = 4'b0111;
                        Set_BusA_To = 4'b1010;
                        Read_To_Acc = 1;
                        Save_ALU    = 1;
                    end

                    8'h46,8'h4e,8'h66,8'h6e: begin
                        // IM 0
                        IMode = 2'b00;
                    end

                    8'h56,8'h76: begin
                        // IM 1
                        IMode = 2'b01;
                    end

                    8'h5e,8'h7e: begin
                        // IM 2
                        IMode = 2'b10;
                        // 16 bit arithmetic
                    end

                    8'h4a,8'h5a,8'h6a,8'h7a: begin
                        // ADC HL,ss
                        MCycles_d = 3'd3;
                        case (MCycle)
                            3'd1: begin
                                No_PC = 1;
                            end
                            3'd2: begin
                                NoRead_i         = 1;
                                ALU_Op           = 4'b0001;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                Set_BusA_To[2:0] = 3'd5;
                                case (IR[5:4])
                                    2'b00,2'b01,2'b10: begin
                                        Set_BusB_To[2:1] = IR[5:4];
                                        Set_BusB_To[0]   = 1;
                                    end
                                    default: begin
                                        Set_BusB_To = 4'b1000;
                                    end
                                endcase
                                TStates = 3'd4;
                                SetWZ   = 2'b11;
                                No_PC   = 1;
                            end
                            3'd3: begin
                                NoRead_i         = 1;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                ALU_Op           = 4'b0001;
                                Set_BusA_To[2:0] = 3'd4;
                                case (IR[5:4])
                                    2'b00,2'b01,2'b10: begin
                                        Set_BusB_To[2:1] = IR[5:4];
                                        Set_BusB_To[0]   = 0;
                                    end
                                    default: begin
                                        Set_BusB_To = 4'b1001;
                                    end
                                endcase
                            end
                            default: begin end
                        endcase
                    end

                    8'h42,8'h52,8'h62,8'h72: begin
                        // SBC HL,ss
                        MCycles_d = 3'd3;
                        case (MCycle)
                            3'd1: begin
                                No_PC = 1;
                            end
                            3'd2: begin
                                NoRead_i         = 1;
                                ALU_Op           = 4'b0011;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                Set_BusA_To[2:0] = 3'd5;
                                case (IR[5:4])
                                    2'b00,2'b01,2'b10: begin
                                        Set_BusB_To[2:1] = IR[5:4];
                                        Set_BusB_To[0]   = 1;
                                    end
                                    default: begin
                                        Set_BusB_To = 4'b1000;
                                    end
                                endcase
                                TStates = 3'd4;
                                SetWZ   = 2'b11;
                                No_PC   = 1;
                            end
                            3'd3: begin
                                NoRead_i         = 1;
                                ALU_Op           = 4'b0011;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                Set_BusA_To[2:0] = 3'd4;
                                case (IR[5:4])
                                    2'b00,2'b01,2'b10: begin
                                        Set_BusB_To[2:1] = IR[5:4];
                                    end
                                    default: begin
                                        Set_BusB_To = 4'b1001;
                                    end
                                endcase
                            end
                            default: begin end
                        endcase
                    end

                    8'h6f: begin
                        // RLD -- Read in M2, not M3! fixed by Sorgelig
                        MCycles_d = 3'd4;
                        case (MCycle)
                            3'd1: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                Read_To_Reg      = 1;
                                Set_BusB_To[2:0] = 3'd6;
                                Set_BusA_To[2:0] = 3'd7;
                                ALU_Op           = 4'b1101;
                                Save_ALU         = 1;
                                No_PC            = 1;
                            end
                            3'd3: begin
                                TStates     = 3'd4;
                                I_RLD       = 1;
                                NoRead_i    = 1;
                                Set_Addr_To = aXY;
                            end
                            3'd4: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'h67: begin
                        // RRD -- Read in M2, not M3! fixed by Sorgelig
                        MCycles_d = 3'd4;
                        case (MCycle)
                            3'd1: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                Read_To_Reg      = 1;
                                Set_BusB_To[2:0] = 3'd6;
                                Set_BusA_To[2:0] = 3'd7;
                                ALU_Op           = 4'b1110;
                                Save_ALU         = 1;
                                No_PC            = 1;
                            end
                            3'd3: begin
                                TStates     = 3'd4;
                                I_RRD       = 1;
                                NoRead_i    = 1;
                                Set_Addr_To = aXY;
                            end
                            3'd4: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'h45,8'h4d,8'h55,8'h5d,8'h65,8'h6d,8'h75,8'h7d: begin
                        // RETI/RETN
                        MCycles_d = 3'd3;
                        case (MCycle)
                            3'd1: begin
                                Set_Addr_To = aSP;
                            end
                            3'd2: begin
                                IncDec_16   = 4'b0111;
                                Set_Addr_To = aSP;
                                LDZ         = 1;
                            end
                            3'd3: begin
                                Jump      = 1;
                                IncDec_16 = 4'b0111;
                                LDW       = 1;
                                I_RETN    = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'h40,8'h48,8'h50,8'h58,8'h60,8'h68,8'h70,8'h78: begin
                        // IN r,(C)
                        MCycles_d = 3'd2;
                        case (MCycle)
                            3'd1: begin
                                Set_Addr_To = aBC;
                                SetWZ       = 2'b01;
                            end
                            3'd2: begin
                                IORQ_i = 1;
                                if (IR[5:3] != 3'd6) begin
                                    Read_To_Reg      = 1;
                                    Set_BusA_To[2:0] = IR[5:3];
                                end
                                I_INRC = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'h41,8'h49,8'h51,8'h59,8'h61,8'h69,8'h71,8'h79: begin
                        // OUT (C),r
                        // OUT (C),0
                        MCycles_d = 3'd2;

                        case (MCycle)
                            3'd1: begin
                                Set_Addr_To      = aBC;
                                SetWZ            = 2'b01;
                                Set_BusB_To[2:0] = IR[5:3];
                                if (IR[5:3] == 3'd6) begin
                                    Set_BusB_To[3] = 1;
                                end
                            end
                            3'd2: begin
                                Write_i = 1;
                                IORQ_i  = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'ha2,8'haa,8'hb2,8'hba: begin
                        // INI, IND, INIR, INDR
                        MCycles_d = 3'd4;
                        case (MCycle)
                            3'd1: begin
                                TStates      = 3'd5;
                                Set_Addr_To  = aBC;
                                Set_BusB_To  = 4'b1010;
                                Set_BusA_To  = 4'b0000;
                                Read_To_Reg  = 1;
                                Save_ALU     = 1;
                                ALU_Op       = 4'b0010;
                                SetWZ        = 2'b11;
                                IncDec_16[3] = IR[3];
                            end
                            3'd2: begin
                                IORQ_i      = 1;
                                Set_BusB_To = 4'b0110;
                                Set_Addr_To = aXY;
                            end
                            3'd3: begin
                                if (!IR[3]) begin
                                    IncDec_16 = 4'b0110;
                                end
                                else begin
                                    IncDec_16 = 4'b1110;
                                end
                                Write_i = 1;
                                I_BTR   = 1;
                            end
                            3'd4: begin
                                NoRead_i = 1;
                                TStates  = 3'd5;
                            end
                            default: begin end
                        endcase
                    end

                    8'ha3,8'hab,8'hb3,8'hbb: begin
                        // OUTI, OUTD, OTIR, OTDR
                        MCycles_d = 3'd4;
                        case (MCycle)
                            3'd1: begin
                                TStates     = 3'd5;
                                Set_Addr_To = aXY;
                                Set_BusB_To = 4'b1010;
                                Set_BusA_To = 4'b0000;
                                Read_To_Reg = 1;
                                Save_ALU    = 1;
                                ALU_Op      = 4'b0010;
                            end
                            3'd2: begin
                                Set_BusB_To  = 4'b0110;
                                Set_Addr_To  = aBC;
                                SetWZ        = 2'b11;
                                IncDec_16[3] = IR[3];
                            end
                            3'd3: begin
                                if (!IR[3]) begin
                                    IncDec_16 = 4'b0110;
                                end
                                else begin
                                    IncDec_16 = 4'b1110;
                                end
                                IORQ_i  = 1;
                                Write_i = 1;
                                I_BTR   = 1;
                            end
                            3'd4: begin
                                NoRead_i = 1;
                                TStates  = 3'd5;
                            end
                            default: begin end
                        endcase
                    end

                    8'hc1,8'hc9,8'hd1,8'hd9: begin end
                    8'hc3,8'hf3: begin end
                    default: begin end
                endcase
            end
        endcase

        if (Mode == 1) begin
            if (MCycle == 3'd1) begin
                //  TStates = "100";
            end else begin
                TStates = 3'd3;
            end
        end

        if (MCycle == 3'd6) begin
            Inc_PC = 1;
            if (Mode == 1) begin
                Set_Addr_To      = aXY;
                TStates          = 3'd4;
                Set_BusB_To[2:0] = SSS;
                Set_BusB_To[3]   = 0;
            end
            if (IR == 8'h36 || IR == 8'hcb) begin
                Set_Addr_To = aNone;
            end
            if (!(IR == 8'h36 || ISet == 2'b01)) begin
                No_PC = 1;
            end
        end

        if (MCycle == 3'd7) begin
            if (Mode == 0) begin
                TStates = 3'd5;
            end
            if (ISet != 2'b01) begin
                Set_Addr_To = aXY;
            end
            Set_BusB_To[2:0] = SSS;
            Set_BusB_To[3]   = 0;
            if (IR == 8'h36 || ISet == 2'b01) begin
                // LD (HL),n
                Inc_PC = 1;
            end else begin
                NoRead_i = 1;
            end
        end
    end

    //------------------------------------------------------------------------
    // ALU
    //------------------------------------------------------------------------
    reg [7:0] alu_bitmask;
    always @* case (IR[5:3])
        3'd0:  alu_bitmask = 8'h01;
        3'd1:  alu_bitmask = 8'h02;
        3'd2:  alu_bitmask = 8'h04;
        3'd3:  alu_bitmask = 8'h08;
        3'd4:  alu_bitmask = 8'h10;
        3'd5:  alu_bitmask = 8'h20;
        3'd6:  alu_bitmask = 8'h40;
        default: alu_bitmask = 8'h80;
    endcase

    wire       alu_do_sub        = ALU_Op_r[1];
    wire       alu_cin           = (alu_do_sub ^ ((!ALU_Op_r[2] & ALU_Op_r[0]) & F[Flag_C]));
    wire [5:0] alu_addsub_l      = {1'b0, BusA[3:0], alu_cin}         + {1'b0, (alu_do_sub ? ~BusB[3:0] : BusB[3:0]), 1'b1};
    wire [4:0] addsub_m          = {1'b0, BusA[6:4], alu_addsub_l[5]} + {1'b0, (alu_do_sub ? ~BusB[6:4] : BusB[6:4]), 1'b1};
    wire [2:0] addsub_h          = {1'b0, BusA[7],   addsub_m[4]}     + {1'b0, (alu_do_sub ? ~BusB[7]   : BusB[7]),   1'b1};
    wire       alu_half_carry    = alu_addsub_l[5];
    wire       alu_carry7        = addsub_m[4];
    wire       alu_carry         = addsub_h[2];
    wire [7:0] alu_addsub_result = {addsub_h[1], addsub_m[3:1], alu_addsub_l[4:1]};
    wire       alu_overflow      = alu_carry ^ alu_carry7;
    reg  [7:0] alu_result;
    reg  [8:0] alu_daa_tmp;

    always @* begin
        alu_result  = 0;
        F_Out       = F;
        alu_daa_tmp = 0;

        case (ALU_Op_r)
            4'b0000, 4'b0001, 4'b0010, 4'b0011, 4'b0100, 4'b0101, 4'b0110, 4'b0111: begin
                F_Out[Flag_N] = 0;
                F_Out[Flag_C] = 0;

                case (ALU_Op_r[2:0])
                    3'd0, 3'd1: begin           // ADD, ADC
                        alu_result    = alu_addsub_result;
                        F_Out[Flag_C] = alu_carry;
                        F_Out[Flag_H] = alu_half_carry;
                        F_Out[Flag_P] = alu_overflow;
                    end

                    3'd2, 3'd3, 3'd7: begin     // SUB, SBC, CP
                        alu_result    = alu_addsub_result;
                        F_Out[Flag_N] = 1;
                        F_Out[Flag_C] = !alu_carry;
                        F_Out[Flag_H] = !alu_half_carry;
                        F_Out[Flag_P] = alu_overflow;
                    end

                    3'd4:    begin alu_result = BusA & BusB; F_Out[Flag_H] = 1; end // AND
                    3'd5:    begin alu_result = BusA ^ BusB; F_Out[Flag_H] = 0; end // XOR
                    default: begin alu_result = BusA | BusB; F_Out[Flag_H] = 0; end // OR (110)
                endcase

                if (ALU_Op_r[2:0] == 3'd7) begin    // CP
                    F_Out[Flag_X] = BusB[3];
                    F_Out[Flag_Y] = BusB[5];
                end else begin
                    F_Out[Flag_X] = alu_result[3];
                    F_Out[Flag_Y] = alu_result[5];
                end

                F_Out[Flag_Z] = Z16_r ? F[Flag_Z] : (alu_result == 8'b0);
                F_Out[Flag_S] = alu_result[7];

                case (ALU_Op_r[2:0])
                    3'd0, 3'd1, 3'd2, 3'd3, 3'd7: begin   // ADD, ADC, SUB, SBC, CP
                    end
                    default: begin
                        F_Out[Flag_P] = !(alu_result[0] ^ alu_result[1] ^ alu_result[2] ^ alu_result[3] ^ alu_result[4] ^ alu_result[5] ^ alu_result[6] ^ alu_result[7]);
                    end
                endcase

                if (Arith16_r) begin
                    F_Out[Flag_S] = F[Flag_S];
                    F_Out[Flag_Z] = F[Flag_Z];
                    F_Out[Flag_P] = F[Flag_P];
                end
            end

            4'b1100: begin  // DAA
                F_Out[Flag_H] = F[Flag_H];
                F_Out[Flag_C] = F[Flag_C];
                alu_daa_tmp   = {1'b0, BusA};

                if (!F[Flag_N]) begin
                    // After addition
                    // A_low > 9 or H = 1
                    if (alu_daa_tmp[3:0] > 4'd9 || F[Flag_H]) begin
                        F_Out[Flag_H] = (alu_daa_tmp[3:0] > 4'd9);
                        alu_daa_tmp   = alu_daa_tmp + 9'd6;
                    end

                    // new A_high > 9 or C = 1
                    if (alu_daa_tmp[8:4] > 5'd9 || F[Flag_C])
                        alu_daa_tmp = alu_daa_tmp + 9'h60;

                end else begin
                    // After subtraction
                    if (alu_daa_tmp[3:0] > 4'd9 || F[Flag_H]) begin
                        if (alu_daa_tmp[3:0] > 4'd5)
                            F_Out[Flag_H] = 0;

                        alu_daa_tmp[7:0] = alu_daa_tmp[7:0] - 8'd6;
                    end

                    if (BusA > 8'd153 || F[Flag_C])
                        alu_daa_tmp = alu_daa_tmp - 9'h160;
                end

                alu_result    = alu_daa_tmp[7:0];
                F_Out[Flag_X] = alu_daa_tmp[3];
                F_Out[Flag_Y] = alu_daa_tmp[5];
                F_Out[Flag_C] = F[Flag_C] | alu_daa_tmp[8];
                F_Out[Flag_Z] = (alu_daa_tmp[7:0] == 8'b0);
                F_Out[Flag_S] = alu_daa_tmp[7];
                F_Out[Flag_P] = !(alu_daa_tmp[0] ^ alu_daa_tmp[1] ^ alu_daa_tmp[2] ^ alu_daa_tmp[3] ^ alu_daa_tmp[4] ^ alu_daa_tmp[5] ^ alu_daa_tmp[6] ^ alu_daa_tmp[7]);
            end

            4'b1101, 4'b1110: begin     // RLD, RRD
                alu_result    = {BusA[7:4], ALU_Op_r[0] ? BusB[7:4] : BusB[3:0]};
                F_Out[Flag_H] = 0;
                F_Out[Flag_N] = 0;
                F_Out[Flag_X] = alu_result[3];
                F_Out[Flag_Y] = alu_result[5];
                F_Out[Flag_Z] = (alu_result == 8'b0);
                F_Out[Flag_S] = alu_result[7];
                F_Out[Flag_P] = !(alu_result[0] ^ alu_result[1] ^ alu_result[2] ^ alu_result[3] ^ alu_result[4] ^ alu_result[5] ^ alu_result[6] ^ alu_result[7]);
            end

            4'b1001: begin      // BIT
                alu_result    = BusB & alu_bitmask;
                F_Out[Flag_S] = alu_result[7];
                F_Out[Flag_Z] = (alu_result == 8'b0);
                F_Out[Flag_P] = (alu_result == 8'b0);
                F_Out[Flag_H] = 1;
                F_Out[Flag_N] = 0;
                if (IR[2:0] == 3'd6 || XY_State != 2'b00) begin
                    F_Out[Flag_X] = WZ[11];
                    F_Out[Flag_Y] = WZ[13];
                end else begin
                    F_Out[Flag_X] = BusB[3];
                    F_Out[Flag_Y] = BusB[5];
                end
            end

            4'b1010: begin      // SET
                alu_result = BusB | alu_bitmask;
            end

            4'b1011: begin      // RES
                alu_result = BusB & ~alu_bitmask;
            end

            4'b1000: begin      // ROT
                case (IR[5:3])
                    3'd0:    begin alu_result = {BusA[6:0], BusA[7]};   F_Out[Flag_C] = BusA[7]; end // RLC
                    3'd2:    begin alu_result = {BusA[6:0], F[Flag_C]}; F_Out[Flag_C] = BusA[7]; end // RL
                    3'd1:    begin alu_result = {BusA[0],   BusA[7:1]}; F_Out[Flag_C] = BusA[0]; end // RRC
                    3'd3:    begin alu_result = {F[Flag_C], BusA[7:1]}; F_Out[Flag_C] = BusA[0]; end // RR
                    3'd4:    begin alu_result = {BusA[6:0], 1'b0};      F_Out[Flag_C] = BusA[7]; end // SLA
                    3'd6:    begin alu_result = {BusA[6:0], 1'b1};      F_Out[Flag_C] = BusA[7]; end // SLL (Undocumented) / SWAP
                    3'd5:    begin alu_result = {BusA[7],   BusA[7:1]}; F_Out[Flag_C] = BusA[0]; end // SRA
                    default: begin alu_result = {1'b0,      BusA[7:1]}; F_Out[Flag_C] = BusA[0]; end // SRL
                endcase

                F_Out[Flag_H] = 0;
                F_Out[Flag_N] = 0;
                F_Out[Flag_X] = alu_result[3];
                F_Out[Flag_Y] = alu_result[5];
                F_Out[Flag_S] = alu_result[7];
                F_Out[Flag_Z] = (alu_result == 8'b0);
                F_Out[Flag_P] = !(alu_result[0] ^ alu_result[1] ^ alu_result[2] ^ alu_result[3] ^ alu_result[4] ^ alu_result[5] ^ alu_result[6] ^ alu_result[7]);

                if (ISet == 2'b00) begin
                    F_Out[Flag_P] = F[Flag_P];
                    F_Out[Flag_S] = F[Flag_S];
                    F_Out[Flag_Z] = F[Flag_Z];
                end
            end

            default: begin end
        endcase
    end

    assign ALU_Q = alu_result;

    //------------------------------------------------------------------------

    assign Really_Wait     = ~WAIT_n & (Write_i | ~NoRead_i);
    assign ClkEn           = CEN;
    assign T_Res           = TState == TStates;
    assign NextIs_XY_Fetch = XY_State != 2'b00 && !XY_Ind && (Set_Addr_To == aXY || (MCycle == 3'd1 && IR == 8'hcb) || (MCycle == 3'd1 && IR == 8'h36));
    assign Save_Mux        = ExchangeRp ? BusB : !Save_ALU_r ? DI_Reg : ALU_Q;

    always @(posedge clk or posedge reset) begin : p1
        reg [7:0] n;
        reg [8:0] ioq;
        reg [8:0] temp_c;
        reg [4:0] temp_h;

        if (reset) begin
            PC            <= 0;
            A             <= 0;
            WZ            <= 0;
            IR            <= 0;
            ISet          <= 0;
            XY_State      <= 0;
            IStatus       <= 0;
            MCycles       <= 0;
            DO            <= 0;
            ACC           <= 8'hFF;
            F             <= 8'hFF;
            Ap            <= 8'hFF;
            Fp            <= 8'hFF;
            I             <= 0;
            R             <= 0;
            SP            <= 16'hFFFF;
            Alternate     <= 0;
            Read_To_Reg_r <= 0;
            Arith16_r     <= 0;
            BTR_r         <= 0;
            Z16_r         <= 0;
            ALU_Op_r      <= 0;
            Save_ALU_r    <= 0;
            PreserveC_r   <= 0;
            XY_Ind        <= 0;
            I_RXDD        <= 0;

        end else begin
            if (ClkEn) begin
                ALU_Op_r      <= 4'b0000;
                Save_ALU_r    <= 0;
                Read_To_Reg_r <= 5'b00000;
                MCycles       <= MCycles_d;

                if (LDHLSP && MCycle == 3'd3 && TState == 1) begin
                    temp_c = {1'b0, SP[7:0]} + {1'b0, Save_Mux};
                    temp_h = {1'b0, SP[3:0]} + {1'b0, Save_Mux[3:0]};
                    F[Flag_Z] <= 0;
                    F[Flag_N] <= 0;
                    F[Flag_H] <= temp_h[4];
                    F[Flag_C] <= temp_c[8];
                end
                if (ADDSPdd && TState == 1) begin
                    temp_c = {1'b0, SP[7:0]} + {1'b0, Save_Mux};
                    temp_h = {1'b0, SP[3:0]} + {1'b0, Save_Mux[3:0]};
                    F[Flag_Z] <= 0;
                    F[Flag_N] <= 0;
                    F[Flag_H] <= temp_h[4];
                    F[Flag_C] <= temp_c[8];
                end
                if (IMode != 2'b11) begin
                    IStatus <= IMode;
                end
                Arith16_r   <= Arith16;
                PreserveC_r <= PreserveC;
                Z16_r       <= (ISet == 2'b10 && !ALU_Op[2] && ALU_Op[0] && MCycle == 3'd3);

                if (MCycle == 3'd1 && !TState[2]) begin
                    // MCycle = 1 and TState = 1, 2, or 3
                    if (TState == 2 && WAIT_n) begin
                        A[7:0]  <= R;
                        A[15:8] <= I;
                        R[6:0]  <= R[6:0] + 7'd1;
                        if (!Jump && !Call && !NMICycle && !IntCycle_i && !(Halt_FF || Halt)) begin
                            PC <= PC + 1;
                        end
                        if (IntCycle_i && IStatus == 2'b01) begin
                            IR <= 8'hFF;
                        end else if (Halt_FF || (IntCycle_i && IStatus == 2'b10) || NMICycle) begin
                            IR <= 8'h00;
                        end else begin
                            IR <= DInst;
                        end
                        if (IntCycle_i && IStatus == 2'b10) begin
                            // IM2 vector address low byte from bus
                            WZ[7:0] <= DInst;
                        end

                        ISet <= 2'b00;
                        if (Prefix != 2'b00) begin
                            if (Prefix == 2'b11) begin
                                if (IR[5]) begin
                                    XY_State <= 2'b10;
                                end else begin
                                    XY_State <= 2'b01;
                                end
                            end else begin
                                if (Prefix == 2'b10) begin
                                    XY_State <= 2'b00;
                                    XY_Ind   <= 0;
                                end
                                ISet <= Prefix;
                            end
                        end else begin
                            XY_State <= 2'b00;
                            XY_Ind   <= 0;
                        end
                    end
                end
                else begin
                    // either (MCycle > 1) OR (MCycle = 1 AND TState > 3)
                    if (MCycle == 3'd6) begin
                        XY_Ind <= 1;
                        if (Prefix == 2'b01) begin
                            ISet <= 2'b01;
                        end
                    end
                    if (T_Res) begin
                        BTR_r <= (I_BT | I_BC | I_BTR) & ~No_BTR;
                        if (Jump) begin
                            A[15:8] <= DI_Reg;
                            A[7:0] <= WZ[7:0];
                            PC[15:8] <= DI_Reg;
                            PC[7:0] <= WZ[7:0];
                        end
                        else if (JumpXY) begin
                            A <= RegBusC;
                            PC <= RegBusC;
                        end
                        else if (Call || RstP) begin
                            A <= WZ;
                            PC <= WZ;
                        end
                        else if (MCycle == MCycles && NMICycle) begin
                            A <= 16'b0000000001100110;
                            PC <= 16'b0000000001100110;
                        end
                        else if ((MCycle == 3'd3) && IntCycle_i && IStatus == 2'b10) begin
                            A[15:8] <= I;
                            A[7:0] <= WZ[7:0];
                            PC[15:8] <= I;
                            PC[7:0] <= WZ[7:0];
                        end
                        else begin
                            case (Set_Addr_To)
                            aXY: begin
                                if (XY_State == 2'b00) begin
                                    A <= RegBusC;
                                end
                                else begin
                                    if (NextIs_XY_Fetch) begin
                                        A <= PC;
                                    end
                                    else begin
                                        A <= WZ;
                                    end
                                end
                            end
                            aIOA: begin
                                A[15:8] <= ACC;
                                A[7:0] <= DI_Reg;
                                WZ <= ({ACC,DI_Reg}) + 1'b1;
                            end
                            aSP: begin
                                A <= SP;
                            end
                            aBC: begin
                                A <= RegBusC;
                                if (SetWZ == 2'b01) begin
                                    WZ <= RegBusC + 1'b1;
                                end
                                if (SetWZ == 2'b10) begin
                                    WZ[7:0] <= RegBusC[7:0] + 1'b1;
                                    WZ[15:8] <= ACC;
                                end
                            end
                            aDE: begin
                                A <= RegBusC;
                                if (SetWZ == 2'b10) begin
                                    WZ[7:0] <= RegBusC[7:0] + 1'b1;
                                    WZ[15:8] <= ACC;
                                end
                            end
                            aZI: begin
                                if (Inc_WZ) begin
                                    A <= (WZ) + 1;
                                end
                                else begin
                                    A[15:8] <= DI_Reg;
                                    A[7:0] <= WZ[7:0];
                                    if (SetWZ == 2'b10) begin
                                        WZ[7:0] <= WZ[7:0] + 1'b1;
                                        WZ[15:8] <= ACC;
                                    end
                                end
                            end
                            default: begin
                                if (ISet == 2'b10 && IR[7:4] == 4'hB && IR[2:1] == 2'b01 && MCycle == 3 && !No_BTR) begin
                                    // INIR, INDR, OTIR, OTDR
                                    A <= RegBusA_r;
                                end
                                else if (!No_PC || No_BTR || (I_DJNZ && IncDecZ)) begin
                                    A <= PC;
                                end
                            end
                            endcase
                        end
                        if (SetWZ == 2'b11) begin
                            WZ <= ID16;
                        end
                        Save_ALU_r <= Save_ALU;
                        ALU_Op_r <= ALU_Op;
                        if (I_CPL) begin
                            // CPL
                            ACC <= ~ACC;
                            F[Flag_Y] <= ~ACC[5];
                            F[Flag_H] <= 1;
                            F[Flag_X] <= ~ACC[3];
                            F[Flag_N] <= 1;
                        end
                        if (I_CCF) begin
                            // CCF
                            F[Flag_C] <= ~F[Flag_C];
                            F[Flag_Y] <= ACC[5];
                            F[Flag_H] <= F[Flag_C];
                            F[Flag_X] <= ACC[3];
                            F[Flag_N] <= 0;
                        end
                        if (I_SCF) begin
                            // SCF
                            F[Flag_C] <= 1;
                            F[Flag_Y] <= ACC[5];
                            F[Flag_H] <= 0;
                            F[Flag_X] <= ACC[3];
                            F[Flag_N] <= 0;
                        end
                    end
                    if ((TState == 2 && !Really_Wait && I_BTR && IR[0]) || (TState == 1 && I_BTR && !IR[0])) begin
                        ioq = ({1'b0,DI_Reg}) + ({1'b0,ID16[7:0]});
                        F[Flag_N] <= DI_Reg[7];
                        F[Flag_C] <= ioq[8];
                        F[Flag_H] <= ioq[8];
                        ioq = (ioq & 9'b000000111) ^ ({1'b0,BusA});
                        F[Flag_P] <= ~(ioq[0] ^ ioq[1] ^ ioq[2] ^ ioq[3] ^ ioq[4] ^ ioq[5] ^ ioq[6] ^ ioq[7]);
                    end
                    if (TState == 2 && !Really_Wait) begin
                        if (ISet == 2'b01 && MCycle == 3'd7) begin
                            IR <= DInst;
                        end
                        if (JumpE) begin
                            PC <= PC + {{8{DI_Reg[7]}}, DI_Reg};
                            WZ <= PC + {{8{DI_Reg[7]}}, DI_Reg};
                        end
                        else if (Inc_PC) begin
                            PC <= PC + 1;
                        end
                        if (BTR_r) begin
                            PC <= PC - 2;
                        end
                        if (RstP) begin
                            WZ <= {16{1'b0}};
                            WZ[5:3] <= IR[5:3];
                        end
                    end
                    if (TState == 3 && MCycle == 3'd6) begin
                        WZ <= RegBusC + {{8{DI_Reg[7]}}, DI_Reg};
                    end
                    if (MCycle == 3'd3 && TState == 4 && !No_BTR) begin
                        if (I_BT || I_BC) begin
                            WZ <= (PC) - 1'b1;
                        end
                    end
                    if ((TState == 2 && !Really_Wait) || (TState == 4 && MCycle == 3'd1)) begin
                        if (IncDec_16[2:0] == 3'd7) begin
                            if (IncDec_16[3]) begin
                                SP <= SP - 1;
                            end
                            else begin
                                SP <= SP + 1;
                            end
                        end
                    end
                    if (ADDSPdd && TState == 2) begin
                        WZ <= SP;
                        SP <= SP + {{8{Save_Mux[7]}}, Save_Mux};
                    end
                    if (LDSPHL) begin
                        SP <= RegBusC;
                    end
                    if (ExchangeAF) begin
                        Ap <= ACC;
                        ACC <= Ap;
                        Fp <= F;
                        F <= Fp;
                    end
                    if (ExchangeRS) begin
                        Alternate <= ~Alternate;
                    end
                end
                if (TState == 3) begin
                    if (LDZ) begin
                        WZ[7:0] <= DI_Reg;
                    end
                    if (LDW) begin
                        WZ[15:8] <= DI_Reg;
                    end
                    if (Special_LD[2]) begin
                        case (Special_LD[1:0])
                        2'b00: begin
                            ACC <= I;
                            F[Flag_P] <= IntE_FF2;
                            F[Flag_S] <= I[7];
                            if (I == 8'h00) begin
                                F[Flag_Z] <= 1;
                            end
                            else begin
                                F[Flag_Z] <= 0;
                            end
                            F[Flag_Y] <= I[5];
                            F[Flag_H] <= 0;
                            F[Flag_X] <= I[3];
                            F[Flag_N] <= 0;
                        end
                        2'b01: begin
                            ACC <= R;
                            F[Flag_P] <= IntE_FF2;
                            F[Flag_S] <= R[7];
                            if (R == 8'h00) begin
                                F[Flag_Z] <= 1;
                            end
                            else begin
                                F[Flag_Z] <= 0;
                            end
                            F[Flag_Y] <= R[5];
                            F[Flag_H] <= 0;
                            F[Flag_X] <= R[3];
                            F[Flag_N] <= 0;
                        end
                        2'b10: begin
                            I <= ACC;
                        end
                        default: begin
                            R <= ACC;
                        end
                        endcase
                    end
                end
                if ((!I_DJNZ && Save_ALU_r) || ALU_Op_r == 4'b1001) begin
                    F[7:1] <= F_Out[7:1];
                    if (!PreserveC_r) begin
                        F[Flag_C] <= F_Out[0];
                    end
                end
                if (T_Res && I_INRC) begin
                    F[Flag_H] <= 0;
                    F[Flag_N] <= 0;
                    F[Flag_X] <= DI_Reg[3];
                    F[Flag_Y] <= DI_Reg[5];
                    F[Flag_Z] <= (DI_Reg[7:0] == 8'h00);
                    F[Flag_S] <= DI_Reg[7];
                    F[Flag_P] <= ~(DI_Reg[0] ^ DI_Reg[1] ^ DI_Reg[2] ^ DI_Reg[3] ^ DI_Reg[4] ^ DI_Reg[5] ^ DI_Reg[6] ^ DI_Reg[7]);
                end
                if (TState == 1 && !Auto_Wait_t1) begin
                    // Keep D0 from M3 for RLD/RRD (Sorgelig)
                    I_RXDD <= I_RLD | I_RRD;
                    if (!I_RXDD) begin
                        DO <= BusB;
                    end
                    if (I_RLD) begin
                        DO[3:0] <= BusA[3:0];
                        DO[7:4] <= BusB[3:0];
                    end
                    if (I_RRD) begin
                        DO[3:0] <= BusB[7:4];
                        DO[7:4] <= BusA[3:0];
                    end
                end
                if (T_Res) begin
                    Read_To_Reg_r[3:0] <= Set_BusA_To;
                    Read_To_Reg_r[4]   <= Read_To_Reg;
                    if (Read_To_Acc) begin
                        Read_To_Reg_r[3:0] <= 4'b0111;
                        Read_To_Reg_r[4]   <= 1;
                    end
                end
                if (TState == 1 && I_BT) begin
                    F[Flag_X] <= ALU_Q[3];
                    F[Flag_Y] <= ALU_Q[1];
                    F[Flag_H] <= 0;
                    F[Flag_N] <= 0;
                end
                if (TState == 1 && I_BC) begin
                    n = ALU_Q - ({7'b0, F_Out[Flag_H]});
                    F[Flag_X] <= n[3];
                    F[Flag_Y] <= n[1];
                end
                if (I_BC || I_BT) begin
                    F[Flag_P] <= IncDecZ;
                end
                if ((TState == 1 && !Save_ALU_r && !Auto_Wait_t1) || (Save_ALU_r && ALU_Op_r != 4'b0111)) begin
                    case (Read_To_Reg_r)
                        5'b10111: ACC      <= Save_Mux;
                        5'b10110: DO       <= Save_Mux;
                        5'b11000: SP[7:0]  <= Save_Mux;
                        5'b11001: SP[15:8] <= Save_Mux;
                        5'b11011: F        <= Save_Mux;
                        default: begin end
                    endcase
                    if (XYbit_undoc) begin
                        DO <= ALU_Q;
                    end
                end
            end
        end
    end

    //-------------------------------------------------------------------------
    //
    // BC('), DE('), HL('), IX and IY
    //
    //-------------------------------------------------------------------------
    always @(posedge clk) begin
        if (ClkEn) begin
            // Bus A / Write
            RegAddrA_r <= {Alternate,Set_BusA_To[2:1]};
            if (!XY_Ind && XY_State != 2'b00 && Set_BusA_To[2:1] == 2'b10) begin
                RegAddrA_r <= {XY_State[1], 2'b11};
            end
            // Bus B
            RegAddrB_r <= {Alternate,Set_BusB_To[2:1]};
            if (!XY_Ind && XY_State != 2'b00 && Set_BusB_To[2:1] == 2'b10) begin
                RegAddrB_r <= {XY_State[1], 2'b11};
            end
            // Address from register
            RegAddrC <= {Alternate,Set_Addr_To[1:0]};
            // Jump (HL), LD SP,HL
            if (JumpXY || LDSPHL) begin
                RegAddrC <= {Alternate,2'b10};
            end
            if (((JumpXY || LDSPHL) && XY_State != 2'b00) || MCycle == 3'd6) begin
                RegAddrC <= {XY_State[1], 2'b11};
            end
            if (I_DJNZ && Save_ALU_r) begin
                IncDecZ <= F_Out[Flag_Z];
            end
            if ((TState == 2 || (TState == 3 && MCycle == 3'd1)) && IncDec_16[2:0] == 3'd4) begin
                if (ID16 == 0) begin
                    IncDecZ <= 0;
                end
                else begin
                    IncDecZ <= 1;
                end
            end
            RegBusA_r <= RegBusA;
        end
    end

    wire [2:0] RegAddrA = (TState == 2 || (TState == 3 && MCycle == 3'd1 && IncDec_16[2])) && XY_State == 2'b00 ? {Alternate,IncDec_16[1:0]} : (TState == 2 || (TState == 3 && MCycle == 3'd1 && IncDec_16[2])) && IncDec_16[1:0] == 2'b10 ? {XY_State[1],2'b11} : ExchangeDH && TState == 3 ? {Alternate,2'b10} : ExchangeDH && TState == 4 ? {Alternate,2'b01} : ExchangeWH && XY_State == 2'b00 && TState == 4 ? {Alternate,2'b10} : ExchangeWH && TState == 4 ? {XY_State[1],2'b11} : LDHLSP && TState == 4 ? 3'd2 : RegAddrA_r;
    wire [2:0] RegAddrB = ExchangeDH && TState == 3 ? {Alternate,2'b01} : RegAddrB_r;
    assign ID16 = IncDec_16[3] ? (RegBusA) - 1 : (RegBusA) + 1;

    always @* begin
        RegWEH = 0;
        RegWEL = 0;
        if ((TState == 1 && !Save_ALU_r && !Auto_Wait_t1) || (Save_ALU_r && ALU_Op_r != 4'b0111)) begin
            case (Read_To_Reg_r)
                5'b10000,5'b10001,5'b10010,5'b10011,5'b10100,5'b10101: begin
                    RegWEH = ~Read_To_Reg_r[0];
                    RegWEL =  Read_To_Reg_r[0];
                end
                default: begin end
            endcase
        end
        if (ExchangeDH && (TState == 3 || TState == 4)) begin
            RegWEH = 1;
            RegWEL = 1;
        end
        if (((LDHLSP && MCycle == 3'd2) || ExchangeWH) && TState == 4) begin
            RegWEH = 1;
            RegWEL = 1;
        end
        if (IncDec_16[2] && ((TState == 2 && !Really_Wait && MCycle != 3'd1) || (TState == 3 && MCycle == 3'd1))) begin
            case (IncDec_16[1:0])
                2'b00,2'b01,2'b10: begin
                    RegWEH = 1;
                    RegWEL = 1;
                end
                default: begin end
            endcase
        end
    end

    wire [15:0] TmpAddr2 = SP + {{8{Save_Mux[7]}}, Save_Mux};
    always @* begin
        RegDIH = Save_Mux;
        RegDIL = Save_Mux;
        if (LDHLSP && MCycle == 3'd2 && TState == 4) begin
            RegDIH = TmpAddr2[15:8];
            RegDIL = TmpAddr2[7:0];
        end
        if (ExchangeDH && TState == 3) begin
            RegDIH = RegBusB[15:8];
            RegDIL = RegBusB[7:0];
        end
        if (ExchangeDH && TState == 4) begin
            RegDIH = RegBusA_r[15:8];
            RegDIL = RegBusA_r[7:0];
        end
        if (ExchangeWH && TState == 4) begin
            RegDIH = WZ[15:8];
            RegDIL = WZ[7:0];
        end
        if (IncDec_16[2] && ((TState == 2 && MCycle != 3'd1) || (TState == 3 && MCycle == 3'd1))) begin
            RegDIH = ID16[15:8];
            RegDIL = ID16[7:0];
        end
    end

    //------------------------------------------------------------------------
    // Register file
    //------------------------------------------------------------------------
    reg [7:0] RegsH [7:0] /* synthesis syn_ramstyle = "distributed_ram" */;
    reg [7:0] RegsL [7:0] /* synthesis syn_ramstyle = "distributed_ram" */;

    always @(posedge clk) if (ClkEn && RegWEH) RegsH[RegAddrA] <= RegDIH;
    always @(posedge clk) if (ClkEn && RegWEL) RegsL[RegAddrA] <= RegDIL;

    assign RegBusA[15:8] = RegsH[RegAddrA];
    assign RegBusA[ 7:0] = RegsL[RegAddrA];

    assign RegBusB[15:8] = RegsH[RegAddrB];
    assign RegBusB[ 7:0] = RegsL[RegAddrB];

    assign RegBusC[15:8] = RegsH[RegAddrC];
    assign RegBusC[ 7:0] = RegsL[RegAddrC];

    //------------------------------------------------------------------------
    // Buses
    //------------------------------------------------------------------------
    always @(posedge clk) begin
        if (ClkEn) begin
            case (Set_BusB_To)
                4'b0111: BusB <= ACC;
                4'b0000,
                4'b0001,
                4'b0010,
                4'b0011,
                4'b0100,
                4'b0101: BusB <= Set_BusB_To[0] ? RegBusB[7:0] : RegBusB[15:8];
                4'b0110: BusB <= DI_Reg;
                4'b1000: BusB <= SP[7:0];
                4'b1001: BusB <= SP[15:8];
                4'b1010: BusB <= 8'h01;
                4'b1011: BusB <= F;
                4'b1100: BusB <= PC[7:0];
                4'b1101: BusB <= PC[15:8];
                4'b1110: BusB <= (IR == 8'h71 && out0) ? 8'hFF : 8'h00;
                default: BusB <= 8'h00;
            endcase

            case (Set_BusA_To)
                4'b0111: BusA <= ACC;
                4'b0000,
                4'b0001,
                4'b0010,
                4'b0011,
                4'b0100,
                4'b0101: BusA <= Set_BusA_To[0] ? RegBusA[7:0] : RegBusA[15:8];
                4'b0110: BusA <= DI_Reg;
                4'b1000: BusA <= SP[7:0];
                4'b1001: BusA <= SP[15:8];
                4'b1010: BusA <= 8'h00;
                default: BusA <= 8'h00;
            endcase

            if (XYbit_undoc) begin
                BusA <= DI_Reg;
                BusB <= DI_Reg;
            end
        end
    end

    //------------------------------------------------------------------------
    // Generate external control signals
    //------------------------------------------------------------------------
    assign MC       = MCycle;
    assign TS       = TState;
    assign DI_Reg   = DI;
    assign IntCycle = IntCycle_i;
    assign IORQ     = IORQ_i;
    assign NoRead   = NoRead_i;
    assign Write    = Write_i;

    //------------------------------------------------------------------------
    // Main state machine
    //------------------------------------------------------------------------
    reg OldNMI_n;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            MCycle       <= 3'd1;
            TState       <= 3'd0;
            Pre_XY_F_M   <= 3'd0;
            Halt_FF      <= 0;
            NMICycle     <= 0;
            IntCycle_i   <= 0;
            IntE_FF1     <= 0;
            IntE_FF2     <= 0;
            No_BTR       <= 0;
            Auto_Wait_t1 <= 0;
            Auto_Wait_t2 <= 0;
            NMI_s        <= 0;
            OldNMI_n     <= 0;

        end else begin
            if (!NMI_n && OldNMI_n) begin
                NMI_s <= 1;
            end
            OldNMI_n <= NMI_n;

            if (CEN) begin
                Auto_Wait_t2 <= Auto_Wait_t1;

                if (T_Res) begin
                    Auto_Wait_t1 <= 0;
                    Auto_Wait_t2 <= 0;
                end else begin
                    Auto_Wait_t1 <= Auto_Wait | IORQ_i;
                end

                No_BTR <=
                    (I_BT  & (~IR[4] |              ~F[Flag_P])) |
                    (I_BC  & (~IR[4] |  F[Flag_Z] | ~F[Flag_P])) |
                    (I_BTR & (~IR[4] |  F[Flag_Z]));

                if (TState == 2) begin
                    if (SetEI) begin
                        IntE_FF1 <= 1;
                        IntE_FF2 <= 1;
                    end

                    if (I_RETN) begin
                        IntE_FF1 <= IntE_FF2;
                    end
                end

                if (TState == 3 && SetDI) begin
                    IntE_FF1 <= 0;
                    IntE_FF2 <= 0;
                end

                if (IntCycle_i || NMICycle) begin
                    Halt_FF <= 0;
                end

                if (TState == 2 && Really_Wait) begin
                    // Wait

                end else if (T_Res) begin
                    if (Halt) begin
                        Halt_FF <= 1;
                    end
                    TState <= 3'd1;

                    if (NextIs_XY_Fetch) begin
                        MCycle     <= 3'd6;
                        Pre_XY_F_M <= MCycle;
                        if (IR == 8'h36 && Mode == 0) begin
                            Pre_XY_F_M <= 3'd2;
                        end

                    end else if (MCycle == 3'd7 || (MCycle == 3'd6 && Mode == 1 && ISet != 2'b01)) begin
                        MCycle <= (Pre_XY_F_M) + 1;

                    end else if (MCycle == MCycles || No_BTR || (MCycle == 3'd2 && I_DJNZ && IncDecZ)) begin
                        MCycle <= 3'd1;
                        IntCycle_i <= 0;
                        NMICycle <= 0;
                        if (NMI_s && Prefix == 2'b00) begin
                            NMI_s <= 0;
                            NMICycle <= 1;
                            IntE_FF1 <= 0;

                        end else if (IntE_FF1 && !INT_n && Prefix == 2'b00 && !SetEI) begin
                            IntCycle_i <= 1;
                            IntE_FF1 <= 0;
                            IntE_FF2 <= 0;
                        end

                    end else begin
                        MCycle <= MCycle + 1;
                    end

                end else begin
                    if (!(Auto_Wait && !Auto_Wait_t2)) begin
                        TState <= TState + 1;
                    end
                end
            end
        end
    end

    assign Auto_Wait = IntCycle_i && MCycle == 3'd1;

endmodule
