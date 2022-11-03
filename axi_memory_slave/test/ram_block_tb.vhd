library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
use osvvm.RandomPkg.all;
use osvvm.CoveragePkg.all;

entity ram_block_tb is
end entity;

architecture testbench of ram_block_tb is
  constant CLOCK_PERIOD: time := 10 ns;

  signal clock: std_logic := '0';
  signal raddr: integer range 0 to 2**16 - 1;
  signal waddr: integer range 0 to 2**16 - 1;
  signal rdata: std_logic_vector(31 downto 0);
  signal wdata: std_logic_vector(31 downto 0);
  signal byte_enable: std_logic_vector(3 downto 0);
  signal write: std_logic;

  shared variable cov: CovPType;

  signal stimulus_request: boolean;
  signal stimulus_generated: boolean;
  signal verify_data_request: boolean;

  type stimulus_t is record
    address: integer range 0 to 2**16 - 1;
    data: std_logic_vector(wdata'range);
    byte_enable: std_logic_vector(byte_enable'range);
  end record;

  signal stimulus: stimulus_t;

  procedure assert_equal(a,b: std_logic; err_msg: string) is
  begin
    assert a = b report err_msg severity failure;
  end procedure;
    
  procedure assert_equal(a,b: std_logic_vector; err_msg: string) is
  begin
    assert a = b report err_msg severity error;
  end procedure;

begin

  DUV: entity work.ram_block
    generic map (
      ADDR_WIDTH => 16
    )
    port map (
      clock => clock,
      raddr => raddr,
      waddr => waddr,
      rdata => rdata,
      wdata => wdata,
      byte_enable => byte_enable,
      write => write
    );

    clock <= not clock after CLOCK_PERIOD / 2;

  driver: process
  begin
    wait until clock = '1';

    -- Test every byte_enable combination
    cov.AddBins(GenBin(0,16));
    
    while not cov.isCovered loop
      stimulus_request <= true;
      wait on stimulus_generated'transaction;

      raddr <= stimulus.address;
      waddr <= stimulus.address;
      wdata <= stimulus.data;
      byte_enable <= stimulus.byte_enable;

      write <= '1';

      wait for CLOCK_PERIOD;

      write <= '0';

      wait for CLOCK_PERIOD;

      verify_data_request <= true;
    end loop;

    report "Test is complete";

  end process;

  coverage_collector: process
  begin
    wait on stimulus_generated'transaction;
    cov.ICover(to_integer(unsigned(stimulus.byte_enable)));
  end process;

  stimuli_generator: process
    variable rv: RandomPType;
  begin
    wait on stimulus_request'transaction;

    stimulus.address <= rv.RandInt(2**16 - 1);
    stimulus.data <= rv.RandSlv(32);
    stimulus.byte_enable <= std_logic_vector(to_unsigned(cov.RandCovPoint, byte_enable'length));

    stimulus_generated <= true;
  end process;

  verify_data: process
  begin
    wait on verify_data_request'transaction;

    if byte_enable(0) = '1' then
      assert_equal(rdata(7 downto 0), stimulus.data(7 downto 0), "first byte is unexpected");
    end if;

    if byte_enable(1) = '1' then
      assert_equal(rdata(15 downto 8), stimulus.data(15 downto 8), "second byte is unexpected");
    end if;

    if byte_enable(2) = '1' then
      assert_equal(rdata(23 downto 16), stimulus.data(23 downto 16), "third byte is unexpected");
    end if;

    if byte_enable(3) = '1' then
      assert_equal(rdata(31 downto 24), stimulus.data(31 downto 24), "fourth byte is unexpected");
    end if;

  end process;

end architecture;