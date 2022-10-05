library ieee;
use ieee.std_logic_1164.all;

entity LT24_touch_init_fsm is
	port (
		clock: in std_logic;
		reset: in std_logic;
		init: in std_logic;
		finished: in std_logic;
		initializing: out std_logic;
		initialized: out std_logic	
	);
end entity;

architecture behavioral of LT24_touch_init_fsm is

	type state_t is (s0, s1, s2, s3);
	signal state: state_t;

begin

	process (clock)
	begin
		
		if rising_edge(clock) then
		
			if reset = '1' then
				state <= s0;
				initializing <= '0';
				initialized <= '0';
			elsif state = s0 and init = '1' then
				state <= s1;
				initializing <= '1';
				initialized <= '0';
			elsif state = s1 and finished = '1' then
				state <= s2;
				initializing <= '0';
				initialized <= '1';
			end if;
		
		end if;
	
	end process;

end architecture;