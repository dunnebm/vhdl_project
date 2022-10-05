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
	constant init_cmd: std_logic_vector(6 downto 0) := b"0000100";
	constant getx_cmd: std_logic_vector(6 downto 0) := b"0010100";
	constant gety_cmd: std_logic_vector(6 downto 0) := b"1010100";
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
	
	signal control_status_register_write_enable: std_logic;
	signal xdata_write_enable: std_logic;
	signal ydata_write_enable: std_logic;
	
	signal chip_select_input: std_logic;
	signal chip_select: std_logic;
	signal chip_select_n: std_logic;
	
	constant SCALE_100MHz_TO_2MHz: std_logic_vector(4 downto 0) := 
		std_logic_vector(to_unsigned(24, 5));

begin
	
	control_status_register_write_enable <= not address(1) and not address(0) and write;
	
	control_status_register <= 
		(3 => penirq_event, 2 => initialized, 1 => penirq_enable, others => '0');
		
	xdata_register(15 downto 12) <= (others => '0');
	ydata_register(15 downto 12) <= (others => '0');					 
								 
	dclk_n <= not dclk;
	penirq <= not adc_penirq_n;
		
	init <= control_status_register_write_enable and writedata(0);
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
			enable              => chip_select,
			dclk                => dclk_n,
			init_seq            => initializing,
			finished            => finished,
			send_start_bit      => send_start_bit,
			shift_cmd_register  => shift_cmd_register,
			shift_data_register => shift_data_register,
			cmd_select          => cmd_select,
			xdata_write_enable  => xdata_write_enable,
			ydata_write_enable  => ydata_write_enable
		);
		
	with send_start_bit select adc_din <=
		START        when '1',
		next_cmd_bit when others;	
		
	with cmd_select select cmd <=
		init_cmd        when b"00",
		getx_cmd        when b"01",
		gety_cmd        when b"10",
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
			clk       => dclk_n,
			sclr      => '0',
			aclr      => reset,
			data_out  => data
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
			D => writedata(1),
			ld => control_status_register_write_enable,
			clk => clock,
			sclr => reset,
			aclr => '0',
			Q => penirq_enable
		);
	
	import_penirq_fsm: entity work.LT24_touch_penirq_fsm
		port map (
			clock => clock,
			reset => reset,
			finished => finished,
			penirq => penirq,
			penirq_event => penirq_event
		);
		
	
	irq <= penirq_event and penirq_enable;
	
	adc_cs_n <= chip_select_n;
	adc_dclk <= dclk;

end architecture;