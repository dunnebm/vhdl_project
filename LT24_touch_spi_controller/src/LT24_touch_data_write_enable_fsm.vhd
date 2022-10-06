library ieee;
use ieee.std_logic_1164.all;

entity LT24_touch_data_write_enable_fsm is
	port (
		clock: std_logic;
		reset: std_logic;
		dclk: in std_logic;
		finished_sending_data: in std_logic;
		write_enable: out std_logic
	);
end entity;

architecture fsm of LT24_touch_data_write_enable_fsm is

	type state_t is (s0, s1, s2, s3, s4);
	signal state: state_t;

begin

	process (clock)
	begin
		
		if rising_edge(clock) then
		
			if reset = '1'then
				state <= s0;
				write_enable <= '0';
			elsif state = s0 and finished_sending_data = '1' and dclk = '0' then
				state <= s1;
				write_enable <= '1';
			elsif state = s1 then
				state <= s2;
				write_enable <= '0';
			elsif state = s2 and dclk = '1' then
				state <= s3;
				write_enable <= '0';
			elsif state = s3 and dclk = '0' then
				state <= s4;
				write_enable <= '0';
			elsif state = s4 and dclk = '1' then
				state <= s0;
				write_enable <= '0';
			end if;
				
		end if;
	
	end process;

end architecture;