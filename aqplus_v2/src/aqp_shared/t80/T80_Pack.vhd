library IEEE;
use IEEE.std_logic_1164.all;

package T80_Pack is

    constant aNone      : std_logic_vector(2 downto 0) := "111";
    constant aBC        : std_logic_vector(2 downto 0) := "000";
    constant aDE        : std_logic_vector(2 downto 0) := "001";
    constant aXY        : std_logic_vector(2 downto 0) := "010";
    constant aIOA       : std_logic_vector(2 downto 0) := "100";
    constant aSP        : std_logic_vector(2 downto 0) := "101";
    constant aZI        : std_logic_vector(2 downto 0) := "110";

    constant Flag_C : integer := 0;
    constant Flag_N : integer := 1;
    constant Flag_P : integer := 2;
    constant Flag_X : integer := 3;
    constant Flag_H : integer := 4;
    constant Flag_Y : integer := 5;
    constant Flag_Z : integer := 6;
    constant Flag_S : integer := 7;

    component T80
    generic(
        Mode : integer := 0    -- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
    );
    port(
        RESET_n         : in std_logic;
        CLK_n           : in std_logic;
        CEN             : in std_logic;
        WAIT_n          : in std_logic;
        INT_n           : in std_logic;
        NMI_n           : in std_logic;
        IORQ            : out std_logic;
        NoRead          : out std_logic;
        Write           : out std_logic;
        A               : out std_logic_vector(15 downto 0);
        DInst           : in std_logic_vector(7 downto 0);
        DI              : in std_logic_vector(7 downto 0);
        DO              : out std_logic_vector(7 downto 0);
        MC              : out std_logic_vector(2 downto 0);
        TS              : out std_logic_vector(2 downto 0);
        IntCycle        : out std_logic;
        out0            : in  std_logic := '0'  -- 0 => OUT(C),0, 1 => OUT(C),255
    );
    end component;

    component T80_Reg
    port(
        Clk             : in std_logic;
        CEN             : in std_logic;
        WEH             : in std_logic;
        WEL             : in std_logic;
        AddrA           : in std_logic_vector(2 downto 0);
        AddrB           : in std_logic_vector(2 downto 0);
        AddrC           : in std_logic_vector(2 downto 0);
        DIH             : in std_logic_vector(7 downto 0);
        DIL             : in std_logic_vector(7 downto 0);
        DOAH            : out std_logic_vector(7 downto 0);
        DOAL            : out std_logic_vector(7 downto 0);
        DOBH            : out std_logic_vector(7 downto 0);
        DOBL            : out std_logic_vector(7 downto 0);
        DOCH            : out std_logic_vector(7 downto 0);
        DOCL            : out std_logic_vector(7 downto 0)
    );
    end component;

    component T80_MCode
    generic(
        Mode   : integer := 0
    );
    port(
        IR                      : in  std_logic_vector(7 downto 0);
        ISet                    : in  std_logic_vector(1 downto 0);
        MCycle                  : in  std_logic_vector(2 downto 0);
        F                       : in  std_logic_vector(7 downto 0);
        NMICycle                : in  std_logic;
        IntCycle                : in  std_logic;
        XY_State                : in  std_logic_vector(1 downto 0);
        MCycles                 : out std_logic_vector(2 downto 0);
        TStates                 : out std_logic_vector(2 downto 0);
        Prefix                  : out std_logic_vector(1 downto 0); -- None,BC,ED,DD/FD
        Inc_PC                  : out std_logic;
        Inc_WZ                  : out std_logic;
        IncDec_16               : out std_logic_vector(3 downto 0); -- BC,DE,HL,SP   0 is inc
        Read_To_Reg             : out std_logic;
        Read_To_Acc             : out std_logic;
        Set_BusA_To             : out std_logic_vector(3 downto 0); -- B,C,D,E,H,L,DI/DB,A,SP(L),SP(M),0,F
        Set_BusB_To             : out std_logic_vector(3 downto 0); -- B,C,D,E,H,L,DI,A,SP(L),SP(M),1,F,PC(L),PC(M),0
        ALU_Op                  : out std_logic_vector(3 downto 0);
            -- ADD, ADC, SUB, SBC, AND, XOR, OR, CP, ROT, BIT, SET, RES, DAA, RLD, RRD, None
        Save_ALU                : out std_logic;
        PreserveC               : out std_logic;
        Arith16                 : out std_logic;
        Set_Addr_To             : out std_logic_vector(2 downto 0); -- aNone,aXY,aIOA,aSP,aBC,aDE,aZI
        IORQ                    : out std_logic;
        Jump                    : out std_logic;
        JumpE                   : out std_logic;
        JumpXY                  : out std_logic;
        Call                    : out std_logic;
        RstP                    : out std_logic;
        LDZ                     : out std_logic;
        LDW                     : out std_logic;
        LDSPHL                  : out std_logic;
        LDHLSP                  : out std_logic;
        ADDSPdd                 : out std_logic;
        Special_LD              : out std_logic_vector(2 downto 0); -- A,I;A,R;I,A;R,A;None
        ExchangeDH              : out std_logic;
        ExchangeRp              : out std_logic;
        ExchangeAF              : out std_logic;
        ExchangeRS              : out std_logic;
        ExchangeWH              : out std_logic;
        I_DJNZ                  : out std_logic;
        I_CPL                   : out std_logic;
        I_CCF                   : out std_logic;
        I_SCF                   : out std_logic;
        I_RETN                  : out std_logic;
        I_BT                    : out std_logic;
        I_BC                    : out std_logic;
        I_BTR                   : out std_logic;
        I_RLD                   : out std_logic;
        I_RRD                   : out std_logic;
        I_INRC                  : out std_logic;
        SetWZ                   : out std_logic_vector(1 downto 0);
        SetDI                   : out std_logic;
        SetEI                   : out std_logic;
        IMode                   : out std_logic_vector(1 downto 0);
        Halt                    : out std_logic;
        NoRead                  : out std_logic;
        Write                   : out std_logic;
        No_PC                   : out std_logic;
        XYbit_undoc             : out std_logic
    );
    end component;

    component T80_ALU
    port(
        Arith16         : in  std_logic;
        Z16             : in  std_logic;
        WZ              : in  std_logic_vector(15 downto 0);
        XY_State        : in  std_logic_vector(1 downto 0);
        ALU_Op          : in  std_logic_vector(3 downto 0);
        IR              : in  std_logic_vector(5 downto 0);
        ISet            : in  std_logic_vector(1 downto 0);
        BusA            : in  std_logic_vector(7 downto 0);
        BusB            : in  std_logic_vector(7 downto 0);
        F_In            : in  std_logic_vector(7 downto 0);
        Q               : out std_logic_vector(7 downto 0);
        F_Out           : out std_logic_vector(7 downto 0)
    );
    end component;

end;
