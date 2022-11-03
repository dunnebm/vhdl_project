-- Author: Brandon Dunne

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_memory_slave_pkg.all;

entity axi_read_transfer_controller is
  port (
    aclk: in std_logic;
    areset: in std_logic;

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
    rready: in std_logic;

    ram_read_address: out std_logic_vector(15 downto 0);
    ram_read_data: in std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of axi_read_transfer_controller is

  signal next_read_address: std_logic_vector(15 downto 0);
  signal byte_enable: std_logic_vector(3 downto 0);
  signal next_byte_enable: std_logic_vector(3 downto 0);
  signal next_read_data: std_logic_vector(31 downto 0);
  signal burst_size: std_logic_vector(2 downto 0);

  function parseReadData(
      data_in: std_logic_vector; 
      byte_enable: std_logic_vector(3 downto 0)
  ) return std_logic_vector is
    variable data_out: std_logic_vector(rdata'range);
  begin
    case byte_enable is
      when b"0001" =>
        data_out := x"000000" & data_in(7 downto 0);
      when b"0010" =>
        data_out := x"000000" & data_in(15 downto 8);
      when b"0100" =>
        data_out := x"000000" & data_in(23 downto 16);
      when b"1000" =>
        data_out := x"000000" & data_in(31 downto 24);
      when b"0011" =>
        data_out := x"0000" & data_in(15 downto 0);
      when b"1100" =>
        data_out := x"0000" & data_in(31 downto 16);
      when others =>
        data_out := data_in;
    end case;

    return data_out;
  end function;

begin

  rdata <= parseReadData(ram_read_data, byte_enable);

  process (aclk)
    type state_t is (
      idle,
      araddr_ready,
      rdata_not_valid,
      rdata_valid,
      error_read_response
    );
    variable state: state_t;
    variable count: integer;

    procedure update_state is
    begin
      if areset = '1' then
        state := idle;
      else
        case state is
          when idle =>
            if arvalid = '1' and checkAlignment(araddr, arsize) = '1' and checkValidBurstSize(arsize) = '1' then
              state := araddr_ready;
            elsif arvalid = '1' then
              state := error_read_response;
            end if;
          when araddr_ready =>
            state := rdata_not_valid;
          when rdata_not_valid =>
            state := rdata_valid;
          when rdata_valid =>
            if rready = '1' and  count = 0 then
              state := idle;
            elsif rready = '1' then
              count := count - 1;
              state := rdata_not_valid;
            end if;
          when error_read_response =>
            if rready = '1' and count = 0 then
              state := idle;
            elsif rready = '1' then
              count := count - 1;
            end if;
        end case;
      end if;
    end procedure;

    procedure update_signals is
    begin
      case state is
        when idle =>
          arready <= '0';
          rvalid <= '0';
          rlast <= '0';
          byte_enable <= b"0000";
          next_byte_enable <= b"0000";
        when araddr_ready =>
          arready <= '1';
          rvalid <= '0';
          rlast <= '0';
          count := to_integer(unsigned(arlen));
			    burst_size <= arsize;
          next_read_address <= (15 downto 2 => araddr(15 downto 2), 1 downto 0 => '0');
          next_byte_enable <= setByteEnable(araddr, arsize);
        when rdata_not_valid =>
          arready <= '0';
          rvalid <= '0';
          rlast <= '0';
          ram_read_address <= next_read_address;
          byte_enable <= next_byte_enable;
          next_read_address <= updateAddress(next_read_address, next_byte_enable);
          next_byte_enable <= updateByteEnable(burst_size, next_byte_enable);
        when rdata_valid =>
          arready <= '0';
          rvalid <= '1';
          rresp <= RESPONSE_OKAY;
          if count = 0 then
            rlast <= '1';
          else
            rlast <= '0';
          end if;
        when error_read_response =>
          arready <= '0';
          rvalid <= '1';
          rresp <= RESPONSE_DECERR;
          if count = 0 then
            rlast <= '1';
          else
            rlast <= '0';
          end if;
      end case;
    end procedure;

  begin
    if rising_edge(aclk) then
      update_state;
      update_signals;
    end if;
  end process;

end architecture;