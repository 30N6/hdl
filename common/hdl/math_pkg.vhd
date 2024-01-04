library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package math_pkg is

  function "abs"(v : signed) return unsigned;

end package math_pkg;

package body math_pkg is

  function "abs"(v : signed) return unsigned is
    variable r : signed(v'length downto 0);
  begin

    r := abs(resize(v, v'length + 1));
    return unsigned(r(v'length - 1 downto 0));
  end function;

end package body math_pkg;
