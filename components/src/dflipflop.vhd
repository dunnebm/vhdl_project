library ieee;
use ieee.std_logic_1164.all;

entity dflipflop is
	port (
		D: in std_logic;
		ld: in std_logic;
		clk: in std_logic;
		sclr: in std_logic;
		aclr: in std_logic;
		Q: out std_logic);
end entity;

architecture behavioral of dflipflop is
begin
	
	process (clk, aclr)
	begin
		if aclr = '1' then
			Q <= '0';
		elsif rising_edge(clk) then
			if sclr = '1' then
				Q <= '0';
			elsif ld = '1' then
				Q <= D;
			end if;
		end if;	
	end process;
	
end architecture;

