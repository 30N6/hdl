library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

entity mag_approximation is
generic (
  DATA_WIDTH    : natural;
  LATENCY       : natural
);
port (
  Clk           : in  std_logic;

  Input_valid   : in  std_logic;
  Input_i       : in  signed(DATA_WIDTH - 1 downto 0);
  Input_q       : in  signed(DATA_WIDTH - 1 downto 0);

  Output_valid  : out std_logic;
  Output_data   : out unsigned(DATA_WIDTH - 1 downto 0)
);
end entity mag_approximation;

architecture rtl of mag_approximation is

  constant MAX_UNSIGNED_IQ  : unsigned(DATA_WIDTH - 2 downto 0) := (others => '1');
  constant MIN_VALUE_FACTOR : unsigned(1 downto 0) := to_unsigned(3, 2);

  signal w_abs_i_raw        : unsigned(DATA_WIDTH - 1 downto 0);
  signal w_abs_q_raw        : unsigned(DATA_WIDTH - 1 downto 0);
  signal w_abs_i_clamped    : unsigned(DATA_WIDTH - 2 downto 0);
  signal w_abs_q_clamped    : unsigned(DATA_WIDTH - 2 downto 0);

  signal w_max_value        : unsigned(DATA_WIDTH - 2 downto 0);
  signal w_min_value        : unsigned(DATA_WIDTH - 2 downto 0);

  signal w_min_value_x3     : unsigned(DATA_WIDTH downto 0);
  signal w_min_value_x0_375 : unsigned(DATA_WIDTH - 3 downto 0);

  signal w_output_valid     : std_logic;
  signal w_output_data      : unsigned(DATA_WIDTH - 1 downto 0);

begin

  w_abs_i_raw <= abs(Input_i);
  w_abs_q_raw <= abs(Input_q);

  process(all)
  begin
    if (w_abs_i_raw > MAX_UNSIGNED_IQ) then
      w_abs_i_clamped <= (others => '1');
    else
      w_abs_i_clamped <= w_abs_i_raw(DATA_WIDTH - 2 downto 0);
    end if;

    if (w_abs_q_raw > MAX_UNSIGNED_IQ) then
      w_abs_q_clamped <= (others => '1');
    else
      w_abs_q_clamped <= w_abs_q_raw(DATA_WIDTH - 2 downto 0);
    end if;
  end process;

  process(all)
  begin
    if (w_abs_i_clamped > w_abs_q_clamped) then
      w_max_value <= w_abs_i_clamped;
      w_min_value <= w_abs_q_clamped;
    else
      w_max_value <= w_abs_q_clamped;
      w_min_value <= w_abs_i_clamped;
    end if;
  end process;

  w_min_value_x3      <= MIN_VALUE_FACTOR * w_min_value;
  w_min_value_x0_375  <= w_min_value_x3(DATA_WIDTH downto 3);

  w_output_valid      <= Input_valid;
  w_output_data       <= ('0' & w_max_value) + ("00" & w_min_value_x0_375);

  g_output : if (LATENCY = 1) generate
    process(Clk)
    begin
      if rising_edge(Clk) then
        Output_valid  <= w_output_valid;
        Output_data   <= w_output_data;
      end if;
    end process;
  elsif (LATENCY = 0) generate
    Output_valid  <= w_output_valid;
    Output_data   <= w_output_data;
  else generate
    assert (false)
      report "LATENCY must be 0 or 1."
      severity failure;
  end generate g_output;

end architecture rtl;
