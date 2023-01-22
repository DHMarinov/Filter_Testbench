
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use std.textio.all;
--use ieee.std_logic_textio.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Filter_Testbench is
    Generic(
        INPUT_FILE_NAME  : string := "D:\Workspaces\MATLAB\Filter_input.txt";    -- File path and name
        OUTPUT_FILE_NAME : string := "D:\Workspaces\MATLAB\Filter_output.txt";   -- File path and name
        
        FILTER_TAPS  : integer := 60;
        INPUT_WIDTH  : integer range 8 to 25 := 16; 
        COEFF_WIDTH  : integer range 8 to 18 := 16;
        OUTPUT_WIDTH : integer range 8 to 43 := 16;    -- This should be < (Input+Coeff width-1) 
        
        DATA_WIDTH       : integer := 16
--        OUTPUT_WIDTH        : integer := 16
    );
--  Port ( );
end Filter_Testbench;

architecture Behavioral of Filter_Testbench is

component Parallel_FIR_Filter_int is
    Generic (
        FILTER_TAPS  : integer := 60;
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
end component;

signal clk : std_logic := '0';
constant clock_period   : time := 10 ns;
signal loop_enable : boolean := true;

signal int_input_s : integer := 0;
signal data_in : signed(DATA_WIDTH-1 downto 0) := (others=>'0');
signal data_out : std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');

begin


Filter_inst: Parallel_FIR_Filter_int
generic map (
    FILTER_TAPS  => FILTER_TAPS  ,
    INPUT_WIDTH  => INPUT_WIDTH  ,
    COEFF_WIDTH  => COEFF_WIDTH  ,
    OUTPUT_WIDTH => OUTPUT_WIDTH 
)
port map(
    clk    => clk,
    reset  => '0',
    enable => '1',
    data_i => std_logic_vector(data_in),
    data_o => data_out 
);



--==================================================================================================
-- Test file IO
--==================================================================================================
process(clk)   

file     input_file  : text is in INPUT_FILE_NAME;
variable input_line  : line; 

file     output_file : text is out OUTPUT_FILE_NAME;         
variable output_line : line;    

variable int_input_v : integer := 0;       
variable good_v      : boolean;                

begin

if rising_edge(clk) then
    -- File operations
    if (not endfile(input_file)) then
        write(output_line, to_integer(signed(data_out)), left, 10);
        writeline(output_file, output_line);
    
        readline(input_file, input_line);
        read(input_line, int_input_v, good_v);
        int_input_s <= int_input_v;
    else
--        file_close(INPUT_FILE_NAME);
        assert (false) report "Reading operation completed!" severity failure;
    end if;
    
    data_in <= shift_right(to_signed(int_input_s, data_in'length), 0);
    
end if;

end process;


--==================================================================================================
-- Testbench clock generator
--==================================================================================================
Clock_gen: process                                
begin
    clk <= '0', '1' after clock_period/2;
    wait for clock_period; 
end process;

end Behavioral;
