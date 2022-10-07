-- Author: Brandon Dunne
-- Course: CE 2820 011

-- This is the hardware component for the pan-tilt module; 
-- it consist of two servo compnents and a control register.
-- The servo components drive PWM outputs with the pulse-width controlled
-- by what is written to the the data register-- 0 reperesents -90 degrees,
-- 500 represents 0 degrees, and 1000 represents 90 degrees.

library ieee;
use ieee.std_logic_1164.all;

library component_lib;

entity pan_tilt_controller is
	port (
		address: in std_logic_vector(1 downto 0);
		rst, clk: in std_logic;
		write: in std_logic;
		writedata: in std_logic_vector(15 downto 0);
		readdata: out std_logic_vector(15 downto 0);
		pan_pulse: out std_logic;
		tilt_pulse: out std_logic);
end entity;

architecture structural of pan_tilt_controller is

	signal control_register_enable: std_logic;
	signal pan_write_enable: std_logic;
	signal tilt_write_enable: std_logic;
	
	signal control_register: std_logic_vector(readdata'range);
	signal pan_data_register: std_logic_vector(readdata'range);
	signal tilt_data_register: std_logic_vector(readdata'range);
	
	alias pan_count_enable: std_logic is control_register(0);
	alias tilt_count_enable: std_logic is control_register(1);

begin

	control_register_enable <= write and not address(1) and not address(0); -- 00
	pan_write_enable        <= write and not address(1) and     address(0); -- 01
	tilt_write_enable       <= write and     address(1) and not address(0); -- 10

	control_register0: entity component_lib.general_sized_register
		generic map (data_width => 16)
		port map (
			D => writedata,
			en => control_register_enable,
			aclr => rst,
			sclr => '0',
			clk => clk,
			Q => control_register);

	pan_servo: entity work.servo
		port map (
			cen => pan_count_enable,
			rst => rst,
			clk => clk,
			write => pan_write_enable,
			writedata => writedata,
			readdata => pan_data_register,
			servo_pulse => pan_pulse);
			
	tilt_servo: entity work.servo
		port map (
			cen => tilt_count_enable,
			rst => rst,
			clk => clk,
			write => tilt_write_enable,
			writedata => writedata,
			readdata => tilt_data_register,
			servo_pulse => tilt_pulse);
			
	with address select readdata <=
		control_register   when b"00",
		pan_data_register  when b"01",
		tilt_data_register when b"10",
		(others => '0')    when others;
	
end architecture;
		