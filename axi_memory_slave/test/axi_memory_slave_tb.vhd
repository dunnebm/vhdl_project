-- Author: Brandon Dunne

-- This testbench tests every burst-length for each 
-- burst-size.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
use osvvm.CoveragePkg.all;
use osvvm.RandomPkg.all;

entity axi_memory_slave_tb is
end entity;

architecture testbench of axi_memory_slave_tb is

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
  signal bready: std_logic := '0';

  signal araddr: std_logic_vector(15 downto 0);
  signal arlen: std_logic_vector(3 downto 0);
  signal arsize: std_logic_vector(2 downto 0);
  signal arburst: std_logic_vector(1 downto 0);
  signal arvalid: std_logic := '0';
  signal arready: std_logic;

  signal rdata: std_logic_vector(31 downto 0);
  signal rresp: std_logic_vector(1 downto 0);
  signal rlast: std_logic;
  signal rvalid: std_logic;
  signal rready: std_logic := '0';

  constant CLOCK_PERIOD: time := 10 ns;

  type addr_ctrl_stimulus_t is record
    address: std_logic_vector(awaddr'range);
    burst_size: std_logic_vector(awsize'range);
    burst_length: std_logic_vector(awlen'range);
  end record;

  type stimulus_data_t is record
    data: std_logic_vector(wdata'range);
    wstrb: std_logic_vector(wstrb'range);
  end record;

  type stimulus_data_array_t is array (0 to 15) of stimulus_data_t;

  signal addr_ctrl_stimulus: addr_ctrl_stimulus_t;
  signal stimulus_data: std_logic_vector(wdata'range);
  signal stimulus_wstrb: std_logic_vector(wstrb'range);
  signal expected_data: std_logic_vector(wdata'range);
  signal expected_wstrb: std_logic_vector(wstrb'range);
  signal stimulus_data_array: stimulus_data_array_t;

  shared variable cov: CovPType;

  -- These signal are used to coordinate processes with each other
  signal addr_ctrl_stimulus_generated: boolean;
  signal addr_ctrl_stimulus_request: boolean;
  signal stimulus_data_generated: boolean;
  signal stimulus_data_request: boolean;
  signal start_write_transfer: boolean;
  signal start_read_transfer: boolean;
  signal end_of_write_transfer: boolean;
  signal end_of_read_transfer: boolean;
  signal verify_data_request: boolean;

  procedure assert_equal(a,b: std_logic; err_msg: string) is
  begin
    assert a = b report err_msg severity failure;
  end procedure;
  
  procedure assert_equal(a,b: std_logic_vector; err_msg: string) is
  begin
    assert a = b report err_msg severity error;
  end procedure;

begin

  DUV: entity work.axi_memory_slave
    port map (
      aclk => aclk,
      areset =>areset,

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

      araddr => araddr,
      arlen => arlen,
      arsize => arsize,
      arburst => arburst,
      arvalid => arvalid,
      arready => arready,

      rdata => rdata,
      rresp => rresp,
      rlast => rlast,
      rvalid => rvalid,
      rready => rready
    );

  aclk <= not aclk after CLOCK_PERIOD/2;
  areset <= '1', '0' after CLOCK_PERIOD;

  simulation_controller: process
  begin
    -- For each burst-size test every burst-length
    cov.AddCross(GenBin(0,2), GenBin(0,15));

    wait until areset = '0' and aclk = '1';

    while not cov.isCovered loop
      addr_ctrl_stimulus_request <= true;
      wait on addr_ctrl_stimulus_generated'transaction;

      start_write_transfer <= true;
      wait on end_of_write_transfer'transaction;

      start_read_transfer <= true;
      wait on end_of_read_transfer'transaction;
    end loop;

    report "Test finished!";
    wait;
  end process;

  write_transfer_driver: process
    variable burst_length: integer;
  begin
    wait on start_write_transfer'transaction;

    awaddr <= addr_ctrl_stimulus.address;
    awsize <= addr_ctrl_stimulus.burst_size;
    awlen <= addr_ctrl_stimulus.burst_length;
    awvalid <= '1';

    wait until awready = '1';
    wait until awready = '0';
    
    awvalid <= '0';

    burst_length := to_integer(unsigned(addr_ctrl_stimulus.burst_length));

    for i in 0 to burst_length loop
      stimulus_data_request <= true;
      wait on stimulus_data_generated'transaction;

      -- store stimulus data so the read-transfer driver can
      -- verify rdata
      stimulus_data_array(i).data <= stimulus_data;
      stimulus_data_array(i).wstrb <= stimulus_wstrb;

      wdata <= stimulus_data;
      wstrb <= stimulus_wstrb;
      wvalid <= '1';

      if i = burst_length then
        wlast <= '1';
      else
        wlast <= '0';
      end if;

      if wready = '0' then
        wait until wready = '1';
      end if;

      wait for CLOCK_PERIOD;
    
    end loop;

    wvalid <= '0';
    wlast <= '0';

    wait until bvalid = '1';
    bready <= '1';
    wait until bvalid = '0';
    bready <= '0';

    end_of_write_transfer <= true;
  end process;

  read_transfer_driver: process
    variable read_transfer_is_not_finished: boolean;
    variable burst_count: integer;
  begin
    wait on start_read_transfer'transaction;

    araddr <= addr_ctrl_stimulus.address;
    arsize <= addr_ctrl_stimulus.burst_size;
    arlen <= addr_ctrl_stimulus.burst_length;
    arvalid <= '1';

    wait until arready = '1';
    wait until arready = '0';

    arvalid <= '0';

    rready <= '1';

    read_transfer_is_not_finished := true;
    burst_count := 0;
    while read_transfer_is_not_finished loop
      wait until rvalid = '1';
      wait for 0 ns;

      if rlast = '1' then
        read_transfer_is_not_finished := false;
      end if;

      expected_data <= stimulus_data_array(burst_count).data;
      expected_wstrb <= stimulus_data_array(burst_count).wstrb;
     
      verify_data_request <= true;
      
      burst_count := burst_count + 1;

      wait until rvalid = '0';
    end loop;

    rready <= '0';

    end_of_read_transfer <= true;
  end process;

  verify_data: process
    function getWstrbBounds(write_strobe: std_logic_vector) return integer_vector is
      variable retval: integer_vector(0 to 1);
      alias upper_bound: integer is retval(0);
      alias lower_bound: integer is retval(1);
    begin
      case write_strobe is
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

    function getRDataUpperBound(burst_size: std_logic_vector(awsize'range)) return integer is
      variable retval: integer;
    begin
      case burst_size is
        when b"000" =>
          retval := 7;
        when b"001" =>
          retval := 15;
        when b"010" =>
          retval := 31;
        when others =>
          retval := -1;
      end case;
      return retval;
    end function;
    
    variable wstrb_upper, wstrb_lower: integer;
    variable rdata_upper: integer;
  begin
    wait on verify_data_request'transaction;

    (wstrb_upper, wstrb_lower) := getWstrbBounds(expected_wstrb);
    rdata_upper := getRDataUpperBound(awsize);

    report "wstrb_upper = " & integer'image(wstrb_upper) & ", wstrb_lower = " & integer'image(wstrb_lower); 
    report "expected_data = " & to_hstring(expected_data) & ", rdata = " & to_hstring(rdata);

    assert_equal(
      expected_data(wstrb_upper downto wstrb_lower), 
      rdata(rdata_upper downto 0),
      "Unexpected data"
    );

  end process;
  
  coverage_collector: process
    variable burst_size: integer;
    variable burst_length: integer;
  begin
    wait on addr_ctrl_stimulus_generated'transaction;
    burst_size := to_integer(unsigned(addr_ctrl_stimulus.burst_size));
    burst_length := to_integer(unsigned(addr_ctrl_stimulus.burst_length));
    cov.ICover((0 => burst_size, 1 => burst_length));
  end process;

  addr_ctrl_stimulus_generator: process
    variable rv: RandomPType;
    variable address: integer;
    variable burst_size: integer;
    variable burst_length: integer;
  begin
    wait on addr_ctrl_stimulus_request'transaction;

    (burst_size, burst_length) := cov.RandCovPoint;
    addr_ctrl_stimulus.burst_size <= std_logic_vector(to_unsigned(burst_size, awsize'length));
    addr_ctrl_stimulus.burst_length <= std_logic_vector(to_unsigned(burst_length, awlen'length));

    if burst_size = 0 then
      addr_ctrl_stimulus.address <= rv.RandSlv(awaddr'length);
    elsif burst_size = 1 then
      addr_ctrl_stimulus.address(15 downto 1) <= rv.RandSlv(awaddr'length - 1);
      addr_ctrl_stimulus.address(0) <= '0';
    else
      addr_ctrl_stimulus.address(15 downto 2) <= rv.RandSlv(awaddr'length - 2);
      addr_ctrl_stimulus.address(1 downto 0) <= b"00";
    end if;

    addr_ctrl_stimulus_generated <= true;
  end process;

  data_stimulus_generator: process
    variable rv: RandomPType;
    variable write_strobe: integer;
    constant valid_1byte_write_strobes: integer_vector(0 to 3) := (1, 2, 4, 8);
    constant valid_2byte_write_strobes: integer_vector(0 to 1) := (3, 12);
  begin
    wait on stimulus_data_request'transaction;
    
    if awsize = b"000" then
      write_strobe := rv.RandInt(valid_1byte_write_strobes);
    elsif awsize = b"001" then
      write_strobe := rv.RandInt(valid_2byte_write_strobes);
    else
      write_strobe := 15;
    end if;

    stimulus_data <= rv.RandSlv(wdata'length);
    stimulus_wstrb <= std_logic_vector(to_unsigned(write_strobe, wstrb'length));

    stimulus_data_generated <= true;
  end process;

end architecture;