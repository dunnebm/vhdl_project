library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter_tb is
end entity;

architecture testbench of counter_tb is

	function predictor(en, ld, clr: std_logic; current_count, ld_data: std_logic_vector) return std_logic_vector is
		variable place_holder: integer;
		variable next_count: std_logic_vector(current_count'length - 1 downto 0);
	begin
	
		if clr = '1' then
			next_count <= x"00";
		elsif ld = '1' then
			next_count <= ld_data;
		elsif en = '0' then
			next_count <= current_count;
		else
			place_holder := to_integer(unsigned(current_count)) + 1;
			next_count <= std_logic_vector(to_unsigned(place_holder, current_count'length));
		end if;
		
		return next_count;
	end function;
	
	signal en: std_logic := '1';
	signal ld: std_logic := '0';
	signal clr: std_logic := '1';
	signal clk: std_logic := '0';
	signal count: std_logic_vector(7 downto 0);
	
begin

	DUV: entity work.counter
		generic map (data_width => 8)
		port map (en=>en, clr=>clr, clk=>clk, Q=>count);
		
	clk <= not clk after 10ns;
	clr <= '1', '0' after 20ns;
	
	run_test: process
		variable expected_count: std_logic_vector(count'length - 1 downto 0);
	begin
		expected_count := predictor(en, clr, count);
		wait for 20ns;
		
		assert count = expected_count
		report "count != expected_count"
		severity failure;
	end process;

end architecture;