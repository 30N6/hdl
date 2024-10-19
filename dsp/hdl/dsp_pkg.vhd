library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

package dsp_pkg is

  constant FFT8_DATA_INDEX_WIDTH  : natural := clog2(8);
  constant FFT32_DATA_INDEX_WIDTH : natural := clog2(32);
  constant FFT64_DATA_INDEX_WIDTH : natural := clog2(64);
  constant FFT_TAG_WIDTH          : natural := 8;

  constant CHAN_POWER_WIDTH       : natural := 32;

  type fft_control_t is record
    valid       : std_logic;
    last        : std_logic;
    reverse     : std_logic;
    data_index  : unsigned(5 downto 0);
    tag         : std_logic_vector(FFT_TAG_WIDTH - 1 downto 0);
  end record;

  type fft_control_array_t is array (natural range <>) of fft_control_t;

  type channelizer_control_t is record
    valid       : std_logic;
    last        : std_logic;
    data_index  : unsigned(5 downto 0);
  end record;

  type channelizer_control_array_t is array (natural range <>) of channelizer_control_t;

  function invert_sign(v : signed; saturate : boolean) return signed;
  function int_to_signed_array(int_array : integer_array_t; output_length : natural; input_width : natural; output_width : natural) return signed_array_t;

end package dsp_pkg;

package body dsp_pkg is

  function invert_sign(v : signed; saturate : boolean) return signed is
    variable r      : signed(v'length - 1 downto 0);
    constant V_MAX  : signed(v'length - 1 downto 0) := ((v'length - 1) => '0', others => '1');
    constant V_MIN  : signed(v'length - 1 downto 0) := ((v'length - 1) => '1', others => '0');
  begin
    if (saturate and (v = V_MAX)) then
      r := V_MIN;
    else
      r := -v;
    end if;
    return r;
  end function;

  function int_to_signed_array(int_array : integer_array_t; output_length : natural; input_width : natural; output_width : natural) return signed_array_t is
    variable v_full_signed : signed(input_width - 1 downto 0);
    variable v_result : signed_array_t(0 to output_length - 1)(output_width - 1 downto 0);
  begin
    assert (output_width <= input_width)
      report "output_width expected to be less than or equal to the input_width."
      severity failure;

    for i in 0 to (output_length - 1) loop
      v_full_signed := to_signed(int_array(i), input_width);
      v_result(i)   := v_full_signed(input_width - 1 downto (input_width - output_width));
      --report "int_to_signed_array: i=" & integer'image(i) & " - " & integer'image(int_array(i)) & " " & to_hstring(v_full_signed) & " " & to_hstring(v_result(i));
    end loop;
    return v_result;
  end function;

end package body dsp_pkg;
