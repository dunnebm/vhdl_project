library ieee;
use ieee.std_logic_1164.all;

entity LT24_touch_cs_controller is
	port (
		clock: in std_logic;
		reset: in std_logic;
		init: in std_logic;
		initialized: in std_logic;
		penirq: in std_logic;
		finished: in std_logic;
		chip_select: out std_logic
	);
end entity;

architecture behavioral of LT24_touch_cs_controller is

	type state_t is (s0, s1, s2, s3);
	signal state: state_t;

begin

	process (clock, reset)
	begin
		
		if reset = '1' then
			state <= s0;
			chip_select <= '0';
		elsif rising_edge(clock) then
		
			if state = s0 and ((init = '1' and initialized = '0') or penirq = '1') and finished = '0' then
				state <= s1;
				chip_select <= '1';
			elsif state = s1 and finished = '1' then
				state <= s2;
				chip_select <= '0';
			elsif state = s2 and finished = '0' then
				state <= s0;
				chip_select <= '0';
			end if;
		
		end if;
		
	end process;

end architecture;