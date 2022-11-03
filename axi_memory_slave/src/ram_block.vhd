library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram_block is
	generic (
		ADDR_WIDTH: natural := 8
	);
	port (
		clock: in std_logic;
		raddr: in integer range 0 to 2**ADDR_WIDTH - 1;
		waddr: in integer range 0 to 2**ADDR_WIDTH - 1;
		wdata: in std_logic_vector(31 downto 0);
		rdata: out std_logic_vector(31 downto 0);
		byte_enable: in std_logic_vector(3 downto 0);
		write: in std_logic
	);
end entity;

architecture rtl of ram_block is
	
	type word_t is array (0 to 3) of std_logic_vector(7 downto 0);
	type ram_t is array (0 to 2**ADDR_WIDTH - 1) of word_t;
	signal ram: ram_t;
	signal dword_out: word_t;

begin

	rdata <= dword_out(3) & dword_out(2) & dword_out(1) & dword_out(0);
	
	process (clock) 
	begin
		if rising_edge(clock) then
			if write = '1' then
				if byte_enable(0) = '1' then
					ram(waddr)(0) <= wdata(7 downto 0);
				end if;
				if byte_enable(1) = '1' then
					ram(waddr)(1) <= wdata(15 downto 8);
				end if;
				if byte_enable(2) = '1' then
					ram(waddr)(2) <= wdata(23 downto 16);
				end if;
				if byte_enable(3) = '1' then
					ram(waddr)(3) <= wdata(31 downto 24);
				end if;
			end if;	

			dword_out <= ram(raddr);
		end if;
	end process;
	
end architecture;