-- Author: Brandon Dunne
-- Date: 10/4/22

-- This entity controls the LT24 touchscreen
-- through the SPI interface and interfaces with
-- the NIOS2 processor through the Altera Avalon 
-- bus interface, and is seen by the processor as
-- a memory-mapped slave. There are three registers:
-- control-status register (address = 0),
-- xdata register (address = 1), and
-- ydata register (address = 2). The control-status 
-- register has four bits: INIT_BIT (0), PENIRQ_ENABLE_BIT (1),
-- INITIALIZED_BIT (2), and PENIRQ_EVENT_BIT (3). The INIT_BIT is
-- write only; PENIRQ_ENABLE_BIT and PENIRQ_EVENT_BIT are read/write;
-- and the INITIALIZED_BIT is read only.

-- What it means for the controller to be initialized is that the LT24's
-- penirq is enabled. The only way to do that is to send a command to it.
-- Therefore, this controller sends a hardcoded command to it when the 
-- INIT_BIT is set in the control-status register; the controller then 
-- sets the INITIALIZED_BIT when the transaction is finished. The penirq 
-- is necessary because that is what triggers the controller to send two 
-- consecutive commands in order to retreive the X and Y coordinates of 
-- the last touch, and notify the application that the X and Y registers 
-- have been updated.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LT24_touch_spi_controller is
	port (
		-- Altera Avalon memory-mapped slave ports
		address: in std_logic_vector(1 downto 0);
		clock : in std_logic;
		reset: in std_logic;
		write: in std_logic;
		read: in std_logic;
		writedata: in std_logic_vector(15 downto 0);
		readdata: out std_logic_vector(15 downto 0);
		irq: out std_logic;
		
		-- LT24 touchscreen SPI and irq ports
		adc_din: out std_logic;
		adc_penirq_n: in std_logic;
		adc_dout: in std_logic;
		adc_cs_n: out std_logic;
		adc_dclk: out std_logic
	);
end entity;

architecture structural of LT24_touch_spi_controller is

	signal dclk: std_logic;
	signal dclk_n: std_logic;
	signal reset_dclk: std_logic;
	
	constant START: std_logic := '1';
	constant INIT_COMMAND: std_logic_vector(6 downto 0) := b"0000100";
	constant GETX_COMMAND: std_logic_vector(6 downto 0) := b"0010100";
	constant GETY_COMMAND: std_logic_vector(6 downto 0) := b"1010100";

	signal cmd_select: std_logic_vector(1 downto 0);
	signal next_cmd_bit: std_logic;
	signal send_start_bit: std_logic;
	signal finished: std_logic;
	signal shift_cmd_register: std_logic;
	signal shift_data_register: std_logic;
	
	signal cmd: std_logic_vector(6 downto 0);
	signal data: std_logic_vector(11 downto 0);
	
	signal control_status_register: std_logic_vector(15 downto 0);
	signal xdata_register: std_logic_vector(15 downto 0);
	signal ydata_register: std_logic_vector(15 downto 0);
	
	signal init: std_logic;
	signal initializing: std_logic;
	signal initialized: std_logic;
	signal penirq: std_logic;
	signal penirq_enable: std_logic;
	signal penirq_event: std_logic;
	signal clear_penirq_event: std_logic;
	
	signal control_status_register_write_enable: std_logic;
	signal finished_sending_xdata: std_logic;
	signal finished_sending_ydata: std_logic;
	signal xdata_write_enable: std_logic;
	signal ydata_write_enable: std_logic;
	
	signal chip_select: std_logic;
	signal chip_select_n: std_logic;
	
	constant SCALE_100MHz_TO_2MHz: std_logic_vector(4 downto 0) := 
		std_logic_vector(to_unsigned(24, 5));
		
	constant INIT_BIT: integer := 0;
	constant PENIRQ_ENABLE_BIT: integer := 1;
	constant INITIALIZED_BIT: integer := 2;
	constant PENIRQ_EVENT_BIT: integer := 3;

begin
	control_status_register_write_enable <= not address(1) and not address(0) and write;
	
	control_status_register <= 
		(3 => penirq_event, 2 => initialized, 1 => penirq_enable, others => '0');
		
	xdata_register(15 downto 12) <= (others => '0');
	ydata_register(15 downto 12) <= (others => '0');					 
								 
	dclk_n <= not dclk;
	penirq <= not adc_penirq_n;
		
	init <= control_status_register_write_enable and writedata(INIT_BIT);
	import_init_fsm: entity work.LT24_touch_init_fsm
		port map (
			clock        => clock,
			reset        => reset,
			init         => init,
			finished     => finished,
			initializing => initializing,
			initialized  => initialized
		);
	
	chip_select_n <= not chip_select;
	import_chip_select_controller: entity work.LT24_touch_cs_controller
		port map (
			clock => clock,
			reset => reset,
			init => init,
			initialized => initialized,
			penirq => penirq,
			finished => finished,
			chip_select => chip_select
		);
		
	reset_dclk <= chip_select_n or reset;
	import_serial_clock_generator: entity work.clock_divider
		generic map (DATA_WIDTH => 5)
		port map (
			enable    => chip_select,
			reset     => reset_dclk,
			prescaler => SCALE_100MHz_TO_2MHz,
			clock_in  => clock,
			clock_out => dclk
		);
	
	import_cmd_and_data_controller: entity work.LT24_touch_cmd_and_data_controller
		port map (
			enable                  => chip_select,
			dclk                    => dclk_n,
			init_seq                => initializing,
			finished                => finished,
			send_start_bit          => send_start_bit,
			shift_cmd_register      => shift_cmd_register,
			shift_data_register     => shift_data_register,
			cmd_select              => cmd_select,
			finished_sending_xdata  => finished_sending_xdata,
			finished_sending_ydata  => finished_sending_ydata
		);
		
	with send_start_bit select adc_din <=
		START        when '1',
		next_cmd_bit when others;	
		
	with cmd_select select cmd <=
		INIT_COMMAND        when b"00",
		GETX_COMMAND        when b"01",
		GETY_COMMAND       when b"10",
		(others => '0') when others;
		
	import_command_shift_register: entity work.shift_register
		generic map (DATA_WIDTH => 7)
		port map (
			D         => '0',
			data_in   => cmd,
			load_data => send_start_bit, -- load command while sending start bit
			shift     => shift_cmd_register,
			clk       => dclk_n,
			sclr      => '0',
			aclr      => reset,
			Q         => next_cmd_bit
		);
	
	import_data_shift_register: entity work.shift_register
		generic map (DATA_WIDTH => 12)
		port map (
			D         => adc_dout,
			data_in   => (others => '0'),
			load_data => '0',
			shift     => shift_data_register,
			clk       => dclk,
			sclr      => '0',
			aclr      => reset,
			data_out  => data
		);
		
	import_xdata_write_enable_fsm: entity work.LT24_touch_data_write_enable_fsm
		port map (
			clock => clock,
			dclk => dclk,
			reset => reset,
			finished_sending_data => finished_sending_xdata,
			write_enable => xdata_write_enable
		);
	
	import_xdata_register: entity work.general_sized_register
		generic map (DATA_WIDTH => 12)
		port map (
			D    => data,
			en   => xdata_write_enable,
			clk  => clock,
			sclr => reset,
			aclr => '0',
			Q    => xdata_register(11 downto 0)
		);
	
	import_ydata_write_enable_fsm: entity work.LT24_touch_data_write_enable_fsm
		port map (
			clock => clock,
			dclk => dclk,
			reset => reset,
			finished_sending_data => finished_sending_ydata,
			write_enable => ydata_write_enable
		);
		
	import_ydata_register: entity work.general_sized_register
		generic map (DATA_WIDTH => 12)
		port map (
			D    => data,
			en   => ydata_write_enable,
			clk  => clock,
			sclr => reset,
			aclr => '0',
			Q    => ydata_register(11 downto 0)
		);
		
	with read & address select readdata <=
		control_status_register when b"100",
		xdata_register          when b"101",
		ydata_register          when b"110",
		(others => '0')         when others;
		
	import_penirq_enable_dflipflop: entity work.dflipflop
		port map (
			D => writedata(PENIRQ_ENABLE_BIT),
			ld => control_status_register_write_enable,
			clk => clock,
			sclr => reset,
			aclr => '0',
			Q => penirq_enable
		);
	
	clear_penirq_event <= (control_status_register_write_enable and writedata(PENIRQ_EVENT_BIT)) or reset;
	import_penirq_fsm: entity work.LT24_touch_penirq_fsm
		port map (
			clock => clock,
			reset => clear_penirq_event,
			finished => finished,
			initialized => initialized,
			busy => chip_select,
			penirq => penirq,
			penirq_event => penirq_event
		);
		
	
	irq <= penirq_event and penirq_enable;
	
	adc_cs_n <= chip_select_n;
	adc_dclk <= dclk;

end architecture;