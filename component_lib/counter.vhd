-- Author: Brandon Dunne

-- When enabled, this counter increments every clock-cycle;
-- it has no concept of overflow.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.and_reduce;

entity counter is
	generic(DATA_WIDTH: natural := 8);
	port(
		cen: in std_logic;
		sclr: in std_logic; 
		aclr: in std_logic;
		clk: in std_logic;
		count: out std_logic_vector(DATA_WIDTH - 1 downto 0));
end entity;

architecture structural of counter is

	-- current_count: value stored in the register
	-- next_count: value that will be written to the register on the next rising clock edge
	signal current_count, next_count: std_logic_vector(data_width - 1 downto 0);
	
	-- This function builds combonational logic that results in the 
	-- register incrementing every clock cycle.
	function update_count(count: std_logic_vector) return std_logic_vector is
		variable next_count: std_logic_vector(count'length - 1 downto 0);
	begin
		next_count(0) := not count(0);
		for i in 1 to count'length - 1 loop
			next_count(i) := count(i) xor and_reduce(count(i-1 downto 0));
		end loop;
		return next_count;
	end function;
	
begin
	
	generate_register: entity work.general_sized_register
		generic map (DATA_WIDTH => DATA_WIDTH)
		port map (
			D => next_count,
			en => cen,
			sclr => sclr,
			aclr => aclr,
			clk => clk,
			Q => current_count);
	
	next_count <= update_count(current_count);
	
	count <= current_count;
			
end architecture;