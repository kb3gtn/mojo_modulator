-----------------------------------------------------------
-- cos_phase_table.vhd
--
-- Lookup 16bit value from a cos(x) table.
--
-- This version implementats the full period table.
-- a full period table works better in higher speed designs
-- because the math logic causes to much delays for the clock rates
--
--
-- y = cos(x)  -- where x is digital phase Q
--
--
-- Peter Fetterer (KB3GTN)
-----------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity cos_phase_table is
    generic (
        constant sample_depth : integer := 16;  -- number of bits in output sample (1->N)
        constant phase_depth  : integer := 12   -- number of bits for phase input value (1->N)
    );
    port (
        i_clk           : in  std_logic;  -- input DSP clock
        i_srst          : in  std_logic;  -- input sync reset to dsp clock
        ---------------------------------------------------------
        x               : in  unsigned( phase_depth-1 downto 0 ); -- digital normalized phase input (0->2*pi)
        y               : out signed( sample_depth-1 downto 0 )   -- output value signed 16b
    );
end entity cos_phase_table;

architecture system of cos_phase_table is

    ----------------------------------
    -- lookup table
    -- pre-compute at compile time..
    ----------------------------------

    constant memory_depth : integer := 2**phase_depth;  -- how many memory entries do we need.
    constant SCALE : real := real((2**(real(sample_depth)-1.0))-1.0);  -- cos is normal 1.0 we want 2^(N-1)-1 (will all be positive values)
    constant STEP  : real := MATH_2_PI/(real(2**phase_depth)); -- phase increment per table entry)
 
    -- memory table is 1/4 cos period, 1024 phase enteries of 16 bit samples
    -- taking advantage of cos symmetry for the other 3/4 of the period.
    type cos_table_mem is array ( 0 to memory_depth ) of signed( sample_depth-1 downto 0); 

    -- function to fill in cos_table_mem
    function init_lookuptable return cos_table_mem is
       variable tmp_mem : cos_table_mem;
    begin
        -- phase table is only
        for i in 0 to integer((2**real(phase_depth))) loop
            tmp_mem(i) := to_signed( integer( round( cos(real(MATH_2_PI*(real(i)*STEP)))*SCALE)), 16 );
        end loop;
        return tmp_mem;
    end;

    -- This is the lookup table, should synth into 1 blockram on Xilinx parts.
    constant cos_lookup : cos_table_mem := init_lookuptable;

begin
    
    -- lookup table
    phase_decoder : process (i_clk)
    begin
        if ( rising_edge( i_clk ) ) then
            y <= cos_lookup( to_integer( x ) );
        end if;
    end process;

end architecture system;

