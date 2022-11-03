-- Author: Brandon Dunne

-- Supports AXI burst transfers (read and write); Burst-sizes supported are:
-- 1-byte, 2-bytes, and 4-bytes; and the largest burst is 16. This component is
-- unable to detect a read-write collision, and only supports the WRAP burst-mode.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library component_lib;

entity axi_memory_slave is
  port (
    aclk: std_logic;
    areset: std_logic;

    -- address/control signals for write transfers
    awaddr: in std_logic_vector(15 downto 0);
    awlen: in std_logic_vector(3 downto 0);
    awsize: in std_logic_vector(2 downto 0);
    awburst: in std_logic_vector(1 downto 0);
    awvalid: in std_logic;
    awready: out std_logic;

    -- write signals
    wdata: in std_logic_vector(31 downto 0);
    wstrb: in std_logic_vector(3 downto 0);
    wlast: in std_logic;
    wvalid: in std_logic;
    wready: out std_logic;

    -- write-response signals
    bresp: out std_logic_vector(1 downto 0);
    bvalid: out std_logic;
    bready: in std_logic;

    -- address/control signals for read transfers
    araddr: in std_logic_vector(15 downto 0);
    arlen: in std_logic_vector(3 downto 0);
    arsize: in std_logic_vector(2 downto 0);
    arburst: in std_logic_vector(1 downto 0);
    arvalid: in std_logic;
    arready: out std_logic;

    -- read signals
    rdata: out std_logic_vector(31 downto 0);
    rresp: out std_logic_vector(1 downto 0);
    rlast: out std_logic;
    rvalid: out std_logic;
    rready: in std_logic
  );
end entity;

architecture rtl of axi_memory_slave is

  signal ram_byte_enable: std_logic_vector(3 downto 0);
  signal ram_write_address: std_logic_vector(15 downto 0);
  signal ram_read_address: std_logic_vector(15 downto 0);
  signal ram_write_data: std_logic_vector(31 downto 0);
  signal write_ready: std_logic;
  signal ram_read_data: std_logic_vector(31 downto 0);

  signal waddr_int: integer range 0 to 2**14 - 1;
  signal raddr_int: integer range 0 to 2**14 - 1;

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

      ram_byte_enable => ram_byte_enable,
      ram_write_address => ram_write_address,
      ram_write_data => ram_write_data
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

      ram_read_address => ram_read_address,
      ram_read_data => ram_read_data
    );

  waddr_int <= to_integer(unsigned(ram_write_address(15 downto 2)));
  raddr_int <= to_integer(unsigned(ram_read_address(15 downto 2)));
  import_ram_block: entity work.ram_block
    generic map (
       ADDR_WIDTH => 14
    )
    port map (
      clock => aclk,
      raddr => raddr_int,
      waddr => waddr_int,
      wdata => ram_write_data,
      rdata => ram_read_data,
      byte_enable => ram_byte_enable,
      write => write_ready and wvalid
    );

end architecture;