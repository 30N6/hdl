library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package common_pkg is
  function to_stdlogic(e : boolean) return std_logic;
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

end package body common_pkg;