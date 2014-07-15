---------------------------------------------------------------------------
-- mojo_modulator.vhd
--
-- This is a simple modulator design top level component
--
-- In this case the design is just a CW generator to test out
-- the NCO design.
--
-- Peter Fetterer
---------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mojo_modulator is
    generic (
        ftw_reg0_addr   : integer := 8;  -- address in memory of this register
        ftw_reg1_addr   : integer := 9;  -- "
        ftw_reg2_addr   : integer := 10; -- "
        ftw_reg3_addr   : integer := 11 -- "
    );
    port (
        -- Databus Clock & reset ---------------------------------
        i_clk_db        : in  std_logic; -- data bus clock
        i_srst_db       : in  std_logic; -- reset for databus clk
        -- Databus signals ---------------------------------------
        i_db_addr       : in  std_logic_vector(6 downto 0);
        i_db_wdata      : in  std_logic_vector(7 downto 0);
        o_db_rdata      : out std_logic_vector(7 downto 0);
        i_db_rstrb      : in  std_logic;
        i_db_wstrb      : in  std_logic;
        -- DSP Sample Clocks & Reset ----------------------------- 
        i_clk_dsp       : in  std_logic; -- dsp sample rate clock (>= db_clk)
        i_srst_dsp      : in  std_logic; -- reset
        ---DSP Samples Out ---------------------------------------
        o_dac_samples   : out signed(15 downto 0)
    );
end entity mojo_modulator;

architecture system of mojo_modulator is

    ------------------------
    -- Components
    ------------------------
    component cos_nco is
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
    end component cos_nco;

    -------------------------
    -- Signals 
    -------------------------
    signal ftw_reg_working      : unsigned( 31 downto 0 );   -- data bus working copy
    signal ftw_reg              : unsigned( 31 downto 0 );   -- register used to drive nco
    signal ftw_reg_state        : bit_vector( 3 downto 0 );  -- track if all registers have been updated.
    signal ftw_update_ff        : std_logic;  -- flip flop to cross clock domain
    signal ftw_update_ff_set    : std_logic;  -- set by data bus (slow clock)
    signal ftw_update_ff_clr    : std_logic;  -- cleared by dsp domain

    -- register address as std_logic_vectors
    constant ftw_reg0_addr_stl  : std_logic_vector := std_logic_vector( to_unsigned(ftw_reg0_addr, 7));
    constant ftw_reg1_addr_stl  : std_logic_vector := std_logic_vector( to_unsigned(ftw_reg1_addr, 7));
    constant ftw_reg2_addr_stl  : std_logic_vector := std_logic_vector( to_unsigned(ftw_reg2_addr, 7));
    constant ftw_reg3_addr_stl  : std_logic_vector := std_logic_vector( to_unsigned(ftw_reg3_addr, 7));

    signal phase_offset         : unsigned( 11 downto 0);

begin

    -- static phase offset for NCO (not changing)
    phase_offset <= (others=>'0');

    -- ff to signal dsp clock domain that ftw_reg_working is ready to latch into ftw_reg
    u_ftw_update_ff : process( i_clk_dsp )
    begin
        if ( rising_edge( i_clk_dsp ) ) then
            if ( i_srst_dsp = '1' ) then
                ftw_update_ff <= '0';
            else
                -- clear has priority over set. (faster clock domain)
                if ( ftw_update_ff_clr = '1' ) then
                    ftw_update_ff <= '0';
                else
                    if ( ftw_update_ff_set = '1' ) then
                        ftw_update_ff <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
                    
    -- data bus slave module
    u_db_slave : process( i_clk_db )
    begin
        if ( rising_edge( i_clk_db ) ) then
            if ( i_srst_db = '1' ) then
                ftw_reg_working <= (others=>'0');
                ftw_reg_state <= "0000";
                ftw_update_ff_set <= '0';
            else
                if ( ftw_reg_state = "1111" ) then
                    ftw_update_ff_set <= '1';  -- only up for 1 clk_db cycle
                    ftw_reg_state <= "0000"; -- reset state
                else
                    ftw_update_ff_set <= '0';  -- always 0 unless signaling.
                end if;
                -- write have priority over reads
                if ( i_db_wstrb = '1' ) then
                    if ( i_db_addr = ftw_reg0_addr_stl ) then
                        ftw_reg_working(7 downto 0) <= unsigned(i_db_wdata);
                        ftw_reg_state(0) <= '1';
                    end if;
                    if ( i_db_addr = ftw_reg1_addr_stl ) then
                        ftw_reg_working(15 downto 8) <= unsigned(i_db_wdata);
                        ftw_reg_state(1) <= '1';
                    end if;
                    if ( i_db_addr = ftw_reg2_addr_stl ) then
                        ftw_reg_working(23 downto 16) <= unsigned(i_db_wdata);
                        ftw_reg_state(2) <= '1';
                    end if;
                    if ( i_db_addr = ftw_reg3_addr_stl ) then
                        ftw_reg_working(31 downto 24) <= unsigned(i_db_wdata);
                        ftw_reg_state(3) <= '1';
                    end if;
                else
                    -- data bus read..
                    if ( i_db_rstrb = '1' ) then
                        if ( i_db_addr = ftw_reg0_addr_stl ) then
                            o_db_rdata <= std_logic_vector( ftw_reg(7 downto 0));
                        end if;
                        if ( i_db_addr = ftw_reg1_addr_stl ) then
                            o_db_rdata <= std_logic_vector( ftw_reg(15 downto 8));
                        end if;
                        if ( i_db_addr = ftw_reg2_addr_stl ) then
                            o_db_rdata <= std_logic_vector( ftw_reg(23 downto 16));
                        end if;
                        if ( i_db_addr = ftw_reg3_addr_stl ) then
                            o_db_rdata <= std_logic_vector( ftw_reg(31 downto 24));
                        end if;
                        -- if none of our register are being addressed.
                        if ( i_db_addr /= ftw_reg0_addr_stl ) and 
                           ( i_db_addr /= ftw_reg1_addr_stl ) and
                           ( i_db_addr /= ftw_reg2_addr_stl ) and
                           ( i_db_addr /= ftw_reg3_addr_stl ) then
                            -- not addressing us, output 'Z' (high Z drive to shared bus)
                            o_db_rdata <= (others=>'Z');
                        end if;
                    else
                        -- not in read strobe, don't drive bus
                        o_db_rdata <= (others=>'Z');
                    end if;  
                end if;
            end if; 
        end if;
    end process;
    
    -- update ftw register into dsp clock domain.
    u_ftw_reg_update : process( i_clk_dsp )
    begin
        if (rising_edge(i_clk_dsp) ) then
            if (  i_srst_dsp = '1' ) then
                ftw_reg <= (others=>'0');
            else
                if ( ftw_update_ff = '1' ) then
                    -- latch in new ftw reg value from databus domain
                    ftw_reg <= ftw_reg_working;
                    -- signal we have handled it.
                    ftw_update_ff_clr <= '1';
                else
                    ftw_update_ff_clr <= '0';
                end if;
            end if;
        end if;
    end process;

    -- nco component
    u_cos_nco_1 : cos_nco
        generic map (
            phase_acc_size => 32, -- 32bit freq resultion
            sample_depth   => 16, -- number of bits in output samples
            phase_depth    => 12  -- resolution of the phase generation
        )
        port map (
            i_clk             => i_clk_dsp, 
            i_srst            => i_srst_dsp,
            ----------------------------------------
            i_phase_offset    => phase_offset,
            i_freq_word       => ftw_reg,
            o_sample          => o_dac_samples
        );
    

end architecture system;

