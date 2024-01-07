library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package common_pkg is

  function to_stdlogic(e : boolean) return std_logic;
  function clog2(v : natural) return natural;
  function clog2_min1bit(v : natural) return natural;
  function and_reduce(v : unsigned) return std_logic;
  function or_reduce(v : unsigned) return std_logic;
  function or_reduce(v : std_logic_vector) return std_logic;
  function resize_up(v : unsigned; n : natural) return unsigned;
  function shift_right(v : std_logic_vector; n : natural) return std_logic_vector;

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

  function clog2_min1bit(v : natural) return natural is
    variable r : natural;
  begin
    r := clog2(v);
    if (r < 1) then
      r := 1;
    end if;
    return r;
  end function;

  function and_reduce(v : unsigned) return std_logic is
    variable v_ones : unsigned(v'length - 1 downto 0);
  begin
    v_ones := (others => '1');
    return to_stdlogic(v = v_ones);
  end function;

  function or_reduce(v : unsigned) return std_logic is
  begin
    return to_stdlogic(v /= 0);
  end function;

  function or_reduce(v : std_logic_vector) return std_logic is
  begin
    return to_stdlogic(unsigned(v) /= 0);
  end function;

  function resize_up(v : unsigned; n : natural) return unsigned is
    variable r : unsigned(n - 1 downto 0);
  begin
    assert (n >= v'length)
      report "resize_up: attempting to size down"
      severity failure;
    r := resize(v, n);
    return r;
  end function;

  function shift_right(v : std_logic_vector; n : natural) return std_logic_vector is
  begin
    return std_logic_vector(shift_right(unsigned(v), n));
  end function;

end package body common_pkg;
