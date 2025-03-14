library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package common_pkg is

  type signed_array_t           is array (natural range <>) of signed;
  type unsigned_array_t         is array (natural range <>) of unsigned;
  type std_logic_vector_array_t is array (natural range <>) of std_logic_vector;
  type std_logic_array_t        is array (natural range <>) of std_logic;
  type natural_array_t          is array (natural range <>) of natural;
  type integer_array_t          is array (natural range <>) of integer;

  function to_stdlogic(e : boolean) return std_logic;
  function clog2(v : natural) return natural;
  function clog2_min1bit(v : natural) return natural;
  function and_reduce(v : unsigned) return std_logic;
  function and_reduce(v : signed) return std_logic;
  function and_reduce(v : std_logic_vector) return std_logic;
  function or_reduce(v : unsigned) return std_logic;
  function or_reduce(v : signed) return std_logic;
  function or_reduce(v : std_logic_vector) return std_logic;
  function resize_up(v : signed; n : natural) return signed;
  function resize_up(v : unsigned; n : natural) return unsigned;
  function resize_up(v : std_logic_vector; n : natural) return std_logic_vector;
  function shift_right(v : std_logic_vector; n : natural) return std_logic_vector;
  function byteswap(v : std_logic_vector; w : natural) return std_logic_vector;
  function byteswap(v : unsigned; w : natural) return unsigned;
  function first_bit_index(v : std_logic_vector) return unsigned;
  function count_ones(v : std_logic_vector) return unsigned;

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

  function and_reduce(v : signed) return std_logic is
  begin
    return and_reduce(unsigned(v));
  end function;

  function and_reduce(v : std_logic_vector) return std_logic is
  begin
    return and_reduce(unsigned(v));
  end function;

  function or_reduce(v : unsigned) return std_logic is
  begin
    return to_stdlogic(v /= 0);
  end function;

  function or_reduce(v : signed) return std_logic is
  begin
    return to_stdlogic(v /= 0);
  end function;

  function or_reduce(v : std_logic_vector) return std_logic is
  begin
    return to_stdlogic(unsigned(v) /= 0);
  end function;

  function resize_up(v : signed; n : natural) return signed is
    variable r : signed(n - 1 downto 0);
  begin
    assert (n >= v'length)
      report "resize_up: attempting to size down"
      severity failure;
    r := resize(v, n);
    return r;
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

  function resize_up(v : std_logic_vector; n : natural) return std_logic_vector is
  begin
    return std_logic_vector(resize_up(unsigned(v), n));
  end function;

  function shift_right(v : std_logic_vector; n : natural) return std_logic_vector is
  begin
    return std_logic_vector(shift_right(unsigned(v), n));
  end function;

  function byteswap(v : std_logic_vector; w : natural) return std_logic_vector is
    variable r : std_logic_vector(v'length - 1 downto 0);
    variable j : natural;
  begin
    assert (v'length mod w = 0)
      report "input length must be divisible by w."
      severity failure;

    for i in 0 to (r'length / w - 1) loop
      j := v'length / w - i - 1;
      r(w * (i + 1) - 1 downto w * i) := v(w * (j + 1) - 1 downto w * j);
    end loop;
    return r;
  end function;

  function byteswap(v : unsigned; w : natural) return unsigned is
    variable r : unsigned(v'length - 1 downto 0);
  begin
    r := unsigned(byteswap(std_logic_vector(v), w));
    return r;
  end function;

  function first_bit_index(v : std_logic_vector) return unsigned is
    variable r : unsigned(clog2(v'length) - 1 downto 0);
  begin
    r := (others => '0');

    for i in 0 to (v'length - 1) loop
      if (v(i) = '1') then
        r := to_unsigned(i, r'length);
        exit;
      end if;
    end loop;

    return r;
  end function;

  function count_ones(v : std_logic_vector) return unsigned is
    variable r : unsigned(clog2(v'length + 1) - 1 downto 0);
    variable c : natural range 0 to v'length;
  begin
    c := 0;
    for i in 0 to (v'length - 1) loop
      if (v(i) = '1') then
        c := c + 1;
      end if;
    end loop;

    r := to_unsigned(c, r'length);
    return r;
  end function;

end package body common_pkg;
