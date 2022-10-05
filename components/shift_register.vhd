library ieee;
use ieee.std_logic_1164.all;

entity shift_register is
	generic (DATA_WIDTH: natural := 8);
	port (
		D: in std_logic;
		data_in: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		load_data: in std_logic;
		shift: in std_logic;
		clk: in std_logic;
		sclr: in std_logic;
		aclr: in std_logic;
		data_out: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		Q: out std_logic
	);
end entity;

architecture structural of shift_register is

	signal din: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal dout: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	signal load: std_logic;

begin
	
	load <= shift or load_data;

	gen: for i in 0 to DATA_WIDTH - 1 generate
		
		u1: if i = 0 generate
			
			with load_data select din(i) <=
				data_in(i) when '1',
				D          when others;
			
			dff0: entity work.dflipflop port map (
				D => din(i),
				ld => load,
				clk => clk,
				sclr => sclr,
				aclr => aclr,
				Q => dout(i)
			);
			
		end generate;
		
		u2: if i > 0 generate
		
			with load_data select din(i) <=
				data_in(i) when '1',
				dout(i-1)  when others;
			
			dff: entity work.dflipflop port map (
				D => din(i),
				ld => load,
				clk => clk,
				sclr => sclr,
				aclr => aclr,
				Q => dout(i)
			);
			
		end generate;
		
	end generate;
		
	Q <= dout(DATA_WIDTH - 1);
	data_out <= dout;

end architecture;