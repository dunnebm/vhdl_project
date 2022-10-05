-- Author: Brandon Dunne
-- Date: 9/26/22

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
	signal end_of_getx:   boolean;
	signal start_of_gety: boolean;
	signal end_of_gety:   boolean;
	
	procedure end_simulation(err_msg: string) is
	begin
		assert false report err_msg severity failure;
	end procedure;
	
	procedure assert_equal(a,b: std_logic; err_msg: string) is
	begin
		if a /= b then
			end_simulation(err_msg);
		end if;
	end procedure;
	
	procedure assert_equal(a,b: std_logic_vector; err_msg: string) is
	begin	
		if a /= b then
			end_simulation(err_msg);
		end if;	
	end procedure;
	
	procedure verify_init_command is
	begin
		
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
	
	
	-- Verifies the data retreival commands
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
			write <= '1';
			address <= CSR_ADDRESS;
			writedata <= (INIT_BIT => '1', others => '0');
			
			wait for CLOCK_PERIOD;
			
			assert_equal(adc_cs_n, '0', "adc_cs_n should be low.");
			write <= '0';
			
			wait until rising_edge(adc_dclk);
			
			verify_init_command;
		end procedure;
		
		procedure drive_penirq_transaction is
		begin
			-- trigger interrupt
			adc_penirq_n <= '0';
			
			wait for CLOCK_PERIOD;
			
			assert_equal(adc_cs_n, '0', "adc_cs_n should be low.");
			
			-- start getx transaction
			start_of_getx <= true;
			
			wait until rising_edge(clock);
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
		end procedure;
		
		procedure enable_penirq_interrupt is
		begin
			wait until falling_edge(clock);
			
			address <= CSR_ADDRESS;
			write <= '1';
			writedata(PENIRQ_ENABLE_BIT) <= '1';
			
			wait for CLOCK_PERIOD;
		end procedure;
		
		procedure check_if_irq_occurred is
		begin
			assert_equal(irq, '1', "irq should be high");
		end procedure;
		
	begin
		
		drive_initialization_transaction;
		
		check_if_initialized;
		
		drive_penirq_transaction;
		
		check_for_penirq_event;
		
		clear_penirq_event;
		
		check_if_irq_occurred;
		
		enable_penirq_interrupt;
		
		drive_penirq_transaction;
		
		check_if_irq_occurred;
		
		clear_penirq_event;
		
	end process;
	
	getx_transaction: process
	
		procedure getx is
		begin
			for i in 11 downto 0 loop
				adc_dout <= X_TEST_DATA(i);
				wait for SERIAL_CLOCK_PERIOD;
			end loop;
		end procedure;
	
	begin
	
		wait on start_of_getx'transaction;
		
		wait until rising_edge(adc_dclk);
		
		verify_command(GETX_COMMAND);
		
		-- waste one cycle before data retreival
		wait for SERIAL_CLOCK_PERIOD;
	
		getx;
		
		-- three cycles to complete transaction
		wait for 3*SERIAL_CLOCK_PERIOD;
		
		end_of_getx <= true;
	
	end process;
	
	
	gety_transaction: process
	
		procedure gety is
		begin
			for i in 11 downto 0 loop
				adc_dout <= Y_TEST_DATA(i);
				wait for SERIAL_CLOCK_PERIOD;
			end loop;
		end procedure;
		
	begin
	
		wait on start_of_gety'transaction;
		
		wait until rising_edge(adc_dclk);
		
		verify_command(GETY_COMMAND);
		
		-- waste one cycle before data retreival
		wait for SERIAL_CLOCK_PERIOD;
		
		gety;
		
		-- three cycles to complete transaction
		wait for 3*SERIAL_CLOCK_PERIOD;
		
		end_of_gety <= true;
	
	end process;
	
end architecture;