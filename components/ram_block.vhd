library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram_block is
	generic (
		ADDRESS_WIDTH: natural := 8;
		DATA_WIDTH: natural := 8
	);
	port (
		clock: in std_logic;
		reset: in std_logic;
		address: in std_logic_vector(ADDRESS_WIDTH-1 downto 0);
		write: in std_logic;
		writedata: in std_logic_vector(DATA_WIDTH-1 downto 0);
		
		read: in std_logic;
		readdata: out std_logic_vector(DATA_WIDTH-1 downto 0)
	);
end entity;

architecture rtl of ram_block is
	
	constant RAM_DEPTH: natural := 2**ADDRESS_WIDTH;
	
	type ram_type is array (0 to RAM_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
	
	impure function ram_init return ram_type is
		variable ram: ram_type;
	begin
		for i in 0 to RAM_DEPTH - 1 loop
				ram(i) := (others => '0');
		end loop;
		
		return ram;
	end function;
	
	signal ram: ram_type := ram_init;

begin
	
	process (clock) begin
		if reset = '1' then
		
			readdata <= (others => '0');
			
		elsif rising_edge(clock) then
			
			if read = '1' then
		
				readdata <= ram(to_integer(unsigned(address)));
			
			end if;
			
			if write = '1' then
			
				ram(to_integer(unsigned(address))) <= writedata;
				
			end if;
			
		end if;
	end process;
	
end architecture;