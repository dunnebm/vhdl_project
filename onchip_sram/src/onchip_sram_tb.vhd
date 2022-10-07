library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
use osvvm.CoveragePkg.all;
use osvvm.RandomPkg.all;

entity onchip_sram_tb is
end entity;

architecture testbench of onchip_sram_tb is

	signal address: std_logic_vector(17 downto 0);
	signal clock: std_logic := '0';
	signal reset: std_logic;
	signal write: std_logic := '0';
	signal writedata: std_logic_vector(15 downto 0);
	
	signal read: std_logic := '0';
	signal readdatavalid: std_logic;
	signal readdata: std_logic_vector(15 downto 0);

  type stimulus_t is record
    addr: std_logic_vector(address'range);
    data: std_logic_vector(readdata'range);
  end record;

  signal stimulus: stimulus_t;
  signal stimulus_generated: boolean;
  signal stimulus_request: boolean;

  shared variable ramblock_coverage_item: CovPType;
	
	constant BLOCK0_START_ADDRESS: integer := 0;
	constant BLOCK0_END_ADDRESS: integer := 1024*32 - 1;
	
	constant BLOCK1_START_ADDRESS: integer := 1024*32;
	constant BLOCK1_END_ADDRESS: integer := 1024*32*2 - 1;
	
	constant BLOCK2_START_ADDRESS: integer := 1024*32*2;
	constant BLOCK2_END_ADDRESS: integer := 1024*32*3 - 1;

  constant BLOCK3_START_ADDRESS: integer := 1024*32*3;
  constant BLOCK3_END_ADDRESS: integer := 1024*32*4 - 1;

  constant BLOCK4_START_ADDRESS: integer := 1024*32*4;
  constant BLOCK4_START_ADDRESS: integer := 1024*32*5 - 1;

  constant OUT_OF_BOUNDS_START_ADDRESS: integer := 1024*32*5;
  constant OUT_OF_BOUNDS_END_ADDRESS: integer := 1024*32*6 - 1;

	constant CLOCK_PERIOD: time := 10ns;

  procedure assert_equal(a,b: std_logic; err_msg: string) is
  begin
    assert a = b report err_msg severity failure;
  end procedure;

  procedure assert_equal(a,b: std_logic_vector; err_msg: string) is
  begin
    assert a = b report err_msg severity failure;
  end procedure;

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

  stimuli_generator: process
    variable random_variable: RandomPType;
  begin
    -- Initialize bins
    ramblock_coverage_item.AddBins(
      GenBin(Min => BLOCK0_START_ADDRESS, Max => OUT_OF_BOUNDS_END_ADDRESS, 6)
    );

    while not ramblock_coverage_item.isCovered loop
      stimulus.addr <= std_logic_vector(to_unsigned(ramblock_coverage_item.RandCovPoint, 18));
      stimulus.data <= std_logic_vector(to_unsigned(random_variable.RandInt(2**16 - 1), 16));
      stimulus_generated <= true;
      wait on stimulus_request'transaction;
    end loop;

    report "All test passed!";
    std.env.finish;
  end process;

  coverage_collector: process
  begin
    wait on stimulus_generated'transaction;
    ramblock_coverage_item.ICover(to_integer(unsigned(address)));
  end process;

  driver: process
  begin
    wait on stimulus_generated'transaction;

    wait until falling_edge(clk);

    address <= stimulus.addr;
    writedata <= stimulus.data;
    write <= '1';

    wait for CLOCK_PERIOD;

    write <= '0';
    read <= '1';

    wait until readdatavalid = '1';

    if to_integer(unsigned(address)) < OUT_OF_BOUNDS_START_ADDRESS then
      assert_equal(writedata, stimulus.data, 
        "unexpected data at address: " & integer.image(to_integer(unsigned(address))) & ".");
    else
      assert_equal(writedata, x"0000", 
        "unexpected data at out-of-bounds address: " & integer'image(to_integer(unsigned(address))) & ".");
    end if;

    stimulus_request <= true;
  end process;

end architecture;