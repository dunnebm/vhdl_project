-- Author: Brandon Dunne
-- Course: CE 2820 011

-- This entity is used to control a single servo.
-- I decided to be lazy and hard code the value in 
-- the timer's prescaler register. This value assumes
-- that the system clock is running at 100MHz and the prescaler
-- slows it down to 1MHz. The output-compare register (ocr) is set
-- to 19999, this value makes the counter reset every 20000
-- edges; at 19999, a flag is set, and the next edge resets the counter.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library component_lib;

entity servo is
	port(
		-- start the servo's timer
		cen: in std_logic;
		clk: in std_logic;
		
		-- asynchronous reset
		rst: in std_logic;
		write: in std_logic;
		writedata: in std_logic_vector(15 downto 0);
		readdata: out std_logic_vector(15 downto 0);
		servo_pulse: out std_logic);
end entity;

architecture structural of servo is

	signal data_register: std_logic_vector(15 downto 0);
	
	-- This value goes into the prescaler register. 
	-- psc = old-freq/(2*new-freq) - 1 = 100MHz / (2*1MHz) - 1 = 49
	constant SCALE_100MHZ_TO_1MHZ: 
		std_logic_vector(5 downto 0) := std_logic_vector(to_unsigned(49, 6));
	
	constant PULSE_WIDTH_20ms: 
		std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(19999, 16));
	
	-- Intermediate signal to only use writedata[9:0] and drvie the rest to ground.
	-- This puts a limit on how big a pulse the user can write to the data-register.
	signal data_in: std_logic_vector(15 downto 0);
	
	-- input to the data-register; this name indicates what the data is used for.
	signal ch1_data: std_logic_vector(15 downto 0);
	
	signal timer_clock: std_logic;
	
begin
	
	data_in(9 downto 0) <= writedata(9 downto 0);
	data_in(15 downto 10) <= (others => '0');
	
	-- When data_in is 0, the pulse should be 1ms, and when data_in is 1000, the
	-- pulse should be 2ms; by subtracting data_in by 19000, these conditions are met.
	ch1_data <= std_logic_vector(to_unsigned(19000, data_in'length) - unsigned(data_in));

	import_data_register: entity component_lib.general_sized_register
		generic map (data_width => 16)
		port map (
			D => ch1_data, 
			en => write, 
			aclr => rst, 
			sclr => '0', 
			clk => clk, 
			Q => data_register
		);
		
		
	import_clock_divider: entity component_lib.clock_divider
		generic map (DATA_WIDTH => 6)
		port map (
			enable => '1',
			reset => rst,
			prescaler => SCALE_100MHz_TO_1MHz,
			clock_in => clk,
			clock_out => timer_clock
		);
	
	-- This configured to generate Pulses at a 20ms period. The data register
	-- determines the duration of the pulse at the end of each
	import_timer: entity component_lib.timer
		generic map (data_width => 16)
		port map (
			cen => cen, 
			clk => timer_clock, 
			aclr => rst, 
			ocr => PULSE_WIDTH_20ms,
			ch1 => data_register,
			ch1_pulse => servo_pulse
		);
		
	readdata <= data_register;
		
end architecture;