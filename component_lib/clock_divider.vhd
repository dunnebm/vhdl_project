library ieee;
use ieee.std_logic_1164.all;

entity clock_divider is
	generic (DATA_WIDTH: natural := 8);
	port (
		enable: in std_logic;
		reset: in std_logic;
		clock_in: in std_logic;
		prescaler: in std_logic_vector(DATA_WIDTH-1 downto 0);
		clock_out: out std_logic
	);
end entity;

architecture rtl of clock_divider is

	signal uef: std_logic;
	signal prescaler_clock: std_logic;
	signal prescaler_clock_D: std_logic;

begin

	clock_counter: entity work.simple_timer
		generic map (DATA_WIDTH => DATA_WIDTH)
		port map (
			cen => enable,
			clk => clock_in,
			aclr => reset,
			ocr => prescaler,
			uef => uef
		);
		
	prescaler_clock_D <= uef xor prescaler_clock;
	clock_generator: entity work.dflipflop
		port map (
			D => prescaler_clock_D,
			clk => clock_in,
			ld => enable,
			aclr => reset,
			sclr => '0',
			Q => prescaler_clock
		);
		
	clock_out <= prescaler_clock;

end architecture;