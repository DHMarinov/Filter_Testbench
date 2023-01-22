--| |-----------------------------------------------------------| |
--| |-----------------------------------------------------------| |
--| |       _______           __      __      __          __    | |
--| |     /|   __  \        /|  |   /|  |   /|  \        /  |   | |
--| |    / |  |  \  \      / |  |  / |  |  / |   \      /   |   | |
--| |   |  |  |\  \  \    |  |  | |  |  | |  |    \    /    |   | |
--| |   |  |  | \  \  \   |  |  | |  |  | |  |     \  /     |   | |
--| |   |  |  |  \  \  \  |  |  |_|__|  | |  |      \/      |   | |
--| |   |  |  |   \  \  \ |  |          | |  |  |\      /|  |   | |
--| |   |  |  |   /  /  / |  |   ____   | |  |  | \    / |  |   | |
--| |   |  |  |  /  /  /  |  |  |__/ |  | |  |  |\ \  /| |  |   | |
--| |   |  |  | /  /  /   |  |  | |  |  | |  |  | \ \//| |  |   | |
--| |   |  |  |/  /  /    |  |  | |  |  | |  |  |  \|/ | |  |   | |
--| |   |  |  |__/  /     |  |  | |  |  | |  |  |      | |  |   | |
--| |   |  |_______/      |  |__| |  |__| |  |__|      | |__|   | |
--| |   |_/_______/	      |_/__/  |_/__/  |_/__/       |_/__/   | |
--| |                                                           | |
--| |-----------------------------------------------------------| |
--| |=============-Developed by Dimitar H.Marinov-==============| |
--|_|-----------------------------------------------------------|_|

--IP: Parallel FIR Filter
--Version: V1 - Standalone 
--Fuctionality: Generic FIR filter
--IO Description
--  clk     : system clock = sampling clock
--  reset   : resets the M registes (buffers) and the P registers (delay line) of the DSP48 blocks 
--  enable  : acts as bypass switch - bypass(0), active(1) 
--  data_i  : data input (signed)
--  data_o  : data output (signed)
--
--Generics Description
--  FILTER_TAPS  : Specifies the amount of filter taps (multiplications)
--  INPUT_WIDTH  : Specifies the input width (8-25 bits)
--  COEFF_WIDTH  : Specifies the coefficient width (8-18 bits)
--  OUTPUT_WIDTH : Specifies the output width (8-43 bits)
--
--Finished on: 30.06.2019
--Notes: the DSP attribute is required to make use of the DSP slices efficiently
--------------------------------------------------------------------
--================= https://github.com/DHMarinov =================--
--------------------------------------------------------------------



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Parallel_FIR_Filter_int is
    Generic (
        FILTER_TAPS  : integer := 60;
        SATURATION   : boolean := true;
        INPUT_WIDTH  : integer range 8 to 25 := 24; 
        COEFF_WIDTH  : integer range 8 to 18 := 16;
        OUTPUT_WIDTH : integer range 8 to 43 := 24    -- This should be < (Input+Coeff width-1) 
    );
    Port ( 
           clk    : in STD_LOGIC;
           reset  : in STD_LOGIC;
           enable : in STD_LOGIC;
           data_i : in STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0);
           data_o : out STD_LOGIC_VECTOR (OUTPUT_WIDTH-1 downto 0)
           );
end Parallel_FIR_Filter_int;

architecture Behavioral of Parallel_FIR_Filter_int is

attribute use_dsp : string;
attribute use_dsp of Behavioral : architecture is "yes";

constant MAC_WIDTH : integer := COEFF_WIDTH+INPUT_WIDTH;

type input_registers is array(0 to FILTER_TAPS-1) of signed(INPUT_WIDTH-1 downto 0);
signal areg_s  : input_registers := (others=>(others=>'0'));

type coeff_registers is array(0 to FILTER_TAPS-1) of signed(COEFF_WIDTH-1 downto 0);
signal breg_s : coeff_registers := (others=>(others=>'0'));

type mult_registers is array(0 to FILTER_TAPS-1) of signed(INPUT_WIDTH+COEFF_WIDTH-1 downto 0);
signal mreg_s : mult_registers := (others=>(others=>'0'));

type dsp_registers is array(0 to FILTER_TAPS-1) of signed(MAC_WIDTH-1 downto 0);
signal preg_s : dsp_registers := (others=>(others=>'0'));

signal dout_s : std_logic_vector(MAC_WIDTH-1 downto 0);
signal sign_s : signed(MAC_WIDTH-INPUT_WIDTH-COEFF_WIDTH+1 downto 0) := (others=>'0');

type coefficients is array (0 to 59) of integer range -((2**COEFF_WIDTH)/2) to (2**COEFF_WIDTH)/2-1;
signal coeff_s: coefficients :=( 
-- Chebyshev
--0, 1, 2, 3, 6, 11, 18, 29, 43, 63, 88, 122, 163, 214, 275, 347, 428, 519, 619, 725, 837, 950, 1063, 1172, 1273, 1364, 1441, 1501, 1542, 1564, 1564, 1542, 1501, 1441, 1364, 1273, 1172, 1063, 950, 837, 725, 619, 519, 428, 347, 275, 214, 163, 122, 88, 63, 43, 29, 18, 11, 6, 3, 2, 1, 0

-- Equiripple
-26, 35, 52, -10, -73, -7, 108, 52, -133, -121, 139, 215, -110, -328, 29, 444, 121, -542, -354, 590, 685, -545, -1136, 339, 1770, 176, -2821, -1577, 5899, 13542, 13542, 5899, -1577, -2821, 176, 1770, 339, -1136, -545, 685, 590, -354, -542, 121, 444, 29, -328, -110, 215, 139, -121, -133, 52, 108, -7, -73, -10, 52, 35, -26

-- Scaled Equiripple
---13, 18, 27, -5, -37, -4, 55, 27, -68, -62, 71, 110, -56, -168, 15, 227, 62, -278, -181, 302, 351, -279, -582, 174, 907, 90, -1445, -808, 3022, 6938, 6938, 3022, -808, -1445, 90, 907, 174, -582, -279, 351, 302, -181, -278, 62, 227, 15, -168, -56, 110, 71, -62, -68, 27, 55, -4, -37, -5, 27, 18, -13

);

--type coefficients is array (0 to 119) of signed(15 downto 0); 
--signal coeff_s: coefficients :=( 
--x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", 
--x"0001", x"0001", x"0000", x"0000", x"FFFF", x"FFFF", x"FFFD", x"FFFB", 
--x"FFF8", x"FFF6", x"FFF4", x"FFF2", x"FFF2", x"FFF3", x"FFF6", x"FFFC", 
--x"0004", x"0010", x"001E", x"002D", x"003D", x"004B", x"0056", x"005C", 
--x"005A", x"004E", x"0038", x"0015", x"FFE8", x"FFB0", x"FF71", x"FF2E", 
--x"FEEE", x"FEB7", x"FE90", x"FE80", x"FE8F", x"FEC3", x"FF21", x"FFAB", 
--x"0060", x"0141", x"0246", x"0368", x"049B", x"05D4", x"0704", x"081C", 
--x"0910", x"09D3", x"0A5B", x"0AA1", x"0AA1", x"0A5B", x"09D3", x"0910", 
--x"081C", x"0704", x"05D4", x"049B", x"0368", x"0246", x"0141", x"0060", 
--x"FFAB", x"FF21", x"FEC3", x"FE8F", x"FE80", x"FE90", x"FEB7", x"FEEE", 
--x"FF2E", x"FF71", x"FFB0", x"FFE8", x"0015", x"0038", x"004E", x"005A", 
--x"005C", x"0056", x"004B", x"003D", x"002D", x"001E", x"0010", x"0004", 
--x"FFFC", x"FFF6", x"FFF3", x"FFF2", x"FFF2", x"FFF4", x"FFF6", x"FFF8", 
--x"FFFB", x"FFFD", x"FFFF", x"FFFF", x"0000", x"0000", x"0001", x"0001", 
--x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000");


signal data_os : STD_LOGIC_VECTOR (OUTPUT_WIDTH downto 0) := (others=>'0');

begin  

-- Coefficient formatting
Coeff_Array: for i in 0 to FILTER_TAPS-1 generate
    breg_s(i) <= to_signed(coeff_s(i), COEFF_WIDTH);        -- for integers
--    breg_s(i) <= signed(coeff_s(i));                        -- for hex
end generate;

data_o <= std_logic_vector(preg_s(0)(MAC_WIDTH-2 downto MAC_WIDTH-OUTPUT_WIDTH-1));         
data_os <= std_logic_vector(preg_s(0)(MAC_WIDTH-1 downto MAC_WIDTH-OUTPUT_WIDTH-1));         
      

process(clk)

variable preg_v : dsp_registers := (others=>(others=>'0'));

begin

if rising_edge(clk) then

    if (reset = '1') then
        for i in 0 to FILTER_TAPS-1 loop
            areg_s(i) <=(others=> '0');
            mreg_s(i) <=(others=> '0');
            preg_s(i) <=(others=> '0');
        end loop;

    elsif (reset = '0') then        
        for i in 0 to FILTER_TAPS-1 loop
            for n in 0 to INPUT_WIDTH-1 loop
                if n > INPUT_WIDTH-2 then
                    areg_s(i)(n) <= data_i(INPUT_WIDTH-1); 
                else
                    areg_s(i)(n) <= data_i(n);              
                end if;
            end loop;
      
            if (i < FILTER_TAPS-1) then
                mreg_s(i) <= areg_s(i)*breg_s(i);         
                    preg_s(i) <= mreg_s(i) + preg_s(i+1);
                        
            elsif (i = FILTER_TAPS-1) then
                mreg_s(i) <= areg_s(i)*breg_s(i); 
                preg_s(i)<= mreg_s(i);
            end if;
        end loop; 
    end if;
    
end if;
end process;

end Behavioral;