library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package axi_memory_slave_pkg is

  constant RESPONSE_OKAY: std_logic_vector(1 downto 0) := b"00";
  constant RESPONSE_EXOKAY: std_logic_vector(1 downto 0) := b"01";
  constant RESPONSE_SLVERR: std_logic_vector(1 downto 0) := b"10";
  constant RESPONSE_DECERR: std_logic_vector(1 downto 0) := b"11";

  function checkAlignment(
      address: std_logic_vector; 
      burst_size: std_logic_vector(2 downto 0)
  ) return std_logic;

  function checkValidBurstSize(
      burst_size: std_logic_vector(2 downto 0)
  ) return std_logic;

  function setByteEnable(
      address: std_logic_vector; 
      burst_size: std_logic_vector(2 downto 0)
  ) return std_logic_vector;

  function updateByteEnable(
      burst_size: std_logic_vector(2 downto 0); 
      byte_enable: std_logic_vector
  ) return std_logic_vector;

  function updateAddress(
    address, byte_enable: std_logic_vector
  ) return std_logic_vector;

end package;

package body axi_memory_slave_pkg is

  function checkAlignment(
      address: std_logic_vector; 
      burst_size: std_logic_vector(2 downto 0)
  ) return std_logic is
    variable retval: std_logic;
  begin
    case burst_size is
      when b"000" =>
        retval := '1';
      when b"001" =>
        retval := not address(0);
      when b"010" =>
        retval := address(1) nor address(0);
      when others =>
        retval := '0';
    end case;
    return retval;
  end function;

  -- Only supports 1, 2, and 4-byte burst-size
  function checkValidBurstSize(
      burst_size: std_logic_vector(2 downto 0)
  ) return std_logic is
    variable size_is_one_or_two_bytes, size_is_four_bytes: std_logic;
  begin
    size_is_one_or_two_bytes := not burst_size(2) and not burst_size(1);
    size_is_four_bytes := not burst_size(2) and burst_size(1) and not burst_size(0);

    return size_is_one_or_two_bytes or size_is_four_bytes;
  end function;

  function setByteEnable(
      address: std_logic_vector; 
      burst_size: std_logic_vector(2 downto 0)
  ) return std_logic_vector is
    variable byte_enable: std_logic_vector(3 downto 0);
  begin
    case burst_size is
      when b"000" =>
        case address(1 downto 0) is
          when b"00" =>
            byte_enable := b"0001";
          when b"01" =>
            byte_enable := b"0010";
          when b"10" =>
            byte_enable := b"0100";
          when b"11" =>
            byte_enable := b"1000";
          when others =>
            byte_enable := b"0000";
        end case;
      when b"001" =>
        case address(1) is
          when '0' =>
            byte_enable := b"0011";
          when '1' =>
            byte_enable := b"1100";
          when others =>
            byte_enable := b"0000";
        end case;
      when b"010" =>
        byte_enable := b"1111";
      when others =>
        byte_enable := b"0000";
    end case;
    return byte_enable;
  end function;

  function updateByteEnable(
    burst_size: std_logic_vector(2 downto 0); 
    byte_enable: std_logic_vector
  ) return std_logic_vector is
    variable retval: std_logic_vector(byte_enable'range);
  begin
    case burst_size is
      when b"000" =>
        retval := byte_enable(2 downto 0) & byte_enable(3);
      when b"001" =>
        retval := byte_enable(1 downto 0) & byte_enable(3 downto 2);
      when b"010" =>
        retval := byte_enable;
      when others =>
        retval := b"0000";
    end case;
    return retval;
  end function;

  function updateAddress(address, byte_enable: std_logic_vector) return std_logic_vector is
    variable retval: integer;
  begin
    if byte_enable(3) = '1' then
      retval := to_integer(unsigned(address)) + 4;
    else
      retval := to_integer(unsigned(address));
    end if;
    return std_logic_vector(to_unsigned(retval, address'length));
  end function;

end package body;