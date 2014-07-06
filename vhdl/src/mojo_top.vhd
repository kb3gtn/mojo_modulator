-------------------------------------------------------------------------------
--  Mojo_Top.vhd
--
-- This file is the top level of heirarchy for the mojo_modulator design.
--
--
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;


entity mojo_top is
    port (
        i_clk50m            : in std_logic;      -- 50 MHZ XO on board
        i_rst_n             : in std_logic;      -- Reset line on board
        ---------------------------------------
        -- RS232 TTL lines comming from a USB <-> TTL SERIAL converter
        o_serial_tx           : out STD_LOGIC;  -- 3rd pin up from uC outside.
        i_serial_rx           : in  STD_LOGIC;   -- 4th pin up from uC outside.
        -- LEDS -------------------------------
        o_led                 : out STD_LOGIC_VECTOR(7 downto 0 );
        ---------------------------------------
        -- DAC Interface
        -- Dac Interface
        o_dac_pin_mode        : out STD_LOGIC;  -- select between pin mode and spi mode
        o_dac_sleep           : out STD_LOGIC;  -- places dac in to sleep when '1' 
        o_dac_mode            : out STD_LOGIC;  -- 2's comp samples or offset binary
        o_dac_cmode           : out STD_LOGIC;  -- clock mode (diff vs single ended)
        o_dac_clk_p           : out STD_LOGIC;  -- differential clock (cmos)   
        o_dac_clk_n           : out STD_LOGIC;  -- inverted version of clk_p 
        o_dac_DB              : out signed( 11 downto 0 ) -- sample data bits (12b dac)
    );
end entity mojo_top;

architecture system of mojo_top is 

    ----------------------------------
    -- Components used in this level
    ----------------------------------

    -- command interface
    component command_interface is
    port (
        i_clk               : in    std_logic;  -- databus clock
        i_srst              : in    std_logic;  -- sync reset to clock provided
        -- Serial Interface ------------------------------------------
        i_rx_serial_stream  : in    std_logic;   -- received TTL rs232 stream
        o_tx_serial_stream  : out   std_logic;   -- transmit TTL rs232 stream
        -- data bus interface to slave devices -----------------------
        o_db_addr           : out   std_logic_vector( 6 downto 0);  -- address bus (7 bits)
        o_db_wdata          : out   std_logic_vector( 7 downto 0);  -- write data 
        i_db_rdata          : in    std_logic_vector( 7 downto 0);  -- read data
        o_db_rstrb          : out   std_logic;                      -- db_read_strobe
        o_db_wstrb          : out   std_logic                       -- db_write_strobe
    );
    end component command_interface;

    -- component that allows us to set the LEDs from a the databus
    component led_display is
        generic (
            led_reg_addr    : integer := 0  -- address for the led display module to use
        );
        port (
            i_clk           : in    std_logic;
            i_srst          : in    std_logic;
            -- Databus signals ------------------
            i_db_addr       : in    std_logic_vector(6 downto 0);
            i_db_wdata      : in    std_logic_vector(7 downto 0);
            o_db_rdata      : out   std_logic_vector(7 downto 0);
            i_db_rstrb      : in    std_logic;
            i_db_wstrb      : in    std_logic;
            -- LED output -----------------------
            o_led           : out   std_logic_vector(7 downto 0)
       );
    end component; 

    -- Dynamic clock management title
    -- use to generate a 100 MHz clock from the 50 MHz XO
    -- 100 MHz clock is used for the DAC DSP.
    component dcm_core
        port (
        -- Clock in ports
        CLK_IN1           : in     std_logic;
        -- Clock out ports
        CLK_OUT1          : out    std_logic;
        -- Status and control signals
        RESET             : in     std_logic;
        LOCKED            : out    std_logic
    );
    end component;

    ----------------------------------
    -- Signal for this level
    ----------------------------------
    signal db_addr          : std_logic_vector(6 downto 0);
    signal db_wdata         : std_logic_vector(7 downto 0);
    signal db_rdata         : std_logic_vector(7 downto 0);
    signal db_rstrb         : std_logic;
    signal db_wstrb         : std_logic;

    -- reset timer
    signal reset_timer      : unsigned( 16 downto 0 );

    signal clk_50           : std_logic;  -- input 50 MHz clock after clock buffer
    signal srst_50          : std_logic;  -- 50 MHz sync reset, active high..

    -- DCM clock signals
    signal clk_100           : std_logic; --  100 MHz clock
    signal clk_100_locked    : std_logic; --  clock 100 is locked. (for srst_100) 
    signal clk_100_dcm_rst   : std_logic; --  reset for dcm
    signal srst_100          : std_logic; --  sync reset for 100 MHz clock domain (active high)
    
begin

    -- IO Interface and clocking stuff here.....

    -- IBUFG: Single-ended global clock input buffer for 50 MHz clk
    -- Spartan-6
    IBUFG_inst : IBUFG
    generic map (
        IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
        IOSTANDARD => "DEFAULT"
    )
    port map (
        O => clk_50, -- Clock buffer output
        I => i_clk50m -- Clock buffer input (connect directly to top-level port)
    );
    -- End of IBUFG_inst instantiation
    
    -- generate synchronious reset signal for
    -- synchronious blocks
    rst_sync : process( clk_50 )
    begin
        if ( rising_edge(clk_50) ) then
            if ( i_rst_n = '0' ) then
                -- reset active
                srst_50 <= '1'; -- 50 MHz clk domain in reset
                srst_100 <= '1'; -- 100 MHZ clk domain in reset
                clk_100_dcm_rst <= '1'; -- dcm in reset at startup
                -- timer to hold design in reset untill clocks are good.
                reset_timer <= (others=>'0');
            else
                -- reset timer expires
                if ( reset_timer = x"FFFF" ) then 
                    srst_50 <= '0'; -- 50 MHZ reset will now de-assert..
                    clk_100_dcm_rst <= '0'; -- start PLL, XO is stable..
                    -- wait for PLL lock before releasing 100 MHz reset.
                    if ( clk_100_locked = '1' ) then 
                        srst_100 <= '0'; -- start design up
                    end if;
                else
                    -- reset time is not expired..
                    reset_timer <= reset_timer + 1;
                end if;
            end if;
        end if;
    end process;

    -- DCM PLL for 100 MHz clock generation
    u_clk_pll : dcm_core
        port map (
            -- Clock in ports
            CLK_IN1 => clk_50,
            -- Clock out ports
            CLK_OUT1 => clk_100,
            -- Status and control signals
            RESET  => clk_100_dcm_rst,
            LOCKED => clk_100_locked
        );

    -- high level system blocks here...............

    -- command interface
    u_ci : command_interface 
    port map (
        i_clk               => clk_50,  -- clock used for uart and databus transactions 
        i_srst              => srst_50,    -- reset sync to this clock
        -- Serial Interface ------------------------------------------
        i_rx_serial_stream  => i_serial_rx,
        o_tx_serial_stream  => o_serial_tx,
        -- data bus interface to slave devices -----------------------
        o_db_addr           => db_addr,
        o_db_wdata          => db_wdata,
        i_db_rdata          => db_rdata,
        o_db_rstrb          => db_rstrb,
        o_db_wstrb          => db_wstrb
    );

    -- block that controls the LED on the board
    -- great for testing memory map control..
    u_led_display : led_display
        port map (
            i_clk           => clk_50, 
            i_srst          => srst_50,
            -- Databus signals ------------------
            i_db_addr       => db_addr,
            i_db_wdata      => db_wdata,
            o_db_rdata      => db_rdata,
            i_db_rstrb      => db_rstrb,
            i_db_wstrb      => db_wstrb,
            -- LED output -----------------------
            o_led           => o_led
       );


    -- currently not used, just tied to '0'
    o_dac_pin_mode       <= '0'; 
    o_dac_sleep          <= '0';
    o_dac_mode           <= '0';
    o_dac_cmode          <= '0';
    o_dac_clk_p          <= '0';
    o_dac_clk_n          <= '0';
    o_dac_DB             <= (others=>'0');
 

end architecture system;

        
