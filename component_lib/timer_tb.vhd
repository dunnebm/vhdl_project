library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer_tb is
end entity;

architecture testbench of timer_tb is

	signal clk: std_logic := '0';
	signal cen, aclr, uef, ch1_pulse: std_logic;
	signal ch1, ocr, count: std_logic_vector(15 downto 0);
	
	constant CLK_PERIOD: time := 10ns;
	
	procedure terminate_simulation(err_msg: string) is begin
		assert false report err_msg severity failure;
	end procedure;
	
	procedure test_pulse_latency(signal pulse: std_logic; variable cycles: integer) is
	begin
	
		for i in 1 to cycles - 1 loop
		
			wait for CLK_PERIOD;
			
			if pulse = '1' then
				terminate_simulation("pulse after " & integer'image(i) & "; expected pulse to be at " & integer'image(cycles) & ".");
			end if;
			
		end loop;
		
			wait for CLK_PERIOD;
		
		if pulse = '1' then
			report "Success: pulse happened at the expected time (" & integer'image(cycles) & ").";
		else
			terminate_simulation("pulse never occurred.");
		end if;
		
	end procedure;
	
	procedure test_pulse_width(signal pulse: std_logic; variable cycles: integer) is
	begin
		
		for i in 1 to cycles - 1 loop
		
			wait for CLK_PERIOD;
		
			if pulse = '0' then
				terminate_simulation("pulse only held for " & integer'image(i) & " cycles; should have held for " & integer'image(cycles) & " cycles.");
			end if;
		
		end loop;
		
		wait for CLK_PERIOD;
		
		if pulse = '0' then
			report "Success: pulse held for the expected number of cycles.";
		else
			terminate_simulation("pulse stayed hight.");
		end if;
		
	end procedure;

begin

	DUV: entity work.timer
		generic map (data_width => 16)
		port map (
			-- inputs
			cen => cen, aclr => aclr, clk => clk, ch1 => ch1, 
			ocr => ocr,
			
			-- outputs
			uef => uef, ch1_pulse => ch1_pulse, cnt => count
		);
		
	clk <= not clk after CLK_PERIOD / 2;
	aclr <= '1', '0' after CLK_PERIOD;
	cen <= '1';
	ocr <= x"000a";
	ch1 <= x"0007";
	
	process 
		variable cycles: integer;
	begin
		
		wait until aclr = '0' and cen = '1';	
		
		cycles := 325;
		test_pulse_latency(ch1_pulse, cycles);
		
		cycles := 200;
		test_pulse_width(ch1_pulse, cycles);
		
		
		for i in 0 to 4 loop
		
			cycles := 350;
			test_pulse_latency(ch1_pulse, cycles);
			
			cycles := 200;
			test_pulse_width(ch1_pulse, cycles);
		
		end loop;
		
	end process;
	
end architecture;