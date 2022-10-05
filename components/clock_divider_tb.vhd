library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_divider_tb is
end entity;

architecture testbench of clock_divider_tb is

	signal enable: std_logic;
	signal clock_in: std_logic := '0';
	signal reset: std_logic;
	signal clock_out: std_logic;
	signal prescaler: std_logic_vector(7 downto 0);
	
	constant CLOCK_PERIOD: time := 10ns;
	
	function calculate_prescaler(old_freq, new_freq, data_width: natural) return std_logic_vector is
		variable prescaler_int: natural := old_freq / (2*new_freq) - 1;
	begin
		return std_logic_vector(to_unsigned(prescaler_int, data_width));
	end function;

begin

	DUV: entity work.clock_divider
		generic map (DATA_WIDTH => prescaler'length)
		port map (
			enable => enable,
			reset => reset,
			clock_in => clock_in,
			clock_out => clock_out,
			prescaler => prescaler
		);
		
	clock_in <= not clock_in after CLOCK_PERIOD/2;
	reset <= '1', '0' after CLOCK_PERIOD;
	
	prescaler <= calculate_prescaler(100e6, 2e6, 8);
	enable <= '1';

end architecture;