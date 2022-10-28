-- Author: Brandon Dunne

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library component_lib;

entity axi_memory_slave is
  port (
    aclk: std_logic;
    areset: std_logic;

    awaddr: in std_logic_vector(15 downto 0);
    awlen: in std_logic_vector(3 downto 0);
    awsize: in std_logic_vector(2 downto 0);
    awburst: in std_logic_vector(1 downto 0);
    awvalid: in std_logic;
    awready: out std_logic;

    wdata: in std_logic_vector(31 downto 0);
    wstrb: in std_logic_vector(3 downto 0);
    wlast: in std_logic;
    wvalid: in std_logic;
    wready: out std_logic;

    bresp: out std_logic_vector(1 downto 0);
    bvalid: out std_logic;
    bready: in std_logic;

    araddr: in std_logic_vector(15 downto 0);
    arlen: in std_logic_vector(3 downto 0);
    arsize: in std_logic_vector(2 downto 0);
    arburst: in std_logic_vector(1 downto 0);
    arvalid: in std_logic;
    arready: out std_logic;

    rdata: out std_logic_vector(31 downto 0);
    rresp: out std_logic_vector(1 downto 0);
    rlast: out std_logic;
    rvalid: out std_logic;
    rready: in std_logic
  );
end entity;

architecture rtl of axi_memory_slave is

  signal byte_enable: std_logic_vector(3 downto 0);
  signal write_address: std_logic_vector(15 downto 0);
  signal read_address: std_logic_vector(15 downto 0);
  signal write_data: std_logic_vector(31 downto 0);
  signal write_ready: std_logic;
  signal read_data: std_logic_vector(31 downto 0);

  signal int_raddr: integer range 0 to 2**14 - 1;
  signal int_waddr: integer range 0 to 2**14 - 1;

begin

  wready <= write_ready;

  import_axi_write_transfer_controller: entity work.axi_write_transfer_controller
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
      wready => write_ready,

      bresp => bresp,
      bvalid => bvalid,
      bready => bready,

      byte_enable => byte_enable,
      write_address => write_address,
      write_data => write_data
    );

  import_axi_read_transfer_controller: entity work.axi_read_transfer_controller
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

      read_address => read_address,
      read_data => read_data
    );

  int_waddr <= to_integer(unsigned(write_address(15 downto 2)));
  int_raddr <= to_integer(unsigned(read_address(15 downto 2)));
  import_ram_block: entity component_lib.ram_block
    generic map (
       ADDR_WIDTH => 14
    )
    port map (
      clock => aclk,
      raddr => int_raddr,
      waddr => int_waddr,
      wdata => write_data,
      rdata => read_data,
      byte_enable => byte_enable,
      write => write_ready
    );

end architecture;