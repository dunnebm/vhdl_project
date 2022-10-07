library ieee;
use ieee.std_logic_1164.all;

entity sram_read_transfer_controller is
	port (
		clock: in std_logic;
		read: in std_logic;
		readdatavalid: out std_logic
	);
end entity;

architecture behavior of sram_read_transfer_controller is
begin

	process (clock)
    type state_t is (invalid_read, valid_read);
    variable state: state_t := invalid_read;

    procedure update_state is
    begin
      case state is
        when invalid_read =>
          if read = '1' then
            state := valid_read;
          end if;
        when valid_read =>
          if read = '0' then
            state := invalid_read;
          end if;
      end case;
    end procedure;
    
    procedure update_signals is
    begin
      if state = invalid_read then
        readdatavalid <= '0';
      else
        readdatavalid <= '1';
      end if;
    end procedure;
    
  begin
		if rising_edge(clock) then
      update_state;
      update_signals;
		end if;
	end process;

end architecture;