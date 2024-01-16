library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

package dsp_pkg is

  function invert_sign(v : signed) return signed;
  function int_to_signed_array(v : integer_array_t; input_width : natural; output_width : natural) return signed_array_t;

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

  function int_to_signed_array(int_array : integer_array_t; input_width : natural; output_width : natural) return signed_array_t is
    variable v_full_signed : signed(input_width - 1 downto 0);
    variable v_result : signed_array_t(int_array'length - 1 downto 0)(output_width - 1 downto 0);
  begin
    assert (output_width >= input_width)
      report "output_width expected to be greater than or equal to the input_width."
      severity failure;

    for i in 0 to (int_array'length - 1) loop
      v_full_signed := to_signed(int_array(i), input_width);
      v_result(i)   := v_full_signed(input_width - 1 downto (input_width - output_width));
    end loop;
    return v_result;
  end function;

end package body dsp_pkg;
