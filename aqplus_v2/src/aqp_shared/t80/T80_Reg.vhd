library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity T80_Reg is
    port(
        Clk     : in  std_logic;
        CEN     : in  std_logic;
        WEH     : in  std_logic;
        WEL     : in  std_logic;
        AddrA   : in  std_logic_vector(2 downto 0);
        AddrB   : in  std_logic_vector(2 downto 0);
        AddrC   : in  std_logic_vector(2 downto 0);
        DIH     : in  std_logic_vector(7 downto 0);
        DIL     : in  std_logic_vector(7 downto 0);
        DOAH    : out std_logic_vector(7 downto 0);
        DOAL    : out std_logic_vector(7 downto 0);
        DOBH    : out std_logic_vector(7 downto 0);
        DOBL    : out std_logic_vector(7 downto 0);
        DOCH    : out std_logic_vector(7 downto 0);
        DOCL    : out std_logic_vector(7 downto 0);
        DOR     : out std_logic_vector(127 downto 0);
        DIRSet  : in  std_logic;
        DIR     : in  std_logic_vector(127 downto 0)
    );
end T80_Reg;

architecture rtl of T80_Reg is

    type Register_Image is array (natural range <>) of std_logic_vector(7 downto 0);
    signal RegsH : Register_Image(0 to 7);
    signal RegsL : Register_Image(0 to 7);

begin

    process (Clk)
    begin
        if rising_edge(Clk) then
            if DIRSet = '1' then
                RegsL(0) <= DIR(  7 downto   0);
                RegsH(0) <= DIR( 15 downto   8);

                RegsL(1) <= DIR( 23 downto  16);
                RegsH(1) <= DIR( 31 downto  24);

                RegsL(2) <= DIR( 39 downto  32);
                RegsH(2) <= DIR( 47 downto  40);

                RegsL(3) <= DIR( 55 downto  48);
                RegsH(3) <= DIR( 63 downto  56);

                RegsL(4) <= DIR( 71 downto  64);
                RegsH(4) <= DIR( 79 downto  72);

                RegsL(5) <= DIR( 87 downto  80);
                RegsH(5) <= DIR( 95 downto  88);

                RegsL(6) <= DIR(103 downto  96);
                RegsH(6) <= DIR(111 downto 104);

                RegsL(7) <= DIR(119 downto 112);
                RegsH(7) <= DIR(127 downto 120);
            elsif CEN = '1' then
                if WEH = '1' then
                    RegsH(to_integer(unsigned(AddrA))) <= DIH;
                end if;
                if WEL = '1' then
                    RegsL(to_integer(unsigned(AddrA))) <= DIL;
                end if;
            end if;
        end if;
    end process;

    DOAH <= RegsH(to_integer(unsigned(AddrA)));
    DOAL <= RegsL(to_integer(unsigned(AddrA)));
    DOBH <= RegsH(to_integer(unsigned(AddrB)));
    DOBL <= RegsL(to_integer(unsigned(AddrB)));
    DOCH <= RegsH(to_integer(unsigned(AddrC)));
    DOCL <= RegsL(to_integer(unsigned(AddrC)));
    DOR  <= RegsH(7) & RegsL(7) & RegsH(6) & RegsL(6) & RegsH(5) & RegsL(5) & RegsH(4) & RegsL(4) & RegsH(3) & RegsL(3) & RegsH(2) & RegsL(2) & RegsH(1) & RegsL(1) & RegsH(0) & RegsL(0);

end;
