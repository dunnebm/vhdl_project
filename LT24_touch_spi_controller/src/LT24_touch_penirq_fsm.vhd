library ieee;
use ieee.std_logic_1164.all;

entity LT24_touch_penirq_fsm is
	port (
		clock: in std_logic;
		reset: in std_logic;
		penirq: in std_logic;
		busy: in std_logic;
		initialized: in std_logic;
		finished: in std_logic;
		penirq_event: out std_logic
	);
end entity;

architecture behavioral of LT24_touch_penirq_fsm is

	type state_t is (s0, s1, s2);
	signal state: state_t;
	
begin

	process (clock)
	begin
	
		if rising_edge(clock) then
		
			if reset = '1' then
				state <= s0;
				penirq_event <= '0';
			elsif state = s0 and penirq = '1' and busy = '0' and initialized = '1' then
				state <= s1;
				penirq_event <= '0';
			elsif state = s1 and finished = '1' then
				state <= s2;
				penirq_event <= '1';
			end if;
		
		end if;
	
	end process;

end architecture;