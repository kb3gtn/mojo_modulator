--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   03:38:40 07/06/2014
-- Design Name:   
-- Module Name:   /home/kb3gtn/sandbox/mojo_modulator/vhdl/testbench/top_level_tb/mojo_top_tb.vhd
-- Project Name:  mojo_modulator
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: mojo_top
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY mojo_top_tb IS
END mojo_top_tb;
 
ARCHITECTURE behavior OF mojo_top_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
    COMPONENT mojo_top
    PORT(
         i_clk50m : IN  std_logic;
         i_rst_n : IN  std_logic;
         o_serial_tx : OUT  std_logic;
         i_serial_rx : IN  std_logic;
         o_led : OUT  std_logic_vector(7 downto 0);
         o_dac_pin_mode : OUT  std_logic;
         o_dac_sleep : OUT  std_logic;
         o_dac_mode : OUT  std_logic;
         o_dac_cmode : OUT  std_logic;
         o_dac_clk_p : OUT  std_logic;
         o_dac_clk_n : OUT  std_logic;
         o_dac_DB : OUT  signed(11 downto 0)
        );
    END COMPONENT;
    
    --Inputs
    signal i_clk50m : std_logic := '0';
    signal i_rst_n : std_logic := '0';
    signal i_serial_rx : std_logic := '0';

 	--Outputs
    signal o_serial_tx : std_logic;
    signal o_led       : std_logic_vector(7 downto 0);
    signal o_dac_pin_mode : std_logic;
    signal o_dac_sleep : std_logic;
    signal o_dac_mode  : std_logic;
    signal o_dac_cmode : std_logic;
    signal o_dac_clk_p : std_logic;
    signal o_dac_clk_n : std_logic;
    signal o_dac_DB    : signed(11 downto 0);

    constant clk50_period   : time := 10 ns;  -- 1/2 period on 50 MHz clk

    constant tx_bit_period  : time := 4.34 us; -- 1/2 period of 115200 bit period
    signal serial_ce        : std_logic;  -- clock enable for serial generation procedure
    

    -- procedure to send a byte of data as a rs232 serial stream
    procedure serial_send (
            constant input_byte          : in std_logic_vector(7 downto 0);
            signal tx_out                : out std_logic
        ) is
    begin
        tx_out <= '1'; -- idle state;
        wait until rising_edge( serial_ce );
        tx_out <= '0'; -- tx start bit.
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(0);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(1);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(2);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(3);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(4);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(5);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(6);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(7);
        wait until rising_edge( serial_ce );
        tx_out <= '0'; -- stop bit
        wait until rising_edge( serial_ce );
        tx_out <= '1'; -- back to idle
        wait until rising_edge( serial_ce );
        wait until rising_edge( serial_ce );
        wait until rising_edge( serial_ce );
        wait until rising_edge( serial_ce );
        wait until rising_edge( serial_ce );
        wait until rising_edge( serial_ce );
    end procedure;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
    uut: mojo_top PORT MAP (
          i_clk50m => i_clk50m,
          i_rst_n => i_rst_n,
          o_serial_tx => o_serial_tx,
          i_serial_rx => i_serial_rx,
          o_led => o_led,
          o_dac_pin_mode => o_dac_pin_mode,
          o_dac_sleep => o_dac_sleep,
          o_dac_mode => o_dac_mode,
          o_dac_cmode => o_dac_cmode,
          o_dac_clk_p => o_dac_clk_p,
          o_dac_clk_n => o_dac_clk_n,
          o_dac_DB => o_dac_DB
        );

    -- Clock process definitions
    clk_50_process :process
    begin
		i_clk50m <= '0';
		wait for clk50_period/2;
		i_clk50m <= '1';
		wait for clk50_period/2;
    end process;

    -- serial_ce_gen 
    serial_ce_gen : process
    begin
        serial_ce <= '0';
        wait for tx_bit_period/2;
        serial_ce <= '1';
        wait for tx_bit_period/2;
    end process;

    -- Stimulus process
    stim_proc: process
    begin
        i_serial_rx <= '1'; -- idle is high
        i_rst_n <= '0';  -- reset asserted board level
        wait for 30 ns;
        i_rst_n <= '1';  -- reset deasserted on board level 
        wait for 700 us;  -- wait for reset and DCM to lock in simulation.
 
        -- turn LEDs on ( address 0x03 )
        serial_send( x"00", i_serial_rx );
        wait for 40 us;
        serial_send( x"55", i_serial_rx );
        wait for 40 us;
        serial_send( x"00", i_serial_rx );
        wait for 40 us;
        serial_send( x"AA", i_serial_rx );
        wait for 40 us;

        -- read back value from led register
        serial_send( x"80", i_serial_rx );
		
        wait;
    end process;

END;
