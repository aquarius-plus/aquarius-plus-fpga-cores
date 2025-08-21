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
    output wire [15:0] bus_addr,
    input  wire  [7:0] DInst,
    input  wire  [7:0] DI,
    output wire  [7:0] bus_wrdata,
    output wire  [2:0] mcycle,
    output wire  [2:0] tstate,
    output wire        irq_cycle);

    parameter [31:0] Mode = 0;  // 0 => Z80, 1 => Fast Z80

    reg  [15:0] q_bus_addr;
    reg   [7:0] q_bus_wrdata;
    assign bus_addr   = q_bus_addr;
    assign bus_wrdata = q_bus_wrdata;


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

    wire [15:0] reg_bus_a;
    wire [15:0] reg_bus_b;
    wire [15:0] reg_bus_c;
    reg   [2:0] q_reg_idx_a;
    reg   [2:0] q_reg_idx_b;
    reg   [2:0] q_reg_idx_c;
    reg         reg_wren_h;
    reg         reg_wren_l;
    reg         q_regs_alt;  // Use alternate registers
    reg  [15:0] q_memptr;
    reg   [7:0] q_instruction;
    reg   [1:0] q_prefix;
    reg  [15:0] q_reg_bus_a;
    wire [15:0] incdec16_result;
    wire  [7:0] Save_Mux;
    reg   [2:0] q_tstate;
    reg   [2:0] q_mcycle;
    reg         q_int_en1;
    reg         q_int_en2;
    reg         q_halt;
    reg   [1:0] q_im;       // Interrupt mode
    wire  [7:0] DI_Reg;
    wire        T_Res;
    reg   [1:0] q_xy_state;
    wire        NextIs_XY_Fetch;
    reg         XY_Ind;
    reg         q_no_btr;
    reg         q_btr;
    wire        d_auto_wait;
    reg         q_auto_wait;
    reg         q_inc_dec_is_zero;
    reg   [7:0] bus_b;
    reg   [7:0] bus_a;
    wire  [7:0] ALU_Q;
    reg   [7:0] F_Out;
    reg   [4:0] q_read_to_reg;
    reg         q_arith16;
    reg         q_z16;
    reg   [3:0] q_alu_op;
    reg         q_save_alu;
    reg         q_preserve_c;
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
    reg   [3:0] d_alu_op;
    reg         Save_ALU;
    reg         d_preserve_c;
    reg         d_arith16;
    reg   [2:0] Set_Addr_To;
    reg         Jump;
    reg         JumpE;
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
    reg         ExchangeRp;
    reg         ExchangeWH;

    reg         is_instr_bc;
    reg         is_instr_bt;
    reg         is_instr_btr;


    reg   [1:0] SetWZ;
    reg   [1:0] d_im;
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

    reg         is_instr_ccf;
    reg         is_instr_cpl;
    reg         is_instr_di;
    reg         is_instr_djnz;
    reg         is_instr_ei;
    reg         is_instr_ex_af;
    reg         is_instr_ex_de_hl;
    reg         is_instr_exx;
    reg         is_instr_halt;
    reg         is_instr_inrc;
    reg         is_instr_jp_ind_hl;
    reg         is_instr_retn;
    reg         is_instr_rld;
    reg         is_instr_rrd;
    reg         is_instr_scf;

    always @* begin
        d_mcycles          = 3'd1;
        tstates            = (q_mcycle == 3'd1) ? 3'd4 : 3'd3;
        d_prefix           = PrefixNone;
        Inc_PC             = 0;
        Inc_WZ             = 0;
        IncDec_16          = 4'b0000;
        Read_To_Acc        = 0;
        Read_To_Reg        = 0;
        Set_BusB_To        = 4'b0000;
        Set_BusA_To        = 4'b0000;
        d_alu_op           = {1'b0, q_instruction[5:3]};
        Save_ALU           = 0;
        d_preserve_c       = 0;
        d_arith16          = 0;
        IORQ_i             = 0;
        Set_Addr_To        = aNone;
        Jump               = 0;
        JumpE              = 0;
        Call               = 0;
        RstP               = 0;
        LDZ                = 0;
        LDW                = 0;
        LDSPHL             = 0;
        LDHLSP             = 0;
        ADDSPdd            = 0;
        Special_LD         = 3'd0;
        ExchangeRp         = 0;
        ExchangeWH         = 0;

        is_instr_bc        = 0;
        is_instr_bt        = 0;
        is_instr_btr       = 0;

        is_instr_ccf       = 0;
        is_instr_cpl       = 0;
        is_instr_di        = 0;
        is_instr_djnz      = 0;
        is_instr_ei        = 0;
        is_instr_ex_af     = 0;
        is_instr_ex_de_hl  = 0;
        is_instr_exx       = 0;
        is_instr_halt      = 0;
        is_instr_inrc      = 0;
        is_instr_jp_ind_hl = 0;
        is_instr_retn      = 0;
        is_instr_rld       = 0;
        is_instr_rrd       = 0;
        is_instr_scf       = 0;

        d_im               = q_im;
        NoRead_i           = 0;
        Write_i            = 0;
        No_PC              = 0;
        XYbit_undoc        = 0;
        SetWZ              = 2'b00;

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
                    8'h78,8'h79,8'h7a,8'h7b,8'h7c,8'h7d,8'h7f: begin    // LD r,r'
                        Set_BusB_To[2:0] = ir_sss;
                        ExchangeRp       = 1;
                        Set_BusA_To[2:0] = ir_ddd;
                        Read_To_Reg      = 1;
                    end

                    8'h06,8'h0e,8'h16,8'h1e,8'h26,8'h2e,8'h3e: begin    // LD r,n
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

                    8'h46,8'h4e,8'h56,8'h5e,8'h66,8'h6e,8'h7e: begin    // LD r,(HL)
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

                    8'h70,8'h71,8'h72,8'h73,8'h74,8'h75,8'h77: begin    // LD (HL),r
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
                    8'h36: begin    // LD (HL),n
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
                    8'h0a: begin    // LD A,(BC)
                        d_mcycles = 3'd2;
                        case (q_mcycle)
                            3'd1: Set_Addr_To = aBC;
                            3'd2: Read_To_Acc = 1;
                            default: begin end
                        endcase
                    end
                    8'h1a: begin    // LD A,(DE)
                        d_mcycles = 3'd2;
                        case (q_mcycle)
                            3'd1: Set_Addr_To = aDE;
                            3'd2: Read_To_Acc = 1;
                            default: begin end
                        endcase
                    end
                    8'h3a: begin    // LD A,(nn)
                        d_mcycles = 3'd4;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC = 1;
                                LDZ    = 1;
                            end
                            3'd3: begin
                                Set_Addr_To = aZI;
                                Inc_PC      = 1;
                            end
                            3'd4: begin
                                Read_To_Acc = 1;
                            end
                            default: begin end
                        endcase
                    end
                    8'h02: begin    // LD (BC),A
                        d_mcycles = 3'd2;
                        case (q_mcycle)
                            3'd1: begin
                                Set_Addr_To = aBC;
                                Set_BusB_To = 4'b0111;
                                SetWZ       = 2'b10;
                            end
                            3'd2: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end
                    8'h12: begin    // LD (DE),A
                        d_mcycles = 3'd2;
                        case (q_mcycle)
                            3'd1: begin
                                Set_Addr_To = aDE;
                                Set_BusB_To = 4'b0111;
                                SetWZ       = 2'b10;
                            end
                            3'd2: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end
                    8'h32: begin    // LD (nn),A
                        d_mcycles = 3'd4;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC = 1;
                                LDZ    = 1;
                            end
                            3'd3: begin
                                Set_Addr_To = aZI;
                                SetWZ       = 2'b10;
                                Inc_PC      = 1;
                                Set_BusB_To = 4'b0111;
                            end
                            3'd4: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end

                    // 16 BIT LOAD GROUP
                    8'h01,8'h11,8'h21,8'h31: begin  // LD dd,nn
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
                                LDZ    = 1;
                            end
                            3'd3: begin
                                Set_Addr_To = aZI;
                                Inc_PC      = 1;
                                LDW         = 1;
                            end
                            3'd4: begin
                                Set_BusA_To[2:0] = 3'd5;    // L
                                Read_To_Reg      = 1;
                                Inc_WZ           = 1;
                                Set_Addr_To      = aZI;
                            end
                            3'd5: begin
                                Set_BusA_To[2:0] = 3'd4;    // H
                                Read_To_Reg      = 1;
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
                                LDZ    = 1;
                            end
                            3'd3: begin
                                Set_Addr_To = aZI;
                                Inc_PC      = 1;
                                LDW         = 1;
                                Set_BusB_To = 4'b0101;  // L
                            end
                            3'd4: begin
                                Inc_WZ      = 1;
                                Set_Addr_To = aZI;
                                Write_i     = 1;
                                Set_BusB_To = 4'b0100;  // H
                            end
                            3'd5: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end
                    8'hf9: begin    // LD q_reg_sp,HL
                        tstates = 3'd6;
                        LDSPHL = 1;
                    end
                    8'hc5,8'hd5,8'he5,8'hf5: begin  // PUSH qq
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1: begin
                                tstates     = 3'd5;
                                IncDec_16   = 4'b1111;
                                Set_Addr_To = aSP;

                                if (ir_dpair == 2'b11) begin
                                    Set_BusB_To = 4'b0111;
                                end else begin
                                    Set_BusB_To[2:1] = ir_dpair;
                                    Set_BusB_To[0]   = 0;
                                    Set_BusB_To[3]   = 0;
                                end
                            end
                            3'd2: begin
                                IncDec_16   = 4'b1111;
                                Set_Addr_To = aSP;

                                if (ir_dpair == 2'b11) begin
                                    Set_BusB_To = 4'b1011;
                                end else begin
                                    Set_BusB_To[2:1] = ir_dpair;
                                    Set_BusB_To[0]   = 1;
                                    Set_BusB_To[3]   = 0;
                                end

                                Write_i = 1;
                            end

                            3'd3: begin
                                Write_i = 1;
                            end
 
                            default: begin end
                        endcase
                    end
                    8'hc1,8'hd1,8'he1,8'hf1: begin  // POP qq
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1: begin
                                Set_Addr_To = aSP;
                            end
                            3'd2: begin
                                IncDec_16   = 4'b0111;
                                Set_Addr_To = aSP;
                                Read_To_Reg = 1;

                                if (ir_dpair == 2'b11) begin
                                    Set_BusA_To[3:0] = 4'b1011;
                                end else begin
                                    Set_BusA_To[2:1] = ir_dpair;
                                    Set_BusA_To[0] = 1;
                                end
                            end
                            3'd3: begin
                                IncDec_16 = 4'b0111;
                                Read_To_Reg = 1;
                                if (ir_dpair == 2'b11) begin
                                    Set_BusA_To[3:0] = 4'b0111;
                                end else begin
                                    Set_BusA_To[2:1] = ir_dpair;
                                    Set_BusA_To[0] = 0;
                                end
                            end
                            default: begin end
                        endcase
                    end

                    // EXCHANGE, BLOCK TRANSFER AND SEARCH GROUP
                    8'heb: is_instr_ex_de_hl = 1; // EX DE,HL
                    8'h08: is_instr_ex_af    = 1; // EX AF,AF'
                    8'hd9: is_instr_exx      = 1; // EXX
                        
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
                                IncDec_16 = 4'b0111;    // SP = SP+1
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
                                IncDec_16 = 4'b1111;    // SP = SP-1
                                Set_Addr_To = aSP;
                            end
                            3'd5: begin
                                ExchangeWH = 1;
                                // save MEMPTR to HL
                                tstates = 3'd5;
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end

                    // 8 BIT ARITHMETIC AND LOGICAL GROUP
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
                        Read_To_Reg      = 1;
                        Save_ALU         = 1;
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
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
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
                            Inc_PC           = 1;
                            Read_To_Reg      = 1;
                            Save_ALU         = 1;
                            Set_BusB_To[2:0] = ir_sss;
                            Set_BusA_To[2:0] = 3'd7;
                        end
                    end
                    8'h04,8'h0c,8'h14,8'h1c,8'h24,8'h2c,8'h3c: begin    // INC r
                        Set_BusB_To      = 4'b1010;
                        Set_BusA_To[2:0] = ir_ddd;
                        Read_To_Reg      = 1;
                        Save_ALU         = 1;
                        d_preserve_c     = 1;
                        d_alu_op         = 4'b0000;
                    end
                    8'h34: begin    // INC (HL)
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                tstates          = 3'd4;
                                Set_Addr_To      = aXY;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                d_preserve_c     = 1;
                                d_alu_op         = 4'b0000;
                                Set_BusB_To      = 4'b1010;
                                Set_BusA_To[2:0] = ir_ddd;
                            end
                            3'd3: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end
                    8'h05,8'h0d,8'h15,8'h1d,8'h25,8'h2d,8'h3d: begin    // DEC r
                        Set_BusB_To      = 4'b1010;
                        Set_BusA_To[2:0] = ir_ddd;
                        Read_To_Reg      = 1;
                        Save_ALU         = 1;
                        d_preserve_c     = 1;
                        d_alu_op         = 4'b0010;
                    end
                    8'h35: begin    // DEC (HL)
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                tstates          = 3'd4;
                                Set_Addr_To      = aXY;
                                d_alu_op         = 4'b0010;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                d_preserve_c     = 1;
                                Set_BusB_To      = 4'b1010;
                                Set_BusA_To[2:0] = ir_ddd;
                            end
                            3'd3: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end

                    // GENERAL PURPOSE ARITHMETIC AND CPU CONTROL GROUPS
                    8'h27: begin
                        // DAA
                        Set_BusA_To[2:0] = 3'd7;
                        Read_To_Reg      = 1;
                        d_alu_op         = 4'b1100;
                        Save_ALU         = 1;
                    end

                    8'h2f: is_instr_cpl = 1;    // CPL
                    8'h3f: is_instr_ccf = 1;    // CCF
                    8'h37: is_instr_scf = 1;    // SCF

                    8'h00: begin
                        if (q_nmi_cycle) begin
                            // NMI
                            d_mcycles = 3'd3;
                            case (q_mcycle)
                                3'd1: begin
                                    tstates     = 3'd5;
                                    IncDec_16   = 4'b1111;
                                    Set_Addr_To = aSP;
                                    Set_BusB_To = 4'b1101;
                                end
                                3'd2: begin
                                    Write_i     = 1;
                                    IncDec_16   = 4'b1111;
                                    Set_Addr_To = aSP;
                                    Set_BusB_To = 4'b1100;
                                end
                                3'd3: begin
                                    Write_i = 1;
                                end
                                default: begin end
                            endcase

                        end else if (q_irq_cycle) begin
                            // INT (IM 2)
                            d_mcycles = 3'd5;
                            case (q_mcycle)
                                3'd1: begin
                                    tstates     = 3'd5;
                                    IncDec_16   = 4'b1111;
                                    Set_Addr_To = aSP;
                                    Set_BusB_To = 4'b1101;
                                end
                                3'd2: begin
                                    Write_i     = 1;
                                    IncDec_16   = 4'b1111;
                                    Set_Addr_To = aSP;
                                    Set_BusB_To = 4'b1100;
                                end
                                3'd3: begin
                                    Write_i = 1;
                                end
                                3'd4: begin
                                    Inc_PC = 1;
                                    LDZ    = 1;
                                end
                                3'd5: begin
                                    Jump = 1;
                                end
                                default: begin end
                            endcase

                        end else begin
                            // NOP
                        end
                    end

                    8'h76: is_instr_halt = 1;   // HALT
                    8'hf3: is_instr_di = 1;     // DI
                    8'hfb: is_instr_ei = 1;     // EI

                    // 16 BIT ARITHMETIC GROUP
                    8'h09,8'h19,8'h29,8'h39: begin
                        // ADD HL,ss
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1: begin
                                No_PC = 1;
                            end
                            3'd2: begin
                                NoRead_i         = 1;
                                d_alu_op         = 4'b0000;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                Set_BusA_To[2:0] = 3'd5;
                                if (q_instruction[5:4] == 2'b11) begin
                                    Set_BusB_To = 4'b1000;
                                end else begin
                                    Set_BusB_To[2:1] = q_instruction[5:4];
                                    Set_BusB_To[0] = 1;
                                end
                                tstates   = 3'd4;
                                d_arith16 = 1;
                                SetWZ     = 2'b11;
                                No_PC     = 1;
                            end
                            3'd3: begin
                                NoRead_i         = 1;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                d_alu_op         = 4'b0001;
                                Set_BusA_To[2:0] = 3'd4;
                                if (q_instruction[5:4] == 2'b11) begin
                                    Set_BusB_To = 4'b1001;
                                end else begin
                                    Set_BusB_To[2:1] = q_instruction[5:4];
                                end
                                d_arith16 = 1;
                            end
                            default: begin end
                        endcase
                    end
                    8'h03,8'h13,8'h23,8'h33: begin
                        // INC ss
                        tstates        = 3'd6;
                        IncDec_16[3:2] = 2'b01;
                        IncDec_16[1:0] = ir_dpair;
                    end
                    8'h0b,8'h1b,8'h2b,8'h3b: begin
                        // DEC ss
                        tstates        = 3'd6;
                        IncDec_16[3:2] = 2'b11;
                        IncDec_16[1:0] = ir_dpair;
                    end

                    // ROTATE AND SHIFT GROUP
                    8'h07,8'h17,8'h0f,8'h1f: begin  // RLCA|RLA|RRCA|RRA
                        Set_BusA_To[2:0] = 3'd7;
                        d_alu_op         = 4'b1000;
                        Read_To_Reg      = 1;
                        Save_ALU         = 1;
                    end

                    // JUMP GROUP
                    8'hc3: begin    // JP nn
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC = 1;
                                LDZ    = 1;
                            end
                            3'd3: begin
                                Inc_PC = 1;
                                Jump   = 1;
                                LDW    = 1;
                            end
                            default: begin end
                        endcase
                    end
                    8'hc2,8'hca,8'hd2,8'hda,8'he2,8'hea,8'hf2,8'hfa: begin  // JP cc,nn
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC = 1;
                                LDZ    = 1;
                            end
                            3'd3: begin
                                LDW    = 1;
                                Inc_PC = 1;
                                if (cc_is_true)
                                    Jump = 1;
                            end
                            default: begin end
                        endcase
                    end
                    8'h18: begin    // JR e
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC = 1;
                                No_PC  = 1;
                            end
                            3'd3: begin
                                NoRead_i = 1;
                                JumpE    = 1;
                                tstates  = 3'd5;
                            end
                            default: begin end
                        endcase
                    end
                    8'h38: begin    // JR C,e
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC = 1;
                                if (!q_reg_f[Flag_C])
                                    d_mcycles = 3'd2;
                                else
                                    No_PC = 1;
                            end
                            3'd3: begin
                                NoRead_i = 1;
                                JumpE    = 1;
                                tstates  = 3'd5;
                            end
                            default: begin end
                        endcase
                    end
                    8'h30: begin    // JR NC,e
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC = 1;
                                if (q_reg_f[Flag_C])
                                    d_mcycles = 3'd2;
                                else
                                    No_PC = 1;
                            end
                            3'd3: begin
                                NoRead_i = 1;
                                JumpE    = 1;
                                tstates  = 3'd5;
                            end
                            default: begin end
                        endcase
                    end
                    8'h28: begin    // JR Z,e
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC = 1;
                                if (!q_reg_f[Flag_Z])
                                    d_mcycles = 3'd2;
                                else
                                    No_PC = 1;
                            end
                            3'd3: begin
                                NoRead_i = 1;
                                JumpE    = 1;
                                tstates  = 3'd5;
                            end
                            default: begin end
                        endcase
                    end
                    8'h20: begin    // JR NZ,e
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC = 1;
                                if (q_reg_f[Flag_Z])
                                    d_mcycles = 3'd2;
                                else
                                    No_PC = 1;
                            end
                            3'd3: begin
                                NoRead_i = 1;
                                JumpE    = 1;
                                tstates  = 3'd5;
                            end
                            default: begin end
                        endcase
                    end

                    8'he9: is_instr_jp_ind_hl = 1;  // JP (HL)

                    8'h10: begin    // DJNZ,e
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1: begin
                                tstates          = 3'd5;
                                is_instr_djnz    = 1;
                                Set_BusB_To      = 4'b1010;
                                Set_BusA_To[2:0] = 3'd0;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                d_alu_op         = 4'b0010;
                            end
                            3'd2: begin
                                is_instr_djnz = 1;
                                Inc_PC        = 1;
                                No_PC         = 1;
                            end
                            3'd3: begin
                                NoRead_i = 1;
                                JumpE    = 1;
                                tstates  = 3'd5;
                            end
                            default: begin end
                        endcase
                    end

                    // CALL AND RETURN GROUP
                    8'hcd: begin    // CALL nn
                        d_mcycles = 3'd5;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC      = 1;
                                LDZ         = 1;
                            end
                            3'd3: begin
                                IncDec_16   = 4'b1111;
                                Inc_PC      = 1;
                                tstates     = 3'd4;
                                Set_Addr_To = aSP;
                                LDW         = 1;
                                Set_BusB_To = 4'b1101;
                            end
                            3'd4: begin
                                Write_i     = 1;
                                IncDec_16   = 4'b1111;
                                Set_Addr_To = aSP;
                                Set_BusB_To = 4'b1100;
                            end
                            3'd5: begin
                                Write_i     = 1;
                                Call        = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'hc4,8'hcc,8'hd4,8'hdc,8'he4,8'hec,8'hf4,8'hfc: begin  // CALL cc,nn
                        d_mcycles = 3'd5;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC = 1;
                                LDZ    = 1;
                            end
                            3'd3: begin
                                Inc_PC = 1;
                                LDW    = 1;
                                if (cc_is_true) begin
                                    IncDec_16   = 4'b1111;
                                    Set_Addr_To = aSP;
                                    tstates     = 3'd4;
                                    Set_BusB_To = 4'b1101;
                                end else begin
                                    d_mcycles = 3'd3;
                                end
                            end
                            3'd4: begin
                                Write_i     = 1;
                                IncDec_16   = 4'b1111;
                                Set_Addr_To = aSP;
                                Set_BusB_To = 4'b1100;
                            end
                            3'd5: begin
                                Write_i = 1;
                                Call    = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'hc9: begin    // RET
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
                            end
                            default: begin end
                        endcase
                    end

                    8'hc0,8'hc8,8'hd0,8'hd8,8'he0,8'he8,8'hf0,8'hf8: begin  // RET cc
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1: begin
                                if (cc_is_true)
                                    Set_Addr_To = aSP;
                                else
                                    d_mcycles = 3'd1;

                                tstates = 3'd5;
                            end
                            3'd2: begin
                                IncDec_16   = 4'b0111;
                                Set_Addr_To = aSP;
                                LDZ         = 1;
                            end
                            3'd3: begin
                                Jump      = 1;
                                IncDec_16 = 4'b0111;
                            end
                            default: begin end
                        endcase
                    end

                    8'hc7,8'hcf,8'hd7,8'hdf,8'he7,8'hef,8'hf7,8'hff: begin  // RST p
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1: begin
                                tstates     = 3'd5;
                                IncDec_16   = 4'b1111;
                                Set_Addr_To = aSP;
                                Set_BusB_To = 4'b1101;
                            end
                            3'd2: begin
                                Write_i     = 1;
                                IncDec_16   = 4'b1111;
                                Set_Addr_To = aSP;
                                Set_BusB_To = 4'b1100;
                            end
                            3'd3: begin
                                Write_i     = 1;
                                RstP        = 1;
                            end
                            default: begin end
                        endcase
                    end

                    // INPUT AND OUTPUT GROUP
                    8'hdb: begin    // IN A,(n)
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC      = 1;
                                Set_Addr_To = aIOA;
                            end
                            3'd3: begin
                                Read_To_Acc = 1;
                                IORQ_i      = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'hd3: begin    // OUT (n),A
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd2: begin
                                Inc_PC      = 1;
                                Set_Addr_To = aIOA;
                                Set_BusB_To = 4'b0111;
                            end
                            3'd3: begin
                                Write_i = 1;
                                IORQ_i  = 1;
                            end
                            default: begin end
                        endcase
                    end

                    //--------------------------------------------------------
                    // MULTIBYTE INSTRUCTIONS
                    //--------------------------------------------------------
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
                        if (q_xy_state == 2'b00) begin
                            if (q_mcycle == 3'd1) begin
                                d_alu_op      = 4'b1000;
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
                                    d_alu_op    = 4'b1000;
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
                                d_alu_op      = 4'b1000;
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
                        if (q_xy_state == 2'b00) begin
                            // BIT b,r
                            if (q_mcycle == 3'd1) begin
                                Set_BusB_To[2:0] = q_instruction[2:0];
                                d_alu_op           = 4'b1001;
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
                                    d_alu_op  = 4'b1001;
                                    tstates = 3'd4;
                                end
                                default: begin end
                            endcase
                        end
                    end

                    8'h46,8'h4e,8'h56,8'h5e,8'h66,8'h6e,8'h76,8'h7e: begin  // BIT b,(HL)
                        d_mcycles = 3'd2;
                        case (q_mcycle)
                            3'd1,3'd7: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                d_alu_op  = 4'b1001;
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
                    8'hf8,8'hf9,8'hfa,8'hfb,8'hfc,8'hfd,8'hff: begin    // SET b,r
                        if (q_xy_state == 2'b00) begin
                            if (q_mcycle == 3'd1) begin
                                d_alu_op      = 4'b1010;
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
                                    d_alu_op      = 4'b1010;
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

                    8'hc6,8'hce,8'hd6,8'hde,8'he6,8'hee,8'hf6,8'hfe: begin  // SET b,(HL)
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1,3'd7: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                d_alu_op      = 4'b1010;
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
                    8'hb8,8'hb9,8'hba,8'hbb,8'hbc,8'hbd,8'hbf: begin    // RES b,r
                        if (q_xy_state == 2'b00) begin
                            if (q_mcycle == 3'd1) begin
                                d_alu_op      = 4'b1011;
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
                                    d_alu_op      = 4'b1011;
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

                    8'h86,8'h8e,8'h96,8'h9e,8'ha6,8'hae,8'hb6,8'hbe: begin  // RES b,(HL)
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1,3'd7: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                d_alu_op    = 4'b1011;
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
                                                              8'h77,
                                                              8'h7f,
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

                    // 8 BIT LOAD GROUP
                    8'h57: begin    // LD A,I
                        Special_LD = 3'd4;
                        tstates    = 3'd5;
                    end

                    8'h5f: begin    // LD A,R
                        Special_LD = 3'd5;
                        tstates    = 3'd5;
                    end

                    8'h47: begin    // LD I,A
                        Special_LD = 3'd6;
                        tstates    = 3'd5;
                    end

                    8'h4f: begin    // LD R,A
                        Special_LD = 3'd7;
                        tstates = 3'd5;
                    end

                    // 16 BIT LOAD GROUP
                    8'h4b,8'h5b,8'h6b,8'h7b: begin  // LD dd,(nn)
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

                    8'h43,8'h53,8'h63,8'h73: begin  // LD (nn),dd
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

                    8'ha0,8'ha8,8'hb0,8'hb8: begin  // LDI, LDD, LDIR, LDDR
                        d_mcycles = 3'd4;
                        case (q_mcycle)
                            3'd1: begin
                                Set_Addr_To = aXY;
                                IncDec_16   = 4'b1100;      // BC
                            end
                            3'd2: begin
                                Set_BusB_To      = 4'b0110;
                                Set_BusA_To[2:0] = 3'd7;
                                d_alu_op         = 4'b0000;
                                Set_Addr_To      = aDE;
                                if (!q_instruction[3]) begin
                                    IncDec_16 = 4'b0110;    // IX
                                end else begin
                                    IncDec_16 = 4'b1110;
                                end
                            end
                            3'd3: begin
                                is_instr_bt = 1;
                                tstates     = 3'd5;
                                Write_i     = 1;
                                if (!q_instruction[3]) begin
                                    IncDec_16 = 4'b0101;    // DE
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

                    8'ha1,8'ha9,8'hb1,8'hb9: begin  // CPI, CPD, CPIR, CPDR
                        d_mcycles = 3'd4;
                        case (q_mcycle)
                            3'd1: begin
                                Set_Addr_To = aXY;
                                IncDec_16   = 4'b1100;  // BC
                            end
                            3'd2: begin
                                Set_BusB_To      = 4'b0110;
                                Set_BusA_To[2:0] = 3'd7;
                                d_alu_op         = 4'b0111;
                                Save_ALU         = 1;
                                d_preserve_c     = 1;
                                if (!q_instruction[3]) begin
                                    IncDec_16 = 4'b0110;
                                end else begin
                                    IncDec_16 = 4'b1110;
                                end
                                No_PC = 1;
                            end
                            3'd3: begin
                                NoRead_i    = 1;
                                is_instr_bc = 1;
                                tstates     = 3'd5;
                                No_PC       = 1;
                            end
                            3'd4: begin
                                NoRead_i = 1;
                                tstates  = 3'd5;
                            end
                            default: begin end
                        endcase
                    end

                    8'h44,8'h4c,8'h54,8'h5c,8'h64,8'h6c,8'h74,8'h7c: begin  // NEG
                        d_alu_op    = 4'b0010;
                        Set_BusB_To = 4'b0111;
                        Set_BusA_To = 4'b1010;
                        Read_To_Acc = 1;
                        Save_ALU    = 1;
                    end

                    8'h46,8'h4e,8'h66,8'h6e: d_im = 2'd0;  // IM 0
                    8'h56,8'h76:             d_im = 2'd1;  // IM 1
                    8'h5e,8'h7e:             d_im = 2'd2;  // IM 2

                    // 16 bit arithmetic
                    8'h4a,8'h5a,8'h6a,8'h7a: begin  // ADC HL,ss
                        d_mcycles = 3'd3;
                        case (q_mcycle)
                            3'd1: begin
                                No_PC = 1;
                            end
                            3'd2: begin
                                NoRead_i         = 1;
                                d_alu_op         = 4'b0001;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                Set_BusA_To[2:0] = 3'd5;

                                if (q_instruction[5:4] == 2'b11) begin
                                    Set_BusB_To = 4'b1000;
                                end else begin
                                    Set_BusB_To[2:1] = q_instruction[5:4];
                                    Set_BusB_To[0]   = 1;
                                end

                                tstates = 3'd4;
                                SetWZ   = 2'b11;
                                No_PC   = 1;
                            end
                            3'd3: begin
                                NoRead_i         = 1;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                d_alu_op         = 4'b0001;
                                Set_BusA_To[2:0] = 3'd4;

                                if (q_instruction[5:4] == 2'b11) begin
                                    Set_BusB_To = 4'b1001;
                                end else begin
                                    Set_BusB_To[2:1] = q_instruction[5:4];
                                    Set_BusB_To[0]   = 0;
                                end
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
                                d_alu_op         = 4'b0011;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                Set_BusA_To[2:0] = 3'd5;

                                if (q_instruction[5:4] == 2'b11) begin
                                    Set_BusB_To = 4'b1000;
                                end else begin
                                    Set_BusB_To[2:1] = q_instruction[5:4];
                                    Set_BusB_To[0]   = 1;
                                end

                                tstates = 3'd4;
                                SetWZ   = 2'b11;
                                No_PC   = 1;
                            end
                            3'd3: begin
                                NoRead_i         = 1;
                                d_alu_op         = 4'b0011;
                                Read_To_Reg      = 1;
                                Save_ALU         = 1;
                                Set_BusA_To[2:0] = 3'd4;

                                if (q_instruction[5:4] == 2'b11) begin
                                    Set_BusB_To = 4'b1001;
                                end else begin
                                    Set_BusB_To[2:1] = q_instruction[5:4];
                                end
                            end
                            default: begin end
                        endcase
                    end

                    8'h6f: begin    // RLD -- Read in M2, not M3! fixed by Sorgelig
                        d_mcycles = 3'd4;
                        case (q_mcycle)
                            3'd1: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                Read_To_Reg      = 1;
                                Set_BusB_To[2:0] = 3'd6;
                                Set_BusA_To[2:0] = 3'd7;
                                d_alu_op         = 4'b1101;
                                Save_ALU         = 1;
                                No_PC            = 1;
                            end
                            3'd3: begin
                                tstates      = 3'd4;
                                is_instr_rld = 1;
                                NoRead_i     = 1;
                                Set_Addr_To  = aXY;
                            end
                            3'd4: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'h67: begin    // RRD -- Read in M2, not M3! fixed by Sorgelig
                        d_mcycles = 3'd4;
                        case (q_mcycle)
                            3'd1: begin
                                Set_Addr_To = aXY;
                            end
                            3'd2: begin
                                Read_To_Reg      = 1;
                                Set_BusB_To[2:0] = 3'd6;
                                Set_BusA_To[2:0] = 3'd7;
                                d_alu_op         = 4'b1110;
                                Save_ALU         = 1;
                                No_PC            = 1;
                            end
                            3'd3: begin
                                tstates      = 3'd4;
                                is_instr_rrd = 1;
                                NoRead_i     = 1;
                                Set_Addr_To  = aXY;
                            end
                            3'd4: begin
                                Write_i = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'h45,8'h4d,8'h55,8'h5d,8'h65,8'h6d,8'h75,8'h7d: begin  // RETI/RETN
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
                                Jump          = 1;
                                IncDec_16     = 4'b0111;
                                LDW           = 1;
                                is_instr_retn = 1;
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

                    8'h41,8'h49,8'h51,8'h59,8'h61,8'h69,8'h71,8'h79: begin  // OUT (C),r   OUT (C),0
                        d_mcycles = 3'd2;
                        case (q_mcycle)
                            3'd1: begin
                                Set_Addr_To      = aBC;
                                SetWZ            = 2'b01;
                                Set_BusB_To[2:0] = q_instruction[5:3];
                                if (q_instruction[5:3] == 3'd6)
                                    Set_BusB_To[3] = 1;
                            end
                            3'd2: begin
                                Write_i = 1;
                                IORQ_i  = 1;
                            end
                            default: begin end
                        endcase
                    end

                    8'ha2,8'haa,8'hb2,8'hba: begin  // INI, IND, INIR, INDR
                        d_mcycles = 3'd4;
                        case (q_mcycle)
                            3'd1: begin
                                tstates      = 3'd5;
                                Set_Addr_To  = aBC;
                                Set_BusB_To  = 4'b1010;
                                Set_BusA_To  = 4'b0000;
                                Read_To_Reg  = 1;
                                Save_ALU     = 1;
                                d_alu_op     = 4'b0010;
                                SetWZ        = 2'b11;
                                IncDec_16[3] = q_instruction[3];
                            end
                            3'd2: begin
                                IORQ_i      = 1;
                                Set_BusB_To = 4'b0110;
                                Set_Addr_To = aXY;
                            end
                            3'd3: begin
                                if (!q_instruction[3])
                                    IncDec_16 = 4'b0110;
                                else
                                    IncDec_16 = 4'b1110;

                                Write_i      = 1;
                                is_instr_btr = 1;
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
                                d_alu_op    = 4'b0010;
                            end
                            3'd2: begin
                                Set_BusB_To  = 4'b0110;
                                Set_Addr_To  = aBC;
                                SetWZ        = 2'b11;
                                IncDec_16[3] = q_instruction[3];
                            end
                            3'd3: begin
                                if (!q_instruction[3])
                                    IncDec_16 = 4'b0110;
                                else
                                    IncDec_16 = 4'b1110;

                                IORQ_i       = 1;
                                Write_i      = 1;
                                is_instr_btr = 1;
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

            if (q_instruction == 8'h36 || q_instruction == 8'hcb)
                Set_Addr_To = aNone;

            if (!(q_instruction == 8'h36 || q_prefix == PrefixCB))
                No_PC = 1;
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

    wire       alu_do_sub        = q_alu_op[1];
    wire       alu_cin           = (alu_do_sub ^ ((!q_alu_op[2] & q_alu_op[0]) & q_reg_f[Flag_C]));
    wire [5:0] alu_addsub_l      = {1'b0, bus_a[3:0], alu_cin}         + {1'b0, (alu_do_sub ? ~bus_b[3:0] : bus_b[3:0]), 1'b1};
    wire [4:0] addsub_m          = {1'b0, bus_a[6:4], alu_addsub_l[5]} + {1'b0, (alu_do_sub ? ~bus_b[6:4] : bus_b[6:4]), 1'b1};
    wire [2:0] addsub_h          = {1'b0, bus_a[7],   addsub_m[4]}     + {1'b0, (alu_do_sub ? ~bus_b[7]   : bus_b[7]),   1'b1};
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

        case (q_alu_op)
            4'b0000, 4'b0001, 4'b0010, 4'b0011, 4'b0100, 4'b0101, 4'b0110, 4'b0111: begin
                F_Out[Flag_N] = 0;
                F_Out[Flag_C] = 0;

                case (q_alu_op[2:0])
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

                    3'd4:    begin alu_result = bus_a & bus_b; F_Out[Flag_H] = 1; end // AND
                    3'd5:    begin alu_result = bus_a ^ bus_b; F_Out[Flag_H] = 0; end // XOR
                    default: begin alu_result = bus_a | bus_b; F_Out[Flag_H] = 0; end // OR (110)
                endcase

                if (q_alu_op[2:0] == 3'd7) begin    // CP
                    F_Out[Flag_X] = bus_b[3];
                    F_Out[Flag_Y] = bus_b[5];
                end else begin
                    F_Out[Flag_X] = alu_result[3];
                    F_Out[Flag_Y] = alu_result[5];
                end

                F_Out[Flag_Z] = q_z16 ? q_reg_f[Flag_Z] : (alu_result == 8'b0);
                F_Out[Flag_S] = alu_result[7];

                case (q_alu_op[2:0])
                    3'd0, 3'd1, 3'd2, 3'd3, 3'd7: begin   // ADD, ADC, SUB, SBC, CP
                    end
                    default: begin
                        F_Out[Flag_P] = !(alu_result[0] ^ alu_result[1] ^ alu_result[2] ^ alu_result[3] ^ alu_result[4] ^ alu_result[5] ^ alu_result[6] ^ alu_result[7]);
                    end
                endcase

                if (q_arith16) begin
                    F_Out[Flag_S] = q_reg_f[Flag_S];
                    F_Out[Flag_Z] = q_reg_f[Flag_Z];
                    F_Out[Flag_P] = q_reg_f[Flag_P];
                end
            end

            4'b1100: begin  // DAA
                F_Out[Flag_H] = q_reg_f[Flag_H];
                F_Out[Flag_C] = q_reg_f[Flag_C];
                alu_daa_tmp   = {1'b0, bus_a};

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

                    if (bus_a > 8'd153 || q_reg_f[Flag_C])
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
                alu_result    = {bus_a[7:4], q_alu_op[0] ? bus_b[7:4] : bus_b[3:0]};
                F_Out[Flag_H] = 0;
                F_Out[Flag_N] = 0;
                F_Out[Flag_X] = alu_result[3];
                F_Out[Flag_Y] = alu_result[5];
                F_Out[Flag_Z] = (alu_result == 8'b0);
                F_Out[Flag_S] = alu_result[7];
                F_Out[Flag_P] = !(alu_result[0] ^ alu_result[1] ^ alu_result[2] ^ alu_result[3] ^ alu_result[4] ^ alu_result[5] ^ alu_result[6] ^ alu_result[7]);
            end

            4'b1001: begin      // BIT
                alu_result    = bus_b & alu_bitmask;
                F_Out[Flag_S] = alu_result[7];
                F_Out[Flag_Z] = (alu_result == 8'b0);
                F_Out[Flag_P] = (alu_result == 8'b0);
                F_Out[Flag_H] = 1;
                F_Out[Flag_N] = 0;
                if (q_instruction[2:0] == 3'd6 || q_xy_state != 2'b00) begin
                    F_Out[Flag_X] = q_memptr[11];
                    F_Out[Flag_Y] = q_memptr[13];
                end else begin
                    F_Out[Flag_X] = bus_b[3];
                    F_Out[Flag_Y] = bus_b[5];
                end
            end

            4'b1010: begin      // SET
                alu_result = bus_b | alu_bitmask;
            end

            4'b1011: begin      // RES
                alu_result = bus_b & ~alu_bitmask;
            end

            4'b1000: begin      // ROT
                case (q_instruction[5:3])
                    3'd0:    begin alu_result = {bus_a[6:0],      bus_a[7]};        F_Out[Flag_C] = bus_a[7]; end // RLC
                    3'd2:    begin alu_result = {bus_a[6:0],      q_reg_f[Flag_C]}; F_Out[Flag_C] = bus_a[7]; end // RL
                    3'd1:    begin alu_result = {bus_a[0],        bus_a[7:1]};      F_Out[Flag_C] = bus_a[0]; end // RRC
                    3'd3:    begin alu_result = {q_reg_f[Flag_C], bus_a[7:1]};      F_Out[Flag_C] = bus_a[0]; end // RR
                    3'd4:    begin alu_result = {bus_a[6:0],      1'b0};            F_Out[Flag_C] = bus_a[7]; end // SLA
                    3'd6:    begin alu_result = {bus_a[6:0],      1'b1};            F_Out[Flag_C] = bus_a[7]; end // SLL (Undocumented) / SWAP
                    3'd5:    begin alu_result = {bus_a[7],        bus_a[7:1]};      F_Out[Flag_C] = bus_a[0]; end // SRA
                    default: begin alu_result = {1'b0,            bus_a[7:1]};      F_Out[Flag_C] = bus_a[0]; end // SRL
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
    assign NextIs_XY_Fetch = q_xy_state != 2'b00 && !XY_Ind && (Set_Addr_To == aXY || (q_mcycle == 3'd1 && q_instruction == 8'hcb) || (q_mcycle == 3'd1 && q_instruction == 8'h36));
    assign Save_Mux        = ExchangeRp ? bus_b : !q_save_alu ? DI_Reg : ALU_Q;

    reg         q_is_instr_rld_rrd;

    wire [8:0] temp_c = {1'b0, q_reg_sp[7:0]} + {1'b0, Save_Mux};
    wire [4:0] temp_h = {1'b0, q_reg_sp[3:0]} + {1'b0, Save_Mux[3:0]};
    wire [8:0] ioq1   = {1'b0, DI_Reg} + {1'b0, incdec16_result[7:0]};
    wire [8:0] ioq2   = (ioq1 & 9'b000000111) ^ {1'b0, bus_a};
    wire [7:0] temp_n = ALU_Q - {7'b0, F_Out[Flag_H]};

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q_reg_pc           <= 0;
            q_reg_a            <= 8'hFF;
            q_reg_f            <= 8'hFF;
            q_reg_a_alt        <= 8'hFF;
            q_reg_f_alt        <= 8'hFF;
            q_reg_i            <= 0;
            q_reg_r            <= 0;
            q_reg_sp           <= 16'hFFFF;

            q_bus_addr         <= 0;
            q_bus_wrdata       <= 0;

            q_memptr           <= 0;
            q_instruction      <= 0;
            q_prefix           <= 0;
            q_xy_state         <= 0;

            q_im               <= 0;
            q_mcycles          <= 0;
            q_regs_alt         <= 0;
            q_read_to_reg      <= 0;
            q_arith16          <= 0;
            q_btr              <= 0;
            q_z16              <= 0;
            q_alu_op           <= 0;
            q_save_alu         <= 0;
            q_preserve_c       <= 0;
            XY_Ind             <= 0;
            q_is_instr_rld_rrd <= 0;

        end else begin
            if (clk_en) begin
                q_alu_op      <= 4'b0000;
                q_save_alu    <= 0;
                q_read_to_reg <= 5'b00000;
                q_mcycles     <= d_mcycles;
                q_im          <= d_im;
                q_arith16     <= d_arith16;
                q_preserve_c  <= d_preserve_c;
                q_z16         <= (q_prefix == PrefixED && !d_alu_op[2] && d_alu_op[0] && q_mcycle == 3'd3);

                if (LDHLSP && q_mcycle == 3'd3 && q_tstate == 1) begin
                    q_reg_f[Flag_Z] <= 0;
                    q_reg_f[Flag_N] <= 0;
                    q_reg_f[Flag_H] <= temp_h[4];
                    q_reg_f[Flag_C] <= temp_c[8];
                end

                if (ADDSPdd && q_tstate == 1) begin
                    q_reg_f[Flag_Z] <= 0;
                    q_reg_f[Flag_N] <= 0;
                    q_reg_f[Flag_H] <= temp_h[4];
                    q_reg_f[Flag_C] <= temp_c[8];
                end


                if (q_mcycle == 3'd1 && !q_tstate[2]) begin
                    if (q_tstate == 2 && !bus_wait) begin
                        q_bus_addr <= {q_reg_i, q_reg_r};
                        q_reg_r[6:0]  <= q_reg_r[6:0] + 7'd1;
                        if (!Jump && !Call && !q_nmi_cycle && !q_irq_cycle && !(q_halt || is_instr_halt)) begin
                            q_reg_pc <= q_reg_pc + 1;
                        end
                        if (q_irq_cycle && q_im == 2'b01) begin
                            q_instruction <= 8'hFF;
                        end else if (q_halt || (q_irq_cycle && q_im == 2'b10) || q_nmi_cycle) begin
                            q_instruction <= 8'h00;
                        end else begin
                            q_instruction <= DInst;
                        end
                        if (q_irq_cycle && q_im == 2'b10) begin
                            // IM2 vector address low byte from bus
                            q_memptr[7:0] <= DInst;
                        end

                        q_prefix <= PrefixNone;
                        if (d_prefix != PrefixNone) begin
                            if (d_prefix == PrefixDD_FD) begin
                                if (q_instruction[5]) begin
                                    q_xy_state <= 2'b10;
                                end else begin
                                    q_xy_state <= 2'b01;
                                end
                            end else begin
                                if (d_prefix == PrefixED) begin
                                    q_xy_state <= 2'b00;
                                    XY_Ind   <= 0;
                                end
                                q_prefix <= d_prefix;
                            end
                        end else begin
                            q_xy_state <= 2'b00;
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
                        q_btr <= (is_instr_bt | is_instr_bc | is_instr_btr) & ~q_no_btr;
                        if (Jump) begin
                            q_bus_addr <= {DI_Reg, q_memptr[7:0]};
                            q_reg_pc <= {DI_Reg, q_memptr[7:0]};
                        end
                        else if (is_instr_jp_ind_hl) begin
                            q_bus_addr <= reg_bus_c;
                            q_reg_pc <= reg_bus_c;
                        end
                        else if (Call || RstP) begin
                            q_bus_addr <= q_memptr;
                            q_reg_pc <= q_memptr;
                        end
                        else if (q_mcycle == q_mcycles && q_nmi_cycle) begin
                            q_bus_addr <= 16'h0066;
                            q_reg_pc <= 16'h0066;
                        end
                        else if (q_mcycle == 3'd3 && q_irq_cycle && q_im == 2'b10) begin
                            q_bus_addr <= {q_reg_i, q_memptr[7:0]};
                            q_reg_pc <= {q_reg_i, q_memptr[7:0]};
                        end
                        else begin
                            case (Set_Addr_To)
                            aXY: begin
                                if (q_xy_state == 2'b00)
                                    q_bus_addr <= reg_bus_c;
                                else
                                    q_bus_addr <= NextIs_XY_Fetch ? q_reg_pc : q_memptr;
                            end
                            aIOA: begin
                                q_bus_addr <= {q_reg_a, DI_Reg};
                                q_memptr <= {q_reg_a, DI_Reg} + 16'd1;
                            end
                            aSP: begin
                                q_bus_addr <= q_reg_sp;
                            end
                            aBC: begin
                                q_bus_addr <= reg_bus_c;
                                if (SetWZ == 2'b01) begin
                                    q_memptr <= reg_bus_c + 1'b1;
                                end
                                if (SetWZ == 2'b10) begin
                                    q_memptr[15:8] <= q_reg_a;
                                    q_memptr[7:0]  <= reg_bus_c[7:0] + 1'b1;
                                end
                            end
                            aDE: begin
                                q_bus_addr <= reg_bus_c;
                                if (SetWZ == 2'b10) begin
                                    q_memptr[15:8] <= q_reg_a;
                                    q_memptr[7:0]  <= reg_bus_c[7:0] + 1'b1;
                                end
                            end
                            aZI: begin
                                if (Inc_WZ) begin
                                    q_bus_addr <= q_memptr + 16'd1;
                                end else begin
                                    q_bus_addr <= {DI_Reg, q_memptr[7:0]};
                                    if (SetWZ == 2'b10) begin
                                        q_memptr[15:8] <= q_reg_a;
                                        q_memptr[7:0]  <= q_memptr[7:0] + 1'b1;
                                    end
                                end
                            end
                            default: begin
                                if (q_prefix == PrefixED && q_instruction[7:4] == 4'hB && q_instruction[2:1] == 2'b01 && q_mcycle == 3 && !q_no_btr) begin
                                    // INIR, INDR, OTIR, OTDR
                                    q_bus_addr <= q_reg_bus_a;
                                end
                                else if (!No_PC || q_no_btr || (is_instr_djnz && q_inc_dec_is_zero)) begin
                                    q_bus_addr <= q_reg_pc;
                                end
                            end
                            endcase
                        end
                        if (SetWZ == 2'b11) begin
                            q_memptr <= incdec16_result;
                        end

                        q_save_alu <= Save_ALU;
                        q_alu_op   <= d_alu_op;

                        if (is_instr_cpl) begin     // CPL
                            q_reg_a         <= ~q_reg_a;
                            q_reg_f[Flag_Y] <= ~q_reg_a[5];
                            q_reg_f[Flag_H] <= 1;
                            q_reg_f[Flag_X] <= ~q_reg_a[3];
                            q_reg_f[Flag_N] <= 1;
                        end

                        if (is_instr_ccf) begin     // CCF
                            q_reg_f[Flag_C] <= ~q_reg_f[Flag_C];
                            q_reg_f[Flag_Y] <= q_reg_a[5];
                            q_reg_f[Flag_H] <= q_reg_f[Flag_C];
                            q_reg_f[Flag_X] <= q_reg_a[3];
                            q_reg_f[Flag_N] <= 0;
                        end

                        if (is_instr_scf) begin     // SCF
                            q_reg_f[Flag_C] <= 1;
                            q_reg_f[Flag_Y] <= q_reg_a[5];
                            q_reg_f[Flag_H] <= 0;
                            q_reg_f[Flag_X] <= q_reg_a[3];
                            q_reg_f[Flag_N] <= 0;
                        end
                    end

                    if ((q_tstate == 2 && !Really_Wait && is_instr_btr && q_instruction[0]) || (q_tstate == 1 && is_instr_btr && !q_instruction[0])) begin
                        q_reg_f[Flag_N] <= DI_Reg[7];
                        q_reg_f[Flag_C] <= ioq1[8];
                        q_reg_f[Flag_H] <= ioq1[8];
                        q_reg_f[Flag_P] <= ~(ioq2[0] ^ ioq2[1] ^ ioq2[2] ^ ioq2[3] ^ ioq2[4] ^ ioq2[5] ^ ioq2[6] ^ ioq2[7]);
                    end

                    if (q_tstate == 2 && !Really_Wait) begin
                        if (q_prefix == PrefixCB && q_mcycle == 3'd7)
                            q_instruction <= DInst;

                        if (JumpE) begin
                            q_reg_pc <= q_reg_pc + {{8{DI_Reg[7]}}, DI_Reg};
                            q_memptr <= q_reg_pc + {{8{DI_Reg[7]}}, DI_Reg};
                        end else if (Inc_PC) begin
                            q_reg_pc <= q_reg_pc + 16'd1;
                        end

                        if (q_btr)
                            q_reg_pc <= q_reg_pc - 16'd2;

                        if (RstP) begin
                            q_memptr <= {16{1'b0}};
                            q_memptr[5:3] <= q_instruction[5:3];
                        end
                    end

                    if (q_tstate == 3 && q_mcycle == 3'd6)
                        q_memptr <= reg_bus_c + {{8{DI_Reg[7]}}, DI_Reg};

                    if ((is_instr_bt || is_instr_bc) && q_mcycle == 3'd3 && q_tstate == 4 && !q_no_btr)
                        q_memptr <= q_reg_pc - 16'd1;

                    if (IncDec_16[2:0] == 3'd7 && ((q_tstate == 2 && !Really_Wait) || (q_tstate == 4 && q_mcycle == 3'd1)))
                        q_reg_sp <= IncDec_16[3] ? (q_reg_sp - 16'd1) : (q_reg_sp + 16'd1);

                    if (ADDSPdd && q_tstate == 2) begin
                        q_memptr <= q_reg_sp;
                        q_reg_sp <= q_reg_sp + {{8{Save_Mux[7]}}, Save_Mux};
                    end

                    if (LDSPHL)
                        q_reg_sp <= reg_bus_c;

                    if (is_instr_ex_af) begin
                        q_reg_a_alt <= q_reg_a;
                        q_reg_a     <= q_reg_a_alt;
                        q_reg_f_alt <= q_reg_f;
                        q_reg_f     <= q_reg_f_alt;
                    end

                    if (is_instr_exx)
                        q_regs_alt <= !q_regs_alt;
                end

                if (q_tstate == 3) begin
                    if (LDZ) q_memptr[7:0]  <= DI_Reg;
                    if (LDW) q_memptr[15:8] <= DI_Reg;

                    if (Special_LD[2]) begin
                        case (Special_LD[1:0])
                            2'b00: begin
                                q_reg_a         <= q_reg_i;
                                q_reg_f[Flag_P] <= q_int_en2;
                                q_reg_f[Flag_S] <= q_reg_i[7];
                                q_reg_f[Flag_Z] <= (q_reg_i == 8'h00);
                                q_reg_f[Flag_Y] <= q_reg_i[5];
                                q_reg_f[Flag_H] <= 0;
                                q_reg_f[Flag_X] <= q_reg_i[3];
                                q_reg_f[Flag_N] <= 0;
                            end

                            2'b01: begin
                                q_reg_a <= q_reg_r;
                                q_reg_f[Flag_P] <= q_int_en2;
                                q_reg_f[Flag_S] <= q_reg_r[7];
                                q_reg_f[Flag_Z] <= (q_reg_r == 8'h00);
                                q_reg_f[Flag_Y] <= q_reg_r[5];
                                q_reg_f[Flag_H] <= 0;
                                q_reg_f[Flag_X] <= q_reg_r[3];
                                q_reg_f[Flag_N] <= 0;
                            end

                            2'b10:   q_reg_i <= q_reg_a;
                            default: q_reg_r <= q_reg_a;
                        endcase
                    end
                end

                if ((!is_instr_djnz && q_save_alu) || q_alu_op == 4'b1001) begin
                    q_reg_f[7:1] <= F_Out[7:1];

                    if (!q_preserve_c)
                        q_reg_f[Flag_C] <= F_Out[0];
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
                    q_is_instr_rld_rrd <= is_instr_rld | is_instr_rrd;

                    if (!q_is_instr_rld_rrd) q_bus_wrdata <= bus_b;
                    if (is_instr_rld)        q_bus_wrdata <= {bus_b[3:0], bus_a[3:0]};
                    if (is_instr_rrd)        q_bus_wrdata <= {bus_a[3:0], bus_b[7:4]};
                end

                if (T_Res) begin
                    q_read_to_reg[3:0] <= Set_BusA_To;
                    q_read_to_reg[4]   <= Read_To_Reg;
                    if (Read_To_Acc) begin
                        q_read_to_reg[3:0] <= 4'b0111;
                        q_read_to_reg[4]   <= 1;
                    end
                end

                if (q_tstate == 1 && is_instr_bt) begin
                    q_reg_f[Flag_X] <= ALU_Q[3];
                    q_reg_f[Flag_Y] <= ALU_Q[1];
                    q_reg_f[Flag_H] <= 0;
                    q_reg_f[Flag_N] <= 0;
                end

                if (q_tstate == 1 && is_instr_bc) begin
                    q_reg_f[Flag_X] <= temp_n[3];
                    q_reg_f[Flag_Y] <= temp_n[1];
                end

                if (is_instr_bc || is_instr_bt)
                    q_reg_f[Flag_P] <= q_inc_dec_is_zero;

                if ((q_tstate == 1 && !q_save_alu && !q_auto_wait) || (q_save_alu && q_alu_op != 4'b0111)) begin
                    case (q_read_to_reg)
                        5'b10111: q_reg_a        <= Save_Mux;
                        5'b10110: q_bus_wrdata   <= Save_Mux;
                        5'b11000: q_reg_sp[7:0]  <= Save_Mux;
                        5'b11001: q_reg_sp[15:8] <= Save_Mux;
                        5'b11011: q_reg_f        <= Save_Mux;
                        default: begin end
                    endcase

                    if (XYbit_undoc)
                        q_bus_wrdata <= ALU_Q;
                end
            end
        end
    end

    //-------------------------------------------------------------------------
    // BC('), DE('), HL('), IX and IY
    //-------------------------------------------------------------------------
    always @(posedge clk) begin
        if (clk_en) begin
            // Bus A / Write
            q_reg_idx_a <= {q_regs_alt,Set_BusA_To[2:1]};
            if (!XY_Ind && q_xy_state != 2'b00 && Set_BusA_To[2:1] == 2'b10)
                q_reg_idx_a <= {q_xy_state[1], 2'b11};

            // Bus B
            q_reg_idx_b <= {q_regs_alt,Set_BusB_To[2:1]};
            if (!XY_Ind && q_xy_state != 2'b00 && Set_BusB_To[2:1] == 2'b10)
                q_reg_idx_b <= {q_xy_state[1], 2'b11};

            // Address from register
            q_reg_idx_c <= {q_regs_alt,Set_Addr_To[1:0]};

            // Jump (HL), LD SP,HL
            if (is_instr_jp_ind_hl || LDSPHL)
                q_reg_idx_c <= {q_regs_alt,2'b10};
            if (((is_instr_jp_ind_hl || LDSPHL) && q_xy_state != 2'b00) || q_mcycle == 3'd6)
                q_reg_idx_c <= {q_xy_state[1], 2'b11};

            if (is_instr_djnz && q_save_alu)
                q_inc_dec_is_zero <= F_Out[Flag_Z];
            if ((q_tstate == 2 || (q_tstate == 3 && q_mcycle == 3'd1)) && IncDec_16[2:0] == 3'd4)
                q_inc_dec_is_zero <= (incdec16_result != 16'b0);

            q_reg_bus_a <= reg_bus_a;
        end
    end

    reg [2:0] reg_idx_a;
    always @* begin
        if      ((q_tstate == 2 || (q_tstate == 3 && q_mcycle == 3'd1 && IncDec_16[2])) && q_xy_state == 2'b00)
            reg_idx_a = {q_regs_alt,IncDec_16[1:0]};
        else if ((q_tstate == 2 || (q_tstate == 3 && q_mcycle == 3'd1 && IncDec_16[2])) && IncDec_16[1:0] == 2'b10)
            reg_idx_a = {q_xy_state[1],2'b11};
        else if (q_tstate == 3 && is_instr_ex_de_hl)
            reg_idx_a = {q_regs_alt,2'b10};
        else if (q_tstate == 4 && is_instr_ex_de_hl)
            reg_idx_a = {q_regs_alt,2'b01};
        else if (q_tstate == 4 && ExchangeWH)
            reg_idx_a = (q_xy_state == 2'b00) ? {q_regs_alt,2'b10} : {q_xy_state[1],2'b11};
        else if (q_tstate == 4 && LDHLSP)
            reg_idx_a = 3'd2;
        else
            reg_idx_a = q_reg_idx_a;
    end

    wire [2:0] reg_idx_b = is_instr_ex_de_hl && q_tstate == 3 ? {q_regs_alt,2'b01} : q_reg_idx_b;
    assign incdec16_result = IncDec_16[3] ? (reg_bus_a - 16'd1) : (reg_bus_a + 16'd1);

    always @* begin
        reg_wren_h = 0;
        reg_wren_l = 0;
        if ((q_tstate == 1 && !q_save_alu && !q_auto_wait) || (q_save_alu && q_alu_op != 4'b0111)) begin
            case (q_read_to_reg)
                5'b10000,5'b10001,5'b10010,5'b10011,5'b10100,5'b10101: begin
                    reg_wren_h = ~q_read_to_reg[0];
                    reg_wren_l =  q_read_to_reg[0];
                end
                default: begin end
            endcase
        end
        if (is_instr_ex_de_hl && (q_tstate == 3 || q_tstate == 4)) begin
            reg_wren_h = 1;
            reg_wren_l = 1;
        end
        if (((LDHLSP && q_mcycle == 3'd2) || ExchangeWH) && q_tstate == 4) begin
            reg_wren_h = 1;
            reg_wren_l = 1;
        end
        if (IncDec_16[2] && IncDec_16[1:0] != 2'b11 &&
            ((q_tstate == 2 && q_mcycle != 3'd1 && !Really_Wait) ||
             (q_tstate == 3 && q_mcycle == 3'd1))) begin

            reg_wren_h = 1;
            reg_wren_l = 1;
        end
    end

    reg [15:0] reg_wrdata;
    always @* begin
        reg_wrdata = {Save_Mux, Save_Mux};
        if (LDHLSP       && q_tstate == 4 && q_mcycle == 3'd2) reg_wrdata = q_reg_sp + {{8{Save_Mux[7]}}, Save_Mux};
        if (is_instr_ex_de_hl   && q_tstate == 3)                     reg_wrdata = reg_bus_b;
        if (is_instr_ex_de_hl   && q_tstate == 4)                     reg_wrdata = q_reg_bus_a;
        if (ExchangeWH   && q_tstate == 4)                     reg_wrdata = q_memptr;
        if (IncDec_16[2] &&
            ((q_tstate == 2 && q_mcycle != 3'd1) ||
             (q_tstate == 3 && q_mcycle == 3'd1)))             reg_wrdata = incdec16_result;
    end

    //------------------------------------------------------------------------
    // Register file
    //------------------------------------------------------------------------
    reg [7:0] regs_h [7:0] /* synthesis syn_ramstyle = "distributed_ram" */;
    reg [7:0] regs_l [7:0] /* synthesis syn_ramstyle = "distributed_ram" */;

    always @(posedge clk) if (clk_en && reg_wren_h) regs_h[reg_idx_a] <= reg_wrdata[15:8];
    always @(posedge clk) if (clk_en && reg_wren_l) regs_l[reg_idx_a] <= reg_wrdata[7:0];

    assign reg_bus_a[15:8] = regs_h[reg_idx_a];
    assign reg_bus_a[ 7:0] = regs_l[reg_idx_a];

    assign reg_bus_b[15:8] = regs_h[reg_idx_b];
    assign reg_bus_b[ 7:0] = regs_l[reg_idx_b];

    assign reg_bus_c[15:8] = regs_h[q_reg_idx_c];
    assign reg_bus_c[ 7:0] = regs_l[q_reg_idx_c];

    //------------------------------------------------------------------------
    // Buses
    //------------------------------------------------------------------------
    always @(posedge clk) begin
        if (clk_en) begin
            case (Set_BusB_To)
                4'b0111: bus_b <= q_reg_a;
                4'b0000,
                4'b0001,
                4'b0010,
                4'b0011,
                4'b0100,
                4'b0101: bus_b <= Set_BusB_To[0] ? reg_bus_b[7:0] : reg_bus_b[15:8];
                4'b0110: bus_b <= DI_Reg;
                4'b1000: bus_b <= q_reg_sp[7:0];
                4'b1001: bus_b <= q_reg_sp[15:8];
                4'b1010: bus_b <= 8'h01;
                4'b1011: bus_b <= q_reg_f;
                4'b1100: bus_b <= q_reg_pc[7:0];
                4'b1101: bus_b <= q_reg_pc[15:8];
                4'b1110: bus_b <= 8'h00;
                default: bus_b <= 8'h00;
            endcase

            case (Set_BusA_To)
                4'b0111: bus_a <= q_reg_a;
                4'b0000,
                4'b0001,
                4'b0010,
                4'b0011,
                4'b0100,
                4'b0101: bus_a <= Set_BusA_To[0] ? reg_bus_a[7:0] : reg_bus_a[15:8];
                4'b0110: bus_a <= DI_Reg;
                4'b1000: bus_a <= q_reg_sp[7:0];
                4'b1001: bus_a <= q_reg_sp[15:8];
                4'b1010: bus_a <= 8'h00;
                default: bus_a <= 8'h00;
            endcase

            if (XYbit_undoc) begin
                bus_a <= DI_Reg;
                bus_b <= DI_Reg;
            end
        end
    end

    //------------------------------------------------------------------------
    // Generate external control signals
    //------------------------------------------------------------------------
    assign mcycle    = q_mcycle;
    assign tstate    = q_tstate;
    assign DI_Reg    = DI;
    assign irq_cycle = q_irq_cycle;
    assign IORQ      = IORQ_i;
    assign NoRead    = NoRead_i;
    assign Write     = Write_i;

    //------------------------------------------------------------------------
    // Main state machine
    //------------------------------------------------------------------------
    reg       q_nmi;
    reg       q_nmi_pending;
    reg       q2_auto_wait;
    reg [2:0] q_pre_xy_f_m;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q_mcycle      <= 3'd1;
            q_tstate      <= 3'd0;
            q_pre_xy_f_m  <= 3'd0;
            q_halt        <= 0;
            q_nmi_cycle   <= 0;
            q_irq_cycle   <= 0;
            q_int_en1     <= 0;
            q_int_en2     <= 0;
            q_no_btr      <= 0;
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

                q_no_btr <=
                    (is_instr_bt  & (~q_instruction[4] |                    ~q_reg_f[Flag_P])) |
                    (is_instr_bc  & (~q_instruction[4] |  q_reg_f[Flag_Z] | ~q_reg_f[Flag_P])) |
                    (is_instr_btr & (~q_instruction[4] |  q_reg_f[Flag_Z]));

                if (q_tstate == 2) begin
                    if (is_instr_ei) begin
                        q_int_en1 <= 1;
                        q_int_en2 <= 1;
                    end

                    if (is_instr_retn)
                        q_int_en1 <= q_int_en2;
                end

                if (q_tstate == 3 && is_instr_di) begin
                    q_int_en1 <= 0;
                    q_int_en2 <= 0;
                end

                if (q_irq_cycle || q_nmi_cycle)
                    q_halt <= 0;

                if (q_tstate == 2 && Really_Wait) begin
                    // Wait

                end else if (T_Res) begin
                    if (is_instr_halt) begin
                        q_halt <= 1;
                    end
                    q_tstate <= 3'd1;

                    if (NextIs_XY_Fetch) begin
                        q_mcycle     <= 3'd6;
                        q_pre_xy_f_m <= (q_instruction == 8'h36 && Mode == 0) ? 3'd2 : q_mcycle;

                    end else if (q_mcycle == 3'd7 || (q_mcycle == 3'd6 && Mode == 1 && q_prefix != PrefixCB)) begin
                        q_mcycle <= q_pre_xy_f_m + 3'd1;

                    end else if (q_mcycle == q_mcycles || q_no_btr || (q_mcycle == 3'd2 && is_instr_djnz && q_inc_dec_is_zero)) begin
                        q_mcycle    <= 3'd1;
                        q_irq_cycle <= 0;
                        q_nmi_cycle <= 0;

                        if (q_nmi_pending && d_prefix == PrefixNone) begin
                            q_nmi_pending <= 0;
                            q_nmi_cycle   <= 1;
                            q_int_en1     <= 0;

                        end else if (q_int_en1 && irq && d_prefix == PrefixNone && !is_instr_ei) begin
                            q_irq_cycle <= 1;
                            q_int_en1   <= 0;
                            q_int_en2   <= 0;
                        end

                    end else begin
                        q_mcycle <= q_mcycle + 1;
                    end

                end else if (!(d_auto_wait && !q2_auto_wait)) begin
                    q_tstate <= q_tstate + 1;
                end
            end
        end
    end

    assign d_auto_wait = q_irq_cycle && q_mcycle == 3'd1;

endmodule
