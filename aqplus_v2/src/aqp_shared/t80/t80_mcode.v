`default_nettype none
`timescale 1 ns / 1 ps

module t80_mcode(
input wire [7:0] IR,
input wire [1:0] ISet,
input wire [2:0] MCycle,
input wire [7:0] F,
input wire NMICycle,
input wire IntCycle,
input wire [1:0] XY_State,
output reg [2:0] MCycles,
output reg [2:0] TStates,
output reg [1:0] Prefix,
output reg Inc_PC,
output reg Inc_WZ,
output reg [3:0] IncDec_16,
output reg Read_To_Reg,
output reg Read_To_Acc,
output reg [3:0] Set_BusA_To,
output reg [3:0] Set_BusB_To,
output reg [3:0] ALU_Op,
output reg Save_ALU,
output reg PreserveC,
output reg Arith16,
output reg [2:0] Set_Addr_To,
output reg IORQ,
output reg Jump,
output reg JumpE,
output reg JumpXY,
output reg Call,
output reg RstP,
output reg LDZ,
output reg LDW,
output reg LDSPHL,
output reg LDHLSP,
output reg ADDSPdd,
output reg [2:0] Special_LD,
output reg ExchangeDH,
output reg ExchangeRp,
output reg ExchangeAF,
output reg ExchangeRS,
output reg ExchangeWH,
output reg I_DJNZ,
output reg I_CPL,
output reg I_CCF,
output reg I_SCF,
output reg I_RETN,
output reg I_BT,
output reg I_BC,
output reg I_BTR,
output reg I_RLD,
output reg I_RRD,
output reg I_INRC,
output reg [1:0] SetWZ,
output reg SetDI,
output reg SetEI,
output reg [1:0] IMode,
output reg Halt,
output reg NoRead,
output reg Write,
output reg No_PC,
output reg XYbit_undoc
);

    localparam
        Flag_C = 0,
        // Flag_N = 1,
        Flag_P = 2,
        // Flag_X = 3,
        // Flag_H = 4,
        // Flag_Y = 5,
        Flag_Z = 6,
        Flag_S = 7;

    localparam
        aNone = 3'b111,
        aBC   = 3'b000,
        aDE   = 3'b001,
        aXY   = 3'b010,
        aIOA  = 3'b100,
        aSP   = 3'b101,
        aZI   = 3'b110;

parameter [31:0] Mode=0;
// None,CB,ED,DD/FD
// BC,DE,HL,SP   0 is inc
// B,C,D,E,H,L,DI/DB,A,SP(L),SP(M),0,F
// B,C,D,E,H,L,DI,A,SP(L),SP(M),1,F,PC(L),PC(M),0
// ADD, ADC, SUB, SBC, AND, XOR, OR, CP, ROT, BIT, SET, RES, DAA, RLD, RRD, None
// aNone,aXY,aIOA,aSP,aBC,aDE,aZI
// A,I;A,R;I,A;R,A;None



reg cc_is_true;

  always @* begin
    case(IR[5:3])
      3'b000:  cc_is_true = !F[Flag_Z]; // NZ
      3'b001:  cc_is_true =  F[Flag_Z]; // Z
      3'b010:  cc_is_true = !F[Flag_C]; // NC
      3'b011:  cc_is_true =  F[Flag_C]; // C
      3'b100:  cc_is_true = !F[Flag_P]; // PO
      3'b101:  cc_is_true =  F[Flag_P]; // PE
      3'b110:  cc_is_true = !F[Flag_S]; // P
      default: cc_is_true =  F[Flag_S]; // M
    endcase
  end

    reg [2:0] DDD;
    reg [2:0] SSS;
    reg [1:0] DPair;

  always @* begin

    DDD = IR[5:3];
    SSS = IR[2:0];
    DPair = IR[5:4];
    MCycles = 3'b001;
    if(MCycle == 3'b001) begin
      TStates = 3'b100;
    end
    else begin
      TStates = 3'b011;
    end
    Prefix = 2'b00;
    Inc_PC = 1'b0;
    Inc_WZ = 1'b0;
    IncDec_16 = 4'b0000;
    Read_To_Acc = 1'b0;
    Read_To_Reg = 1'b0;
    Set_BusB_To = 4'b0000;
    Set_BusA_To = 4'b0000;
    ALU_Op = {1'b0,IR[5:3]};
    Save_ALU = 1'b0;
    PreserveC = 1'b0;
    Arith16 = 1'b0;
    IORQ = 1'b0;
    Set_Addr_To = aNone;
    Jump = 1'b0;
    JumpE = 1'b0;
    JumpXY = 1'b0;
    Call = 1'b0;
    RstP = 1'b0;
    LDZ = 1'b0;
    LDW = 1'b0;
    LDSPHL = 1'b0;
    LDHLSP = 1'b0;
    ADDSPdd = 1'b0;
    Special_LD = 3'b000;
    ExchangeDH = 1'b0;
    ExchangeRp = 1'b0;
    ExchangeAF = 1'b0;
    ExchangeRS = 1'b0;
    ExchangeWH = 1'b0;
    I_DJNZ = 1'b0;
    I_CPL = 1'b0;
    I_CCF = 1'b0;
    I_SCF = 1'b0;
    I_RETN = 1'b0;
    I_BT = 1'b0;
    I_BC = 1'b0;
    I_BTR = 1'b0;
    I_RLD = 1'b0;
    I_RRD = 1'b0;
    I_INRC = 1'b0;
    SetDI = 1'b0;
    SetEI = 1'b0;
    IMode = 2'b11;
    Halt = 1'b0;
    NoRead = 1'b0;
    Write = 1'b0;
    No_PC = 1'b0;
    XYbit_undoc = 1'b0;
    SetWZ = 2'b00;
    case(ISet)
    2'b00 : begin
      //----------------------------------------------------------------------------
      //
      // Unprefixed instructions
      //
      //----------------------------------------------------------------------------
      case(IR)
            // 8 BIT LOAD GROUP
      8'b01000000,8'b01000001,8'b01000010,8'b01000011,8'b01000100,8'b01000101,8'b01000111,8'b01001000,8'b01001001,8'b01001010,8'b01001011,8'b01001100,8'b01001101,8'b01001111,8'b01010000,8'b01010001,8'b01010010,8'b01010011,8'b01010100,8'b01010101,8'b01010111,8'b01011000,8'b01011001,8'b01011010,8'b01011011,8'b01011100,8'b01011101,8'b01011111,8'b01100000,8'b01100001,8'b01100010,8'b01100011,8'b01100100,8'b01100101,8'b01100111,8'b01101000,8'b01101001,8'b01101010,8'b01101011,8'b01101100,8'b01101101,8'b01101111,8'b01111000,8'b01111001,8'b01111010,8'b01111011,8'b01111100,8'b01111101,8'b01111111 : begin
        // LD r,r'
        Set_BusB_To[2:0] = SSS;
        ExchangeRp = 1'b1;
        Set_BusA_To[2:0] = DDD;
        Read_To_Reg = 1'b1;
      end
      8'b00000110,8'b00001110,8'b00010110,8'b00011110,8'b00100110,8'b00101110,8'b00111110 : begin
        // LD r,n
        MCycles = 3'b010;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          Set_BusA_To[2:0] = DDD;
          Read_To_Reg = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01000110,8'b01001110,8'b01010110,8'b01011110,8'b01100110,8'b01101110,8'b01111110 : begin
        // LD r,(HL)
        MCycles = 3'b010;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aXY;
        end
        3'b010 : begin
          Set_BusA_To[2:0] = DDD;
          Read_To_Reg = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01110000,8'b01110001,8'b01110010,8'b01110011,8'b01110100,8'b01110101,8'b01110111 : begin
        // LD (HL),r
        MCycles = 3'b010;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aXY;
          Set_BusB_To[2:0] = SSS;
          Set_BusB_To[3] = 1'b0;
        end
        3'b010 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00110110 : begin
        // LD (HL),n
        MCycles = 3'b011;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          Set_Addr_To = aXY;
          Set_BusB_To[2:0] = SSS;
          Set_BusB_To[3] = 1'b0;
        end
        3'b011 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00001010 : begin
        // LD A,(BC)
        MCycles = 3'b010;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aBC;
        end
        3'b010 : begin
          Read_To_Acc = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00011010 : begin
        // LD A,(DE)
        MCycles = 3'b010;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aDE;
        end
        3'b010 : begin
          Read_To_Acc = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00111010 : begin
        // LD A,(nn)
        MCycles = 3'b100;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          LDZ = 1'b1;
        end
        3'b011 : begin
          Set_Addr_To = aZI;
          Inc_PC = 1'b1;
        end
        3'b100 : begin
          Read_To_Acc = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00000010 : begin
        // LD (BC),A
        MCycles = 3'b010;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aBC;
          Set_BusB_To = 4'b0111;
          SetWZ = 2'b10;
        end
        3'b010 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00010010 : begin
        // LD (DE),A
        MCycles = 3'b010;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aDE;
          Set_BusB_To = 4'b0111;
          SetWZ = 2'b10;
        end
        3'b010 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00110010 : begin
        // LD (nn),A
        MCycles = 3'b100;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          LDZ = 1'b1;
        end
        3'b011 : begin
          Set_Addr_To = aZI;
          SetWZ = 2'b10;
          Inc_PC = 1'b1;
          Set_BusB_To = 4'b0111;
        end
        3'b100 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
        // 16 BIT LOAD GROUP
      end
      8'b00000001,8'b00010001,8'b00100001,8'b00110001 : begin
        // LD dd,nn
        MCycles = 3'b011;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          Read_To_Reg = 1'b1;
          if(DPair == 2'b11) begin
            Set_BusA_To[3:0] = 4'b1000;
          end
          else begin
            Set_BusA_To[2:1] = DPair;
            Set_BusA_To[0] = 1'b1;
          end
        end
        3'b011 : begin
          Inc_PC = 1'b1;
          Read_To_Reg = 1'b1;
          if(DPair == 2'b11) begin
            Set_BusA_To[3:0] = 4'b1001;
          end
          else begin
            Set_BusA_To[2:1] = DPair;
            Set_BusA_To[0] = 1'b0;
          end
        end
        default : begin
        end
        endcase
      end
      8'b00101010 : begin
        // LD HL,(nn)
        MCycles = 3'b101;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          LDZ = 1'b1;
        end
        3'b011 : begin
          Set_Addr_To = aZI;
          Inc_PC = 1'b1;
          LDW = 1'b1;
        end
        3'b100 : begin
          Set_BusA_To[2:0] = 3'b101;
          // L
          Read_To_Reg = 1'b1;
          Inc_WZ = 1'b1;
          Set_Addr_To = aZI;
        end
        3'b101 : begin
          Set_BusA_To[2:0] = 3'b100;
          // H
          Read_To_Reg = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00100010 : begin
        // LD (nn),HL
        MCycles = 3'b101;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          LDZ = 1'b1;
        end
        3'b011 : begin
          Set_Addr_To = aZI;
          Inc_PC = 1'b1;
          LDW = 1'b1;
          Set_BusB_To = 4'b0101;
          // L
        end
        3'b100 : begin
          Inc_WZ = 1'b1;
          Set_Addr_To = aZI;
          Write = 1'b1;
          Set_BusB_To = 4'b0100;
          // H
        end
        3'b101 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b11111001 : begin
        // LD SP,HL
        TStates = 3'b110;
        LDSPHL = 1'b1;
      end
      8'b11000101,8'b11010101,8'b11100101,8'b11110101 : begin
        // PUSH qq
        MCycles = 3'b011;
        case(MCycle)
        3'b001 : begin
          TStates = 3'b101;
          IncDec_16 = 4'b1111;
          Set_Addr_To = aSP;
          if(DPair == 2'b11) begin
            Set_BusB_To = 4'b0111;
          end
          else begin
            Set_BusB_To[2:1] = DPair;
            Set_BusB_To[0] = 1'b0;
            Set_BusB_To[3] = 1'b0;
          end
        end
        3'b010 : begin
          IncDec_16 = 4'b1111;
          Set_Addr_To = aSP;
          if(DPair == 2'b11) begin
            Set_BusB_To = 4'b1011;
          end
          else begin
            Set_BusB_To[2:1] = DPair;
            Set_BusB_To[0] = 1'b1;
            Set_BusB_To[3] = 1'b0;
          end
          Write = 1'b1;
        end
        3'b011 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b11000001,8'b11010001,8'b11100001,8'b11110001 : begin
        // POP qq
        MCycles = 3'b011;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aSP;
        end
        3'b010 : begin
          IncDec_16 = 4'b0111;
          Set_Addr_To = aSP;
          Read_To_Reg = 1'b1;
          if(DPair == 2'b11) begin
            Set_BusA_To[3:0] = 4'b1011;
          end
          else begin
            Set_BusA_To[2:1] = DPair;
            Set_BusA_To[0] = 1'b1;
          end
        end
        3'b011 : begin
          IncDec_16 = 4'b0111;
          Read_To_Reg = 1'b1;
          if(DPair == 2'b11) begin
            Set_BusA_To[3:0] = 4'b0111;
          end
          else begin
            Set_BusA_To[2:1] = DPair;
            Set_BusA_To[0] = 1'b0;
          end
        end
        default : begin
        end
        endcase
        // EXCHANGE, BLOCK TRANSFER AND SEARCH GROUP
      end
      8'b11101011 : begin
        // EX DE,HL
        ExchangeDH = 1'b1;
      end
      8'b00001000 : begin
        // EX AF,AF'
        ExchangeAF = 1'b1;
      end
      8'b11011001 : begin
        // EXX
        ExchangeRS = 1'b1;
      end
      8'b11100011 : begin
        // EX (SP),HL
        MCycles = 3'b101;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aSP;
        end
        3'b010 : begin
          Set_Addr_To = aSP;
          LDZ = 1'b1;
          IncDec_16 = 4'b0111;
          // SP = SP+1
        end
        3'b011 : begin
          TStates = 3'b100;
          Set_BusB_To = 4'b0100;
          Set_Addr_To = aSP;
          LDW = 1'b1;
        end
        3'b100 : begin
          Set_BusB_To = 4'b0101;
          Write = 1'b1;
          IncDec_16 = 4'b1111;
          // SP = SP-1
          Set_Addr_To = aSP;
        end
        3'b101 : begin
          ExchangeWH = 1'b1;
          // save WZ to HL
          TStates = 3'b101;
          Write = 1'b1;
        end
        default : begin
        end
        endcase
        // 8 BIT ARITHMETIC AND LOGICAL GROUP
      end
      8'b10000000,8'b10000001,8'b10000010,8'b10000011,8'b10000100,8'b10000101,8'b10000111,8'b10001000,8'b10001001,8'b10001010,8'b10001011,8'b10001100,8'b10001101,8'b10001111,8'b10010000,8'b10010001,8'b10010010,8'b10010011,8'b10010100,8'b10010101,8'b10010111,8'b10011000,8'b10011001,8'b10011010,8'b10011011,8'b10011100,8'b10011101,8'b10011111,8'b10100000,8'b10100001,8'b10100010,8'b10100011,8'b10100100,8'b10100101,8'b10100111,8'b10101000,8'b10101001,8'b10101010,8'b10101011,8'b10101100,8'b10101101,8'b10101111,8'b10110000,8'b10110001,8'b10110010,8'b10110011,8'b10110100,8'b10110101,8'b10110111,8'b10111000,8'b10111001,8'b10111010,8'b10111011,8'b10111100,8'b10111101,8'b10111111 : begin
        // ADD A,r
        // ADC A,r
        // SUB A,r
        // SBC A,r
        // AND A,r
        // OR A,r
        // XOR A,r
        // CP A,r
        Set_BusB_To[2:0] = SSS;
        Set_BusA_To[2:0] = 3'b111;
        Read_To_Reg = 1'b1;
        Save_ALU = 1'b1;
      end
      8'b10000110,8'b10001110,8'b10010110,8'b10011110,8'b10100110,8'b10101110,8'b10110110,8'b10111110 : begin
        // ADD A,(HL)
        // ADC A,(HL)
        // SUB A,(HL)
        // SBC A,(HL)
        // AND A,(HL)
        // OR A,(HL)
        // XOR A,(HL)
        // CP A,(HL)
        MCycles = 3'b010;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aXY;
        end
        3'b010 : begin
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          Set_BusB_To[2:0] = SSS;
          Set_BusA_To[2:0] = 3'b111;
        end
        default : begin
        end
        endcase
      end
      8'b11000110,8'b11001110,8'b11010110,8'b11011110,8'b11100110,8'b11101110,8'b11110110,8'b11111110 : begin
        // ADD A,n
        // ADC A,n
        // SUB A,n
        // SBC A,n
        // AND A,n
        // OR A,n
        // XOR A,n
        // CP A,n
        MCycles = 3'b010;
        if(MCycle == 3'b010) begin
          Inc_PC = 1'b1;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          Set_BusB_To[2:0] = SSS;
          Set_BusA_To[2:0] = 3'b111;
        end
      end
      8'b00000100,8'b00001100,8'b00010100,8'b00011100,8'b00100100,8'b00101100,8'b00111100 : begin
        // INC r
        Set_BusB_To = 4'b1010;
        Set_BusA_To[2:0] = DDD;
        Read_To_Reg = 1'b1;
        Save_ALU = 1'b1;
        PreserveC = 1'b1;
        ALU_Op = 4'b0000;
      end
      8'b00110100 : begin
        // INC (HL)
        MCycles = 3'b011;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aXY;
        end
        3'b010 : begin
          TStates = 3'b100;
          Set_Addr_To = aXY;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          PreserveC = 1'b1;
          ALU_Op = 4'b0000;
          Set_BusB_To = 4'b1010;
          Set_BusA_To[2:0] = DDD;
        end
        3'b011 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00000101,8'b00001101,8'b00010101,8'b00011101,8'b00100101,8'b00101101,8'b00111101 : begin
        // DEC r
        Set_BusB_To = 4'b1010;
        Set_BusA_To[2:0] = DDD;
        Read_To_Reg = 1'b1;
        Save_ALU = 1'b1;
        PreserveC = 1'b1;
        ALU_Op = 4'b0010;
      end
      8'b00110101 : begin
        // DEC (HL)
        MCycles = 3'b011;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aXY;
        end
        3'b010 : begin
          TStates = 3'b100;
          Set_Addr_To = aXY;
          ALU_Op = 4'b0010;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          PreserveC = 1'b1;
          Set_BusB_To = 4'b1010;
          Set_BusA_To[2:0] = DDD;
        end
        3'b011 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
        // GENERAL PURPOSE ARITHMETIC AND CPU CONTROL GROUPS
      end
      8'b00100111 : begin
        // DAA
        Set_BusA_To[2:0] = 3'b111;
        Read_To_Reg = 1'b1;
        ALU_Op = 4'b1100;
        Save_ALU = 1'b1;
      end
      8'b00101111 : begin
        // CPL
        I_CPL = 1'b1;
      end
      8'b00111111 : begin
        // CCF
        I_CCF = 1'b1;
      end
      8'b00110111 : begin
        // SCF
        I_SCF = 1'b1;
      end
      8'b00000000 : begin
        if(NMICycle == 1'b1) begin
          // NMI
          MCycles = 3'b011;
          case(MCycle)
          3'b001 : begin
            TStates = 3'b101;
            IncDec_16 = 4'b1111;
            Set_Addr_To = aSP;
            Set_BusB_To = 4'b1101;
          end
          3'b010 : begin
            Write = 1'b1;
            IncDec_16 = 4'b1111;
            Set_Addr_To = aSP;
            Set_BusB_To = 4'b1100;
          end
          3'b011 : begin
            Write = 1'b1;
          end
          default : begin
          end
          endcase
        end
        else if(IntCycle == 1'b1) begin
          // INT (IM 2)
          MCycles = 3'b101;
          case(MCycle)
          3'b001 : begin
            TStates = 3'b101;
            IncDec_16 = 4'b1111;
            Set_Addr_To = aSP;
            Set_BusB_To = 4'b1101;
          end
          3'b010 : begin
            //TStates = "100";
            Write = 1'b1;
            IncDec_16 = 4'b1111;
            Set_Addr_To = aSP;
            Set_BusB_To = 4'b1100;
          end
          3'b011 : begin
            //TStates = "100";
            Write = 1'b1;
          end
          3'b100 : begin
            Inc_PC = 1'b1;
            LDZ = 1'b1;
          end
          3'b101 : begin
            Jump = 1'b1;
          end
          default : begin
          end
          endcase
        end
        else begin
          // NOP
        end
      end
      8'b01110110 : begin
        // HALT
        Halt = 1'b1;
      end
      8'b11110011 : begin
        // DI
        SetDI = 1'b1;
      end
      8'b11111011 : begin
        // EI
        SetEI = 1'b1;
        // 16 BIT ARITHMETIC GROUP
      end
      8'b00001001,8'b00011001,8'b00101001,8'b00111001 : begin
        // ADD HL,ss
        MCycles = 3'b011;
        case(MCycle)
        3'b001 : begin
          No_PC = 1'b1;
        end
        3'b010 : begin
          NoRead = 1'b1;
          ALU_Op = 4'b0000;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          Set_BusA_To[2:0] = 3'b101;
          case(IR[5:4])
          2'b00,2'b01,2'b10 : begin
            Set_BusB_To[2:1] = IR[5:4];
            Set_BusB_To[0] = 1'b1;
          end
          default : begin
            Set_BusB_To = 4'b1000;
          end
          endcase
          TStates = 3'b100;
          Arith16 = 1'b1;
          SetWZ = 2'b11;
          No_PC = 1'b1;
        end
        3'b011 : begin
          NoRead = 1'b1;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          ALU_Op = 4'b0001;
          Set_BusA_To[2:0] = 3'b100;
          case(IR[5:4])
          2'b00,2'b01,2'b10 : begin
            Set_BusB_To[2:1] = IR[5:4];
          end
          default : begin
            Set_BusB_To = 4'b1001;
          end
          endcase
          Arith16 = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b00000011,8'b00010011,8'b00100011,8'b00110011 : begin
        // INC ss
        TStates = 3'b110;
        IncDec_16[3:2] = 2'b01;
        IncDec_16[1:0] = DPair;
      end
      8'b00001011,8'b00011011,8'b00101011,8'b00111011 : begin
        // DEC ss
        TStates = 3'b110;
        IncDec_16[3:2] = 2'b11;
        IncDec_16[1:0] = DPair;
        // ROTATE AND SHIFT GROUP
        // RLCA|RLA|RRCA|RRA
      end
      8'b00000111,8'b00010111,8'b00001111,8'b00011111 : begin
        Set_BusA_To[2:0] = 3'b111;
        ALU_Op = 4'b1000;
        Read_To_Reg = 1'b1;
        Save_ALU = 1'b1;
        // JUMP GROUP
      end
      8'b11000011 : begin
        // JP nn
        MCycles = 3'b011;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          LDZ = 1'b1;
        end
        3'b011 : begin
          Inc_PC = 1'b1;
          Jump = 1'b1;
          LDW = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b11000010,8'b11001010,8'b11010010,8'b11011010,8'b11100010,8'b11101010,8'b11110010,8'b11111010 : begin
        // JP cc,nn
        MCycles = 3'b011;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          LDZ = 1'b1;
        end
        3'b011 : begin
          LDW = 1'b1;
          Inc_PC = 1'b1;
          if(cc_is_true == 1'b1) begin
            Jump = 1'b1;
          end
        end
        default : begin
        end
        endcase
      end
      8'b00011000 : begin
        // JR e
        MCycles = 3'b011;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          No_PC = 1'b1;
        end
        3'b011 : begin
          NoRead = 1'b1;
          JumpE = 1'b1;
          TStates = 3'b101;
        end
        default : begin
        end
        endcase
      end
      8'b00111000 : begin
        // JR C,e
        MCycles = 3'b011;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          if(F[Flag_C] == 1'b0) begin
            MCycles = 3'b010;
          end
          else begin
            No_PC = 1'b1;
          end
        end
        3'b011 : begin
          NoRead = 1'b1;
          JumpE = 1'b1;
          TStates = 3'b101;
        end
        default : begin
        end
        endcase
      end
      8'b00110000 : begin
        // JR NC,e
        MCycles = 3'b011;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          if(F[Flag_C] == 1'b1) begin
            MCycles = 3'b010;
          end
          else begin
            No_PC = 1'b1;
          end
        end
        3'b011 : begin
          NoRead = 1'b1;
          JumpE = 1'b1;
          TStates = 3'b101;
        end
        default : begin
        end
        endcase
      end
      8'b00101000 : begin
        // JR Z,e
        MCycles = 3'b011;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          if(F[Flag_Z] == 1'b0) begin
            MCycles = 3'b010;
          end
          else begin
            No_PC = 1'b1;
          end
        end
        3'b011 : begin
          NoRead = 1'b1;
          JumpE = 1'b1;
          TStates = 3'b101;
        end
        default : begin
        end
        endcase
      end
      8'b00100000 : begin
        // JR NZ,e
        MCycles = 3'b011;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          if(F[Flag_Z] == 1'b1) begin
            MCycles = 3'b010;
          end
          else begin
            No_PC = 1'b1;
          end
        end
        3'b011 : begin
          NoRead = 1'b1;
          JumpE = 1'b1;
          TStates = 3'b101;
        end
        default : begin
        end
        endcase
      end
      8'b11101001 : begin
        // JP (HL)
        JumpXY = 1'b1;
      end
      8'b00010000 : begin
        // DJNZ,e
        MCycles = 3'b011;
        case(MCycle)
        3'b001 : begin
          TStates = 3'b101;
          I_DJNZ = 1'b1;
          Set_BusB_To = 4'b1010;
          Set_BusA_To[2:0] = 3'b000;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          ALU_Op = 4'b0010;
        end
        3'b010 : begin
          I_DJNZ = 1'b1;
          Inc_PC = 1'b1;
          No_PC = 1'b1;
        end
        3'b011 : begin
          NoRead = 1'b1;
          JumpE = 1'b1;
          TStates = 3'b101;
        end
        default : begin
        end
        endcase
        // CALL AND RETURN GROUP
      end
      8'b11001101 : begin
        // CALL nn
        MCycles = 3'b101;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          LDZ = 1'b1;
        end
        3'b011 : begin
          IncDec_16 = 4'b1111;
          Inc_PC = 1'b1;
          TStates = 3'b100;
          Set_Addr_To = aSP;
          LDW = 1'b1;
          Set_BusB_To = 4'b1101;
        end
        3'b100 : begin
          Write = 1'b1;
          IncDec_16 = 4'b1111;
          Set_Addr_To = aSP;
          Set_BusB_To = 4'b1100;
        end
        3'b101 : begin
          Write = 1'b1;
          Call = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b11000100,8'b11001100,8'b11010100,8'b11011100,8'b11100100,8'b11101100,8'b11110100,8'b11111100 : begin
        // CALL cc,nn
        MCycles = 3'b101;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          LDZ = 1'b1;
        end
        3'b011 : begin
          Inc_PC = 1'b1;
          LDW = 1'b1;
          if(cc_is_true == 1'b1) begin
            IncDec_16 = 4'b1111;
            Set_Addr_To = aSP;
            TStates = 3'b100;
            Set_BusB_To = 4'b1101;
          end
          else begin
            MCycles = 3'b011;
          end
        end
        3'b100 : begin
          Write = 1'b1;
          IncDec_16 = 4'b1111;
          Set_Addr_To = aSP;
          Set_BusB_To = 4'b1100;
        end
        3'b101 : begin
          Write = 1'b1;
          Call = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b11001001 : begin
        // RET
        MCycles = 3'b011;
        case(MCycle)
        3'b001 : begin
          //TStates = "101";
          Set_Addr_To = aSP;
        end
        3'b010 : begin
          IncDec_16 = 4'b0111;
          Set_Addr_To = aSP;
          LDZ = 1'b1;
        end
        3'b011 : begin
          Jump = 1'b1;
          IncDec_16 = 4'b0111;
        end
        default : begin
        end
        endcase
      end
      8'b11000000,8'b11001000,8'b11010000,8'b11011000,8'b11100000,8'b11101000,8'b11110000,8'b11111000 : begin
        // RET cc
        MCycles = 3'b011;
        case(MCycle)
        3'b001 : begin
          if(cc_is_true == 1'b1) begin
            Set_Addr_To = aSP;
          end
          else begin
            MCycles = 3'b001;
          end
          TStates = 3'b101;
        end
        3'b010 : begin
          IncDec_16 = 4'b0111;
          Set_Addr_To = aSP;
          LDZ = 1'b1;
        end
        3'b011 : begin
          Jump = 1'b1;
          IncDec_16 = 4'b0111;
        end
        default : begin
        end
        endcase
      end
      8'b11000111,8'b11001111,8'b11010111,8'b11011111,8'b11100111,8'b11101111,8'b11110111,8'b11111111 : begin
        // RST p
        MCycles = 3'b011;
        case(MCycle)
        3'b001 : begin
          TStates = 3'b101;
          IncDec_16 = 4'b1111;
          Set_Addr_To = aSP;
          Set_BusB_To = 4'b1101;
        end
        3'b010 : begin
          Write = 1'b1;
          IncDec_16 = 4'b1111;
          Set_Addr_To = aSP;
          Set_BusB_To = 4'b1100;
        end
        3'b011 : begin
          Write = 1'b1;
          RstP = 1'b1;
        end
        default : begin
        end
        endcase
        // INPUT AND OUTPUT GROUP
      end
      8'b11011011 : begin
        // IN A,(n)
        MCycles = 3'b011;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          Set_Addr_To = aIOA;
        end
        3'b011 : begin
          Read_To_Acc = 1'b1;
          IORQ = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b11010011 : begin
        // OUT (n),A
        MCycles = 3'b011;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          Set_Addr_To = aIOA;
          Set_BusB_To = 4'b0111;
        end
        3'b011 : begin
          Write = 1'b1;
          IORQ = 1'b1;
        end
        default : begin
        end
        endcase
        //----------------------------------------------------------------------------
        //----------------------------------------------------------------------------
        // MULTIBYTE INSTRUCTIONS
        //----------------------------------------------------------------------------
        //----------------------------------------------------------------------------
      end
      8'b11001011 : begin
        Prefix = 2'b01;
      end
      8'b11101101 : begin
        Prefix = 2'b10;
      end
      8'b11011101,8'b11111101 : begin
        Prefix = 2'b11;
      end
      default : begin
      end
      endcase
    end
    2'b01 : begin
      //----------------------------------------------------------------------------
      //
      // CB prefixed instructions
      //
      //----------------------------------------------------------------------------
      Set_BusA_To[2:0] = IR[2:0];
      Set_BusB_To[2:0] = IR[2:0];
      case(IR)
      8'b00000000,8'b00000001,8'b00000010,8'b00000011,8'b00000100,8'b00000101,8'b00000111,8'b00010000,8'b00010001,8'b00010010,8'b00010011,8'b00010100,8'b00010101,8'b00010111,8'b00001000,8'b00001001,8'b00001010,8'b00001011,8'b00001100,8'b00001101,8'b00001111,8'b00011000,8'b00011001,8'b00011010,8'b00011011,8'b00011100,8'b00011101,8'b00011111,8'b00100000,8'b00100001,8'b00100010,8'b00100011,8'b00100100,8'b00100101,8'b00100111,8'b00101000,8'b00101001,8'b00101010,8'b00101011,8'b00101100,8'b00101101,8'b00101111,8'b00110000,8'b00110001,8'b00110010,8'b00110011,8'b00110100,8'b00110101,8'b00110111,8'b00111000,8'b00111001,8'b00111010,8'b00111011,8'b00111100,8'b00111101,8'b00111111 : begin
        // RLC r
        // RL r
        // RRC r
        // RR r
        // SLA r
        // SRA r
        // SRL r
        // SLL r (Undocumented) / SWAP r
        if(XY_State == 2'b00) begin
          if(MCycle == 3'b001) begin
            ALU_Op = 4'b1000;
            Read_To_Reg = 1'b1;
            Save_ALU = 1'b1;
          end
        end
        else begin
          // R/S (IX+d),Reg, undocumented
          MCycles = 3'b011;
          XYbit_undoc = 1'b1;
          case(MCycle)
          3'b001,3'b111 : begin
            Set_Addr_To = aXY;
          end
          3'b010 : begin
            ALU_Op = 4'b1000;
            Read_To_Reg = 1'b1;
            Save_ALU = 1'b1;
            Set_Addr_To = aXY;
            TStates = 3'b100;
          end
          3'b011 : begin
            Write = 1'b1;
          end
          default : begin
          end
          endcase
        end
      end
      8'b00000110,8'b00010110,8'b00001110,8'b00011110,8'b00101110,8'b00111110,8'b00100110,8'b00110110 : begin
        // RLC (HL)
        // RL (HL)
        // RRC (HL)
        // RR (HL)
        // SRA (HL)
        // SRL (HL)
        // SLA (HL)
        // SLL (HL) (Undocumented) / SWAP (HL)
        MCycles = 3'b011;
        case(MCycle)
        3'b001,3'b111 : begin
          Set_Addr_To = aXY;
        end
        3'b010 : begin
          ALU_Op = 4'b1000;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          Set_Addr_To = aXY;
          TStates = 3'b100;
        end
        3'b011 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01000000,8'b01000001,8'b01000010,8'b01000011,8'b01000100,8'b01000101,8'b01000111,8'b01001000,8'b01001001,8'b01001010,8'b01001011,8'b01001100,8'b01001101,8'b01001111,8'b01010000,8'b01010001,8'b01010010,8'b01010011,8'b01010100,8'b01010101,8'b01010111,8'b01011000,8'b01011001,8'b01011010,8'b01011011,8'b01011100,8'b01011101,8'b01011111,8'b01100000,8'b01100001,8'b01100010,8'b01100011,8'b01100100,8'b01100101,8'b01100111,8'b01101000,8'b01101001,8'b01101010,8'b01101011,8'b01101100,8'b01101101,8'b01101111,8'b01110000,8'b01110001,8'b01110010,8'b01110011,8'b01110100,8'b01110101,8'b01110111,8'b01111000,8'b01111001,8'b01111010,8'b01111011,8'b01111100,8'b01111101,8'b01111111 : begin
        // BIT b,r
        if(XY_State == 2'b00) begin
          if(MCycle == 3'b001) begin
            Set_BusB_To[2:0] = IR[2:0];
            ALU_Op = 4'b1001;
          end
        end
        else begin
          // BIT b,(IX+d), undocumented
          MCycles = 3'b010;
          XYbit_undoc = 1'b1;
          case(MCycle)
          3'b001,3'b111 : begin
            Set_Addr_To = aXY;
          end
          3'b010 : begin
            ALU_Op = 4'b1001;
            TStates = 3'b100;
          end
          default : begin
          end
          endcase
        end
      end
      8'b01000110,8'b01001110,8'b01010110,8'b01011110,8'b01100110,8'b01101110,8'b01110110,8'b01111110 : begin
        // BIT b,(HL)
        MCycles = 3'b010;
        case(MCycle)
        3'b001,3'b111 : begin
          Set_Addr_To = aXY;
        end
        3'b010 : begin
          ALU_Op = 4'b1001;
          TStates = 3'b100;
        end
        default : begin
        end
        endcase
      end
      8'b11000000,8'b11000001,8'b11000010,8'b11000011,8'b11000100,8'b11000101,8'b11000111,8'b11001000,8'b11001001,8'b11001010,8'b11001011,8'b11001100,8'b11001101,8'b11001111,8'b11010000,8'b11010001,8'b11010010,8'b11010011,8'b11010100,8'b11010101,8'b11010111,8'b11011000,8'b11011001,8'b11011010,8'b11011011,8'b11011100,8'b11011101,8'b11011111,8'b11100000,8'b11100001,8'b11100010,8'b11100011,8'b11100100,8'b11100101,8'b11100111,8'b11101000,8'b11101001,8'b11101010,8'b11101011,8'b11101100,8'b11101101,8'b11101111,8'b11110000,8'b11110001,8'b11110010,8'b11110011,8'b11110100,8'b11110101,8'b11110111,8'b11111000,8'b11111001,8'b11111010,8'b11111011,8'b11111100,8'b11111101,8'b11111111 : begin
        // SET b,r
        if(XY_State == 2'b00) begin
          if(MCycle == 3'b001) begin
            ALU_Op = 4'b1010;
            Read_To_Reg = 1'b1;
            Save_ALU = 1'b1;
          end
        end
        else begin
          // SET b,(IX+d),Reg, undocumented
          MCycles = 3'b011;
          XYbit_undoc = 1'b1;
          case(MCycle)
          3'b001,3'b111 : begin
            Set_Addr_To = aXY;
          end
          3'b010 : begin
            ALU_Op = 4'b1010;
            Read_To_Reg = 1'b1;
            Save_ALU = 1'b1;
            Set_Addr_To = aXY;
            TStates = 3'b100;
          end
          3'b011 : begin
            Write = 1'b1;
          end
          default : begin
          end
          endcase
        end
      end
      8'b11000110,8'b11001110,8'b11010110,8'b11011110,8'b11100110,8'b11101110,8'b11110110,8'b11111110 : begin
        // SET b,(HL)
        MCycles = 3'b011;
        case(MCycle)
        3'b001,3'b111 : begin
          Set_Addr_To = aXY;
        end
        3'b010 : begin
          ALU_Op = 4'b1010;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          Set_Addr_To = aXY;
          TStates = 3'b100;
        end
        3'b011 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b10000000,8'b10000001,8'b10000010,8'b10000011,8'b10000100,8'b10000101,8'b10000111,8'b10001000,8'b10001001,8'b10001010,8'b10001011,8'b10001100,8'b10001101,8'b10001111,8'b10010000,8'b10010001,8'b10010010,8'b10010011,8'b10010100,8'b10010101,8'b10010111,8'b10011000,8'b10011001,8'b10011010,8'b10011011,8'b10011100,8'b10011101,8'b10011111,8'b10100000,8'b10100001,8'b10100010,8'b10100011,8'b10100100,8'b10100101,8'b10100111,8'b10101000,8'b10101001,8'b10101010,8'b10101011,8'b10101100,8'b10101101,8'b10101111,8'b10110000,8'b10110001,8'b10110010,8'b10110011,8'b10110100,8'b10110101,8'b10110111,8'b10111000,8'b10111001,8'b10111010,8'b10111011,8'b10111100,8'b10111101,8'b10111111 : begin
        // RES b,r
        if(XY_State == 2'b00) begin
          if(MCycle == 3'b001) begin
            ALU_Op = 4'b1011;
            Read_To_Reg = 1'b1;
            Save_ALU = 1'b1;
          end
        end
        else begin
          // RES b,(IX+d),Reg, undocumented
          MCycles = 3'b011;
          XYbit_undoc = 1'b1;
          case(MCycle)
          3'b001,3'b111 : begin
            Set_Addr_To = aXY;
          end
          3'b010 : begin
            ALU_Op = 4'b1011;
            Read_To_Reg = 1'b1;
            Save_ALU = 1'b1;
            Set_Addr_To = aXY;
            TStates = 3'b100;
          end
          3'b011 : begin
            Write = 1'b1;
          end
          default : begin
          end
          endcase
        end
      end
      8'b10000110,8'b10001110,8'b10010110,8'b10011110,8'b10100110,8'b10101110,8'b10110110,8'b10111110 : begin
        // RES b,(HL)
        MCycles = 3'b011;
        case(MCycle)
        3'b001,3'b111 : begin
          Set_Addr_To = aXY;
        end
        3'b010 : begin
          ALU_Op = 4'b1011;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          Set_Addr_To = aXY;
          TStates = 3'b100;
        end
        3'b011 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
      end
      default : begin
      end
      endcase
    end
    default : begin
      //----------------------------------------------------------------------------
      //
      // ED prefixed instructions
      //
      //----------------------------------------------------------------------------
      case(IR)
      8'b00000000,8'b00000001,8'b00000010,8'b00000011,8'b00000100,8'b00000101,8'b00000110,8'b00000111,8'b00001000,8'b00001001,8'b00001010,8'b00001011,8'b00001100,8'b00001101,8'b00001110,8'b00001111,8'b00010000,8'b00010001,8'b00010010,8'b00010011,8'b00010100,8'b00010101,8'b00010110,8'b00010111,8'b00011000,8'b00011001,8'b00011010,8'b00011011,8'b00011100,8'b00011101,8'b00011110,8'b00011111,8'b00100000,8'b00100001,8'b00100010,8'b00100011,8'b00100100,8'b00100101,8'b00100110,8'b00100111,8'b00101000,8'b00101001,8'b00101010,8'b00101011,8'b00101100,8'b00101101,8'b00101110,8'b00101111,8'b00110000,8'b00110001,8'b00110010,8'b00110011,8'b00110100,8'b00110101,8'b00110110,8'b00110111,8'b00111000,8'b00111001,8'b00111010,8'b00111011,8'b00111100,8'b00111101,8'b00111110,8'b00111111,8'b10000000,8'b10000001,8'b10000010,8'b10000011,8'b10000100,8'b10000101,8'b10000110,8'b10000111,8'b10001000,8'b10001001,8'b10001010,8'b10001011,8'b10001100,8'b10001101,8'b10001110,8'b10001111,8'b10010000,8'b10010001,8'b10010010,8'b10010011,8'b10010100,8'b10010101,8'b10010110,8'b10010111,8'b10011000,8'b10011001,8'b10011010,8'b10011011,8'b10011100,8'b10011101,8'b10011110,8'b10011111,8'b10100100,8'b10100101,8'b10100110,8'b10100111,8'b10101100,8'b10101101,8'b10101110,8'b10101111,8'b10110100,8'b10110101,8'b10110110,8'b10110111,8'b10111100,8'b10111101,8'b10111110,8'b10111111,8'b11000000,8'b11000010,8'b11000100,8'b11000101,8'b11000110,8'b11000111,8'b11001000,8'b11001010,8'b11001011,8'b11001100,8'b11001101,8'b11001110,8'b11001111,8'b11010000,8'b11010010,8'b11010011,8'b11010100,8'b11010101,8'b11010110,8'b11010111,8'b11011000,8'b11011010,8'b11011011,8'b11011100,8'b11011101,8'b11011110,8'b11011111,8'b11100000,8'b11100001,8'b11100010,8'b11100011,8'b11100100,8'b11100101,8'b11100110,8'b11100111,8'b11101000,8'b11101001,8'b11101010,8'b11101011,8'b11101100,8'b11101101,8'b11101110,8'b11101111,8'b11110000,8'b11110001,8'b11110010,8'b11110100,8'b11110101,8'b11110110,8'b11110111,8'b11111000,8'b11111001,8'b11111010,8'b11111011,8'b11111100,8'b11111101,8'b11111110,8'b11111111 : begin
        // NOP, undocumented
      end
      8'b01110111,8'b01111111 : begin
        // NOP, undocumented
                // 8 BIT LOAD GROUP
      end
      8'b01010111 : begin
        // LD A,I
        Special_LD = 3'b100;
        TStates = 3'b101;
      end
      8'b01011111 : begin
        // LD A,R
        Special_LD = 3'b101;
        TStates = 3'b101;
      end
      8'b01000111 : begin
        // LD I,A
        Special_LD = 3'b110;
        TStates = 3'b101;
      end
      8'b01001111 : begin
        // LD R,A
        Special_LD = 3'b111;
        TStates = 3'b101;
        // 16 BIT LOAD GROUP
      end
      8'b01001011,8'b01011011,8'b01101011,8'b01111011 : begin
        // LD dd,(nn)
        MCycles = 3'b101;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          LDZ = 1'b1;
        end
        3'b011 : begin
          Set_Addr_To = aZI;
          Inc_PC = 1'b1;
          LDW = 1'b1;
        end
        3'b100 : begin
          Read_To_Reg = 1'b1;
          if(IR[5:4] == 2'b11) begin
            Set_BusA_To = 4'b1000;
          end
          else begin
            Set_BusA_To[2:1] = IR[5:4];
            Set_BusA_To[0] = 1'b1;
          end
          Inc_WZ = 1'b1;
          Set_Addr_To = aZI;
        end
        3'b101 : begin
          Read_To_Reg = 1'b1;
          if(IR[5:4] == 2'b11) begin
            Set_BusA_To = 4'b1001;
          end
          else begin
            Set_BusA_To[2:1] = IR[5:4];
            Set_BusA_To[0] = 1'b0;
          end
        end
        default : begin
        end
        endcase
      end
      8'b01000011,8'b01010011,8'b01100011,8'b01110011 : begin
        // LD (nn),dd
        MCycles = 3'b101;
        case(MCycle)
        3'b010 : begin
          Inc_PC = 1'b1;
          LDZ = 1'b1;
        end
        3'b011 : begin
          Set_Addr_To = aZI;
          Inc_PC = 1'b1;
          LDW = 1'b1;
          if(IR[5:4] == 2'b11) begin
            Set_BusB_To = 4'b1000;
          end
          else begin
            Set_BusB_To[2:1] = IR[5:4];
            Set_BusB_To[0] = 1'b1;
            Set_BusB_To[3] = 1'b0;
          end
        end
        3'b100 : begin
          Inc_WZ = 1'b1;
          Set_Addr_To = aZI;
          Write = 1'b1;
          if(IR[5:4] == 2'b11) begin
            Set_BusB_To = 4'b1001;
          end
          else begin
            Set_BusB_To[2:1] = IR[5:4];
            Set_BusB_To[0] = 1'b0;
            Set_BusB_To[3] = 1'b0;
          end
        end
        3'b101 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b10100000,8'b10101000,8'b10110000,8'b10111000 : begin
        // LDI, LDD, LDIR, LDDR
        MCycles = 3'b100;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aXY;
          IncDec_16 = 4'b1100;
          // BC
        end
        3'b010 : begin
          Set_BusB_To = 4'b0110;
          Set_BusA_To[2:0] = 3'b111;
          ALU_Op = 4'b0000;
          Set_Addr_To = aDE;
          if(IR[3] == 1'b0) begin
            IncDec_16 = 4'b0110;
            // IX
          end
          else begin
            IncDec_16 = 4'b1110;
          end
        end
        3'b011 : begin
          I_BT = 1'b1;
          TStates = 3'b101;
          Write = 1'b1;
          if(IR[3] == 1'b0) begin
            IncDec_16 = 4'b0101;
            // DE
          end
          else begin
            IncDec_16 = 4'b1101;
          end
          No_PC = 1'b1;
        end
        3'b100 : begin
          NoRead = 1'b1;
          TStates = 3'b101;
        end
        default : begin
        end
        endcase
      end
      8'b10100001,8'b10101001,8'b10110001,8'b10111001 : begin
        // CPI, CPD, CPIR, CPDR
        MCycles = 3'b100;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aXY;
          IncDec_16 = 4'b1100;
          // BC
        end
        3'b010 : begin
          Set_BusB_To = 4'b0110;
          Set_BusA_To[2:0] = 3'b111;
          ALU_Op = 4'b0111;
          Save_ALU = 1'b1;
          PreserveC = 1'b1;
          if(IR[3] == 1'b0) begin
            IncDec_16 = 4'b0110;
          end
          else begin
            IncDec_16 = 4'b1110;
          end
          No_PC = 1'b1;
        end
        3'b011 : begin
          NoRead = 1'b1;
          I_BC = 1'b1;
          TStates = 3'b101;
          No_PC = 1'b1;
        end
        3'b100 : begin
          NoRead = 1'b1;
          TStates = 3'b101;
        end
        default : begin
        end
        endcase
      end
      8'b01000100,8'b01001100,8'b01010100,8'b01011100,8'b01100100,8'b01101100,8'b01110100,8'b01111100 : begin
        // NEG
        ALU_Op = 4'b0010;
        Set_BusB_To = 4'b0111;
        Set_BusA_To = 4'b1010;
        Read_To_Acc = 1'b1;
        Save_ALU = 1'b1;
      end
      8'b01000110,8'b01001110,8'b01100110,8'b01101110 : begin
        // IM 0
        IMode = 2'b00;
      end
      8'b01010110,8'b01110110 : begin
        // IM 1
        IMode = 2'b01;
      end
      8'b01011110,8'b01111110 : begin
        // IM 2
        IMode = 2'b10;
        // 16 bit arithmetic
      end
      8'b01001010,8'b01011010,8'b01101010,8'b01111010 : begin
        // ADC HL,ss
        MCycles = 3'b011;
        case(MCycle)
        3'b001 : begin
          No_PC = 1'b1;
        end
        3'b010 : begin
          NoRead = 1'b1;
          ALU_Op = 4'b0001;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          Set_BusA_To[2:0] = 3'b101;
          case(IR[5:4])
          2'b00,2'b01,2'b10 : begin
            Set_BusB_To[2:1] = IR[5:4];
            Set_BusB_To[0] = 1'b1;
          end
          default : begin
            Set_BusB_To = 4'b1000;
          end
          endcase
          TStates = 3'b100;
          SetWZ = 2'b11;
          No_PC = 1'b1;
        end
        3'b011 : begin
          NoRead = 1'b1;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          ALU_Op = 4'b0001;
          Set_BusA_To[2:0] = 3'b100;
          case(IR[5:4])
          2'b00,2'b01,2'b10 : begin
            Set_BusB_To[2:1] = IR[5:4];
            Set_BusB_To[0] = 1'b0;
          end
          default : begin
            Set_BusB_To = 4'b1001;
          end
          endcase
        end
        default : begin
        end
        endcase
      end
      8'b01000010,8'b01010010,8'b01100010,8'b01110010 : begin
        // SBC HL,ss
        MCycles = 3'b011;
        case(MCycle)
        3'b001 : begin
          No_PC = 1'b1;
        end
        3'b010 : begin
          NoRead = 1'b1;
          ALU_Op = 4'b0011;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          Set_BusA_To[2:0] = 3'b101;
          case(IR[5:4])
          2'b00,2'b01,2'b10 : begin
            Set_BusB_To[2:1] = IR[5:4];
            Set_BusB_To[0] = 1'b1;
          end
          default : begin
            Set_BusB_To = 4'b1000;
          end
          endcase
          TStates = 3'b100;
          SetWZ = 2'b11;
          No_PC = 1'b1;
        end
        3'b011 : begin
          NoRead = 1'b1;
          ALU_Op = 4'b0011;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          Set_BusA_To[2:0] = 3'b100;
          case(IR[5:4])
          2'b00,2'b01,2'b10 : begin
            Set_BusB_To[2:1] = IR[5:4];
          end
          default : begin
            Set_BusB_To = 4'b1001;
          end
          endcase
        end
        default : begin
        end
        endcase
      end
      8'b01101111 : begin
        // RLD -- Read in M2, not M3! fixed by Sorgelig
        MCycles = 3'b100;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aXY;
        end
        3'b010 : begin
          Read_To_Reg = 1'b1;
          Set_BusB_To[2:0] = 3'b110;
          Set_BusA_To[2:0] = 3'b111;
          ALU_Op = 4'b1101;
          Save_ALU = 1'b1;
          No_PC = 1'b1;
        end
        3'b011 : begin
          TStates = 3'b100;
          I_RLD = 1'b1;
          NoRead = 1'b1;
          Set_Addr_To = aXY;
        end
        3'b100 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01100111 : begin
        // RRD -- Read in M2, not M3! fixed by Sorgelig
        MCycles = 3'b100;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aXY;
        end
        3'b010 : begin
          Read_To_Reg = 1'b1;
          Set_BusB_To[2:0] = 3'b110;
          Set_BusA_To[2:0] = 3'b111;
          ALU_Op = 4'b1110;
          Save_ALU = 1'b1;
          No_PC = 1'b1;
        end
        3'b011 : begin
          TStates = 3'b100;
          I_RRD = 1'b1;
          NoRead = 1'b1;
          Set_Addr_To = aXY;
        end
        3'b100 : begin
          Write = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01000101,8'b01001101,8'b01010101,8'b01011101,8'b01100101,8'b01101101,8'b01110101,8'b01111101 : begin
        // RETI/RETN
        MCycles = 3'b011;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aSP;
        end
        3'b010 : begin
          IncDec_16 = 4'b0111;
          Set_Addr_To = aSP;
          LDZ = 1'b1;
        end
        3'b011 : begin
          Jump = 1'b1;
          IncDec_16 = 4'b0111;
          LDW = 1'b1;
          I_RETN = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01000000,8'b01001000,8'b01010000,8'b01011000,8'b01100000,8'b01101000,8'b01110000,8'b01111000 : begin
        // IN r,(C)
        MCycles = 3'b010;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aBC;
          SetWZ = 2'b01;
        end
        3'b010 : begin
          IORQ = 1'b1;
          if(IR[5:3] != 3'b110) begin
            Read_To_Reg = 1'b1;
            Set_BusA_To[2:0] = IR[5:3];
          end
          I_INRC = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b01000001,8'b01001001,8'b01010001,8'b01011001,8'b01100001,8'b01101001,8'b01110001,8'b01111001 : begin
        // OUT (C),r
        // OUT (C),0
        MCycles = 3'b010;
        case(MCycle)
        3'b001 : begin
          Set_Addr_To = aBC;
          SetWZ = 2'b01;
          Set_BusB_To[2:0] = IR[5:3];
          if(IR[5:3] == 3'b110) begin
            Set_BusB_To[3] = 1'b1;
          end
        end
        3'b010 : begin
          Write = 1'b1;
          IORQ = 1'b1;
        end
        default : begin
        end
        endcase
      end
      8'b10100010,8'b10101010,8'b10110010,8'b10111010 : begin
        // INI, IND, INIR, INDR
        MCycles = 3'b100;
        case(MCycle)
        3'b001 : begin
          TStates = 3'b101;
          Set_Addr_To = aBC;
          Set_BusB_To = 4'b1010;
          Set_BusA_To = 4'b0000;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          ALU_Op = 4'b0010;
          SetWZ = 2'b11;
          IncDec_16[3] = IR[3];
        end
        3'b010 : begin
          IORQ = 1'b1;
          Set_BusB_To = 4'b0110;
          Set_Addr_To = aXY;
        end
        3'b011 : begin
          if(IR[3] == 1'b0) begin
            IncDec_16 = 4'b0110;
          end
          else begin
            IncDec_16 = 4'b1110;
          end
          Write = 1'b1;
          I_BTR = 1'b1;
        end
        3'b100 : begin
          NoRead = 1'b1;
          TStates = 3'b101;
        end
        default : begin
        end
        endcase
      end
      8'b10100011,8'b10101011,8'b10110011,8'b10111011 : begin
        // OUTI, OUTD, OTIR, OTDR
        MCycles = 3'b100;
        case(MCycle)
        3'b001 : begin
          TStates = 3'b101;
          Set_Addr_To = aXY;
          Set_BusB_To = 4'b1010;
          Set_BusA_To = 4'b0000;
          Read_To_Reg = 1'b1;
          Save_ALU = 1'b1;
          ALU_Op = 4'b0010;
        end
        3'b010 : begin
          Set_BusB_To = 4'b0110;
          Set_Addr_To = aBC;
          SetWZ = 2'b11;
          IncDec_16[3] = IR[3];
        end
        3'b011 : begin
          if(IR[3] == 1'b0) begin
            IncDec_16 = 4'b0110;
          end
          else begin
            IncDec_16 = 4'b1110;
          end
          IORQ = 1'b1;
          Write = 1'b1;
          I_BTR = 1'b1;
        end
        3'b100 : begin
          NoRead = 1'b1;
          TStates = 3'b101;
        end
        default : begin
        end
        endcase
      end
      8'b11000001,8'b11001001,8'b11010001,8'b11011001 : begin
      end
      8'b11000011,8'b11110011 : begin
      end
      default : begin
      end
      endcase
    end
    endcase
    if(Mode == 1) begin
      if(MCycle == 3'b001) begin
        //  TStates = "100";
      end
      else begin
        TStates = 3'b011;
      end
    end
    if(MCycle == 3'b110) begin
      Inc_PC = 1'b1;
      if(Mode == 1) begin
        Set_Addr_To = aXY;
        TStates = 3'b100;
        Set_BusB_To[2:0] = SSS;
        Set_BusB_To[3] = 1'b0;
      end
      if(IR == 8'b00110110 || IR == 8'b11001011) begin
        Set_Addr_To = aNone;
      end
      if(!(IR == 8'b00110110 || ISet == 2'b01)) begin
        No_PC = 1'b1;
      end
    end
    if(MCycle == 3'b111) begin
      if(Mode == 0) begin
        TStates = 3'b101;
      end
      if(ISet != 2'b01) begin
        Set_Addr_To = aXY;
      end
      Set_BusB_To[2:0] = SSS;
      Set_BusB_To[3] = 1'b0;
      if(IR == 8'b00110110 || ISet == 2'b01) begin
        // LD (HL),n
        Inc_PC = 1'b1;
      end
      else begin
        NoRead = 1'b1;
      end
    end
  end


endmodule
