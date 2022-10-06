library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

package my_pkg is

	function "="(L,R: std_logic_vector) return std_logic;
	function ">"(L,R: std_logic_vector) return std_logic;
	function "<"(L,R: std_logic_vector) return std_logic;

end package;

package body my_pkg is

	function "="(L,R: std_logic_vector) return std_logic is
	begin
		assert L'length = R'length
		report "L'length != R'length"
		severity error;
		
		return and_reduce(L xnor R);
	end function;
	
	function ">"(L, R: std_logic_vector) return std_logic is
		variable x: std_logic_vector(L'length downto 0);
		variable y: std_logic_vector(R'length downto 0);
		variable z: std_logic_vector(L'length downto 0);
	begin
		assert L'length = R'length
		report "L'length != R'length"
		severity error;
		
		x(L'length) := '0';
		x(L'length - 1 downto 0) := L;
		y(R'length) := '0';
		y(R'length - 1 downto 0) := R;
		z := std_logic_vector(signed(y) - signed(x));
		return z(L'length);

	end function;
	
	function "<"(L,R: std_logic_vector) return std_logic is
	begin
		return R > L;
	end function;

end package body;