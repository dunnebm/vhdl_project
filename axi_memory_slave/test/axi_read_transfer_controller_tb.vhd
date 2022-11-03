-- Author: Brandon Dunne

-- This testbench tests every burst-length for each
-- burst-size using cross-coverage.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
use osvvm.CoveragePkg.all;
use osvvm.RandomPkg.all;

entity axi_read_transfer_controller_tb is
end entity;

architecture testbench of axi_read_transfer_controller_tb is

  signal aclk: std_logic := '0';
  signal areset: std_logic;

  signal araddr: std_logic_vector(15 downto 0);
  signal arlen: std_logic_vector(3 downto 0);
  signal arsize: std_logic_vector(2 downto 0);
  signal arburst: std_logic_vector(1 downto 0);
  signal arvalid: std_logic;
  signal arready: std_logic;

  signal rdata: std_logic_vector(31 downto 0);
  signal rresp: std_logic_vector(1 downto 0);
  signal rlast: std_logic;
  signal rvalid: std_logic;
  signal rready: std_logic;

  signal ram_read_address: std_logic_vector(15 downto 0);
  signal ram_read_data: std_logic_vector(31 downto 0);

  constant CLOCK_PERIOD: time := 10 ns;
  constant DELTA_CYCLE: time := 0 ns;

  shared variable ar_cov: CovPType;

  signal ar_stimulus_request: boolean;
  signal ar_stimulus_generated: boolean;
  signal r_stimulus_request: boolean;
  signal r_stimulus_generated: boolean;
  signal verify_data_request: boolean;

  type ar_stimulus_t is record
    araddr: std_logic_vector(araddr'range);
    arlen: std_logic_vector(arlen'range);
    arsize: std_logic_vector(arsize'range);
    arburst: std_logic_vector(arburst'range);
    arvalid: std_logic;
  end record;

  type r_stimulus_t is record
    rdata: std_logic_vector(rdata'range);
  end record;

  signal ar_stimulus: ar_stimulus_t;
  signal r_stimulus: r_stimulus_t;

  procedure assert_equal(a,b: std_logic; err_msg: string) is
  begin
    assert a = b report err_msg severity failure;
  end procedure;
  
  procedure assert_equal(a,b: std_logic_vector; err_msg: string) is
  begin
    assert a = b report err_msg severity error;
  end procedure;

  procedure assert_not_equal(a,b: integer; err_msg: string) is
  begin
    assert a /= b report err_msg severity error;
  end procedure;

begin

  DUV: entity work.axi_read_transfer_controller
    port map (
      aclk => aclk,
      areset => areset,

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
      rready => rready,

      ram_read_address => ram_read_address,
      ram_read_data => ram_read_data
    );

  aclk <= not aclk after CLOCK_PERIOD/2;
  areset <= '1', '0' after 2*CLOCK_PERIOD;

  coverage_collector: process
    variable burst_size: integer;
    variable burst_length: integer;
  begin
    wait on ar_stimulus_generated'transaction;

    burst_size := to_integer(unsigned(ar_stimulus.arsize));
    burst_length := to_integer(unsigned(ar_stimulus.arlen));
    ar_cov.ICover((0 => burst_size, 1 => burst_length));
  end process;

  ar_stimulus_generator: process
    variable rv: RandomPType;
    variable address: integer;
    variable burst_size: integer;
    variable burst_length: integer;
  begin
    -- for each burst size, test every burst length
    ar_cov.AddCross(GenBin(0,2), GenBin(0,15));
    
    while not ar_cov.isCovered loop
      wait on ar_stimulus_request'transaction;

      (burst_size, burst_length) := ar_cov.RandCovPoint;
      ar_stimulus.arsize <= std_logic_vector(to_unsigned(burst_size, 3));
      ar_stimulus.arlen <= std_logic_vector(to_unsigned(burst_length, 4));

      if burst_size = 0 then
        address := rv.RandInt(2**16 - 1);
        ar_stimulus.araddr <= std_logic_vector(to_unsigned(address, 16));
      elsif burst_size = 1 then
        address := rv.RandInt(2**15 - 1);
        ar_stimulus.araddr(15 downto 1) <= std_logic_vector(to_unsigned(address, 15));
        ar_stimulus.araddr(0) <= '0';
      else
        address := rv.RandInt(2**14 - 1);
        ar_stimulus.araddr(15 downto 2) <= std_logic_vector(to_unsigned(address, 14));
        ar_stimulus.araddr(1 downto 0) <= b"00";
      end if;

      ar_stimulus_generated <= true;
    end loop;

    wait;

  end process;

  r_stimulus_generator: process
    variable rv: RandomPType;
  begin
    wait on r_stimulus_request'transaction;

    r_stimulus.rdata <= rv.RandSlv(32);

    r_stimulus_generated <= true;
  end process;

  
  driver: process
    variable burst_length: integer;
    variable burst_count: integer;
    variable transfer_is_not_finished: integer;
  begin
    wait until areset = '0' and aclk = '1';

    ar_stimulus_request <= true;
    wait on ar_stimulus_generated'transaction;

    araddr <= ar_stimulus.araddr;
    arlen <= ar_stimulus.arlen;
    arsize <= ar_stimulus.arsize;
    arvalid <= '1';

    report "waiting for arready";
    wait until arready = '1';

    wait for CLOCK_PERIOD;

    arvalid <= '0';
    rready <= '1';
    
    burst_length := to_integer(unsigned(arlen));
    burst_count := 0;

    transfer_is_not_finished := 0;
    while transfer_is_not_finished = 0 loop
      r_stimulus_request <= true;
      wait on r_stimulus_generated'transaction;

      ram_read_data <= r_stimulus.rdata;

      wait until rvalid = '1';

      if rlast = '1' then
        report "last transfer";
        transfer_is_not_finished := 1;
      end if;

      verify_data_request <= true;

      wait until rvalid = '0';
    end loop;

    report "read transfer finished";

    rready <= '0';

  end process;


  verify_data: process
    function getRDataUpperBound(
        arsize: std_logic_vector(arsize'range)
    ) return integer is
      variable retval: integer;
    begin
      if arsize = b"000" then
        retval := 7;
      elsif arsize = b"001" then
        retval := 15;
      else
        retval := 31;
      end if;
      return retval;
    end function;

    function getStimulusDataBounds(
        araddr: std_logic_vector(araddr'range); 
        arsize: std_logic_vector(arsize'range)
    ) return integer_vector is
      variable bounds: integer_vector(0 to 1);
      alias upper: integer is bounds(0);
      alias lower: integer is bounds(1);
    begin
      case arsize is
        when b"000" =>
          case araddr(1 downto 0) is
            when b"00" =>
              upper := 7;
              lower := 0;
            when b"01" =>
              upper := 15;
              lower := 8;
            when b"10" =>
              upper := 23;
              lower := 16;
            when b"11" =>
              upper := 31;
              lower := 24;
            when others =>
              upper := -1;
              lower := -1;
          end case;
        when b"001" =>
          case araddr(1) is
            when '0' =>
              upper := 15;
              lower := 0;
            when '1' =>
              upper := 31;
              lower := 16;
            when others =>
              upper := -1;
              lower := -1;
          end case;
        when b"010" =>
          upper := 31;
          lower := 0;
        when others =>
          upper := -1;
          lower := -1;
      end case;
      return bounds;
    end function;

    variable stimulus_upper, stimulus_lower, rdata_upper: integer;
  begin
    wait on verify_data_request'transaction;

    rdata_upper := getRDataUpperBound(ar_stimulus.arsize);
    (stimulus_upper, stimulus_lower) := getStimulusDataBounds(ar_stimulus.araddr, ar_stimulus.arsize);

    report "expected_data = " & to_hstring(ram_read_data(stimulus_upper downto stimulus_lower)) &
           ", rdata = " & to_hstring(rdata(rdata_upper downto 0));
   
    assert_equal(
      rdata(rdata_upper downto 0), ram_read_data(stimulus_upper downto stimulus_lower), "Unexpected data");

  end process;

end architecture;