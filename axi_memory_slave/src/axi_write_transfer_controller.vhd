-- Author: Brandon Dunne

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library component_lib;
use component_lib.my_pkg.all;

use work.axi_memory_slave_pkg.all;

entity axi_write_transfer_controller is
  port (
    aclk: in std_logic;
    areset: in std_logic;

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

    byte_enable: out std_logic_vector(3 downto 0);
    write_address: out std_logic_vector(15 downto 0);
    write_data: out std_logic_vector(31 downto 0)
  );
end entity;

architecture fsm of axi_write_transfer_controller is
  signal next_write_address: std_logic_vector(write_address'range);
  signal current_byte_enable: std_logic_vector(byte_enable'range);
  signal next_byte_enable: std_logic_vector(byte_enable'range) := b"0000";
  signal burst_length: std_logic_vector(awlen'range);
  signal burst_size: std_logic_vector(awsize'range);

  function checkValidWriteStrobe(
      wstrb: std_logic_vector; 
      burst_size: std_logic_vector(2 downto 0)
  ) return std_logic is
    variable retval: std_logic;
  begin
    case burst_size is
      when b"000" =>
        retval := (wstrb(3) xor wstrb(2)) xor (wstrb(1) xor wstrb(0));
      when b"001" =>
        retval := (wstrb(3) and wstrb(2)) xor (wstrb(1) and wstrb(0));
      when b"010" =>
        retval := wstrb(3) and wstrb(2) and wstrb(1) and wstrb(0);
      when others =>
        retval := '0';
    end case;
    return retval;
  end function;

  function parseWriteData(
      write_data: std_logic_vector; 
      write_strobe, byte_enable: std_logic_vector(3 downto 0)
  ) return std_logic_vector is
    variable retval: std_logic_vector(write_data'range);
  begin
    case byte_enable is
      when b"0001" =>
        case write_strobe is
          when b"0001" =>
            retval := x"000000" & write_data(7 downto 0);
          when b"0010" =>
            retval := x"000000" & write_data(15 downto 8);
          when b"0100" =>
            retval := x"000000" & write_data(23 downto 16);
          when b"1000" =>
            retval := x"000000" & write_data(31 downto 24);
          when others =>
            retval := (others => '-');
        end case;
      when b"0010" =>
        case write_strobe is
          when b"0001" =>
            retval := x"0000" & write_data(7 downto 0) & x"00";
          when b"0010" =>
            retval := x"0000" & write_data(15 downto 8) & x"00";
          when b"0100" =>
            retval := x"0000" & write_data(23 downto 16) & x"00";
          when b"1000" =>
            retval := x"0000" & write_data(31 downto 24) & x"00";
          when others =>
            retval := (others => '-');
        end case;
      when b"0100" =>
        case write_strobe is
          when b"0001" =>
            retval := x"00" & write_data(7 downto 0) & x"0000";
          when b"0010" =>
            retval := x"00" & write_data(15 downto 8) & x"0000";
          when b"0100" =>
            retval := x"00" & write_data(23 downto 16) & x"0000";
          when b"1000" =>
            retval := x"00" & write_data(31 downto 24) & x"0000";
          when others =>
            retval := (others => '-');
        end case;
      when b"1000" =>
        case write_strobe is
          when b"0001" =>
            retval := write_data(7 downto 0) & x"000000";
          when b"0010" =>
            retval := write_data(15 downto 8) & x"000000";
          when b"0100" =>
            retval := write_data(23 downto 16) & x"000000";
          when b"1000" =>
            retval := write_data(31 downto 24) & x"000000";
          when others =>
            retval := (others => '-');
        end case;
      when b"0011" =>
        case write_strobe is
          when b"0011" =>
            retval := x"0000" & write_data(15 downto 0);
          when b"1100" =>
            retval := x"0000" & write_data(31 downto 16);
          when others =>
            retval := (others => '-');
        end case;
      when b"1100" =>
        case write_strobe is
          when b"0011" =>
            retval := write_data(15 downto 0) & x"0000";
          when b"1100" =>
            retval := write_data(31 downto 16) & x"0000";
          when others =>
            retval := (others => '-');
        end case;
      when b"1111" =>
        retval := write_data;
      when others =>
        retval := (others => '-');
    end case;
	 
	  return retval;
  end function;

begin

  --read_write_collision <= (read_address = next_write_address);
  write_data <= parseWriteData(wdata, wstrb, next_byte_enable);
 
  process (aclk)
    type state_t is (
      idle,
      awaddr_ready,
      wdata_not_ready,
      wdata_ready,
		  last_wdata_ready,
      ignoring_wdata_because_of_error,
      ignoring_last_wdata_because_of_error,
      write_response_valid,
      write_response_ready
    );
    variable state: state_t := idle;
    variable write_response: std_logic_vector(1 downto 0);

    -- three states have the same transition logic;
    -- this procedure eliminates duplicate code
    procedure wdata_transition_logic is
    begin
      if wvalid = '0' then
        state := wdata_not_ready;
      elsif checkValidWriteStrobe(wstrb, burst_size) = '0' then
        write_response := RESPONSE_DECERR;
        if wlast = '1' then
          state := ignoring_last_wdata_because_of_error;
        else
          state := ignoring_wdata_because_of_error;
        end if;
      elsif wlast = '1' then
        state := last_wdata_ready;
      else 
        state := wdata_ready;
      end if;
    end procedure;

    procedure update_state is
    begin
      if areset = '1' then
        state := idle;
      else
        case state is
          when idle =>
            if awvalid = '1' and checkValidBurstSize(awsize) = '1' and checkAlignment(awaddr, awsize) = '1' then
              state := awaddr_ready;
            elsif awvalid = '1' then
              write_response := RESPONSE_SLVERR;
              state := ignoring_wdata_because_of_error;
            end if;
          when awaddr_ready =>
            wdata_transition_logic;
          when wdata_not_ready =>
            wdata_transition_logic;
          when wdata_ready =>
            wdata_transition_logic;
			    when last_wdata_ready =>
            write_response := RESPONSE_OKAY;
				    state := write_response_valid;
          when ignoring_wdata_because_of_error =>
            if wlast = '1' then
              state := ignoring_last_wdata_because_of_error;
            end if;
          when ignoring_last_wdata_because_of_error =>
            state := write_response_valid;
          when write_response_valid =>
            if bready = '1' then  
              state := write_response_ready;
            end if;
          when write_response_ready =>
            state := idle;
        end case;
      end if;
    end procedure;

    procedure update_signals is
    begin
      case state is
        when idle =>
          awready <= '0';
          wready <= '0';
          bvalid <= '0';
			    byte_enable <= b"0000";
          next_byte_enable <= b"0000";
        when awaddr_ready =>
          awready <= '1';
          wready <= '0';
          bvalid <= '0';
			    burst_size <= awsize;
          next_write_address <= (15 downto 2 => awaddr(15 downto 2), 1 downto 0 => '0');
          next_byte_enable <= setByteEnable(awaddr, awsize);
        when wdata_not_ready =>
          awready <= '0';
          wready <= '0';
          bvalid <= '0';
        when wdata_ready =>
          awready <= '0';
          wready <= '1';
          bvalid <= '0';
          write_address <= next_write_address;
          byte_enable <= next_byte_enable;
          next_write_address <= updateAddress(next_write_address, next_byte_enable);
          next_byte_enable <= updateByteEnable(burst_size, next_byte_enable);
        when last_wdata_ready =>
          awready <= '0';
          wready <= '1';
          bvalid <= '0';
          write_address <= next_write_address;
          byte_enable <= next_byte_enable;
        when ignoring_wdata_because_of_error =>
          awready <= '0';
          wready <= '1';
          bvalid <= '0';
        when ignoring_last_wdata_because_of_error =>
          awready <= '0';
          wready <= '1';
          bvalid <= '0';
        when write_response_valid =>
          awready <= '0';
          wready <= '0';
          bvalid <= '1';
          bresp <= write_response;
        when write_response_ready =>
          awready <= '0';
          wready <= '0';
          bvalid <= '1';
          bresp <= write_response;
      end case;
    end procedure;

  begin
    if rising_edge(aclk) then
      update_state;
      update_signals;
    end if;
  end process;

end architecture;