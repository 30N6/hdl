library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package common_pkg is
  function to_stdlogic(e : boolean) return std_logic;
  function clog2(v : natural) return natural;
end package common_pkg;

package body common_pkg is
  function to_stdlogic(e : boolean) return std_logic is
  begin
    if ( e = true ) then
      return '1';
    else
      return '0';
    end if;
  end function;

  function clog2(v : natural) return natural is
    variable v_result : natural;
    variable v_max    : natural;
  begin
    if (v < 2) then
      return 0;
    end if;

    v_result := 1;
    v_max := 2;
    while (v_max < v) loop
      v_result  := v_result + 1;
      v_max     := v_max * 2;
    end loop;

    return v_result;
  end function;

end package body common_pkg;
