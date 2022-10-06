-- Author: Brandon Dunne
-- Course: CE 2820 011

-- This timer counts to the value in the output-compare register,
-- then sets the update-event flag, then resets the counter and
-- update-event flag. 

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.and_reduce;

entity simple_timer is
	generic (data_width: natural := 8);
	port (
		-- count-enable, async-clear, clock
		cen, aclr, clk: in std_logic;
		
		-- Output compare register
		ocr: in std_logic_vector(data_width - 1 downto 0);
		
		-- current count register
		cnt: out std_logic_vector(data_width - 1 downto 0);
		
		-- update event flag
		uef: out std_logic);
end entity;

architecture structural of simple_timer is

	signal clr_cnt: std_logic;
	signal cnt_sig: std_logic_vector(data_width - 1 downto 0);
	signal update_event: std_logic;
	
	function is_equal(a,b: std_logic_vector) return std_logic is
	begin
		return and_reduce(a xnor b);
	end function;

begin
	
	import_counter: entity work.counter
		generic map (data_width => data_width)
		port map (cen => cen, sclr => update_event, aclr => aclr, clk => clk, count => cnt_sig);
		
	update_event <= is_equal(ocr, cnt_sig);
	
	
	uef <= update_event;
	cnt <= cnt_sig;
	
end architecture;