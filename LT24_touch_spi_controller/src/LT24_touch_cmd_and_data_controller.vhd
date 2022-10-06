library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library component_lib;
use component_lib.my_pkg.all;

entity LT24_touch_cmd_and_data_controller is
	port (
		enable: in std_logic;
		dclk: in std_logic;
		init_seq: in std_logic;
		finished: out std_logic;
		send_start_bit: out std_logic;
		shift_cmd_register: out std_logic;
		shift_data_register: out std_logic;
		cmd_select: out std_logic_vector(1 downto 0);
		finished_sending_xdata: out std_logic;
		finished_sending_ydata: out std_logic;
		
		count_sim: out std_logic_vector(5 downto 0)
	);
end entity;

architecture rtl of LT24_touch_cmd_and_data_controller is

	signal enable_n: std_logic;
	signal count: std_logic_vector(5 downto 0);
	signal ocr_val: std_logic_vector(5 downto 0);
	
	signal start_of_first_transaction: std_logic;
	signal start_of_second_transaction: std_logic;
	
	signal first_cmd_interval: std_logic;
	signal second_cmd_interval: std_logic;
	signal first_data_interval: std_logic;
	signal second_data_interval: std_logic;
	
	signal init_seq_finished: std_logic;
	signal penirq_seq_finished: std_logic;
	signal seq_finished: std_logic;
	
	signal cmd_select_select: std_logic_vector(2 downto 0);
	
begin
	count_sim <= count;

	enable_n <= not enable;

	start_of_first_transaction  <= (count = std_logic_vector(to_unsigned(1, count'length)));
	
	start_of_second_transaction <= (count = std_logic_vector(to_unsigned(16, count'length)));
	
	first_cmd_interval          <= (count > std_logic_vector(to_unsigned(1, count'length))) and
	                               (count < std_logic_vector(to_unsigned(9, count'length)));
	
	second_cmd_interval         <= (count > std_logic_vector(to_unsigned(16, count'length))) and
	                               (count < std_logic_vector(to_unsigned(24, count'length)));
	
	first_data_interval         <= (count > std_logic_vector(to_unsigned(9, count'length))) and
	                               (count < std_logic_vector(to_unsigned(22, count'length)));
	
	second_data_interval        <= (count > std_logic_vector(to_unsigned(24, count'length))) and
	                               (count < std_logic_vector(to_unsigned(37, count'length)));
									
	init_seq_finished           <= (count = std_logic_vector(to_unsigned(20, count'length)));
	
	penirq_seq_finished         <= (count = std_logic_vector(to_unsigned(39, count'length)));
	
	
	import_timer: entity component_lib.counter
		generic map (DATA_WIDTH => 6)
		port map (
			cen   => enable,
			clk   => dclk,
			sclr  => '0',
			aclr  => enable_n,
			count => count
		);
	
	finished <= enable and seq_finished;
	with init_seq select seq_finished <=
		init_seq_finished   when '1',
		penirq_seq_finished when '0',
		'0'                 when others;
		
	send_start_bit <= start_of_first_transaction or
	                  (start_of_second_transaction and not init_seq);
		
	cmd_select_select <= (
		2 => start_of_second_transaction, 
		1 => start_of_first_transaction, 
		0 => init_seq);
		
	with cmd_select_select select cmd_select <=
		b"00" when b"011",
		b"01" when b"010",
		b"10" when b"100",
		b"11" when others;
					  
	shift_cmd_register  <= (first_cmd_interval or (second_cmd_interval and not init_seq)) and enable;	
	shift_data_register <= ((first_data_interval or second_data_interval) and not init_seq) and enable;
				 
	finished_sending_xdata <= (count = std_logic_vector(to_unsigned(22, count'length))) and not init_seq;
	finished_sending_ydata <= (count = std_logic_vector(to_unsigned(37, count'length))) and not init_seq;

end architecture;