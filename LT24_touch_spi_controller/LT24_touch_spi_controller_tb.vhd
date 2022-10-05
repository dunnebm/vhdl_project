-- Author: Brandon Dunne
-- Date: 9/26/22

-- Test the initialization sequence that the 
-- LT24_touch_spi_controller must do to enable 
-- the penirq on the LT24 device. Next, simulate the
-- LT24 device triggering the penirq interrupt and verify
-- that the X and Y data registers are updated correctly.
-- Plus, verify that the penirq_event bit goes high after
-- the registers have been updated and an irq is not sent
-- to the processor because the penirq_enable bit is low.
-- Finally, set the penirq_enable bit, then trigger another
-- interrupt and perform the same verification except this time
-- verify an irq was sent to the processor.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LT24_touch_spi_controller_tb is
end entity;

architecture testbench of LT24_touch_spi_controller_tb is

	signal address: std_logic_vector(1 downto 0);
	signal clock: std_logic := '0';
	signal reset: std_logic;
	signal irq: std_logic;
	signal read: std_logic;
	signal write: std_logic;
	signal writedata: std_logic_vector(15 downto 0);
	signal readdata: std_logic_vector(15 downto 0);
	
	constant INIT_BIT: integer := 0;
	constant PENIRQ_ENABLE_BIT: integer := 1;
	constant INITIALIZED_BIT: integer := 2;
	constant PENIRQ_EVENT_BIT: integer := 3;
	
	signal adc_din: std_logic;
	signal adc_penirq_n: std_logic;
	signal adc_dout: std_logic;
	signal adc_cs_n: std_logic;
	signal adc_dclk: std_logic;
	
	constant CLOCK_PERIOD: time := 10ns;
	constant SERIAL_CLOCK_PERIOD: time := 500ns;
	
	constant START: std_logic := '1';
	constant INIT_COMMAND: std_logic_vector(6 downto 0) := "0000100";
	constant GETX_COMMAND: std_logic_vector(6 downto 0) := "0010100";
	constant GETY_COMMAND: std_logic_vector(6 downto 0) := "1010100";
	
	constant X_TEST_DATA: std_logic_vector(15 downto 0) := x"0ABC";
	constant Y_TEST_DATA: std_logic_vector(15 downto 0) := x"0CBA";
	
	constant CSR_ADDRESS: std_logic_vector(1 downto 0) := b"00";
	constant XDATA_ADDRESS: std_logic_vector(1 downto 0) := b"01";
	constant YDATA_ADDRESS: std_logic_vector(1 downto 0) := b"10";
	
	-- for communication between processes
	signal start_of_getx: boolean;
	signal start_of_xdata_retrieval: boolean;
	signal end_of_getx:   boolean;
	signal start_of_gety: boolean;
	signal start_of_ydata_retrieval: boolean;
	signal end_of_gety:   boolean;
	
	procedure assert_equal(a,b: std_logic; err_msg: string) is
	begin
		assert a = b report err_msg severity failure;
	end procedure;
	
	procedure assert_equal(a,b: std_logic_vector; err_msg: string) is
	begin	
		assert a = b report err_msg severity failure;
	end procedure;
	
begin

	DUV: entity work.LT24_touch_spi_controller
		port map (
			-- Altera Avalon memory-mapped ports
			address => address,
			clock => clock,
			reset => reset,
			irq => irq,
			write => write,
			read => read,
			writedata => writedata,
			readdata => readdata,
			
			-- LT24 touchscreen SPI ports
			adc_din => adc_din,
			adc_penirq_n => adc_penirq_n,
			adc_dout => adc_dout,
			adc_cs_n => adc_cs_n,
			adc_dclk => adc_dclk
		);
	
	clock <= not clock after CLOCK_PERIOD / 2;
	reset <= '1', '0' after CLOCK_PERIOD;
	
	
	driver: process
		procedure drive_initialization_transaction  is
		begin
			wait until falling_edge(reset);
			
			write <= '1';
			address <= CSR_ADDRESS;
			
			-- initialize the controller
			writedata <= (INIT_BIT => '1', others => '0');
			
			wait for CLOCK_PERIOD;
			
			assert_equal(adc_cs_n, '0', "adc_cs_n should be low.");
			write <= '0';
			
			--** Verify init command is sent correctly throught adc_din **--
			
			wait until rising_edge(adc_dclk);
			
			wait for SERIAL_CLOCK_PERIOD;	
			assert_equal(adc_din, START, "Start bit was not sent.");
			
			for i in INIT_COMMAND'range loop	
				wait for SERIAL_CLOCK_PERIOD;	
				assert_equal(adc_din, INIT_COMMAND(i), "Unexpected initialization command.");
			end loop;
			
			-- 1 delay cycle + 8 data cycles + 3 trailing zeros cycles
			-- need to be wasted in order to complete the initialization phase.
			wait for 12*SERIAL_CLOCK_PERIOD;	
		end procedure;
		
		procedure drive_penirq_transaction is
		begin
			-- trigger interrupt
			adc_penirq_n <= '0';
			
			wait until falling_edge(clock);
			wait for CLOCK_PERIOD;
			
			adc_penirq_n <= '1';
			
			assert_equal(adc_cs_n, '0', "adc_cs_n should be low.");
			
			wait until falling_edge(adc_dclk);
			
			-- start getx transaction
			start_of_getx <= true;
			
			wait for 15*SERIAL_CLOCK_PERIOD;
			
			-- start gety transaction
			start_of_gety <= true;
			
			-- wait for getx transaction to finish
			wait on end_of_getx'transaction;
			
			wait until falling_edge(clock);
			
			address <= XDATA_ADDRESS;
			read <= '1';
			
			wait for CLOCK_PERIOD;
			
			assert_equal(readdata, X_TEST_DATA, "xdata does not equal test data.");
			
			-- wait for gety transaction to finish
			wait on end_of_gety'transaction;
			
			wait until falling_edge(clock);
			
			address <= YDATA_ADDRESS;
			read <= '1';
			
			wait for CLOCK_PERIOD;
			
			assert_equal(readdata, Y_TEST_DATA, "ydata does not equal test data.");
		end procedure;
		
		procedure check_if_initialized is
		begin
			wait until falling_edge(clock);
			
			address <= CSR_ADDRESS;
			read <= '1';
			
			wait for CLOCK_PERIOD;
		
			assert_equal(readdata(INITIALIZED_BIT), '1', "Controller should be initialized.");
		end procedure;
		
		procedure enable_penirq is
		begin
			wait until falling_edge(clock);
			
			address <= CSR_ADDRESS;
			write <= '1';
			writedata(PENIRQ_ENABLE_BIT) <= '1';
			
			wait for CLOCK_PERIOD;	
			
			write <= '0';
		end procedure;
		
		procedure check_for_penirq_event is
		begin
			wait until falling_edge(clock);
			
			address <= CSR_ADDRESS;
			read <= '1';
			
			wait for CLOCK_PERIOD;
			
			assert_equal(readdata(PENIRQ_EVENT_BIT), '1', "Penirq event never occurred.");
		end procedure;
		
		procedure clear_penirq_event is
		begin
			wait until falling_edge(clock);
			
			address <= CSR_ADDRESS;
			write <= '1';
			writedata(PENIRQ_EVENT_BIT) <= '0';
			
			wait for CLOCK_PERIOD;
			
			write <= '0';
		end procedure;
		
		procedure enable_penirq_interrupt is
		begin
			wait until falling_edge(clock);
			
			address <= CSR_ADDRESS;
			write <= '1';
			writedata(PENIRQ_ENABLE_BIT) <= '1';
			
			wait for CLOCK_PERIOD;
			
			write <= '0';
		end procedure;
		
		procedure check_if_irq_occurred is
		begin
		
			wait until falling_edge(clock);
			
			address <= CSR_ADDRESS;
			read <= '1';
			
			wait for CLOCK_PERIOD;
			
			if readdata(PENIRQ_ENABLE_BIT) = '1' then
				assert_equal(irq, '1', "irq should be high");
			else
				assert_equal(irq, '0', "irq should be low");
			end if;
		end procedure;
		
	begin
		
		drive_initialization_transaction;
		
		check_if_initialized;
		
		report "Initialization was completed successfully.";
		
		drive_penirq_transaction;
		
		check_for_penirq_event;
		
		report "Penirq event did occur as expected.";
		
		check_if_irq_occurred;
		
		report "Irq was not sent, which was expected.";
		
		enable_penirq_interrupt;
		
		drive_penirq_transaction;
		
		check_if_irq_occurred;
		
		report "Irq was sent, which was expected.";
		
		clear_penirq_event;
		
		report "All test passed.";
		
		wait;
		
	end process;
	
	
	penirq_transaction_verify_cmds: process
	
		procedure verify_command(constant cmd: std_logic_vector) is
		begin
			wait for SERIAL_CLOCK_PERIOD;
			assert_equal(adc_din, START, "Start bit was not sent.");
		
			for i in cmd'range loop
				wait for SERIAL_CLOCK_PERIOD;
				assert_equal(adc_din, cmd(i), "Unexpected command.");
			end loop;
		end procedure;
		
	begin
	
		wait on start_of_getx'transaction;
		
		verify_command(GETX_COMMAND);
		
		wait for SERIAL_CLOCK_PERIOD;
		
		start_of_xdata_retrieval <= true;
		
		wait on start_of_gety'transaction;
		
		verify_command(GETY_COMMAND);
		
		wait for SERIAL_CLOCK_PERIOD;
		
		start_of_ydata_retrieval <= true;
		
	end process;
	
	
	penirq_transaction_send_test_data: process
	
		procedure send_test_data(test_data: std_logic_vector) is
		begin
			for i in 11 downto 0 loop
				adc_dout <= test_data(i);
				wait for SERIAL_CLOCK_PERIOD;
			end loop;
		end procedure;	
		
	begin
	
		wait on start_of_xdata_retrieval'transaction;
		
		send_test_data(X_TEST_DATA);
		
		wait for 3*SERIAL_CLOCK_PERIOD;
		
		end_of_getx <= true;
		
		wait on start_of_ydata_retrieval'transaction;
		
		send_test_data(Y_TEST_DATA);
		
		wait for 3*SERIAL_CLOCK_PERIOD;
		
		end_of_gety <= true;
	
	end process;
	
end architecture;