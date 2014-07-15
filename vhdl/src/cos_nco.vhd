----------------------------------------------------------------------------------
-- cos_nco.vhd
--
-- This block implements a cos generating Numerically Controlled Oscilator (NCO)
--
-- This block is basically a phase accumulator and a cos phase lookup table.
--
-- This block has a 3 clock delay between when a input parameter (phase offset or 
-- freq) is changed untill the output responds to it.
--
-- This delay also affects startup out of a reset.  It will take 3 clock cycles for
-- the NCO to produce the output based on the input.
--
-- NCO default output value while starting up is 0 
--
-- This block can be used to generate a sin() function as well by just adding
-- 1/4 phase depth to the phase_offset port.
--
-- Peter Fetterer (KB3GTN)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cos_nco is
    generic (
        constant phase_acc_size :   integer := 32; -- 32bit freq resultion
        constant sample_depth   :   integer := 16; -- number of bits in output samples
        constant phase_depth    :   integer := 12  -- resolution of the phase generation
    );
    port (
        i_clk               : in  std_logic;    -- sample rate clock
        i_srst              : in  std_logic;    -- sync reset to provided clock
        ----------------------------------------
        i_phase_offset      : in  unsigned( phase_depth-1 downto 0 );   -- phase shift input
        i_freq_word         : in  unsigned( phase_acc_size-1 downto 0); -- frequency input
        o_sample            : out signed( sample_depth-1 downto 0)      -- output samples, every clock
    );
end entity cos_nco;

architecture system of cos_nco is

    ----------------------
    -- components
    ----------------------
    component cos_phase_table is
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
    end component cos_phase_table;

    
    ------------------------
    -- signals
    ------------------------

    signal phase_acc        : unsigned( phase_acc_size-1 downto 0 );   -- phase accumulator
    signal gen_phase        : unsigned( phase_depth-1 downto 0 );      -- phase to lookup table

begin

    	-- Instantiate the Unit Under Test (UUT)
    u_phase_table: cos_phase_table 
    GENERIC Map (
        sample_depth => sample_depth,
        phase_depth => phase_depth
    )
    PORT MAP (
          i_clk => i_clk,
          i_srst => i_srst,
          x => gen_phase,
          y => o_sample
        );

    -- accumulate phase to generate full period of cos wave..
    phase_accumulator : process( i_clk )
    begin
        if ( rising_edge(i_clk) ) then
            if ( i_srst = '1' ) then
                phase_acc <= (others=>'0'); -- reset phase accumulator to 0 phase
            else
                -- overflows roll over..
                phase_acc <= (phase_acc + i_freq_word);  -- add phase_steps/clock period
                gen_phase <= phase_acc(phase_acc_size-1 downto (phase_acc_size-phase_depth)) + i_phase_offset;
            end if;
        end if;
    end process;

end architecture system;
   
