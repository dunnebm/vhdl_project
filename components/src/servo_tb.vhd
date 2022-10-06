-- Author: Brandon Dunne
-- Course: CE 2820 011

-- This file is the testbench for the servo component. It
-- test the responsed of the data_register taking values 
-- from 0 to 1000, and verifies that the pulse-widths were 
-- expected.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity servo_tb is
end entity;

architecture testbench of servo_tb is

	signal cen: std_logic;
	signal clk: std_logic := '0';
	signal rst: std_logic;
	signal write: std_logic;
	signal writedata: std_logic_vector(15 downto 0);
	signal readdata: std_logic_vector(15 downto 0);
	signal servo_pulse: std_logic;
	
	constant CLOCK_PERIOD: time := 20ns;
	constant PULSE_PERIOD: time := 20ms;

begin

	DUV: entity work.servo
		port map (
			cen => cen,
			clk => clk,
			rst => rst,
			write => write,
			writedata => writedata,
			readdata => readdata,
			servo_pulse => servo_pulse
		);
	
	clk <= not clk after CLOCK_PERIOD / 2;
	rst <= '1', '0' after CLOCK_PERIOD / 2;

end architecture;