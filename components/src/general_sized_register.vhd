-- Author: Brandon Dunne
-- Course: CE 2820 011

library ieee;
use ieee.std_logic_1164.all;

entity general_sized_register is
	generic (data_width: natural := 8);
	port (
		D: in std_logic_vector(data_width - 1 downto 0);
		en: in std_logic;
		sclr: in std_logic;
		aclr: in std_logic;
		clk: in std_logic;
		Q: out std_logic_vector(data_width - 1 downto 0));
end entity;

architecture structural of general_sized_register is
begin

	gen: for i in 0 to data_width - 1 generate
		dff: entity work.dflipflop port map(
			D => D(i),
			ld => en,
			sclr => sclr,
			aclr => aclr,
			clk => clk,
			Q => Q(i)
		);
	end generate;

end architecture;