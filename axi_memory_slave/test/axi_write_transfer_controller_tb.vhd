-- Author: Brandon Dunne

-- This testbench tests every burst-length for each
-- burst-size using cross-coverage.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
use osvvm.CoveragePkg.all;
use osvvm.RandomPkg.all;

entity axi_write_transfer_controller_tb is
end entity;

architecture testbench of axi_write_transfer_controller_tb is

  signal aclk: std_logic := '0';
  signal areset: std_logic;
  
  signal awaddr: std_logic_vector(15 downto 0);
  signal awlen: std_logic_vector(3 downto 0);
  signal awsize: std_logic_vector(2 downto 0);
  signal awburst: std_logic_vector(1 downto 0);
  signal awvalid: std_logic := '0';
  signal awready: std_logic;

  signal wdata: std_logic_vector(31 downto 0);
  signal wstrb: std_logic_vector(3 downto 0);
  signal wlast: std_logic := '0';
  signal wvalid: std_logic := '0';
  signal wready: std_logic;

  signal bresp: std_logic_vector(1 downto 0);
  signal bvalid: std_logic;
  signal bready: std_logic;

  signal ram_byte_enable: std_logic_vector(3 downto 0);
  signal ram_write_address: std_logic_vector(15 downto 0);
  signal ram_write_data: std_logic_vector(31 downto 0);

  constant CLOCK_PERIOD: time := 10 ns;
  constant LAST_BYTE_ADDRESS: integer := 2**16 - 1;
  constant LAST_HWORD_ADDRESS: integer := 2**15 - 1;
  constant LAST_WORD_ADDRESS: integer := 2**14 - 1;

  shared variable aw_cov: CovPType;

  signal aw_stimulus_generated: boolean := false;
  signal aw_stimulus_request: boolean := false;
  signal w_stimulus_generated: boolean := false;
  signal w_stimulus_request: boolean := false;
  signal verify_data_request: boolean := false;

  type aw_stimulus_t is record
    awaddr: std_logic_vector(awaddr'range);
    awlen: std_logic_vector(awlen'range);
    awsize: std_logic_vector(awsize'range);
    awburst: std_logic_vector(awburst'range);
    awvalid: std_logic;
  end record;

  signal aw_stimulus: aw_stimulus_t;

  type w_stimulus_t is record
    wdata: std_logic_vector(wdata'range);
    wstrb: std_logic_vector(wstrb'range);
  end record;

  signal w_stimulus: w_stimulus_t;

  procedure assert_equal(a,b: std_logic; err_msg: string) is
  begin
    assert a = b report err_msg severity failure;
  end procedure;

  procedure assert_equal(a,b: std_logic_vector; err_msg: string) is
  begin
    assert a = b report err_msg severity failure;
  end procedure;

begin

  DUV: entity work.axi_write_transfer_controller
    port map (
      aclk => aclk,
      areset => areset,

      awaddr => awaddr,
      awlen => awlen,
      awsize => awsize,
      awburst => awburst,
      awvalid => awvalid,
      awready => awready,

      wdata => wdata,
      wstrb => wstrb,
      wlast => wlast,
      wvalid => wvalid,
      wready => wready,

      bresp => bresp,
      bvalid => bvalid,
      bready => bready,

      ram_byte_enable => ram_byte_enable,
      ram_write_address => ram_write_address,
      ram_write_data => ram_write_data
    );

  aclk <= not aclk after CLOCK_PERIOD/2;
  areset <= '1', '0' after CLOCK_PERIOD;

  coverage_collector: process
    variable burst_size: integer;
    variable burst_length: integer;
  begin
    wait on aw_stimulus_generated'transaction;

    burst_size := to_integer(unsigned(aw_stimulus.awsize));
    burst_length := to_integer(unsigned(aw_stimulus.awlen));
    aw_cov.ICover((0 => burst_size, 1 => burst_length));
  end process;

  aw_stimuli_generator: process
    variable address: integer;
    variable random_variable: RandomPType;
    variable burst_size: integer;
    variable burst_length: integer;
  begin

    -- for each burst size, test every transfer length supported
    aw_cov.AddCross(GenBin(min => 0, max => 2), GenBin(min => 0, max => 15));

    while not aw_cov.isCovered loop
      (burst_size, burst_length) := aw_cov.RandCovPoint;
      aw_stimulus.awsize <= std_logic_vector(to_unsigned(burst_size, 3));
      aw_stimulus.awlen <= std_logic_vector(to_unsigned(burst_length, 4));

      if burst_size = 0 then
        address := random_variable.RandInt(0, 2**16 - 1);
        aw_stimulus.awaddr <= std_logic_vector(to_unsigned(address, awaddr'length));
      elsif burst_size = 1 then
        address := random_variable.RandInt(0, 2**15 - 1);
        aw_stimulus.awaddr <= (15 downto 1 => std_logic_vector(to_unsigned(address, 15)), 0 => '0');
      else
        address := random_variable.RandInt(0, 2**14 - 1);
        aw_stimulus.awaddr <= (15 downto 2 => std_logic_vector(to_unsigned(address, 14)), others => '0');
      end if;

      aw_stimulus_generated <= true;
      wait on aw_stimulus_request'transaction;
    end loop;
  end process;

  w_stimuli_generator: process
    variable random_variable: RandomPType;
    variable write_strobe: integer;
    constant valid_1byte_write_strobes: integer_vector(0 to 3) := (1, 2, 4, 8);
    constant valid_2byte_write_strobes: integer_vector(0 to 1) := (3, 12);
  begin
    
    wait on w_stimulus_request'transaction;

    if aw_stimulus.awsize = b"000" then
      write_strobe := random_variable.RandInt(valid_1byte_write_strobes);
    elsif aw_stimulus.awsize = b"001" then
      write_strobe := random_variable.RandInt(valid_2byte_write_strobes);
    else
      write_strobe := 15;
    end if;
    
    -- Generate a random 32-bit wide std_logic_vector
    w_stimulus.wdata <= random_variable.RandSlv(32);
    w_stimulus.wstrb <= std_logic_vector(to_unsigned(write_strobe, 4));

    w_stimulus_generated <= true;

  end process;


  driver: process
    variable burst_length: natural := 0;
    variable burst_count: natural := 0;
  begin
    wait on aw_stimulus_generated'transaction;

    wait until areset = '0' and aclk = '1';

    awaddr <= aw_stimulus.awaddr;
    awlen <= aw_stimulus.awlen;
    awsize <= aw_stimulus.awsize;
    awburst <= (others => '0');
    awvalid <= '1';

    wait for CLOCK_PERIOD;
    wait for 0 ns;

    assert_equal(awready, '1', "awready should be high.");

    wait for CLOCK_PERIOD;
    awvalid <= '0';

    burst_length := to_integer(unsigned(awlen)) + 1;
    burst_count := 0;
    for burst_count in 0 to burst_length - 1 loop

      w_stimulus_request <= true;
      wait on w_stimulus_generated'transaction;

      wdata <= w_stimulus.wdata;
      wstrb <= w_stimulus.wstrb;
      wvalid <= '1';

      if burst_count = burst_length - 1 then
        wlast <= '1';
      else
        wlast <= '0';
      end if;

      if wready = '0' then
        wait until wready = '1';
      end if;

      wait for CLOCK_PERIOD;

      -- request data verification
      verify_data_request <= true;
      
    end loop;

    wvalid <= '0';
    wlast <= '0';

    --** Testing  write response channel **--

    wait until bvalid = '1';

    bready <= '1';

    wait for CLOCK_PERIOD;

    bready <= '0';

    wait for CLOCK_PERIOD;

    aw_stimulus_request <= true;

  end process;

  verify_data: process
    function getBounds(byte_lanes: std_logic_vector) return integer_vector is
      variable retval: integer_vector(0 to 1);
      alias upper_bound: integer is retval(0);
      alias lower_bound: integer is retval(1);
    begin
      case byte_lanes is
        when b"0001" =>
          upper_bound := 7;
          lower_bound := 0;
        when b"0010" =>
          upper_bound := 15;
          lower_bound := 8;
        when b"0100" =>
          upper_bound := 23;
          lower_bound := 16;
        when b"1000" =>
          upper_bound := 31;
          lower_bound := 24;
        when b"0011" =>
          upper_bound := 15;
          lower_bound := 0;
        when b"1100" =>
          upper_bound := 31;
          lower_bound := 16;
        when others =>
          upper_bound := 31;
          lower_bound := 0;
      end case;
      return retval;
    end function;

    variable wstrb_upper, wstrb_lower: integer;
    variable be_upper, be_lower: integer;
  begin

    wait on verify_data_request'transaction;

    (wstrb_upper, wstrb_lower) := getBounds(wstrb);
    (be_upper, be_lower) := getBounds(ram_byte_enable);

    assert_equal(
      wdata(wstrb_upper downto wstrb_lower), 
      ram_write_data(be_upper downto be_lower),
      "unexpected data"
    );

  end process;

end architecture;