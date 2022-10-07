library ieee;
use ieee.std_logic_1164.all;

library component_lib;

entity onchip_sram is
	port (
		address: in std_logic_vector(17 downto 0);
		clock: in std_logic;
		reset: in std_logic;
		
		write: in std_logic;
		writedata: in std_logic_vector(15 downto 0);
		
		read: in std_logic;
		readdatavalid: out std_logic;
		readdata: out std_logic_vector(15 downto 0)
	);
end entity;

architecture structural of onchip_sram is

	signal block0_write_enable: std_logic;
	signal block1_write_enable: std_logic;
	signal block2_write_enable: std_logic;
	signal block3_write_enable: std_logic;
	signal block4_write_enable: std_logic;
	
	signal block0_readdata: std_logic_vector(readdata'range);
	signal block1_readdata: std_logic_vector(readdata'range);
	signal block2_readdata: std_logic_vector(readdata'range);
	signal block3_readdata: std_logic_vector(readdata'range);
	signal block4_readdata: std_logic_vector(readdata'range);
	
	alias cs: std_logic_vector(3 downto 0) is address(17 downto 14);
	
	signal read_select: std_logic_vector(3 downto 0);

begin

	block0_write_enable <= not cs(3) and not cs(2) and not cs(1) and not cs(0) and write; -- 0000
	block1_write_enable <= not cs(3) and not cs(2) and not cs(1) and     cs(0) and write; -- 0001
	block2_write_enable <= not cs(3) and not cs(2) and     cs(1) and not cs(0) and write; -- 0010
	block3_write_enable <= not cs(3) and not cs(2) and     cs(1) and     cs(0) and write; -- 0011
	block4_write_enable <= not cs(3) and     cs(2) and not cs(1) and not cs(0) and write; -- 0100
	
	-- 32 kB
	ram_block0: entity component_lib.ram_block
		generic map (
			ADDRESS_WIDTH => 14,
			DATA_WIDTH => 16
		)
		port map (
			clock => clock,
			reset => reset,
			write => block0_write_enable,
			address => address(13 downto 0),
			writedata => writedata,
			
			read => read,
			readdata => block0_readdata
		);
		
	ram_block1: entity component_lib.ram_block
		generic map (
			ADDRESS_WIDTH => 14,
			DATA_WIDTH => 16
		)
		port map (
			clock => clock,
			reset => reset,
			write => block1_write_enable,
			address => address(13 downto 0),
			writedata => writedata,
			
			read => read,
			readdata => block1_readdata
		);
			
	ram_block2: entity component_lib.ram_block
		generic map (
			ADDRESS_WIDTH => 14,
			DATA_WIDTH => 16
		)
		port map (
			clock => clock,
			reset => reset,
			write => block2_write_enable,
			address => address(13 downto 0),
			writedata => writedata,
			
			read => read,
			readdata => block2_readdata
		);
		
	ram_block3: entity component_lib.ram_block
		generic map (
			ADDRESS_WIDTH => 14,
			DATA_WIDTH => 16
		)
		port map (
			clock => clock,
			reset => reset,
			write => block3_write_enable,
			address => address(13 downto 0),
			writedata => writedata,
			
			read => read,
			readdata => block3_readdata
		);
		
	ram_block4: entity component_lib.ram_block
		generic map (
			ADDRESS_WIDTH => 14,
			DATA_WIDTH => 16
		)
		port map (
			clock => clock,
			reset => reset,
			write => block4_write_enable,
			address => address(13 downto 0),
			writedata => writedata,
			
			read => read,
			readdata => block4_readdata
		);
		
	read_transfer_controller: entity work.sram_read_transfer_controller
		port map (
			clock => clock,
			read => read,
			readdatavalid => readdatavalid
		);	
		
	sync_read_select: entity component_lib.general_sized_register
		generic map (data_width => 4)
		port map (
			D => cs,
			clk => clock,
			en => '1',
			sclr => '0',
			aclr => '0',
			Q => read_select
		);
		
	with read_select select readdata <=
		block0_readdata when b"0000",
		block1_readdata when b"0001",
		block2_readdata when b"0010",
		block3_readdata when b"0011",
		block4_readdata when b"0100",
		(others => '0') when others;		

end architecture;