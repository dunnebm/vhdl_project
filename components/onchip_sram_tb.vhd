library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity onchip_sram_tb is
end entity;

architecture testbench of onchip_sram_tb is

	signal address: std_logic_vector(16 downto 0);
	signal clock: std_logic := '0';
	signal reset: std_logic;
	signal write: std_logic := '0';
	signal writedata: std_logic_vector(15 downto 0);
	
	signal read: std_logic := '0';
	signal readdatavalid: std_logic;
	signal readdata: std_logic_vector(15 downto 0);
	
	constant BLOCK1_START_ADDRESS: std_logic_vector(address'range) :=
		std_logic_vector(to_unsigned(0, address'length));
		
	constant BLOCK1_END_ADDRESS: std_logic_vector(address'range) :=
		std_logic_vector(to_unsigned(512*64 - 1, address'length));
	
	constant BLOCK2_START_ADDRESS: std_logic_vector(address'range) :=
		std_logic_vector(to_unsigned(512*64, address'length));
		
	constant BLOCK2_END_ADDRESS: std_logic_vector(address'range) := 
		std_logic_vector(to_unsigned(512*64*2 - 1, address'length));
	
	constant BLOCK3_START_ADDRESS: std_logic_vector(address'range) := 
		std_logic_vector(to_unsigned(512*64*2, address'length));
		
	constant BLOCK3_END_ADDRESS: std_logic_vector(address'range) :=
		std_logic_vector(to_unsigned(512*64*3 - 1, address'length));
		
	type test_type is record
		address: std_logic_vector(16 downto 0);
		data:    std_logic_vector(15 downto 0);
	end record;
	
	type test_type_array is array (natural range <>) of test_type;
	
	constant TEST_DATA: test_type_array := (
		(BLOCK1_START_ADDRESS, x"ABCD"), (BLOCK1_END_ADDRESS, x"1234"),
		(BLOCK2_START_ADDRESS, x"5678"), (BLOCK2_END_ADDRESS, x"9ABC"),
		(BLOCK3_START_ADDRESS, x"DEF0"), (BLOCK3_END_ADDRESS, x"BEEF"),
		
		-- Out-of-bounds addresses
		(std_logic_vector(to_unsigned(512*64*3,   address'length)), x"DEAF"),
		(std_logic_vector(to_unsigned(512*64*4-1, address'length)), x"FEED")
	);
	
	constant CLOCK_PERIOD: time := 10ns;
	
begin

	DUV: entity work.onchip_sram
		port map (
			address => address,
			clock => clock,
			reset => reset,
			write => write,
			writedata => writedata,
			
			read => read,
			readdatavalid => readdatavalid,
			readdata => readdata
		);
		
	clock <= not clock after CLOCK_PERIOD/2;
	
	process
	
		procedure write_test_data_to_ram is
		begin
		
			for i in TEST_DATA'range loop
			
				address <= TEST_DATA(i).address;
				writedata <= TEST_DATA(i).data;
				
				wait for CLOCK_PERIOD;
			
			end loop;
		
		end procedure;
		
		
		procedure read_ram is
		
			variable expected_data: std_logic_vector(readdata'range);
			
		begin
			
			for i in TEST_DATA'range loop
			
				address <= TEST_DATA(i).address;
				
				wait for CLOCK_PERIOD;
				
--				if (to_integer(unsigned(address)) > to_integer(unsigned(BLOCK3_END_ADDRESS))) then
--					expected_data := (others => '0');
--				else
--					expected_data := TEST_DATA(i).data;
--				end if;
--				
--				assert readdata = expected_data
--				
--				report "data = " & integer'image(to_integer(unsigned(readdata))) & ", it should equal " &
--						 integer'image(to_integer(unsigned(TEST_DATA(i).data))) & "."
--						 
--				severity failure;
				
			end loop;
			
		end procedure;
		
		
	begin
		
		wait until rising_edge(clock);
		
		write <= '1';
		
		write_test_data_to_ram;
		
		write <= '0';
		
		wait until rising_edge(clock);
		
		read <= '1';
		
		read_ram;
		
		read <= '0';
		
	end process;

end architecture;