-- Author: Brandon Dunne

-- Test that the pulse behavior is exactly what was expected by 
-- testing that the delay before the pulse goes high, and that
-- the pulse remains high for the correct duration. The testbench
-- will fail with an error message if either servo-pulse behaves differently than
-- what was expected.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pan_tilt_controller_tb is
end entity;

architecture testbench of pan_tilt_controller_tb is

	signal address: std_logic_vector(1 downto 0);
	signal clk: std_logic := '0';
	signal rst: std_logic;
	signal write: std_logic;
	signal writedata: std_logic_vector(15 downto 0);
	signal pan_pulse:  std_logic;
	signal tilt_pulse: std_logic;
	
	constant CLK_PERIOD: time := 10ns;
	
	-- The number of clock cycles that go into a timer clock-cycle (one timer
	-- per servo).
	constant CLKS_PER_PSC_CLKS: integer := 100;
	
	constant CONTROL_REG_ADDR:   std_logic_vector(address'range) := b"00";
	constant PAN_DATA_REG_ADDR:  std_logic_vector(address'range) := b"01";
	constant TILT_DATA_REG_ADDR: std_logic_vector(address'range) := b"10";
	
	-- The value to write into the control register to turn on the servo's timer
	constant pan_count_enable:  std_logic_vector(writedata'range) := x"0001";
	constant tilt_count_enable: std_logic_vector(writedata'range) := x"0002";
	
	procedure terminate_simulation(err_msg: string) is begin
		assert false report err_msg severity failure;
	end procedure;
	
	-- This procedure verifies that the delay before the pulse 
	-- is exactly what was expected.
	procedure verify_pulse_delay(
		signal pulse: std_logic; 
		variable expected_clks: integer
	) is begin
		
		for i in 1 to expected_clks - 1 loop
			
			wait for CLK_PERIOD;
			
			if pulse = '1' then
			
				terminate_simulation(
					"ERROR: Pulse event occurred after " & 
					integer'image(i) & " clock edges; " &
					integer'image(expected_clks) & " clock edges were expected."
				);
				
			end if;
			
		end loop;
		
		wait for CLK_PERIOD;
		
		if pulse = '1' then
			report "SUCCESS: rising-edge pulse occurred at the right time";
		else
			terminate_simulation("ERROR: rising-edge pulse never occurred");
		end if;
		
	end procedure;
	
	
	-- This procedure verifies that pulse stays high for the exact 
	-- amount of time expected.
	procedure verify_pulse_width(
		signal pulse: in std_logic; 
		variable expected_clks: integer
	) is begin
	
		for i in 1 to expected_clks - 1 loop
		
			wait for CLK_PERIOD;
			
			if pulse = '0' then
			
				terminate_simulation(
					"ERROR: pulse'event occurred after " & 
					integer'image(i) & " clock edges; " 
				   & integer'image(expected_clks) & " clock edges were expected.");

			end if;
			
		end loop;
		
		wait for CLK_PERIOD;
		
		if pulse = '0' then
			report "SUCCESS: falling-edge pulse occurred at the right time";
		else
			terminate_simulation("ERROR: falling-edge pulse never occurred");
		end if;
		
	end procedure;
	
	
begin

	DUV: entity work.pan_tilt_controller
		port map (
			address    => address,
			clk        => clk,
			rst        => rst,
			write      => write,
			writedata  => writedata,
			pan_pulse  => pan_pulse,
			tilt_pulse => tilt_pulse
		);
		
	clk <= not clk after CLK_PERIOD / 2;
	rst <= '1', '0' after CLK_PERIOD;
	
	
	process
		-- The data that is written to the servo's data register
		variable test_data: std_logic_vector(writedata'range) := 
			std_logic_vector(to_unsigned(500, writedata'length));
		
		variable expected_delay, expected_width: integer;
	begin
	
		wait until falling_edge(rst);
	
		--*** Test Pan Servo ***--
		
		-- configure the pan-servo pulse
		address <= PAN_DATA_REG_ADDR;
		writedata <= test_data;
		write <= '1';
		
		wait until falling_edge(clk);
		
		-- enable pan-servo timer
		address <= CONTROL_REG_ADDR;
		writedata <= pan_count_enable;
		write <= '1';
		
		-- Waste one cycle, because the pan-servo's count-enable needs to be 
		-- written to the control register before the pan-servo sees it.
		wait for CLK_PERIOD;
		
		-- On the first duty-cycle, the delay is 50 cycles shorter 
		-- (misses a half-period with respect to the prescaled clk).
		expected_delay := CLKS_PER_PSC_CLKS * (19000 - to_integer(unsigned(test_data)) - 1) 
			+ CLKS_PER_PSC_CLKS/2;
			
		expected_width := CLKS_PER_PSC_CLKS * (1000 + to_integer(unsigned(test_data)));
			
		-- Verify pulse behavior for the first duty-cycle.
		verify_pulse_delay(pan_pulse, expected_delay);
		verify_pulse_width(pan_pulse, expected_width);
		
		-- Add the half period back in for the second duty-cycle.
		expected_delay := CLKS_PER_PSC_CLKS * (19000 - to_integer(unsigned(test_data)));
		
		-- Verify pulse behavior for the second duty-cycle.
		verify_pulse_delay(pan_pulse, expected_delay);
		verify_pulse_width(pan_pulse, expected_width);
		
		wait until falling_edge(clk);
		
		--*** Test Tilt Servo ***--
		
		-- configure the tilt-servo pulse
		address <= TILT_DATA_REG_ADDR;
		writedata <= test_data;
		write <= '1';
		
		wait until falling_edge(clk);
		
		-- enable the tilt-servo timer
		address <= CONTROL_REG_ADDR;
		writedata <= tilt_count_enable;
		write <= '1';
		
		-- Waste on cycle, because the tilt-servo's count-enable needs to 
		-- be written to the control register before the tilt-servo sees it.
		wait for CLK_PERIOD;
		
		-- The Tilt Servo's expected delay for the first duty cycle is cut short 
		-- by a half prescaled-clock period.
		expected_delay := CLKS_PER_PSC_CLKS * (19000 - to_integer(unsigned(test_data)) - 1)
			+ CLKS_PER_PSC_CLKS/2;
		
		-- Verify pulse behavior for the first duty cycle.
		verify_pulse_delay(tilt_pulse, expected_delay);
		verify_pulse_width(tilt_pulse, expected_width);
		
		-- Add the half period back in for the next duty-cycle.
		expected_delay := CLKS_PER_PSC_CLKS * (19000 - to_integer(unsigned(test_data)));
		
		-- Verify pulse behavior for the second duty cycle.
		verify_pulse_delay(tilt_pulse, expected_delay);
		verify_pulse_width(tilt_pulse, expected_width);
		
		report "Test complete!";
	end process;
	

end architecture;