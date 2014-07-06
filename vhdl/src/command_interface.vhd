-------------------------------------------------------------------------------
-- command interface 
--
-- This module encapsulates a serial to databus interface for controlling
-- the FPGA design from a computer serial port.
--
-- Blocks encapsulated here..
--
-- RS232 UART
--   handles ttl rs232 stream on io pins, output/sends bytes of data
--   Connects to the uart_db_interface block
--
-- UART_DB_INTERFACE 
--   handles serial byte stream commands into databus master commands
--   performs the state machinery to interface the uart to the databus
--   master command interface.
--
-- DATABUS_MASTER
--   this block is the master of the register memory maps system.
--   produces a 7 address bit (127 register) memory map of 8 bit registers.
--   Databus slaves with interface to the provided memory interface.
--
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity command_interface is
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
end entity command_interface;

architecture system of command_interface is

    ---------------------------------------
    -- Components
    ---------------------------------------

    -- uart to receive/transmit data to/from a ttl rs232 serial stream
    component uart is
    port (
        i_clk               : in    std_logic;  -- system clock
        i_srst              : in    std_logic;  -- synchronious reset, 1 - active
        i_baud_div          : in    std_logic_vector(15 downto 0);  -- clk divider to get to baud rate
        -- uart interface
        o_uart_tx           : out   std_logic;  -- tx bit stream
        i_uart_rx           : in    std_logic;  -- uart rx bit stream input
        -- fpga side
        i_tx_send           : in    std_logic_vector(7 downto 0); -- data byte in
        i_tx_send_we        : in    std_logic;  -- write enable
        o_tx_send_busy      : out   std_logic;  -- tx is busy, writes are ignored.
        o_rx_read           : out   std_logic_vector(7 downto 0); -- data byte out
        o_rx_read_valid     : out   std_logic;  -- read data valid this clock cycle
        i_rx_read_rd        : in    std_logic  -- read request, get next byte..
    );
    end component uart;

    -- translate serial commands into databus master commands
    component uart_db_interface is
    port (
        i_clk             : in    std_logic;     -- input system clock
        i_srst            : in    std_logic;     -- sync reset to system clock
        -- uart interface
        i_rx_data         : in    std_logic_vector( 7 downto 0);  -- data from uart
        i_rx_data_valid   : in    std_logic;     -- valid data from uart
        o_rx_read_ack     : out   std_logic;     -- tell uart we have read byte.
        o_tx_send         : out   std_logic_vector( 7 downto 0); -- tx_send data
        o_tx_send_wstrb   : out   std_logic;     -- write data strobe
        i_tx_send_busy    : in    std_logic;     -- uart is busy tx, don't write anything.. (stall)
        -- databus master interface
        o_db_cmd_wstrb    : out   std_logic;     -- write command strobe
        o_db_cmd_out      : out   std_logic_vector( 7 downto 0); -- cmd to databus master
        o_db_cmd_data_out : out   std_logic_vector( 7 downto 0); -- write data to databus master
        i_db_cmd_data_in  : in    std_logic_vector( 7 downto 0); -- read data from databus master
        i_db_cmd_rdy      : in    std_logic  -- db is ready to process a cmd / previous cmd is complete.
    );
    end component;

    -- data bus master
    component databus_master is
    generic (
        slave_latency_max   : integer := 3       -- latency from read/write strb to when the 
                                                 -- operation is complete in number of i_clk cycles.
                                                 -- 3 would give a slave 3 clock cycles to perform 
                                                 -- the needed operation.
    );
    port (
        -- clock and resets
        i_clk               : in    std_logic;                      -- input system clock
        i_srst              : in    std_logic;                      -- sync reset to system clock
        -- db master cmd interface
        i_db_cmd_in         : in    std_logic_vector( 7 downto 0);  -- input cmd byte
        i_db_cmd_wstrb      : in    std_logic;                      -- write strobe for cmd byte
        o_db_cmd_rdy        : out   std_logic;                      -- '1' rdy to process next cmd, '0' busy
        i_db_cmd_data_in    : in    std_logic_vector( 7 downto 0);  -- input byte if cmd is a write (with wstrb)
        o_db_cmd_data_out   : out   std_logic_vector( 7 downto 0);  -- output byte if cmd was a read
        -- data bus interface
        o_db_addr           : out   std_logic_vector( 6 downto 0);  -- 6 -> 0 bit address bus (7 bits)
        o_db_write_data     : out   std_logic_vector( 7 downto 0);  -- write data 
        i_db_read_data      : in    std_logic_vector( 7 downto 0);  -- read data
        o_db_read_strb      : out   std_logic;                      -- db_read_strobe
        o_db_write_strb     : out   std_logic                       -- db_write_strobe
    );
    end component;

    ---------------------------------------
    -- Signals
    ---------------------------------------
    -- uart signals
    signal baud_div          : std_logic_vector( 15 downto 0);
    signal tx_byte           : std_logic_vector( 7 downto 0);
    signal tx_byte_we        : std_logic;
    signal tx_byte_busy      : std_logic;
    signal rx_byte           : std_logic_vector( 7 downto 0);
    signal rx_byte_valid     : std_logic;
    signal rx_byte_rd        : std_logic;

    -- data bus master signals
    signal db_cmd            : std_logic_vector( 7 downto 0 );
    signal db_cmd_wstrb      : std_logic;
    signal db_cmd_rdy        : std_logic;
    signal db_cmd_wr_data    : std_logic_vector( 7 downto 0 );
    signal db_cmd_rd_data    : std_logic_vector( 7 downto 0 );

    -- data bus interface to slaves
    signal db_addr           : std_logic_vector(6 downto 0);
    signal db_wr_data        : std_logic_vector(7 downto 0);
    signal db_rd_data        : std_logic_vector(7 downto 0);
    signal db_wr_strb        : std_logic;
    signal db_rd_strb        : std_logic;

    signal serial_rx         : std_logic;
    signal serial_tx         : std_logic;

begin

    -- connect local signals to top level
    -- Serial Interface ------------------------------------------
    serial_rx <= i_rx_serial_stream;  
    o_tx_serial_stream <= serial_tx;
    -- data bus interface to slave devices -----------------------
    o_db_addr <= db_addr;           
    o_db_wdata <= db_wr_data;     
    db_rd_data <= i_db_rdata;      
    o_db_rstrb <= db_rd_strb;      
    o_db_wstrb <= db_wr_strb;   
 
    -- define baud rate 
    baud_div <= x"01B2";  -- 115200

    -- uart
    u_uart : uart 
    port map (
        i_clk                   => i_clk,
        i_srst                  => i_srst,
        i_baud_div              => baud_div,
        -- uart interface
        o_uart_tx               => serial_tx,
        i_uart_rx               => serial_rx,
        -- fpga side
        i_tx_send               => tx_byte,
        i_tx_send_we            => tx_byte_we,
        o_tx_send_busy          => tx_byte_busy,
        o_rx_read               => rx_byte,
        o_rx_read_valid         => rx_byte_valid,
        i_rx_read_rd            => rx_byte_rd
    );

    -- databus command state machine
    u_udbi : uart_db_interface
    port map (
        i_clk                   => i_clk, 
        i_srst                  => i_srst,
        -- uart interface
        i_rx_data               => rx_byte,
        i_rx_data_valid         => rx_byte_valid,
        o_rx_read_ack           => rx_byte_rd,
        o_tx_send               => tx_byte,
        o_tx_send_wstrb         => tx_byte_we,
        i_tx_send_busy          => tx_byte_busy,
        -- databus master interface
        o_db_cmd_wstrb          => db_cmd_wstrb,
        o_db_cmd_out            => db_cmd,
        o_db_cmd_data_out       => db_cmd_wr_data,
        i_db_cmd_data_in        => db_cmd_rd_data,
        i_db_cmd_rdy            => db_cmd_rdy
    );


    -- data bus bus master
    u_db_master : databus_master
    generic map (
        slave_latency_max    => 3                -- latency from read/write strb to when the 
                                                 -- operation is complete in number of i_clk cycles.
                                                 -- 3 would give a slave 3 clock cycles to perform 
                                                 -- the needed operation.
    )
    port map (
        -- clock and resets
        i_clk                 => i_clk,   
        i_srst                => i_srst,
        -- db master cmd interface
        i_db_cmd_in           => db_cmd,
        i_db_cmd_wstrb        => db_cmd_wstrb,
        o_db_cmd_rdy          => db_cmd_rdy,
        i_db_cmd_data_in      => db_cmd_wr_data,
        o_db_cmd_data_out     => db_cmd_rd_data,
        -- data bus interface
        o_db_addr             => db_addr,
        o_db_write_data       => db_wr_data,
        i_db_read_data        => db_rd_data,
        o_db_read_strb        => db_rd_strb,
        o_db_write_strb       => db_wr_strb
    );

end architecture system;
 
        

