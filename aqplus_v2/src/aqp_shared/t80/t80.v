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
        // aNone = 3'b111,
        aBC   = 3'b000,
        aDE   = 3'b001,
        aXY   = 3'b010,
        aIOA  = 3'b100,
        aSP   = 3'b101,
        aZI   = 3'b110;

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
    wire  [2:0] RegAddrA;
    reg   [2:0] RegAddrB_r;
    wire  [2:0] RegAddrB;
    reg   [2:0] RegAddrC;
    reg         RegWEH;
    reg         RegWEL;
    reg         Alternate;  // Help Registers
    reg  [15:0] WZ;  // MEMPTR register
    wire [15:0] TmpAddr2;  // Temporary address register
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
    wire  [2:0] MCycles_d;
    wire  [2:0] TStates;
    reg         IntCycle_i;
    reg         NMICycle;
    wire        Inc_PC;
    wire        Inc_WZ;
    wire  [3:0] IncDec_16;
    wire  [1:0] Prefix;
    wire        Read_To_Acc;
    wire        Read_To_Reg;
    wire  [3:0] Set_BusB_To;
    wire  [3:0] Set_BusA_To;
    wire  [3:0] ALU_Op;
    wire        Save_ALU;
    wire        PreserveC;
    wire        Arith16;
    wire  [2:0] Set_Addr_To;
    wire        Jump;
    wire        JumpE;
    wire        JumpXY;
    wire        Call;
    wire        RstP;
    wire        LDZ;
    wire        LDW;
    wire        LDSPHL;
    wire        LDHLSP;
    wire        ADDSPdd;
    wire        IORQ_i;
    wire        Write_i;
    wire        NoRead_i;
    wire  [2:0] Special_LD;
    wire        ExchangeDH;
    wire        ExchangeRp;
    wire        ExchangeAF;
    wire        ExchangeRS;
    wire        ExchangeWH;
    wire        I_DJNZ;
    wire        I_CPL;
    wire        I_CCF;
    wire        I_SCF;
    wire        I_RETN;
    wire        I_BT;
    wire        I_BC;
    wire        I_BTR;
    wire        I_RLD;
    wire        I_RRD;
    reg         I_RXDD;
    wire        I_INRC;
    wire  [1:0] SetWZ;
    wire        SetDI;
    wire        SetEI;
    wire  [1:0] IMode;
    wire        Halt;
    wire        XYbit_undoc;
    wire        No_PC;
    wire        Really_Wait;

    t80_mcode #(.Mode(Mode)) mcode(
        .IR(IR),
        .ISet(ISet),
        .MCycle(MCycle),
        .F(F),
        .NMICycle(NMICycle),
        .IntCycle(IntCycle_i),
        .XY_State(XY_State),
        .MCycles(MCycles_d),
        .TStates(TStates),
        .Prefix(Prefix),
        .Inc_PC(Inc_PC),
        .Inc_WZ(Inc_WZ),
        .IncDec_16(IncDec_16),
        .Read_To_Acc(Read_To_Acc),
        .Read_To_Reg(Read_To_Reg),
        .Set_BusB_To(Set_BusB_To),
        .Set_BusA_To(Set_BusA_To),
        .ALU_Op(ALU_Op),
        .Save_ALU(Save_ALU),
        .PreserveC(PreserveC),
        .Arith16(Arith16),
        .Set_Addr_To(Set_Addr_To),
        .IORQ(IORQ_i),
        .Jump(Jump),
        .JumpE(JumpE),
        .JumpXY(JumpXY),
        .Call(Call),
        .RstP(RstP),
        .LDZ(LDZ),
        .LDW(LDW),
        .LDSPHL(LDSPHL),
        .LDHLSP(LDHLSP),
        .ADDSPdd(ADDSPdd),
        .Special_LD(Special_LD),
        .ExchangeDH(ExchangeDH),
        .ExchangeRp(ExchangeRp),
        .ExchangeAF(ExchangeAF),
        .ExchangeRS(ExchangeRS),
        .ExchangeWH(ExchangeWH),
        .I_DJNZ(I_DJNZ),
        .I_CPL(I_CPL),
        .I_CCF(I_CCF),
        .I_SCF(I_SCF),
        .I_RETN(I_RETN),
        .I_BT(I_BT),
        .I_BC(I_BC),
        .I_BTR(I_BTR),
        .I_RLD(I_RLD),
        .I_RRD(I_RRD),
        .I_INRC(I_INRC),
        .SetWZ(SetWZ),
        .SetDI(SetDI),
        .SetEI(SetEI),
        .IMode(IMode),
        .Halt(Halt),
        .NoRead(NoRead_i),
        .Write(Write_i),
        .No_PC(No_PC),
        .XYbit_undoc(XYbit_undoc));

    //------------------------------------------------------------------------
    // ALU
    //------------------------------------------------------------------------
    reg [7:0] alu_bitmask;
    always @* case (IR[5:3])
        3'b000:  alu_bitmask = 8'b00000001;
        3'b001:  alu_bitmask = 8'b00000010;
        3'b010:  alu_bitmask = 8'b00000100;
        3'b011:  alu_bitmask = 8'b00001000;
        3'b100:  alu_bitmask = 8'b00010000;
        3'b101:  alu_bitmask = 8'b00100000;
        3'b110:  alu_bitmask = 8'b01000000;
        default: alu_bitmask = 8'b10000000;
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
                    3'b000, 3'b001: begin           // ADD, ADC
                        alu_result    = alu_addsub_result;
                        F_Out[Flag_C] = alu_carry;
                        F_Out[Flag_H] = alu_half_carry;
                        F_Out[Flag_P] = alu_overflow;
                    end

                    3'b010, 3'b011, 3'b111: begin   // SUB, SBC, CP
                        alu_result    = alu_addsub_result;
                        F_Out[Flag_N] = 1;
                        F_Out[Flag_C] = !alu_carry;
                        F_Out[Flag_H] = !alu_half_carry;
                        F_Out[Flag_P] = alu_overflow;
                    end

                    3'b100:  begin alu_result = BusA & BusB; F_Out[Flag_H] = 1; end // AND
                    3'b101:  begin alu_result = BusA ^ BusB; F_Out[Flag_H] = 0; end // XOR
                    default: begin alu_result = BusA | BusB; F_Out[Flag_H] = 0; end // OR (110)
                endcase

                if (ALU_Op_r[2:0] == 3'b111) begin    // CP
                    F_Out[Flag_X] = BusB[3];
                    F_Out[Flag_Y] = BusB[5];
                end else begin
                    F_Out[Flag_X] = alu_result[3];
                    F_Out[Flag_Y] = alu_result[5];
                end

                F_Out[Flag_Z] = Z16_r ? F[Flag_Z] : (alu_result == 8'b0);
                F_Out[Flag_S] = alu_result[7];

                case (ALU_Op_r[2:0])
                    3'b000, 3'b001, 3'b010, 3'b011, 3'b111: begin   // ADD, ADC, SUB, SBC, CP
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
                if (IR[2:0] == 3'b110 || XY_State != 2'b00) begin
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
                    3'b000:  begin alu_result = {BusA[6:0], BusA[7]};   F_Out[Flag_C] = BusA[7]; end // RLC
                    3'b010:  begin alu_result = {BusA[6:0], F[Flag_C]}; F_Out[Flag_C] = BusA[7]; end // RL
                    3'b001:  begin alu_result = {BusA[0],   BusA[7:1]}; F_Out[Flag_C] = BusA[0]; end // RRC
                    3'b011:  begin alu_result = {F[Flag_C], BusA[7:1]}; F_Out[Flag_C] = BusA[0]; end // RR
                    3'b100:  begin alu_result = {BusA[6:0], 1'b0};      F_Out[Flag_C] = BusA[7]; end // SLA
                    3'b110:  begin alu_result = {BusA[6:0], 1'b1};      F_Out[Flag_C] = BusA[7]; end // SLL (Undocumented) / SWAP
                    3'b101:  begin alu_result = {BusA[7],   BusA[7:1]}; F_Out[Flag_C] = BusA[0]; end // SRA
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
    assign T_Res           = TState == (TStates) ? 1'b1 : 1'b0;
    assign NextIs_XY_Fetch = XY_State != 2'b00 && XY_Ind == 1'b0 && ((Set_Addr_To == aXY) || (MCycle == 3'b001 && IR == 8'b11001011) || (MCycle == 3'b001 && IR == 8'b00110110)) ? 1'b1 : 1'b0;
    assign Save_Mux        = ExchangeRp == 1'b1 ? BusB : Save_ALU_r == 1'b0 ? DI_Reg : ALU_Q;

    always @(posedge clk or posedge reset) begin : p1
        reg [7:0] n;
        reg [8:0] ioq;
        reg [8:0] temp_c;
        reg [4:0] temp_h;

        if (reset) begin
            PC            <= 0;
            // Program Counter
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

                if (LDHLSP == 1'b1 && MCycle == 3'b011 && TState == 1) begin
                    temp_c = ({1'b0,SP[7:0]}) + ({1'b0,Save_Mux});
                    temp_h = ({1'b0,SP[3:0]}) + ({1'b0,Save_Mux[3:0]});
                    F[Flag_Z] <= 1'b0;
                    F[Flag_N] <= 1'b0;
                    F[Flag_H] <= temp_h[4];
                    F[Flag_C] <= temp_c[8];
                end
                if (ADDSPdd == 1'b1 && TState == 1) begin
                    temp_c = ({1'b0,SP[7:0]}) + ({1'b0,Save_Mux});
                    temp_h = ({1'b0,SP[3:0]}) + ({1'b0,Save_Mux[3:0]});
                    F[Flag_Z] <= 1'b0;
                    F[Flag_N] <= 1'b0;
                    F[Flag_H] <= temp_h[4];
                    F[Flag_C] <= temp_c[8];
                end
                if (IMode != 2'b11) begin
                    IStatus <= IMode;
                end
                Arith16_r <= Arith16;
                PreserveC_r <= PreserveC;
                if (ISet == 2'b10 && ALU_Op[2] == 1'b0 && ALU_Op[0] == 1'b1 && MCycle == 3'b011) begin
                    Z16_r <= 1'b1;
                end
                else begin
                    Z16_r <= 1'b0;
                end
                if (MCycle == 3'b001 && TState[2] == 1'b0) begin
                    // MCycle = 1 and TState = 1, 2, or 3
                    if (TState == 2 && WAIT_n == 1'b1) begin
                        A[7:0] <= R;
                        A[15:8] <= I;
                        R[6:0] <= R[6:0] + 1;
                        if (Jump == 1'b0 && Call == 1'b0 && NMICycle == 1'b0 && IntCycle_i == 1'b0 && !(Halt_FF == 1'b1 || Halt == 1'b1)) begin
                            PC <= PC + 1;
                        end
                        if (IntCycle_i == 1'b1 && IStatus == 2'b01) begin
                            IR <= 8'hFF;
                        end
                        else if (Halt_FF == 1'b1 || (IntCycle_i == 1'b1 && IStatus == 2'b10) || NMICycle == 1'b1) begin
                            IR <= 8'h00;
                        end
                        else begin
                            IR <= DInst;
                        end
                        if (IntCycle_i == 1'b1 && IStatus == 2'b10) begin
                            // IM2 vector address low byte from bus
                            WZ[7:0] <= DInst;
                        end
                        ISet <= 2'b00;
                        if (Prefix != 2'b00) begin
                            if (Prefix == 2'b11) begin
                                if (IR[5] == 1'b1) begin
                                    XY_State <= 2'b10;
                                end
                                else begin
                                    XY_State <= 2'b01;
                                end
                            end
                            else begin
                                if (Prefix == 2'b10) begin
                                    XY_State <= 2'b00;
                                    XY_Ind <= 1'b0;
                                end
                                ISet <= Prefix;
                            end
                        end
                        else begin
                            XY_State <= 2'b00;
                            XY_Ind <= 1'b0;
                        end
                    end
                end
                else begin
                    // either (MCycle > 1) OR (MCycle = 1 AND TState > 3)
                    if (MCycle == 3'b110) begin
                        XY_Ind <= 1'b1;
                        if (Prefix == 2'b01) begin
                            ISet <= 2'b01;
                        end
                    end
                    if (T_Res == 1'b1) begin
                        BTR_r <= (I_BT | I_BC | I_BTR) & ~No_BTR;
                        if (Jump == 1'b1) begin
                            A[15:8] <= DI_Reg;
                            A[7:0] <= WZ[7:0];
                            PC[15:8] <= DI_Reg;
                            PC[7:0] <= WZ[7:0];
                        end
                        else if (JumpXY == 1'b1) begin
                            A <= RegBusC;
                            PC <= RegBusC;
                        end
                        else if (Call == 1'b1 || RstP == 1'b1) begin
                            A <= WZ;
                            PC <= WZ;
                        end
                        else if (MCycle == MCycles && NMICycle == 1'b1) begin
                            A <= 16'b0000000001100110;
                            PC <= 16'b0000000001100110;
                        end
                        else if ((MCycle == 3'b011) && IntCycle_i == 1'b1 && IStatus == 2'b10) begin
                            A[15:8] <= I;
                            A[7:0] <= WZ[7:0];
                            PC[15:8] <= I;
                            PC[7:0] <= WZ[7:0];
                        end
                        else begin
                            case (Set_Addr_To)
                            aXY : begin
                                if (XY_State == 2'b00) begin
                                    A <= RegBusC;
                                end
                                else begin
                                    if (NextIs_XY_Fetch == 1'b1) begin
                                        A <= PC;
                                    end
                                    else begin
                                        A <= WZ;
                                    end
                                end
                            end
                            aIOA : begin
                                A[15:8] <= ACC;
                                A[7:0] <= DI_Reg;
                                WZ <= ({ACC,DI_Reg}) + 1'b1;
                            end
                            aSP : begin
                                A <= SP;
                            end
                            aBC : begin
                                A <= RegBusC;
                                if (SetWZ == 2'b01) begin
                                    WZ <= RegBusC + 1'b1;
                                end
                                if (SetWZ == 2'b10) begin
                                    WZ[7:0] <= RegBusC[7:0] + 1'b1;
                                    WZ[15:8] <= ACC;
                                end
                            end
                            aDE : begin
                                A <= RegBusC;
                                if (SetWZ == 2'b10) begin
                                    WZ[7:0] <= RegBusC[7:0] + 1'b1;
                                    WZ[15:8] <= ACC;
                                end
                            end
                            aZI : begin
                                if (Inc_WZ == 1'b1) begin
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
                            default : begin
                                if (ISet == 2'b10 && IR[7:4] == 4'hB && IR[2:1] == 2'b01 && MCycle == 3 && No_BTR == 1'b0) begin
                                    // INIR, INDR, OTIR, OTDR
                                    A <= RegBusA_r;
                                end
                                else if (No_PC == 1'b0 || No_BTR == 1'b1 || (I_DJNZ == 1'b1 && IncDecZ == 1'b1)) begin
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
                        if (I_CPL == 1'b1) begin
                            // CPL
                            ACC <= ~ACC;
                            F[Flag_Y] <= ~ACC[5];
                            F[Flag_H] <= 1'b1;
                            F[Flag_X] <= ~ACC[3];
                            F[Flag_N] <= 1'b1;
                        end
                        if (I_CCF == 1'b1) begin
                            // CCF
                            F[Flag_C] <= ~F[Flag_C];
                            F[Flag_Y] <= ACC[5];
                            F[Flag_H] <= F[Flag_C];
                            F[Flag_X] <= ACC[3];
                            F[Flag_N] <= 1'b0;
                        end
                        if (I_SCF == 1'b1) begin
                            // SCF
                            F[Flag_C] <= 1'b1;
                            F[Flag_Y] <= ACC[5];
                            F[Flag_H] <= 1'b0;
                            F[Flag_X] <= ACC[3];
                            F[Flag_N] <= 1'b0;
                        end
                    end
                    if ((TState == 2 && Really_Wait == 1'b0 && I_BTR == 1'b1 && IR[0] == 1'b1) || (TState == 1 && I_BTR == 1'b1 && IR[0] == 1'b0)) begin
                        ioq = ({1'b0,DI_Reg}) + ({1'b0,ID16[7:0]});
                        F[Flag_N] <= DI_Reg[7];
                        F[Flag_C] <= ioq[8];
                        F[Flag_H] <= ioq[8];
                        ioq = (ioq & 9'b000000111) ^ ({1'b0,BusA});
                        F[Flag_P] <= ~(ioq[0] ^ ioq[1] ^ ioq[2] ^ ioq[3] ^ ioq[4] ^ ioq[5] ^ ioq[6] ^ ioq[7]);
                    end
                    if (TState == 2 && Really_Wait == 1'b0) begin
                        if (ISet == 2'b01 && MCycle == 3'b111) begin
                            IR <= DInst;
                        end
                        if (JumpE == 1'b1) begin
                            PC <= PC + {{8{DI_Reg[7]}}, DI_Reg};
                            WZ <= PC + {{8{DI_Reg[7]}}, DI_Reg};
                        end
                        else if (Inc_PC == 1'b1) begin
                            PC <= PC + 1;
                        end
                        if (BTR_r == 1'b1) begin
                            PC <= PC - 2;
                        end
                        if (RstP == 1'b1) begin
                            WZ <= {16{1'b0}};
                            WZ[5:3] <= IR[5:3];
                        end
                    end
                    if (TState == 3 && MCycle == 3'b110) begin
                        WZ <= RegBusC + {{8{DI_Reg[7]}}, DI_Reg};
                    end
                    if (MCycle == 3'b011 && TState == 4 && No_BTR == 1'b0) begin
                        if (I_BT == 1'b1 || I_BC == 1'b1) begin
                            WZ <= (PC) - 1'b1;
                        end
                    end
                    if ((TState == 2 && Really_Wait == 1'b0) || (TState == 4 && MCycle == 3'b001)) begin
                        if (IncDec_16[2:0] == 3'b111) begin
                            if (IncDec_16[3] == 1'b1) begin
                                SP <= SP - 1;
                            end
                            else begin
                                SP <= SP + 1;
                            end
                        end
                    end
                    if (ADDSPdd == 1'b1 && TState == 2) begin
                        WZ <= SP;
                        SP <= SP + {{8{Save_Mux[7]}}, Save_Mux};
                    end
                    if (LDSPHL == 1'b1) begin
                        SP <= RegBusC;
                    end
                    if (ExchangeAF == 1'b1) begin
                        Ap <= ACC;
                        ACC <= Ap;
                        Fp <= F;
                        F <= Fp;
                    end
                    if (ExchangeRS == 1'b1) begin
                        Alternate <= ~Alternate;
                    end
                end
                if (TState == 3) begin
                    if (LDZ == 1'b1) begin
                        WZ[7:0] <= DI_Reg;
                    end
                    if (LDW == 1'b1) begin
                        WZ[15:8] <= DI_Reg;
                    end
                    if (Special_LD[2] == 1'b1) begin
                        case (Special_LD[1:0])
                        2'b00 : begin
                            ACC <= I;
                            F[Flag_P] <= IntE_FF2;
                            F[Flag_S] <= I[7];
                            if (I == 8'h00) begin
                                F[Flag_Z] <= 1'b1;
                            end
                            else begin
                                F[Flag_Z] <= 1'b0;
                            end
                            F[Flag_Y] <= I[5];
                            F[Flag_H] <= 1'b0;
                            F[Flag_X] <= I[3];
                            F[Flag_N] <= 1'b0;
                        end
                        2'b01 : begin
                            ACC <= R;
                            F[Flag_P] <= IntE_FF2;
                            F[Flag_S] <= R[7];
                            if (R == 8'h00) begin
                                F[Flag_Z] <= 1'b1;
                            end
                            else begin
                                F[Flag_Z] <= 1'b0;
                            end
                            F[Flag_Y] <= R[5];
                            F[Flag_H] <= 1'b0;
                            F[Flag_X] <= R[3];
                            F[Flag_N] <= 1'b0;
                        end
                        2'b10 : begin
                            I <= ACC;
                        end
                        default : begin
                            R <= ACC;
                        end
                        endcase
                    end
                end
                if ((I_DJNZ == 1'b0 && Save_ALU_r == 1'b1) || ALU_Op_r == 4'b1001) begin
                    F[7:1] <= F_Out[7:1];
                    if (PreserveC_r == 1'b0) begin
                        F[Flag_C] <= F_Out[0];
                    end
                end
                if (T_Res == 1'b1 && I_INRC == 1'b1) begin
                    F[Flag_H] <= 1'b0;
                    F[Flag_N] <= 1'b0;
                    F[Flag_X] <= DI_Reg[3];
                    F[Flag_Y] <= DI_Reg[5];
                    if (DI_Reg[7:0] == 8'h00) begin
                        F[Flag_Z] <= 1'b1;
                    end
                    else begin
                        F[Flag_Z] <= 1'b0;
                    end
                    F[Flag_S] <= DI_Reg[7];
                    F[Flag_P] <= ~(DI_Reg[0] ^ DI_Reg[1] ^ DI_Reg[2] ^ DI_Reg[3] ^ DI_Reg[4] ^ DI_Reg[5] ^ DI_Reg[6] ^ DI_Reg[7]);
                end
                if (TState == 1 && Auto_Wait_t1 == 1'b0) begin
                    // Keep D0 from M3 for RLD/RRD (Sorgelig)
                    I_RXDD <= I_RLD | I_RRD;
                    if (I_RXDD == 1'b0) begin
                        DO <= BusB;
                    end
                    if (I_RLD == 1'b1) begin
                        DO[3:0] <= BusA[3:0];
                        DO[7:4] <= BusB[3:0];
                    end
                    if (I_RRD == 1'b1) begin
                        DO[3:0] <= BusB[7:4];
                        DO[7:4] <= BusA[3:0];
                    end
                end
                if (T_Res == 1'b1) begin
                    Read_To_Reg_r[3:0] <= Set_BusA_To;
                    Read_To_Reg_r[4] <= Read_To_Reg;
                    if (Read_To_Acc == 1'b1) begin
                        Read_To_Reg_r[3:0] <= 4'b0111;
                        Read_To_Reg_r[4] <= 1'b1;
                    end
                end
                if (TState == 1 && I_BT == 1'b1) begin
                    F[Flag_X] <= ALU_Q[3];
                    F[Flag_Y] <= ALU_Q[1];
                    F[Flag_H] <= 1'b0;
                    F[Flag_N] <= 1'b0;
                end
                if (TState == 1 && I_BC == 1'b1) begin
                    n = ALU_Q - ({7'b0000000,F_Out[Flag_H]});
                    F[Flag_X] <= n[3];
                    F[Flag_Y] <= n[1];
                end
                if (I_BC == 1'b1 || I_BT == 1'b1) begin
                    F[Flag_P] <= IncDecZ;
                end
                if ((TState == 1 && Save_ALU_r == 1'b0 && Auto_Wait_t1 == 1'b0) || (Save_ALU_r == 1'b1 && ALU_Op_r != 4'b0111)) begin
                    case (Read_To_Reg_r)
                    5'b10111 : begin
                        ACC <= Save_Mux;
                    end
                    5'b10110 : begin
                        DO <= Save_Mux;
                    end
                    5'b11000 : begin
                        SP[7:0] <= Save_Mux;
                    end
                    5'b11001 : begin
                        SP[15:8] <= Save_Mux;
                    end
                    5'b11011 : begin
                        F <= Save_Mux;
                    end
                    default : begin
                    end
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
        if (ClkEn == 1'b1) begin
            // Bus A / Write
            RegAddrA_r <= {Alternate,Set_BusA_To[2:1]};
            if (XY_Ind == 1'b0 && XY_State != 2'b00 && Set_BusA_To[2:1] == 2'b10) begin
                RegAddrA_r <= {XY_State[1],2'b11};
            end
            // Bus B
            RegAddrB_r <= {Alternate,Set_BusB_To[2:1]};
            if (XY_Ind == 1'b0 && XY_State != 2'b00 && Set_BusB_To[2:1] == 2'b10) begin
                RegAddrB_r <= {XY_State[1],2'b11};
            end
            // Address from register
            RegAddrC <= {Alternate,Set_Addr_To[1:0]};
            // Jump (HL), LD SP,HL
            if ((JumpXY == 1'b1 || LDSPHL == 1'b1)) begin
                RegAddrC <= {Alternate,2'b10};
            end
            if (((JumpXY == 1'b1 || LDSPHL == 1'b1) && XY_State != 2'b00) || (MCycle == 3'b110)) begin
                RegAddrC <= {XY_State[1],2'b11};
            end
            if (I_DJNZ == 1'b1 && Save_ALU_r == 1'b1) begin
                IncDecZ <= F_Out[Flag_Z];
            end
            if ((TState == 2 || (TState == 3 && MCycle == 3'b001)) && IncDec_16[2:0] == 3'b100) begin
                if (ID16 == 0) begin
                    IncDecZ <= 1'b0;
                end
                else begin
                    IncDecZ <= 1'b1;
                end
            end
            RegBusA_r <= RegBusA;
        end
    end

    assign RegAddrA = (TState == 2 || (TState == 3 && MCycle == 3'b001 && IncDec_16[2] == 1'b1)) && XY_State == 2'b00 ? {Alternate,IncDec_16[1:0]} : (TState == 2 || (TState == 3 && MCycle == 3'b001 && IncDec_16[2] == 1'b1)) && IncDec_16[1:0] == 2'b10 ? {XY_State[1],2'b11} : ExchangeDH == 1'b1 && TState == 3 ? {Alternate,2'b10} : ExchangeDH == 1'b1 && TState == 4 ? {Alternate,2'b01} : ExchangeWH == 1'b1 && XY_State == 2'b00 && TState == 4 ? {Alternate,2'b10} : ExchangeWH == 1'b1 && TState == 4 ? {XY_State[1],2'b11} : LDHLSP == 1'b1 && TState == 4 ? 3'b010 : RegAddrA_r;
    assign RegAddrB = ExchangeDH == 1'b1 && TState == 3 ? {Alternate,2'b01} : RegAddrB_r;
    assign ID16 = IncDec_16[3] == 1'b1 ? (RegBusA) - 1 : (RegBusA) + 1;
    always @* begin
        RegWEH = 1'b0;
        RegWEL = 1'b0;
        if ((TState == 1 && Save_ALU_r == 1'b0 && Auto_Wait_t1 == 1'b0) || (Save_ALU_r == 1'b1 && ALU_Op_r != 4'b0111)) begin
            case (Read_To_Reg_r)
            5'b10000,5'b10001,5'b10010,5'b10011,5'b10100,5'b10101 : begin
                RegWEH = ~Read_To_Reg_r[0];
                RegWEL = Read_To_Reg_r[0];
            end
            default : begin
            end
            endcase
        end
        if (ExchangeDH == 1'b1 && (TState == 3 || TState == 4)) begin
            RegWEH = 1'b1;
            RegWEL = 1'b1;
        end
        if (((LDHLSP == 1'b1 && MCycle == 3'b010) || ExchangeWH == 1'b1) && TState == 4) begin
            RegWEH = 1'b1;
            RegWEL = 1'b1;
        end
        if (IncDec_16[2] == 1'b1 && ((TState == 2 && Really_Wait == 1'b0 && MCycle != 3'b001) || (TState == 3 && MCycle == 3'b001))) begin
            case (IncDec_16[1:0])
            2'b00,2'b01,2'b10 : begin
                RegWEH = 1'b1;
                RegWEL = 1'b1;
            end
            default : begin
            end
            endcase
        end
    end

    assign TmpAddr2 = (SP) + {{8{Save_Mux[7]}}, Save_Mux};
    always @* begin
        RegDIH = Save_Mux;
        RegDIL = Save_Mux;
        if (LDHLSP == 1'b1 && MCycle == 3'b010 && TState == 4) begin
            RegDIH = TmpAddr2[15:8];
            RegDIL = TmpAddr2[7:0];
        end
        if (ExchangeDH == 1'b1 && TState == 3) begin
            RegDIH = RegBusB[15:8];
            RegDIL = RegBusB[7:0];
        end
        if (ExchangeDH == 1'b1 && TState == 4) begin
            RegDIH = RegBusA_r[15:8];
            RegDIL = RegBusA_r[7:0];
        end
        if (ExchangeWH == 1'b1 && TState == 4) begin
            RegDIH = WZ[15:8];
            RegDIL = WZ[7:0];
        end
        if (IncDec_16[2] == 1'b1 && ((TState == 2 && MCycle != 3'b001) || (TState == 3 && MCycle == 3'b001))) begin
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
        if (ClkEn == 1'b1) begin
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
                4'b1110: BusB <= (IR == 8'h71 && out0 == 1'b1) ? 8'hFF : 8'h00;
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
    always @(posedge clk or posedge reset) begin : p2
        reg OldNMI_n;

        if (reset) begin
            MCycle       <= 3'b001;
            TState       <= 3'b000;
            Pre_XY_F_M   <= 3'b000;
            Halt_FF      <= 0;
            NMICycle     <= 0;
            IntCycle_i   <= 0;
            IntE_FF1     <= 0;
            IntE_FF2     <= 0;
            No_BTR       <= 0;
            Auto_Wait_t1 <= 0;
            Auto_Wait_t2 <= 0;
            NMI_s        <= 0;

        end else begin
            if (NMI_n == 1'b0 && OldNMI_n == 1'b1) begin
                NMI_s <= 1'b1;
            end
            OldNMI_n = NMI_n;
            if (CEN == 1'b1) begin
                Auto_Wait_t2 <= Auto_Wait_t1;
                if (T_Res == 1'b1) begin
                    Auto_Wait_t1 <= 1'b0;
                    Auto_Wait_t2 <= 1'b0;
                end
                else begin
                    Auto_Wait_t1 <= Auto_Wait | IORQ_i;
                end
                No_BTR <= (I_BT & ( ~IR[4] | ~F[Flag_P])) | (I_BC & ( ~IR[4] | F[Flag_Z] | ~F[Flag_P])) | (I_BTR & ( ~IR[4] | F[Flag_Z]));
                if (TState == 2) begin
                    if (SetEI == 1'b1) begin
                        IntE_FF1 <= 1'b1;
                        IntE_FF2 <= 1'b1;
                    end
                    if (I_RETN == 1'b1) begin
                        IntE_FF1 <= IntE_FF2;
                    end
                end
                if (TState == 3) begin
                    if (SetDI == 1'b1) begin
                        IntE_FF1 <= 1'b0;
                        IntE_FF2 <= 1'b0;
                    end
                end
                if (IntCycle_i == 1'b1 || NMICycle == 1'b1) begin
                    Halt_FF <= 1'b0;
                end
                if (TState == 2 && Really_Wait == 1'b1) begin
                end
                else if (T_Res == 1'b1) begin
                    if (Halt == 1'b1) begin
                        Halt_FF <= 1'b1;
                    end
                    TState <= 3'b001;
                    if (NextIs_XY_Fetch == 1'b1) begin
                        MCycle <= 3'b110;
                        Pre_XY_F_M <= MCycle;
                        if (IR == 8'b00110110 && Mode == 0) begin
                            Pre_XY_F_M <= 3'b010;
                        end
                    end
                    else if ((MCycle == 3'b111) || (MCycle == 3'b110 && Mode == 1 && ISet != 2'b01)) begin
                        MCycle <= (Pre_XY_F_M) + 1;
                    end
                    else if ((MCycle == MCycles) || No_BTR == 1'b1 || (MCycle == 3'b010 && I_DJNZ == 1'b1 && IncDecZ == 1'b1)) begin
                        MCycle <= 3'b001;
                        IntCycle_i <= 1'b0;
                        NMICycle <= 1'b0;
                        if (NMI_s == 1'b1 && Prefix == 2'b00) begin
                            NMI_s <= 1'b0;
                            NMICycle <= 1'b1;
                            IntE_FF1 <= 1'b0;
                        end
                        else if (IntE_FF1 == 1'b1 && INT_n == 1'b0 && Prefix == 2'b00 && SetEI == 1'b0) begin
                            IntCycle_i <= 1'b1;
                            IntE_FF1 <= 1'b0;
                            IntE_FF2 <= 1'b0;
                        end
                    end
                    else begin
                        MCycle <= (MCycle) + 1;
                    end
                end
                else begin
                    if (!(Auto_Wait == 1'b1 && Auto_Wait_t2 == 1'b0)) begin
                        TState <= TState + 1;
                    end
                end
            end
        end
    end

    assign Auto_Wait = IntCycle_i == 1'b1 && MCycle == 3'b001 ? 1'b1 : 1'b0;

endmodule
