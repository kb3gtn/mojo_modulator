-----------------------------------------------------------
-- cos_phase_table.vhd
--
-- Lookup 16bit value from a cos(x) table.
-- Table resolution is 12 bits (4096 entries)
--
-- y = cos(x)  -- where x is digital phase Q
--
--    Q = (radian/2*pi)*((2^phase_depth))
--       or if you talk degrees
--    Q = ( degrees/360)*((2^phase_depth))
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
    constant STEP  : real := 1.0/(real(2**phase_depth)); -- phase increment per table entry (0->90 degrees)
 
    -- memory table is 1/4 cos period, 1024 phase enteries of 16 bit samples
    -- taking advantage of cos symmetry for the other 3/4 of the period.
    type cos_table_mem is array ( 0 to memory_depth ) of signed( sample_depth-1 downto 0); 

    -- function to fill in cos_table_mem
    function init_lookuptable return cos_table_mem is
       variable tmp_mem : cos_table_mem;
    begin
        -- phase table is only 0.25 + 1 sample of the total period. (0 -> 1024, 1025 entries)
        for i in 0 to integer((2**real(phase_depth))) loop
            tmp_mem(i) := to_signed( integer( round( cos(real(MATH_2_PI*(real(i)*STEP)))*SCALE)), 16 );
        end loop;
        return tmp_mem;
    end;

    -- This is the lookup table, should synth into 1 blockram on Xilinx parts.
    constant cos_lookup : cos_table_mem := init_lookuptable;

    ----------------------------
    -- Design Signals
    ----------------------------
    signal ref_phase            : unsigned(9 downto 0);  -- lower 10 bits of X
    signal base_phase           : unsigned(10 downto 0);  -- base phase 0 -> 90 degrees
    signal inv_sample_out       : std_logic;             -- output sample needs to be inverted.
    signal quadrant             : unsigned(1 downto 0);   -- phase quadrant requested
begin

    quadrant <= x(11 downto 10);  -- upper 2 bits of phase give's us quadrant
    ref_phase <= x(9 downto 0);   -- phase within quadrant

    compute_base_phase : process( i_clk )
    begin
        if ( rising_edge( i_clk ) ) then
            if ( i_srst = '1' ) then
                base_phase <= (others=>'0');
                inv_sample_out <= '0';
            else
                case quadrant is
                when "00" =>
                    -- requested direct entry in table.
                    -- 0 -> >90 degrees
                    base_phase <= ("0" & ref_phase);
                    inv_sample_out <= '0';
                when "01" =>
                    -- request second quadrante
                    -- 90 -> >180 degrees
                    -- map 2nd quad phase to 1st quad phase
                    base_phase <= "10000000000" - ("0" & ref_phase);  -- 180 degrees - ref_phase => phase in quad 1.
                    inv_sample_out <= '1';   -- invert the base_base from quad1 to get quad2's value.
                when "10" =>
                    -- request third quad
                    -- 180 -> >270
                    -- map 3rd quad phase to 1st quad phase
                    base_phase <= ("1" & ref_phase) - "10000000000";  -- just subtract 180 degrees
                    inv_sample_out <= '1';             -- invert magnatude
                when "11" =>
                    -- request forth quad
                    -- 270 -> >360  (360 is zero)
                    -- map 4th quad to 1st quad phase
                    base_phase <= "10000000000" - ( "0" & ref_phase);
                    inv_sample_out <= '0';
                when others => 
                    null;
                end case;
            end if;
        end if;
    end process;

    generate_sample : process( i_clk )
    begin
        if ( rising_edge( i_clk ) ) then
            if ( inv_sample_out = '1' ) then
                -- invert sample before outputing ( invert and add 1 )
                y <= not cos_lookup( to_integer(base_phase) ) + 1;
            else
                -- normal output
                y <= cos_lookup( to_integer(base_phase) );
            end if;
        end if;
    end process;
                
end architecture system;

