-- Author: Brandon Dunne
-- Course: CE 2820 011

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.my_pkg.all;

entity timer is
	generic (DATA_WIDTH: natural := 8);
	port(
		cen, aclr, clk: in std_logic;
		
		ch1: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		
		-- output compare register
		ocr: in std_logic_vector(data_width - 1 downto 0);
		
		-- update event flag 
		uef: out std_logic;
		
		-- simulation only
		cnt: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		
		-- pulse width modulation output based on ch1
		ch1_pulse: out std_logic);
end entity;

architecture structural of timer is
	
	signal count: std_logic_vector(data_width - 1 downto 0);

begin
	
	-- counter
	map_main_counter: entity work.simple_timer 
		generic map (data_width => data_width)
		port map (
			cen => cen, aclr => aclr, clk => clk,
			ocr => ocr, cnt => count, uef => uef
		);
	
	-- ch1_pulse will go high when ch1 > count and the timer's counter is enabled
	ch1_pulse <= ((count > ch1) or (count = ch1)) and cen;
	
	cnt <= count;

end architecture;