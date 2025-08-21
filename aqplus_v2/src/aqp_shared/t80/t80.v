`default_nettype none
`timescale 1 ns / 1 ps

module t80(
    input  wire        clk,
    input  wire        reset,

    input  wire        clk_en,
    input  wire        bus_wait,
    input  wire        irq,
    input  wire        nmi,
    output wire        IORQ,
    output wire        NoRead,
    output wire        Write,
    output reg  [15:0] bus_addr,
    input  wire  [7:0] DInst,
    input  wire  [7:0] DI,
    output reg   [7:0] bus_wrdata,
    output wire  [2:0] MC,
    output wire  [2:0] TS,
    output wire        IntCycle);

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

    localparam
        PrefixNone  = 2'b00,
        PrefixCB    = 2'b01,
        PrefixED    = 2'b10,
        PrefixDD_FD = 2'b11;

    // Registers
    reg  [15:0] q_reg_pc;       // PC  program counter
    reg   [7:0] q_reg_a;        // A
    reg   [7:0] q_reg_f;        // F   flags
    reg   [7:0] q_reg_a_alt;    // A'
    reg   [7:0] q_reg_f_alt;    // F'
    reg   [7:0] q_reg_i;        // I   interrupt vector register
    reg   [7:0] q_reg_r;        // R   refresh register
    reg  [15:0] q_reg_sp;       // SP  stack pointer

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
    reg   [7:0] q_instruction;
    reg   [1:0] q_prefix;
    reg  [15:0] RegBusA_r;
    wire [15:0] ID16;
    wire  [7:0] Save_Mux;
    reg   [2:0] q_tstate;
    reg   [2:0] q_mcycle;
    reg         IntE_FF1;
    reg         IntE_FF2;
    reg         q_halt;
    reg   [1:0] IStatus;
    wire  [7:0] DI_Reg;
    wire        T_Res;
    reg   [1:0] XY_State;
    reg   [2:0] Pre_XY_F_M;
    wire        NextIs_XY_Fetch;
    reg         XY_Ind;
    reg         No_BTR;
    reg         BTR_r;
    wire        d_auto_wait;
    reg         q_auto_wait;
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
    reg   [2:0] q_mcycles;
    reg   [2:0] d_mcycles;
    reg   [2:0] tstates;
    reg         q_irq_cycle;
    reg         q_nmi_cycle;
    reg         Inc_PC;
    reg         Inc_WZ;
    reg   [3:0] IncDec_16;
    reg   [1:0] d_prefix;
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

    reg         is_instr_bc;
    reg         is_instr_bt;
    reg         is_instr_btr;
    reg         is_instr_ccf;
    reg         is_instr_cpl;
    reg         is_instr_djnz;
    reg         is_instr_inrc;
    reg         is_instr_retn;
    reg         is_instr_rld;
    reg         is_instr_rrd;
    reg         is_instr_scf;

    reg         I_RXDD;
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
        case (q_instruction[5:3])
            3'd0:    cc_is_true = !q_reg_f[Flag_Z]; // NZ
            3'd1:    cc_is_true =  q_reg_f[Flag_Z]; // Z
            3'd2:    cc_is_true = !q_reg_f[Flag_C]; // NC
            3'd3:    cc_is_true =  q_reg_f[Flag_C]; // C
            3'd4:    cc_is_true = !q_reg_f[Flag_P]; // PO
            3'd5:    cc_is_true =  q_reg_f[Flag_P]; // PE
            3'd6:    cc_is_true = !q_reg_f[Flag_S]; // P
            default: cc_is_true =  q_reg_f[Flag_S]; // M
        endcase
    end

    wire [2:0] ir_ddd   = q_instruction[5:3];
    wire [2:0] ir_sss   = q_instruction[2:0];
    wire [1:0] ir_dpair = q_instruction[5:4];

    always @* begin
        d_mcycles     = 3'd1;
        tstates       = (q_mcycle == 3'd1) ? 3'd4 : 3'd3;
        d_prefix      = PrefixNone;
        Inc_PC        = 0;
        Inc_WZ        = 0;
        IncDec_16     = 4'b0000;
        Read_To_Acc   = 0;
        Read_To_Reg   = 0;
        Set_BusB_To   = 4'b0000;
        Set_BusA_To   = 4'b0000;
        ALU_Op        = {1'b0, q_instruction[5:3]};
        Save_ALU      = 0;
        PreserveC     = 0;
        Arith16       = 0;
        IORQ_i        = 0;
        Set_Addr_To   = aNone;
        Jump          = 0;
        JumpE         = 0;
        JumpXY        = 0;
        Call          = 0;
        RstP          = 0;
        LDZ           = 0;
        LDW           = 0;
        LDSPHL        = 0;
        LDHLSP        = 0;
        ADDSPdd       = 0;
        Special_LD    = 3'd0;
        ExchangeDH    = 0;
        ExchangeRp    = 0;
        ExchangeAF    = 0;
        ExchangeRS    = 0;
        ExchangeWH    = 0;

        is_instr_bc   = 0;
        is_instr_bt   = 0;
        is_instr_btr  = 0;
        is_instr_ccf  = 0;
        is_instr_cpl  = 0;
        is_instr_djnz = 0;
        is_instr_inrc = 0;
        is_instr_retn = 0;
        is_instr_rld  = 0;
        is_instr_rrd  = 0;
        is_instr_scf  = 0;

        SetDI         = 0;
        SetEI         = 0;
        IMode         = 2'b11;
        Halt          = 0;
        NoRead_i      = 0;
        Write_i       = 0;
        No_PC         = 0;
        XYbit_undoc   = 0;
        SetWZ         = 2'b00;

        case (q_prefix)
            //----------------------------------------------------------------
            // Unprefixed instructions
            //----------------------------------------------------------------
            2'b00: begin
                case (q_instruction)
                    // 8 BIT LOAD GROUP
                    8'h40,8'h41,8'h42,8'h43,8'h44,8'h45,8'h47,
                    8'h48,8'h49,8'h4a,8'h4b,8'h4c,8'h4d,8'h4f,
                    8'h50,8'h51,8'h52,8'h53,8'h54,8'h55,8'h57,
                    8'h58,8'h59,8'h5a,8'h5b,8'h5c,8'h5d,8'h5f,
                    8'h60,8'h61,8'h62,8'h63,8'h64,8'h65,8'h67,
                    8'h68,8'h69,8'h6a,8'h6b,8'h6c,8'h6d,8'h6f,
                    8'h78,8'h79,8'h7a,8'h7b,8'h7c,8'h7d,8'h7f: begin
                        // LD r,r'
                        Set_BusB_To[2:0] = ir_sss;
                        ExchangeRp       = 1;
                        Set_BusA_To[2:0] = ir_ddd;
                        Read_To_Reg      = 1;
                    end

                    8'h06,8'h0e,8'h16,8'h1e,8'h26,8'h2e,8'h3e: begin
                        // LD r,n
                        d_mcycles = 3'd2;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC           = 1;
                                Set_BusA_To[2:0] = ir_ddd;
                                Read_To_Reg      = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'h46,8'h4e,8'h56,8'h5e,8'h66,8'h6e,8'h7e: begin
                        // LD r,(HL)
                        d_mcycles = 3'd2;
                        case (q_mcycle)
                        3'd1: begin
                            Set_Addr_To = aXY;
                        end
                        3'd2: begin
                            Set_BusA_To[2:0] = ir_ddd;
                            Read_To_Reg      = 1;
                        end
                        default: begin end
                        endcase
                    end

                    8'h70,8'h71,8'h72,8'h73,8'h74,8'h75,8'h77: begin
                        // LD (HL),r
                        d_mcycles = 3'd2;
                        case (q_mcycle)
                        3'd1: begin
                            Set_Addr_To = aXY;
                            Set_BusB_To[2:0] = ir_sss;
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd2: begin
                            Inc_PC = 1;
                            Set_Addr_To = aXY;
                            Set_BusB_To[2:0] = ir_sss;
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
                        d_mcycles = 3'd2;
                        case (q_mcycle)
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
                        d_mcycles = 3'd2;
                        case (q_mcycle)
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
                        d_mcycles = 3'd4;
                        case (q_mcycle)
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
                        d_mcycles = 3'd2;
                        case (q_mcycle)
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
                        d_mcycles = 3'd2;
                        case (q_mcycle)
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
                        d_mcycles = 3'd4;
                        case (q_mcycle)
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd2: begin
                            Inc_PC = 1;
                            Read_To_Reg = 1;
                            if (ir_dpair == 2'b11) begin
                                Set_BusA_To[3:0] = 4'b1000;
                            end
                            else begin
                                Set_BusA_To[2:1] = ir_dpair;
                                Set_BusA_To[0] = 1;
                            end
                        end
                        3'd3: begin
                            Inc_PC = 1;
                            Read_To_Reg = 1;
                            if (ir_dpair == 2'b11) begin
                                Set_BusA_To[3:0] = 4'b1001;
                            end
                            else begin
                                Set_BusA_To[2:1] = ir_dpair;
                                Set_BusA_To[0] = 0;
                            end
                        end
                        default: begin end
                        endcase
                    end
                    8'h2a: begin
                        // LD HL,(nn)
                        d_mcycles = 3'd5;
                        case (q_mcycle)
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
                        d_mcycles = 3'd5;
                        case (q_mcycle)
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
                        // LD q_reg_sp,HL
                        tstates = 3'd6;
                        LDSPHL = 1;
                    end
                    8'hc5,8'hd5,8'he5,8'hf5: begin
                        // PUSH qq
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd1: begin
                            tstates = 3'd5;
                            IncDec_16 = 4'b1111;
                            Set_Addr_To = aSP;
                            if (ir_dpair == 2'b11) begin
                                Set_BusB_To = 4'b0111;
                            end
                            else begin
                                Set_BusB_To[2:1] = ir_dpair;
                                Set_BusB_To[0] = 0;
                                Set_BusB_To[3] = 0;
                            end
                        end
                        3'd2: begin
                            IncDec_16 = 4'b1111;
                            Set_Addr_To = aSP;
                            if (ir_dpair == 2'b11) begin
                                Set_BusB_To = 4'b1011;
                            end
                            else begin
                                Set_BusB_To[2:1] = ir_dpair;
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd1: begin
                            Set_Addr_To = aSP;
                        end
                        3'd2: begin
                            IncDec_16 = 4'b0111;
                            Set_Addr_To = aSP;
                            Read_To_Reg = 1;
                            if (ir_dpair == 2'b11) begin
                                Set_BusA_To[3:0] = 4'b1011;
                            end
                            else begin
                                Set_BusA_To[2:1] = ir_dpair;
                                Set_BusA_To[0] = 1;
                            end
                        end
                        3'd3: begin
                            IncDec_16 = 4'b0111;
                            Read_To_Reg = 1;
                            if (ir_dpair == 2'b11) begin
                                Set_BusA_To[3:0] = 4'b0111;
                            end
                            else begin
                                Set_BusA_To[2:1] = ir_dpair;
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
                        d_mcycles = 3'd5;
                        case (q_mcycle)
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
                            tstates = 3'd4;
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
                            tstates = 3'd5;
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
                        Set_BusB_To[2:0] = ir_sss;
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
                        d_mcycles = 3'd2;
                        case (q_mcycle)
                        3'd1: begin
                            Set_Addr_To = aXY;
                        end
                        3'd2: begin
                            Read_To_Reg = 1;
                            Save_ALU = 1;
                            Set_BusB_To[2:0] = ir_sss;
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
                        d_mcycles = 3'd2;
                        if (q_mcycle == 3'd2) begin
                            Inc_PC = 1;
                            Read_To_Reg = 1;
                            Save_ALU = 1;
                            Set_BusB_To[2:0] = ir_sss;
                            Set_BusA_To[2:0] = 3'd7;
                        end
                    end
                    8'h04,8'h0c,8'h14,8'h1c,8'h24,8'h2c,8'h3c: begin
                        // INC r
                        Set_BusB_To = 4'b1010;
                        Set_BusA_To[2:0] = ir_ddd;
                        Read_To_Reg = 1;
                        Save_ALU = 1;
                        PreserveC = 1;
                        ALU_Op = 4'b0000;
                    end
                    8'h34: begin
                        // INC (HL)
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd1: begin
                            Set_Addr_To = aXY;
                        end
                        3'd2: begin
                            tstates = 3'd4;
                            Set_Addr_To = aXY;
                            Read_To_Reg = 1;
                            Save_ALU = 1;
                            PreserveC = 1;
                            ALU_Op = 4'b0000;
                            Set_BusB_To = 4'b1010;
                            Set_BusA_To[2:0] = ir_ddd;
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
                        Set_BusA_To[2:0] = ir_ddd;
                        Read_To_Reg = 1;
                        Save_ALU = 1;
                        PreserveC = 1;
                        ALU_Op = 4'b0010;
                    end
                    8'h35: begin
                        // DEC (HL)
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd1: begin
                            Set_Addr_To = aXY;
                        end
                        3'd2: begin
                            tstates = 3'd4;
                            Set_Addr_To = aXY;
                            ALU_Op = 4'b0010;
                            Read_To_Reg = 1;
                            Save_ALU = 1;
                            PreserveC = 1;
                            Set_BusB_To = 4'b1010;
                            Set_BusA_To[2:0] = ir_ddd;
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
                        is_instr_cpl = 1;
                    end
                    8'h3f: begin
                        // CCF
                        is_instr_ccf = 1;
                    end
                    8'h37: begin
                        // SCF
                        is_instr_scf = 1;
                    end
                    8'h00: begin
                        if (q_nmi_cycle) begin
                            // NMI
                            d_mcycles = 3'd3;
                            case (q_mcycle)
                                3'd1: begin
                                    tstates = 3'd5;
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
                        else if (q_irq_cycle) begin
                            // INT (IM 2)
                            d_mcycles = 3'd5;
                            case (q_mcycle)
                            3'd1: begin
                                tstates = 3'd5;
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd1: begin
                            No_PC = 1;
                        end
                        3'd2: begin
                            NoRead_i = 1;
                            ALU_Op = 4'b0000;
                            Read_To_Reg = 1;
                            Save_ALU = 1;
                            Set_BusA_To[2:0] = 3'd5;
                            case (q_instruction[5:4])
                            2'b00,2'b01,2'b10: begin
                                Set_BusB_To[2:1] = q_instruction[5:4];
                                Set_BusB_To[0] = 1;
                            end
                            default: begin
                                Set_BusB_To = 4'b1000;
                            end
                            endcase
                            tstates = 3'd4;
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
                            case (q_instruction[5:4])
                            2'b00,2'b01,2'b10: begin
                                Set_BusB_To[2:1] = q_instruction[5:4];
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
                        tstates = 3'd6;
                        IncDec_16[3:2] = 2'b01;
                        IncDec_16[1:0] = ir_dpair;
                    end
                    8'h0b,8'h1b,8'h2b,8'h3b: begin
                        // DEC ss
                        tstates = 3'd6;
                        IncDec_16[3:2] = 2'b11;
                        IncDec_16[1:0] = ir_dpair;
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd2: begin
                            Inc_PC = 1;
                            No_PC = 1;
                        end
                        3'd3: begin
                            NoRead_i = 1;
                            JumpE = 1;
                            tstates = 3'd5;
                        end
                        default: begin end
                        endcase
                    end
                    8'h38: begin
                        // JR C,e
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd2: begin
                            Inc_PC = 1;
                            if (!q_reg_f[Flag_C]) begin
                                d_mcycles = 3'd2;
                            end
                            else begin
                                No_PC = 1;
                            end
                        end
                        3'd3: begin
                            NoRead_i = 1;
                            JumpE = 1;
                            tstates = 3'd5;
                        end
                        default: begin end
                        endcase
                    end
                    8'h30: begin
                        // JR NC,e
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd2: begin
                            Inc_PC = 1;
                            if (q_reg_f[Flag_C]) begin
                                d_mcycles = 3'd2;
                            end
                            else begin
                                No_PC = 1;
                            end
                        end
                        3'd3: begin
                            NoRead_i = 1;
                            JumpE = 1;
                            tstates = 3'd5;
                        end
                        default: begin end
                        endcase
                    end
                    8'h28: begin
                        // JR Z,e
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd2: begin
                            Inc_PC = 1;
                            if (!q_reg_f[Flag_Z]) begin
                                d_mcycles = 3'd2;
                            end
                            else begin
                                No_PC = 1;
                            end
                        end
                        3'd3: begin
                            NoRead_i = 1;
                            JumpE = 1;
                            tstates = 3'd5;
                        end
                        default: begin end
                        endcase
                    end
                    8'h20: begin
                        // JR NZ,e
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd2: begin
                            Inc_PC = 1;
                            if (q_reg_f[Flag_Z]) begin
                                d_mcycles = 3'd2;
                            end
                            else begin
                                No_PC = 1;
                            end
                        end
                        3'd3: begin
                            NoRead_i = 1;
                            JumpE = 1;
                            tstates = 3'd5;
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd1: begin
                            tstates = 3'd5;
                            is_instr_djnz = 1;
                            Set_BusB_To = 4'b1010;
                            Set_BusA_To[2:0] = 3'd0;
                            Read_To_Reg = 1;
                            Save_ALU = 1;
                            ALU_Op = 4'b0010;
                        end
                        3'd2: begin
                            is_instr_djnz = 1;
                            Inc_PC = 1;
                            No_PC = 1;
                        end
                        3'd3: begin
                            NoRead_i = 1;
                            JumpE = 1;
                            tstates = 3'd5;
                        end
                        default: begin end
                        endcase
                        // CALL AND RETURN GROUP
                    end
                    8'hcd: begin
                        // CALL nn
                        d_mcycles = 3'd5;
                        case (q_mcycle)
                        3'd2: begin
                            Inc_PC = 1;
                            LDZ = 1;
                        end
                        3'd3: begin
                            IncDec_16 = 4'b1111;
                            Inc_PC = 1;
                            tstates = 3'd4;
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
                        d_mcycles = 3'd5;
                        case (q_mcycle)
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
                                tstates = 3'd4;
                                Set_BusB_To = 4'b1101;
                            end
                            else begin
                                d_mcycles = 3'd3;
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd1: begin
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd1: begin
                            if (cc_is_true) begin
                                Set_Addr_To = aSP;
                            end
                            else begin
                                d_mcycles = 3'd1;
                            end
                            tstates = 3'd5;
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                        3'd1: begin
                            tstates = 3'd5;
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
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

                    8'hcb:       d_prefix = PrefixCB;
                    8'hed:       d_prefix = PrefixED;
                    8'hdd,8'hfd: d_prefix = PrefixDD_FD;

                    default: begin end
                endcase
            end

            //----------------------------------------------------------------
            // CB prefixed instructions
            //----------------------------------------------------------------
            2'b01: begin
                Set_BusA_To[2:0] = q_instruction[2:0];
                Set_BusB_To[2:0] = q_instruction[2:0];

                case (q_instruction)
                    8'h00,8'h01,8'h02,8'h03,8'h04,8'h05,8'h07,          // RLC r
                    8'h08,8'h09,8'h0a,8'h0b,8'h0c,8'h0d,8'h0f,          // RRC r
                    8'h10,8'h11,8'h12,8'h13,8'h14,8'h15,8'h17,          // RL r
                    8'h18,8'h19,8'h1a,8'h1b,8'h1c,8'h1d,8'h1f,          // RR r
                    8'h20,8'h21,8'h22,8'h23,8'h24,8'h25,8'h27,          // SLA r
                    8'h28,8'h29,8'h2a,8'h2b,8'h2c,8'h2d,8'h2f,          // SRA r
                    8'h30,8'h31,8'h32,8'h33,8'h34,8'h35,8'h37,          // SLL r
                    8'h38,8'h39,8'h3a,8'h3b,8'h3c,8'h3d,8'h3f: begin    // SRL r
                    
                        if (XY_State == 2'b00) begin
                            if (q_mcycle == 3'd1) begin
                                ALU_Op      = 4'b1000;
                                Read_To_Reg = 1;
                                Save_ALU    = 1;
                            end

                        end else begin
                            // R/S (IX+d),Reg, undocumented
                            d_mcycles   = 3'd3;
                            XYbit_undoc = 1;
                            case (q_mcycle)
                                3'd1,3'd7: begin
                                    Set_Addr_To = aXY;
                                end
                                3'd2: begin
                                    ALU_Op      = 4'b1000;
                                    Read_To_Reg = 1;
                                    Save_ALU    = 1;
                                    Set_Addr_To = aXY;
                                    tstates     = 3'd4;
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1,3'd7: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                ALU_Op      = 4'b1000;
                                Read_To_Reg = 1;
                                Save_ALU    = 1;
                                Set_Addr_To = aXY;
                                tstates     = 3'd4;
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
                            if (q_mcycle == 3'd1) begin
                                Set_BusB_To[2:0] = q_instruction[2:0];
                                ALU_Op           = 4'b1001;
                            end

                        end else begin
                            // BIT b,(IX+d), undocumented
                            d_mcycles   = 3'd2;
                            XYbit_undoc = 1;
                            case (q_mcycle)
                                3'd1,3'd7: begin
                                    Set_Addr_To = aXY;
                                end
                                3'd2: begin
                                    ALU_Op  = 4'b1001;
                                    tstates = 3'd4;
                                end
                                default: begin end
                            endcase
                        end
                    end

                    8'h46,8'h4e,8'h56,8'h5e,8'h66,8'h6e,8'h76,8'h7e: begin
                        // BIT b,(HL)
                        d_mcycles = 3'd2;
                        case (q_mcycle)
                            3'd1,3'd7: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                ALU_Op  = 4'b1001;
                                tstates = 3'd4;
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
                            if (q_mcycle == 3'd1) begin
                                ALU_Op      = 4'b1010;
                                Read_To_Reg = 1;
                                Save_ALU    = 1;
                            end

                        end else begin
                            // SET b,(IX+d),Reg, undocumented
                            d_mcycles = 3'd3;
                            XYbit_undoc = 1;
                            case (q_mcycle)
                                3'd1,3'd7: begin
                                    Set_Addr_To = aXY;
                                end
                                3'd2: begin
                                    ALU_Op      = 4'b1010;
                                    Read_To_Reg = 1;
                                    Save_ALU    = 1;
                                    Set_Addr_To = aXY;
                                    tstates     = 3'd4;
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1,3'd7: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                ALU_Op      = 4'b1010;
                                Read_To_Reg = 1;
                                Save_ALU    = 1;
                                Set_Addr_To = aXY;
                                tstates     = 3'd4;
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
                            if (q_mcycle == 3'd1) begin
                                ALU_Op      = 4'b1011;
                                Read_To_Reg = 1;
                                Save_ALU    = 1;
                            end
                        end else begin
                            // RES b,(IX+d),Reg, undocumented
                            d_mcycles   = 3'd3;
                            XYbit_undoc = 1;
                            case (q_mcycle)
                                3'd1,3'd7: begin
                                    Set_Addr_To = aXY;
                                end
                                3'd2: begin
                                    ALU_Op      = 4'b1011;
                                    Read_To_Reg = 1;
                                    Save_ALU    = 1;
                                    Set_Addr_To = aXY;
                                    tstates     = 3'd4;
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1,3'd7: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                ALU_Op      = 4'b1011;
                                Read_To_Reg = 1;
                                Save_ALU    = 1;
                                Set_Addr_To = aXY;
                                tstates     = 3'd4;
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
                case (q_instruction)
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
                        tstates    = 3'd5;
                    end

                    8'h5f: begin
                        // LD A,R
                        Special_LD = 3'd5;
                        tstates    = 3'd5;
                    end

                    8'h47: begin
                        // LD I,A
                        Special_LD = 3'd6;
                        tstates    = 3'd5;
                    end

                    8'h4f: begin
                        // LD R,A
                        Special_LD = 3'd7;
                        tstates = 3'd5;
                        // 16 BIT LOAD GROUP
                    end

                    8'h4b,8'h5b,8'h6b,8'h7b: begin
                        // LD dd,(nn)
                        d_mcycles = 3'd5;
                        case (q_mcycle)
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
                                if (q_instruction[5:4] == 2'b11) begin
                                    Set_BusA_To = 4'b1000;
                                end else begin
                                    Set_BusA_To[2:1] = q_instruction[5:4];
                                    Set_BusA_To[0]   = 1;
                                end
                                Inc_WZ      = 1;
                                Set_Addr_To = aZI;
                            end
                            3'd5: begin
                                Read_To_Reg = 1;
                                if (q_instruction[5:4] == 2'b11) begin
                                    Set_BusA_To = 4'b1001;
                                end else begin
                                    Set_BusA_To[2:1] = q_instruction[5:4];
                                    Set_BusA_To[0] = 0;
                                end
                            end
                            default: begin end
                        endcase
                    end

                    8'h43,8'h53,8'h63,8'h73: begin
                        // LD (nn),dd
                        d_mcycles = 3'd5;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC = 1;
                                LDZ    = 1;
                            end
                            3'd3: begin
                                Set_Addr_To = aZI;
                                Inc_PC      = 1;
                                LDW         = 1;
                                if (q_instruction[5:4] == 2'b11) begin
                                    Set_BusB_To = 4'b1000;
                                end else begin
                                    Set_BusB_To[2:1] = q_instruction[5:4];
                                    Set_BusB_To[0]   = 1;
                                    Set_BusB_To[3]   = 0;
                                end
                            end
                            3'd4: begin
                                Inc_WZ      = 1;
                                Set_Addr_To = aZI;
                                Write_i     = 1;
                                if (q_instruction[5:4] == 2'b11) begin
                                    Set_BusB_To = 4'b1001;
                                end else begin
                                    Set_BusB_To[2:1] = q_instruction[5:4];
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
                        d_mcycles = 3'd4;
                        case (q_mcycle)
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
                                if (!q_instruction[3]) begin
                                    IncDec_16 = 4'b0110;
                                    // IX
                                end else begin
                                    IncDec_16 = 4'b1110;
                                end
                            end
                            3'd3: begin
                                is_instr_bt    = 1;
                                tstates = 3'd5;
                                Write_i = 1;
                                if (!q_instruction[3]) begin
                                    IncDec_16 = 4'b0101;
                                    // DE
                                end else begin
                                    IncDec_16 = 4'b1101;
                                end
                                No_PC = 1;
                            end
                            3'd4: begin
                                NoRead_i = 1;
                                tstates  = 3'd5;
                            end
                            default: begin end
                        endcase
                    end

                    8'ha1,8'ha9,8'hb1,8'hb9: begin
                        // CPI, CPD, CPIR, CPDR
                        d_mcycles = 3'd4;
                        case (q_mcycle)
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
                                if (!q_instruction[3]) begin
                                    IncDec_16 = 4'b0110;
                                end
                                else begin
                                    IncDec_16 = 4'b1110;
                                end
                                No_PC = 1;
                            end
                            3'd3: begin
                                NoRead_i = 1;
                                is_instr_bc     = 1;
                                tstates  = 3'd5;
                                No_PC    = 1;
                            end
                            3'd4: begin
                                NoRead_i = 1;
                                tstates  = 3'd5;
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1: begin
                                No_PC = 1;
                            end
                            3'd2: begin
                                NoRead_i         = 1;
                                ALU_Op           = 4'b0001;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                Set_BusA_To[2:0] = 3'd5;
                                case (q_instruction[5:4])
                                    2'b00,2'b01,2'b10: begin
                                        Set_BusB_To[2:1] = q_instruction[5:4];
                                        Set_BusB_To[0]   = 1;
                                    end
                                    default: begin
                                        Set_BusB_To = 4'b1000;
                                    end
                                endcase
                                tstates = 3'd4;
                                SetWZ   = 2'b11;
                                No_PC   = 1;
                            end
                            3'd3: begin
                                NoRead_i         = 1;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                ALU_Op           = 4'b0001;
                                Set_BusA_To[2:0] = 3'd4;
                                case (q_instruction[5:4])
                                    2'b00,2'b01,2'b10: begin
                                        Set_BusB_To[2:1] = q_instruction[5:4];
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1: begin
                                No_PC = 1;
                            end
                            3'd2: begin
                                NoRead_i         = 1;
                                ALU_Op           = 4'b0011;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                Set_BusA_To[2:0] = 3'd5;
                                case (q_instruction[5:4])
                                    2'b00,2'b01,2'b10: begin
                                        Set_BusB_To[2:1] = q_instruction[5:4];
                                        Set_BusB_To[0]   = 1;
                                    end
                                    default: begin
                                        Set_BusB_To = 4'b1000;
                                    end
                                endcase
                                tstates = 3'd4;
                                SetWZ   = 2'b11;
                                No_PC   = 1;
                            end
                            3'd3: begin
                                NoRead_i         = 1;
                                ALU_Op           = 4'b0011;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                Set_BusA_To[2:0] = 3'd4;
                                case (q_instruction[5:4])
                                    2'b00,2'b01,2'b10: begin
                                        Set_BusB_To[2:1] = q_instruction[5:4];
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
                        d_mcycles = 3'd4;
                        case (q_mcycle)
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
                                tstates     = 3'd4;
                                is_instr_rld       = 1;
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
                        d_mcycles = 3'd4;
                        case (q_mcycle)
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
                                tstates     = 3'd4;
                                is_instr_rrd       = 1;
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
                        d_mcycles = 3'd3;
                        case (q_mcycle)
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
                                is_instr_retn    = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'h40,8'h48,8'h50,8'h58,8'h60,8'h68,8'h70,8'h78: begin
                        // IN r,(C)
                        d_mcycles = 3'd2;
                        case (q_mcycle)
                            3'd1: begin
                                Set_Addr_To = aBC;
                                SetWZ       = 2'b01;
                            end
                            3'd2: begin
                                IORQ_i = 1;
                                if (q_instruction[5:3] != 3'd6) begin
                                    Read_To_Reg      = 1;
                                    Set_BusA_To[2:0] = q_instruction[5:3];
                                end
                                is_instr_inrc = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'h41,8'h49,8'h51,8'h59,8'h61,8'h69,8'h71,8'h79: begin
                        // OUT (C),r
                        // OUT (C),0
                        d_mcycles = 3'd2;

                        case (q_mcycle)
                            3'd1: begin
                                Set_Addr_To      = aBC;
                                SetWZ            = 2'b01;
                                Set_BusB_To[2:0] = q_instruction[5:3];
                                if (q_instruction[5:3] == 3'd6) begin
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
                        d_mcycles = 3'd4;
                        case (q_mcycle)
                            3'd1: begin
                                tstates      = 3'd5;
                                Set_Addr_To  = aBC;
                                Set_BusB_To  = 4'b1010;
                                Set_BusA_To  = 4'b0000;
                                Read_To_Reg  = 1;
                                Save_ALU     = 1;
                                ALU_Op       = 4'b0010;
                                SetWZ        = 2'b11;
                                IncDec_16[3] = q_instruction[3];
                            end
                            3'd2: begin
                                IORQ_i      = 1;
                                Set_BusB_To = 4'b0110;
                                Set_Addr_To = aXY;
                            end
                            3'd3: begin
                                if (!q_instruction[3]) begin
                                    IncDec_16 = 4'b0110;
                                end
                                else begin
                                    IncDec_16 = 4'b1110;
                                end
                                Write_i = 1;
                                is_instr_btr   = 1;
                            end
                            3'd4: begin
                                NoRead_i = 1;
                                tstates  = 3'd5;
                            end
                            default: begin end
                        endcase
                    end

                    8'ha3,8'hab,8'hb3,8'hbb: begin
                        // OUTI, OUTD, OTIR, OTDR
                        d_mcycles = 3'd4;
                        case (q_mcycle)
                            3'd1: begin
                                tstates     = 3'd5;
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
                                IncDec_16[3] = q_instruction[3];
                            end
                            3'd3: begin
                                if (!q_instruction[3]) begin
                                    IncDec_16 = 4'b0110;
                                end
                                else begin
                                    IncDec_16 = 4'b1110;
                                end
                                IORQ_i  = 1;
                                Write_i = 1;
                                is_instr_btr   = 1;
                            end
                            3'd4: begin
                                NoRead_i = 1;
                                tstates  = 3'd5;
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
            if (q_mcycle == 3'd1) begin
            end else begin
                tstates = 3'd3;
            end
        end

        if (q_mcycle == 3'd6) begin
            Inc_PC = 1;
            if (Mode == 1) begin
                Set_Addr_To      = aXY;
                tstates          = 3'd4;
                Set_BusB_To[2:0] = ir_sss;
                Set_BusB_To[3]   = 0;
            end
            if (q_instruction == 8'h36 || q_instruction == 8'hcb) begin
                Set_Addr_To = aNone;
            end
            if (!(q_instruction == 8'h36 || q_prefix == PrefixCB)) begin
                No_PC = 1;
            end
        end

        if (q_mcycle == 3'd7) begin
            if (Mode == 0) begin
                tstates = 3'd5;
            end
            if (q_prefix != PrefixCB) begin
                Set_Addr_To = aXY;
            end
            Set_BusB_To[2:0] = ir_sss;
            Set_BusB_To[3]   = 0;
            if (q_instruction == 8'h36 || q_prefix == PrefixCB) begin
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
    always @* case (q_instruction[5:3])
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
    wire       alu_cin           = (alu_do_sub ^ ((!ALU_Op_r[2] & ALU_Op_r[0]) & q_reg_f[Flag_C]));
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
        F_Out       = q_reg_f;
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

                F_Out[Flag_Z] = Z16_r ? q_reg_f[Flag_Z] : (alu_result == 8'b0);
                F_Out[Flag_S] = alu_result[7];

                case (ALU_Op_r[2:0])
                    3'd0, 3'd1, 3'd2, 3'd3, 3'd7: begin   // ADD, ADC, SUB, SBC, CP
                    end
                    default: begin
                        F_Out[Flag_P] = !(alu_result[0] ^ alu_result[1] ^ alu_result[2] ^ alu_result[3] ^ alu_result[4] ^ alu_result[5] ^ alu_result[6] ^ alu_result[7]);
                    end
                endcase

                if (Arith16_r) begin
                    F_Out[Flag_S] = q_reg_f[Flag_S];
                    F_Out[Flag_Z] = q_reg_f[Flag_Z];
                    F_Out[Flag_P] = q_reg_f[Flag_P];
                end
            end

            4'b1100: begin  // DAA
                F_Out[Flag_H] = q_reg_f[Flag_H];
                F_Out[Flag_C] = q_reg_f[Flag_C];
                alu_daa_tmp   = {1'b0, BusA};

                if (!q_reg_f[Flag_N]) begin
                    // After addition
                    // A_low > 9 or H = 1
                    if (alu_daa_tmp[3:0] > 4'd9 || q_reg_f[Flag_H]) begin
                        F_Out[Flag_H] = (alu_daa_tmp[3:0] > 4'd9);
                        alu_daa_tmp   = alu_daa_tmp + 9'd6;
                    end

                    // new A_high > 9 or C = 1
                    if (alu_daa_tmp[8:4] > 5'd9 || q_reg_f[Flag_C])
                        alu_daa_tmp = alu_daa_tmp + 9'h60;

                end else begin
                    // After subtraction
                    if (alu_daa_tmp[3:0] > 4'd9 || q_reg_f[Flag_H]) begin
                        if (alu_daa_tmp[3:0] > 4'd5)
                            F_Out[Flag_H] = 0;

                        alu_daa_tmp[7:0] = alu_daa_tmp[7:0] - 8'd6;
                    end

                    if (BusA > 8'd153 || q_reg_f[Flag_C])
                        alu_daa_tmp = alu_daa_tmp - 9'h160;
                end

                alu_result    = alu_daa_tmp[7:0];
                F_Out[Flag_X] = alu_daa_tmp[3];
                F_Out[Flag_Y] = alu_daa_tmp[5];
                F_Out[Flag_C] = q_reg_f[Flag_C] | alu_daa_tmp[8];
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
                if (q_instruction[2:0] == 3'd6 || XY_State != 2'b00) begin
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
                case (q_instruction[5:3])
                    3'd0:    begin alu_result = {BusA[6:0],       BusA[7]};         F_Out[Flag_C] = BusA[7]; end // RLC
                    3'd2:    begin alu_result = {BusA[6:0],       q_reg_f[Flag_C]}; F_Out[Flag_C] = BusA[7]; end // RL
                    3'd1:    begin alu_result = {BusA[0],         BusA[7:1]};       F_Out[Flag_C] = BusA[0]; end // RRC
                    3'd3:    begin alu_result = {q_reg_f[Flag_C], BusA[7:1]};       F_Out[Flag_C] = BusA[0]; end // RR
                    3'd4:    begin alu_result = {BusA[6:0],       1'b0};            F_Out[Flag_C] = BusA[7]; end // SLA
                    3'd6:    begin alu_result = {BusA[6:0],       1'b1};            F_Out[Flag_C] = BusA[7]; end // SLL (Undocumented) / SWAP
                    3'd5:    begin alu_result = {BusA[7],         BusA[7:1]};       F_Out[Flag_C] = BusA[0]; end // SRA
                    default: begin alu_result = {1'b0,            BusA[7:1]};       F_Out[Flag_C] = BusA[0]; end // SRL
                endcase

                F_Out[Flag_H] = 0;
                F_Out[Flag_N] = 0;
                F_Out[Flag_X] = alu_result[3];
                F_Out[Flag_Y] = alu_result[5];
                F_Out[Flag_S] = alu_result[7];
                F_Out[Flag_Z] = (alu_result == 8'b0);
                F_Out[Flag_P] = !(alu_result[0] ^ alu_result[1] ^ alu_result[2] ^ alu_result[3] ^ alu_result[4] ^ alu_result[5] ^ alu_result[6] ^ alu_result[7]);

                if (q_prefix == PrefixNone) begin
                    F_Out[Flag_P] = q_reg_f[Flag_P];
                    F_Out[Flag_S] = q_reg_f[Flag_S];
                    F_Out[Flag_Z] = q_reg_f[Flag_Z];
                end
            end

            default: begin end
        endcase
    end

    assign ALU_Q = alu_result;

    //------------------------------------------------------------------------

    assign Really_Wait     = bus_wait & (Write_i | ~NoRead_i);
    assign T_Res           = q_tstate == tstates;
    assign NextIs_XY_Fetch = XY_State != 2'b00 && !XY_Ind && (Set_Addr_To == aXY || (q_mcycle == 3'd1 && q_instruction == 8'hcb) || (q_mcycle == 3'd1 && q_instruction == 8'h36));
    assign Save_Mux        = ExchangeRp ? BusB : !Save_ALU_r ? DI_Reg : ALU_Q;

    always @(posedge clk or posedge reset) begin : p1
        reg [7:0] n;
        reg [8:0] ioq;
        reg [8:0] temp_c;
        reg [4:0] temp_h;

        if (reset) begin
            q_reg_pc      <= 0;
            q_reg_a       <= 8'hFF;
            q_reg_f       <= 8'hFF;
            q_reg_a_alt   <= 8'hFF;
            q_reg_f_alt   <= 8'hFF;
            q_reg_i       <= 0;
            q_reg_r       <= 0;
            q_reg_sp      <= 16'hFFFF;

            bus_addr      <= 0;
            WZ            <= 0;
            q_instruction <= 0;
            q_prefix      <= 0;
            XY_State      <= 0;
            IStatus       <= 0;
            q_mcycles     <= 0;
            bus_wrdata    <= 0;
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
            if (clk_en) begin
                ALU_Op_r      <= 4'b0000;
                Save_ALU_r    <= 0;
                Read_To_Reg_r <= 5'b00000;
                q_mcycles       <= d_mcycles;

                if (LDHLSP && q_mcycle == 3'd3 && q_tstate == 1) begin
                    temp_c = {1'b0, q_reg_sp[7:0]} + {1'b0, Save_Mux};
                    temp_h = {1'b0, q_reg_sp[3:0]} + {1'b0, Save_Mux[3:0]};
                    q_reg_f[Flag_Z] <= 0;
                    q_reg_f[Flag_N] <= 0;
                    q_reg_f[Flag_H] <= temp_h[4];
                    q_reg_f[Flag_C] <= temp_c[8];
                end
                if (ADDSPdd && q_tstate == 1) begin
                    temp_c = {1'b0, q_reg_sp[7:0]} + {1'b0, Save_Mux};
                    temp_h = {1'b0, q_reg_sp[3:0]} + {1'b0, Save_Mux[3:0]};
                    q_reg_f[Flag_Z] <= 0;
                    q_reg_f[Flag_N] <= 0;
                    q_reg_f[Flag_H] <= temp_h[4];
                    q_reg_f[Flag_C] <= temp_c[8];
                end
                if (IMode != 2'b11) begin
                    IStatus <= IMode;
                end
                Arith16_r   <= Arith16;
                PreserveC_r <= PreserveC;
                Z16_r       <= (q_prefix == PrefixED && !ALU_Op[2] && ALU_Op[0] && q_mcycle == 3'd3);

                if (q_mcycle == 3'd1 && !q_tstate[2]) begin
                    if (q_tstate == 2 && !bus_wait) begin
                        bus_addr <= {q_reg_i, q_reg_r};
                        q_reg_r[6:0]  <= q_reg_r[6:0] + 7'd1;
                        if (!Jump && !Call && !q_nmi_cycle && !q_irq_cycle && !(q_halt || Halt)) begin
                            q_reg_pc <= q_reg_pc + 1;
                        end
                        if (q_irq_cycle && IStatus == 2'b01) begin
                            q_instruction <= 8'hFF;
                        end else if (q_halt || (q_irq_cycle && IStatus == 2'b10) || q_nmi_cycle) begin
                            q_instruction <= 8'h00;
                        end else begin
                            q_instruction <= DInst;
                        end
                        if (q_irq_cycle && IStatus == 2'b10) begin
                            // IM2 vector address low byte from bus
                            WZ[7:0] <= DInst;
                        end

                        q_prefix <= PrefixNone;
                        if (d_prefix != PrefixNone) begin
                            if (d_prefix == PrefixDD_FD) begin
                                if (q_instruction[5]) begin
                                    XY_State <= 2'b10;
                                end else begin
                                    XY_State <= 2'b01;
                                end
                            end else begin
                                if (d_prefix == PrefixED) begin
                                    XY_State <= 2'b00;
                                    XY_Ind   <= 0;
                                end
                                q_prefix <= d_prefix;
                            end
                        end else begin
                            XY_State <= 2'b00;
                            XY_Ind   <= 0;
                        end
                    end
                end
                else begin
                    if (q_mcycle == 3'd6) begin
                        XY_Ind <= 1;
                        if (d_prefix == PrefixCB) begin
                            q_prefix <= d_prefix;
                        end
                    end
                    if (T_Res) begin
                        BTR_r <= (is_instr_bt | is_instr_bc | is_instr_btr) & ~No_BTR;
                        if (Jump) begin
                            bus_addr <= {DI_Reg, WZ[7:0]};
                            q_reg_pc       <= {DI_Reg, WZ[7:0]};
                        end
                        else if (JumpXY) begin
                            bus_addr <= RegBusC;
                            q_reg_pc       <= RegBusC;
                        end
                        else if (Call || RstP) begin
                            bus_addr <= WZ;
                            q_reg_pc       <= WZ;
                        end
                        else if (q_mcycle == q_mcycles && q_nmi_cycle) begin
                            bus_addr <= 16'h0066;
                            q_reg_pc       <= 16'h0066;
                        end
                        else if (q_mcycle == 3'd3 && q_irq_cycle && IStatus == 2'b10) begin
                            bus_addr <= {q_reg_i, WZ[7:0]};
                            q_reg_pc       <= {q_reg_i, WZ[7:0]};
                        end
                        else begin
                            case (Set_Addr_To)
                            aXY: begin
                                if (XY_State == 2'b00) begin
                                    bus_addr <= RegBusC;
                                end
                                else begin
                                    if (NextIs_XY_Fetch) begin
                                        bus_addr <= q_reg_pc;
                                    end
                                    else begin
                                        bus_addr <= WZ;
                                    end
                                end
                            end
                            aIOA: begin
                                bus_addr <= {q_reg_a, DI_Reg};
                                WZ       <= {q_reg_a, DI_Reg} + 16'd1;
                            end
                            aSP: begin
                                bus_addr <= q_reg_sp;
                            end
                            aBC: begin
                                bus_addr <= RegBusC;
                                if (SetWZ == 2'b01) begin
                                    WZ <= RegBusC + 1'b1;
                                end
                                if (SetWZ == 2'b10) begin
                                    WZ[7:0] <= RegBusC[7:0] + 1'b1;
                                    WZ[15:8] <= q_reg_a;
                                end
                            end
                            aDE: begin
                                bus_addr <= RegBusC;
                                if (SetWZ == 2'b10) begin
                                    WZ[7:0] <= RegBusC[7:0] + 1'b1;
                                    WZ[15:8] <= q_reg_a;
                                end
                            end
                            aZI: begin
                                if (Inc_WZ) begin
                                    bus_addr <= (WZ) + 1;
                                end
                                else begin
                                    bus_addr <= {DI_Reg, WZ[7:0]};
                                    if (SetWZ == 2'b10) begin
                                        WZ[7:0] <= WZ[7:0] + 1'b1;
                                        WZ[15:8] <= q_reg_a;
                                    end
                                end
                            end
                            default: begin
                                if (q_prefix == PrefixED && q_instruction[7:4] == 4'hB && q_instruction[2:1] == 2'b01 && q_mcycle == 3 && !No_BTR) begin
                                    // INIR, INDR, OTIR, OTDR
                                    bus_addr <= RegBusA_r;
                                end
                                else if (!No_PC || No_BTR || (is_instr_djnz && IncDecZ)) begin
                                    bus_addr <= q_reg_pc;
                                end
                            end
                            endcase
                        end
                        if (SetWZ == 2'b11) begin
                            WZ <= ID16;
                        end
                        Save_ALU_r <= Save_ALU;
                        ALU_Op_r <= ALU_Op;
                        if (is_instr_cpl) begin
                            // CPL
                            q_reg_a         <= ~q_reg_a;
                            q_reg_f[Flag_Y] <= ~q_reg_a[5];
                            q_reg_f[Flag_H] <= 1;
                            q_reg_f[Flag_X] <= ~q_reg_a[3];
                            q_reg_f[Flag_N] <= 1;
                        end
                        if (is_instr_ccf) begin
                            // CCF
                            q_reg_f[Flag_C] <= ~q_reg_f[Flag_C];
                            q_reg_f[Flag_Y] <= q_reg_a[5];
                            q_reg_f[Flag_H] <= q_reg_f[Flag_C];
                            q_reg_f[Flag_X] <= q_reg_a[3];
                            q_reg_f[Flag_N] <= 0;
                        end
                        if (is_instr_scf) begin
                            // SCF
                            q_reg_f[Flag_C] <= 1;
                            q_reg_f[Flag_Y] <= q_reg_a[5];
                            q_reg_f[Flag_H] <= 0;
                            q_reg_f[Flag_X] <= q_reg_a[3];
                            q_reg_f[Flag_N] <= 0;
                        end
                    end
                    if ((q_tstate == 2 && !Really_Wait && is_instr_btr && q_instruction[0]) || (q_tstate == 1 && is_instr_btr && !q_instruction[0])) begin
                        ioq = ({1'b0,DI_Reg}) + ({1'b0,ID16[7:0]});
                        q_reg_f[Flag_N] <= DI_Reg[7];
                        q_reg_f[Flag_C] <= ioq[8];
                        q_reg_f[Flag_H] <= ioq[8];
                        ioq = (ioq & 9'b000000111) ^ ({1'b0,BusA});
                        q_reg_f[Flag_P] <= ~(ioq[0] ^ ioq[1] ^ ioq[2] ^ ioq[3] ^ ioq[4] ^ ioq[5] ^ ioq[6] ^ ioq[7]);
                    end
                    if (q_tstate == 2 && !Really_Wait) begin
                        if (q_prefix == PrefixCB && q_mcycle == 3'd7) begin
                            q_instruction <= DInst;
                        end
                        if (JumpE) begin
                            q_reg_pc <= q_reg_pc + {{8{DI_Reg[7]}}, DI_Reg};
                            WZ <= q_reg_pc + {{8{DI_Reg[7]}}, DI_Reg};
                        end
                        else if (Inc_PC) begin
                            q_reg_pc <= q_reg_pc + 16'd1;
                        end
                        if (BTR_r) begin
                            q_reg_pc <= q_reg_pc - 16'd2;
                        end
                        if (RstP) begin
                            WZ <= {16{1'b0}};
                            WZ[5:3] <= q_instruction[5:3];
                        end
                    end
                    if (q_tstate == 3 && q_mcycle == 3'd6) begin
                        WZ <= RegBusC + {{8{DI_Reg[7]}}, DI_Reg};
                    end
                    if (q_mcycle == 3'd3 && q_tstate == 4 && !No_BTR) begin
                        if (is_instr_bt || is_instr_bc) begin
                            WZ <= (q_reg_pc) - 1'b1;
                        end
                    end
                    if ((q_tstate == 2 && !Really_Wait) || (q_tstate == 4 && q_mcycle == 3'd1)) begin
                        if (IncDec_16[2:0] == 3'd7) begin
                            if (IncDec_16[3]) begin
                                q_reg_sp <= q_reg_sp - 1;
                            end
                            else begin
                                q_reg_sp <= q_reg_sp + 1;
                            end
                        end
                    end
                    if (ADDSPdd && q_tstate == 2) begin
                        WZ       <= q_reg_sp;
                        q_reg_sp <= q_reg_sp + {{8{Save_Mux[7]}}, Save_Mux};
                    end
                    if (LDSPHL) begin
                        q_reg_sp <= RegBusC;
                    end
                    if (ExchangeAF) begin
                        q_reg_a_alt <= q_reg_a;
                        q_reg_a     <= q_reg_a_alt;
                        q_reg_f_alt <= q_reg_f;
                        q_reg_f     <= q_reg_f_alt;
                    end
                    if (ExchangeRS) begin
                        Alternate <= ~Alternate;
                    end
                end
                if (q_tstate == 3) begin
                    if (LDZ)  WZ[7:0]  <= DI_Reg;
                    if (LDW)  WZ[15:8] <= DI_Reg;
                    if (Special_LD[2]) begin
                        case (Special_LD[1:0])
                        2'b00: begin
                            q_reg_a         <= q_reg_i;
                            q_reg_f[Flag_P] <= IntE_FF2;
                            q_reg_f[Flag_S] <= q_reg_i[7];
                            q_reg_f[Flag_Z] <= (q_reg_i == 8'h00);
                            q_reg_f[Flag_Y] <= q_reg_i[5];
                            q_reg_f[Flag_H] <= 0;
                            q_reg_f[Flag_X] <= q_reg_i[3];
                            q_reg_f[Flag_N] <= 0;
                        end
                        2'b01: begin
                            q_reg_a <= q_reg_r;
                            q_reg_f[Flag_P] <= IntE_FF2;
                            q_reg_f[Flag_S] <= q_reg_r[7];
                            q_reg_f[Flag_Z] <= (q_reg_r == 8'h00);
                            q_reg_f[Flag_Y] <= q_reg_r[5];
                            q_reg_f[Flag_H] <= 0;
                            q_reg_f[Flag_X] <= q_reg_r[3];
                            q_reg_f[Flag_N] <= 0;
                        end
                        2'b10: begin
                            q_reg_i <= q_reg_a;
                        end
                        default: begin
                            q_reg_r <= q_reg_a;
                        end
                        endcase
                    end
                end
                if ((!is_instr_djnz && Save_ALU_r) || ALU_Op_r == 4'b1001) begin
                    q_reg_f[7:1] <= F_Out[7:1];
                    if (!PreserveC_r) begin
                        q_reg_f[Flag_C] <= F_Out[0];
                    end
                end
                if (T_Res && is_instr_inrc) begin
                    q_reg_f[Flag_H] <= 0;
                    q_reg_f[Flag_N] <= 0;
                    q_reg_f[Flag_X] <= DI_Reg[3];
                    q_reg_f[Flag_Y] <= DI_Reg[5];
                    q_reg_f[Flag_Z] <= (DI_Reg[7:0] == 8'h00);
                    q_reg_f[Flag_S] <= DI_Reg[7];
                    q_reg_f[Flag_P] <= ~(DI_Reg[0] ^ DI_Reg[1] ^ DI_Reg[2] ^ DI_Reg[3] ^ DI_Reg[4] ^ DI_Reg[5] ^ DI_Reg[6] ^ DI_Reg[7]);
                end
                if (q_tstate == 1 && !q_auto_wait) begin
                    // Keep D0 from M3 for RLD/RRD (Sorgelig)
                    I_RXDD <= is_instr_rld | is_instr_rrd;
                    if (!I_RXDD) begin
                        bus_wrdata <= BusB;
                    end
                    if (is_instr_rld) begin
                        bus_wrdata <= {BusB[3:0], BusA[3:0]};
                    end
                    if (is_instr_rrd) begin
                        bus_wrdata <= {BusA[3:0], BusB[7:4]};
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
                if (q_tstate == 1 && is_instr_bt) begin
                    q_reg_f[Flag_X] <= ALU_Q[3];
                    q_reg_f[Flag_Y] <= ALU_Q[1];
                    q_reg_f[Flag_H] <= 0;
                    q_reg_f[Flag_N] <= 0;
                end
                if (q_tstate == 1 && is_instr_bc) begin
                    n = ALU_Q - ({7'b0, F_Out[Flag_H]});
                    q_reg_f[Flag_X] <= n[3];
                    q_reg_f[Flag_Y] <= n[1];
                end
                if (is_instr_bc || is_instr_bt) begin
                    q_reg_f[Flag_P] <= IncDecZ;
                end
                if ((q_tstate == 1 && !Save_ALU_r && !q_auto_wait) || (Save_ALU_r && ALU_Op_r != 4'b0111)) begin
                    case (Read_To_Reg_r)
                        5'b10111: q_reg_a        <= Save_Mux;
                        5'b10110: bus_wrdata     <= Save_Mux;
                        5'b11000: q_reg_sp[7:0]  <= Save_Mux;
                        5'b11001: q_reg_sp[15:8] <= Save_Mux;
                        5'b11011: q_reg_f        <= Save_Mux;
                        default: begin end
                    endcase
                    if (XYbit_undoc) begin
                        bus_wrdata <= ALU_Q;
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
        if (clk_en) begin
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
            if (((JumpXY || LDSPHL) && XY_State != 2'b00) || q_mcycle == 3'd6) begin
                RegAddrC <= {XY_State[1], 2'b11};
            end
            if (is_instr_djnz && Save_ALU_r) begin
                IncDecZ <= F_Out[Flag_Z];
            end
            if ((q_tstate == 2 || (q_tstate == 3 && q_mcycle == 3'd1)) && IncDec_16[2:0] == 3'd4) begin
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

    wire [2:0] RegAddrA = (q_tstate == 2 || (q_tstate == 3 && q_mcycle == 3'd1 && IncDec_16[2])) && XY_State == 2'b00 ? {Alternate,IncDec_16[1:0]} : (q_tstate == 2 || (q_tstate == 3 && q_mcycle == 3'd1 && IncDec_16[2])) && IncDec_16[1:0] == 2'b10 ? {XY_State[1],2'b11} : ExchangeDH && q_tstate == 3 ? {Alternate,2'b10} : ExchangeDH && q_tstate == 4 ? {Alternate,2'b01} : ExchangeWH && XY_State == 2'b00 && q_tstate == 4 ? {Alternate,2'b10} : ExchangeWH && q_tstate == 4 ? {XY_State[1],2'b11} : LDHLSP && q_tstate == 4 ? 3'd2 : RegAddrA_r;
    wire [2:0] RegAddrB = ExchangeDH && q_tstate == 3 ? {Alternate,2'b01} : RegAddrB_r;
    assign ID16 = IncDec_16[3] ? (RegBusA) - 1 : (RegBusA) + 1;

    always @* begin
        RegWEH = 0;
        RegWEL = 0;
        if ((q_tstate == 1 && !Save_ALU_r && !q_auto_wait) || (Save_ALU_r && ALU_Op_r != 4'b0111)) begin
            case (Read_To_Reg_r)
                5'b10000,5'b10001,5'b10010,5'b10011,5'b10100,5'b10101: begin
                    RegWEH = ~Read_To_Reg_r[0];
                    RegWEL =  Read_To_Reg_r[0];
                end
                default: begin end
            endcase
        end
        if (ExchangeDH && (q_tstate == 3 || q_tstate == 4)) begin
            RegWEH = 1;
            RegWEL = 1;
        end
        if (((LDHLSP && q_mcycle == 3'd2) || ExchangeWH) && q_tstate == 4) begin
            RegWEH = 1;
            RegWEL = 1;
        end
        if (IncDec_16[2] && ((q_tstate == 2 && !Really_Wait && q_mcycle != 3'd1) || (q_tstate == 3 && q_mcycle == 3'd1))) begin
            case (IncDec_16[1:0])
                2'b00,2'b01,2'b10: begin
                    RegWEH = 1;
                    RegWEL = 1;
                end
                default: begin end
            endcase
        end
    end

    wire [15:0] TmpAddr2 = q_reg_sp + {{8{Save_Mux[7]}}, Save_Mux};
    always @* begin
        RegDIH = Save_Mux;
        RegDIL = Save_Mux;
        if (LDHLSP && q_mcycle == 3'd2 && q_tstate == 4) begin
            RegDIH = TmpAddr2[15:8];
            RegDIL = TmpAddr2[7:0];
        end
        if (ExchangeDH && q_tstate == 3) begin
            RegDIH = RegBusB[15:8];
            RegDIL = RegBusB[7:0];
        end
        if (ExchangeDH && q_tstate == 4) begin
            RegDIH = RegBusA_r[15:8];
            RegDIL = RegBusA_r[7:0];
        end
        if (ExchangeWH && q_tstate == 4) begin
            RegDIH = WZ[15:8];
            RegDIL = WZ[7:0];
        end
        if (IncDec_16[2] && ((q_tstate == 2 && q_mcycle != 3'd1) || (q_tstate == 3 && q_mcycle == 3'd1))) begin
            RegDIH = ID16[15:8];
            RegDIL = ID16[7:0];
        end
    end

    //------------------------------------------------------------------------
    // Register file
    //------------------------------------------------------------------------
    reg [7:0] RegsH [7:0] /* synthesis syn_ramstyle = "distributed_ram" */;
    reg [7:0] RegsL [7:0] /* synthesis syn_ramstyle = "distributed_ram" */;

    always @(posedge clk) if (clk_en && RegWEH) RegsH[RegAddrA] <= RegDIH;
    always @(posedge clk) if (clk_en && RegWEL) RegsL[RegAddrA] <= RegDIL;

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
        if (clk_en) begin
            case (Set_BusB_To)
                4'b0111: BusB <= q_reg_a;
                4'b0000,
                4'b0001,
                4'b0010,
                4'b0011,
                4'b0100,
                4'b0101: BusB <= Set_BusB_To[0] ? RegBusB[7:0] : RegBusB[15:8];
                4'b0110: BusB <= DI_Reg;
                4'b1000: BusB <= q_reg_sp[7:0];
                4'b1001: BusB <= q_reg_sp[15:8];
                4'b1010: BusB <= 8'h01;
                4'b1011: BusB <= q_reg_f;
                4'b1100: BusB <= q_reg_pc[7:0];
                4'b1101: BusB <= q_reg_pc[15:8];
                4'b1110: BusB <= 8'h00;
                default: BusB <= 8'h00;
            endcase

            case (Set_BusA_To)
                4'b0111: BusA <= q_reg_a;
                4'b0000,
                4'b0001,
                4'b0010,
                4'b0011,
                4'b0100,
                4'b0101: BusA <= Set_BusA_To[0] ? RegBusA[7:0] : RegBusA[15:8];
                4'b0110: BusA <= DI_Reg;
                4'b1000: BusA <= q_reg_sp[7:0];
                4'b1001: BusA <= q_reg_sp[15:8];
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
    assign MC       = q_mcycle;
    assign TS       = q_tstate;
    assign DI_Reg   = DI;
    assign IntCycle = q_irq_cycle;
    assign IORQ     = IORQ_i;
    assign NoRead   = NoRead_i;
    assign Write    = Write_i;

    //------------------------------------------------------------------------
    // Main state machine
    //------------------------------------------------------------------------
    reg q_nmi;
    reg q_nmi_pending;
    reg q2_auto_wait;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q_mcycle      <= 3'd1;
            q_tstate      <= 3'd0;
            Pre_XY_F_M    <= 3'd0;
            q_halt        <= 0;
            q_nmi_cycle   <= 0;
            q_irq_cycle   <= 0;
            IntE_FF1      <= 0;
            IntE_FF2      <= 0;
            No_BTR        <= 0;
            q_auto_wait   <= 0;
            q2_auto_wait  <= 0;
            q_nmi_pending <= 0;
            q_nmi         <= 0;

        end else begin
            q_nmi <= nmi;
            if (nmi && !q_nmi) begin
                q_nmi_pending <= 1;
            end

            if (clk_en) begin
                q2_auto_wait <= q_auto_wait;

                if (T_Res) begin
                    q_auto_wait  <= 0;
                    q2_auto_wait <= 0;
                end else begin
                    q_auto_wait  <= d_auto_wait | IORQ_i;
                end

                No_BTR <=
                    (is_instr_bt  & (~q_instruction[4] |                    ~q_reg_f[Flag_P])) |
                    (is_instr_bc  & (~q_instruction[4] |  q_reg_f[Flag_Z] | ~q_reg_f[Flag_P])) |
                    (is_instr_btr & (~q_instruction[4] |  q_reg_f[Flag_Z]));

                if (q_tstate == 2) begin
                    if (SetEI) begin
                        IntE_FF1 <= 1;
                        IntE_FF2 <= 1;
                    end

                    if (is_instr_retn) begin
                        IntE_FF1 <= IntE_FF2;
                    end
                end

                if (q_tstate == 3 && SetDI) begin
                    IntE_FF1 <= 0;
                    IntE_FF2 <= 0;
                end

                if (q_irq_cycle || q_nmi_cycle) begin
                    q_halt <= 0;
                end

                if (q_tstate == 2 && Really_Wait) begin
                    // Wait

                end else if (T_Res) begin
                    if (Halt) begin
                        q_halt <= 1;
                    end
                    q_tstate <= 3'd1;

                    if (NextIs_XY_Fetch) begin
                        q_mcycle     <= 3'd6;
                        Pre_XY_F_M <= q_mcycle;
                        if (q_instruction == 8'h36 && Mode == 0) begin
                            Pre_XY_F_M <= 3'd2;
                        end

                    end else if (q_mcycle == 3'd7 || (q_mcycle == 3'd6 && Mode == 1 && q_prefix != PrefixCB)) begin
                        q_mcycle <= (Pre_XY_F_M) + 1;

                    end else if (q_mcycle == q_mcycles || No_BTR || (q_mcycle == 3'd2 && is_instr_djnz && IncDecZ)) begin
                        q_mcycle    <= 3'd1;
                        q_irq_cycle <= 0;
                        q_nmi_cycle <= 0;
                        if (q_nmi_pending && d_prefix == PrefixNone) begin
                            q_nmi_pending <= 0;
                            q_nmi_cycle   <= 1;
                            IntE_FF1      <= 0;

                        end else if (IntE_FF1 && irq && d_prefix == PrefixNone && !SetEI) begin
                            q_irq_cycle <= 1;
                            IntE_FF1    <= 0;
                            IntE_FF2    <= 0;
                        end

                    end else begin
                        q_mcycle <= q_mcycle + 1;
                    end

                end else begin
                    if (!(d_auto_wait && !q2_auto_wait)) begin
                        q_tstate <= q_tstate + 1;
                    end
                end
            end
        end
    end

    assign d_auto_wait = q_irq_cycle && q_mcycle == 3'd1;

endmodule
