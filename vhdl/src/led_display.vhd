-------------------------------------------------------------------------------
-- LED Display 
--
-- This module is a simple module that has 1 register
-- that defines the state of the 8 leds on the board.
--
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity led_display is
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
end entity led_display;

architecture system of led_display is

    -- signals
    signal led_reg      : std_logic_vector(7 downto 0);
    signal led_reg_addr_stl : std_logic_vector( 6 downto 0);

begin

    -- output tie to local signal register.
    o_led <= led_reg;

    led_reg_addr_stl <= std_logic_vector(to_unsigned(led_reg_addr, 7));

    -- update led_reg depending on databus activity.
    u_db_slave : process( i_clk )
    begin
        if ( rising_edge( i_clk ) ) then
            if ( i_srst = '1' ) then
                -- reset state
                led_reg <= (others=>'0');
            else
                -- write have priority over reads here..
                if ( i_db_wstrb = '1' ) then
                    if ( i_db_addr = led_reg_addr_stl ) then
                        led_reg <= i_db_wdata;
                    end if;
                else
                    if ( i_db_rstrb = '1' ) then
                        if ( i_db_addr = led_reg_addr_stl ) then
                            o_db_rdata <= led_reg;
                        else
                            o_db_rdata <= (others=>'Z'); -- we are not address, don't drive bus..
                        end if;
                    else
                        -- do not drive shared rdata line if we are not addressed to output anything
                        o_db_rdata <= (others=>'Z');
                    end if; -- end db_rstrb
                end if; -- end db_wstrb
            end if; -- end not in reset
        end if;
    end process;

end architecture; 
