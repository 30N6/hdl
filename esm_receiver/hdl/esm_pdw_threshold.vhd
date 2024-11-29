library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library esm_lib;
  use esm_lib.esm_pkg.all;

entity esm_pdw_threshold is
generic (
  DATA_WIDTH          : natural;
  CHANNEL_INDEX_WIDTH : natural;
  LATENCY             : natural
);
port (
  Clk                     : in  std_logic;

  Dwell_active            : in  std_logic;
  Dwell_threshold_shift   : in  unsigned(ESM_THRESHOLD_SHIFT_WIDTH - 1 downto 0);

  Input_ctrl              : in  channelizer_control_t;
  Input_data              : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  Input_power             : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Output_ctrl             : out channelizer_control_t;
  Output_data             : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  Output_power            : out unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  Output_threshold_value  : out unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  Output_threshold_valid  : out std_logic

);
end entity esm_pdw_threshold;

architecture rtl of esm_pdw_threshold is

  function is_power_of_2_minus_1(v : unsigned; min_value : natural) return unsigned is
    variable r : unsigned(clog2(v'length) - 1 downto 0);
  begin
    r := (others => '0');
    for i in clog2(min_value) to (v'length - 1) loop
      if to_integer(v) = (2**i - 1) then
        r := to_unsigned(i, r'length);
      end if;
    end loop;
    return r;
  end function;

  constant SAT_POWER_WIDTH        : natural := CHAN_POWER_WIDTH - 4;
  constant ACCUM_LENGTH_WIDTH     : natural := 20;
  constant ACCUM_WIDTH            : natural := SAT_POWER_WIDTH + ACCUM_LENGTH_WIDTH;
  constant MIN_THRESHOLD_LENGTH   : natural := 127;

  signal m_channel_accum_value    : unsigned_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0)(ACCUM_WIDTH - 1 downto 0);
  signal m_channel_accum_length   : unsigned_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0)(ACCUM_LENGTH_WIDTH - 1 downto 0);
  signal m_channel_average_value  : unsigned_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0)(SAT_POWER_WIDTH - 1 downto 0);
  signal m_channel_average_valid  : std_logic_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0);

  signal r_accum_wr_en            : std_logic;
  signal r_accum_wr_index         : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_accum_wr_value         : unsigned(ACCUM_WIDTH - 1 downto 0);
  signal r_accum_wr_length        : unsigned(ACCUM_LENGTH_WIDTH - 1 downto 0);

  signal r_average_wr_en          : std_logic;
  signal r_average_wr_index       : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_average_wr_data        : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r_average_wr_valid       : std_logic;

  signal r_clear_channel_index    : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0) := (others => '0');

  signal r_dwell_active           : std_logic;
  signal r_dwell_thresh_shift     : unsigned(ESM_THRESHOLD_SHIFT_WIDTH - 1 downto 0);

  signal r0_input_ctrl            : channelizer_control_t;
  signal r0_input_data            : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r0_input_power_sat       : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r0_channel_accum_value   : unsigned(ACCUM_WIDTH - 1 downto 0);
  signal r0_channel_accum_length  : unsigned(ACCUM_LENGTH_WIDTH - 1 downto 0);
  signal r0_channel_average_value : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r0_channel_average_valid : std_logic;

  signal r1_input_ctrl            : channelizer_control_t;
  signal r1_input_data            : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r1_input_power_sat       : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r1_channel_accum_value   : unsigned(ACCUM_WIDTH - 1 downto 0);
  signal r1_channel_accum_length  : unsigned(ACCUM_LENGTH_WIDTH - 1 downto 0);
  signal r1_channel_average_value : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r1_channel_average_valid : std_logic;

  signal r2_input_ctrl            : channelizer_control_t;
  signal r2_input_data            : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r2_input_power_sat       : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r2_channel_accum_value   : unsigned(ACCUM_WIDTH - 1 downto 0);
  signal r2_channel_accum_length  : unsigned(ACCUM_LENGTH_WIDTH - 1 downto 0);
  signal r2_channel_average_value : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r2_channel_average_valid : std_logic;
  signal r2_shift_count           : unsigned(clog2(ACCUM_LENGTH_WIDTH) - 1 downto 0);

  signal r3_input_ctrl            : channelizer_control_t;
  signal r3_input_data            : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r3_input_power_sat       : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r3_channel_accum_value   : unsigned(ACCUM_WIDTH - 1 downto 0);
  signal r3_channel_accum_length  : unsigned(ACCUM_LENGTH_WIDTH - 1 downto 0);
  signal r3_threshold_value       : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r3_threshold_valid       : std_logic;
  signal r3_new_average_value     : unsigned(ACCUM_WIDTH - 1 downto 0);
  signal r3_new_average_valid     : std_logic;

begin

  assert (LATENCY = 4)
    report "LATENCY expected to be 4."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_dwell_active        <= Dwell_active;
      r_dwell_thresh_shift  <= Dwell_threshold_shift;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_input_ctrl           <= Input_ctrl;
      r0_input_data           <= Input_data;

      if (or_reduce(Input_power(CHAN_POWER_WIDTH - 1 downto SAT_POWER_WIDTH)) = '1') then
        r0_input_power_sat    <= (others => '1');
      else
        r0_input_power_sat    <= Input_power(SAT_POWER_WIDTH - 1 downto 0);
      end if;

      r0_channel_accum_value    <= m_channel_accum_value(to_integer(Input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
      r0_channel_accum_length   <= m_channel_accum_length(to_integer(Input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
      r0_channel_average_value  <= m_channel_average_value(to_integer(Input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
      r0_channel_average_valid  <= m_channel_average_valid(to_integer(Input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_input_ctrl             <= r0_input_ctrl;
      r1_input_data             <= r0_input_data;
      r1_input_power_sat        <= r0_input_power_sat;

      r1_channel_accum_value    <= r0_channel_accum_value;
      r1_channel_accum_length   <= r0_channel_accum_length;
      r1_channel_average_value  <= r0_channel_average_value;
      r1_channel_average_valid  <= r0_channel_average_valid;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_input_ctrl             <= r1_input_ctrl;
      r2_input_data             <= r1_input_data;
      r2_input_power_sat        <= r1_input_power_sat;
      r2_channel_accum_value    <= r1_channel_accum_value + r1_input_power_sat;
      r2_channel_accum_length   <= r1_channel_accum_length + 1;
      r2_shift_count            <= is_power_of_2_minus_1(r1_channel_accum_length, MIN_THRESHOLD_LENGTH);
      r2_channel_average_value  <= r1_channel_average_value;
      r2_channel_average_valid  <= r1_channel_average_valid;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_input_ctrl       <= r2_input_ctrl;
      r3_input_data       <= r2_input_data;
      r3_input_power_sat  <= r2_input_power_sat;

      r3_channel_accum_length <= r2_channel_accum_length;
      if (r2_channel_accum_length = 0) then
        r3_channel_accum_value <= (others => '0');
      else
        r3_channel_accum_value <= r2_channel_accum_value;
      end if;

      r3_threshold_valid <= r2_channel_average_valid;
      if (r2_channel_average_value = 0) then
        r3_threshold_value <= shift_left(to_unsigned(1, SAT_POWER_WIDTH), to_integer(r_dwell_thresh_shift));
      else
        r3_threshold_value <= shift_left(r2_channel_average_value, to_integer(r_dwell_thresh_shift));
      end if;

      r3_new_average_value <= shift_right(r2_channel_accum_value, to_integer(r2_shift_count));
      r3_new_average_valid <= to_stdlogic(r2_shift_count > 0);
    end if;
  end process;

  Output_ctrl             <= r3_input_ctrl;
  Output_data             <= r3_input_data;
  Output_power            <= resize_up(r3_input_power_sat, CHAN_POWER_WIDTH);
  Output_threshold_value  <= resize_up(r3_threshold_value, CHAN_POWER_WIDTH);
  Output_threshold_valid  <= r3_threshold_valid;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_clear_channel_index <= r_clear_channel_index + 1;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_dwell_active = '0') then
        r_accum_wr_en     <= '1';
        r_accum_wr_index  <= r_clear_channel_index;
        r_accum_wr_value  <= (others => '0');
        r_accum_wr_length <= (others => '0');
      else
        r_accum_wr_en     <= r3_input_ctrl.valid;
        r_accum_wr_index  <= r3_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0);
        r_accum_wr_value  <= r3_channel_accum_value;
        r_accum_wr_length <= r3_channel_accum_length;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_accum_wr_en = '1') then
        m_channel_accum_value(to_integer(r_accum_wr_index))   <= r_accum_wr_value;
        m_channel_accum_length(to_integer(r_accum_wr_index))  <= r_accum_wr_length;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_dwell_active = '0') then
        r_average_wr_en     <= '1';
        r_average_wr_index  <= r_clear_channel_index;
        r_average_wr_data   <= (others => '-');
        r_average_wr_valid  <= '0';
      else
        r_average_wr_en     <= r3_input_ctrl.valid and r3_new_average_valid;
        r_average_wr_index  <= r3_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0);
        r_average_wr_data   <= r3_new_average_value(SAT_POWER_WIDTH - 1 downto 0);
        r_average_wr_valid  <= '1';
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_average_wr_en = '1') then
        m_channel_average_value(to_integer(r_average_wr_index)) <= r_average_wr_data;
        m_channel_average_valid(to_integer(r_average_wr_index)) <= r_average_wr_valid;
      end if;
    end if;
  end process;

end architecture rtl;
