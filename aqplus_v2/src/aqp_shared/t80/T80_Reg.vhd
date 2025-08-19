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
        DOCL    : out std_logic_vector(7 downto 0)
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
            if CEN = '1' then
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

end;
