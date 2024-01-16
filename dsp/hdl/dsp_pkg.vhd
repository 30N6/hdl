library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package dsp_pkg is

  function invert_sign(v : signed) return signed;

end package dsp_pkg;

package body dsp_pkg is

  function invert_sign(v : signed) return signed is
    variable r      : signed(v'length - 1 downto 0);
    constant V_MAX  : signed(v'length - 1 downto 0) := ((v'length - 1) => 0, others => '1');
    constant V_MIN  : signed(v'length - 1 downto 0) := ((v'length - 1) => 1, others => '0');
  begin
    if (v = V_MAX) then
      r := V_MIN;
    else
      r := -v;
    end if;
    return r;
  end function;

end package body dsp_pkg;
