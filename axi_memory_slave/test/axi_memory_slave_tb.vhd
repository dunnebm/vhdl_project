-- Author: Brandon Dunne

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
  signal awvalid: std_logic;
  signal awready: std_logic;

  signal wdata: std_logic_vector(31 downto 0);
  signal wstrb: std_logic_vector(3 downto 0);
  signal wlast: std_logic;
  signal wvalid: std_logic;
  signal wready: std_logic;
  
  signal bresp: std_logic_vector(1 downto 0);
  signal bvalid: std_logic;
  signal bready: std_logic;

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

  constant CLOCK_PERIOD: time := 10 ns;

  type aw_channel is record
    awaddr: std_logic_vector(15 downto 0);
    awlen: std_logic_vector(3 downto 0);

  end record;

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
  
  process
  begin

  end process;

end architecture;