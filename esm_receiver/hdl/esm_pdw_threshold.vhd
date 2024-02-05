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
  CHANNEL_INDEX_WIDTH : natural
);
port (
  Clk                     : in  std_logic;

  Dwell_active            : in  std_logic;
  Dwell_threshold_factor  : in  unsigned(ESM_THRESHOLD_FACTOR_WIDTH - 1 downto 0);

  Input_ctrl              : in  channelizer_control_t;
  Input_data              : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  Input_pwr               : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Output_ctrl             : out channelizer_control_t;
  Output_data             : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  Output_pwr              : out unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  Output_threshold        : out unsigned(CHAN_POWER_WIDTH - 1 downto 0)
);
end entity esm_pdw_threshold;

architecture rtl of esm_pdw_threshold is

  constant POWER_SCALED_WIDTH   : natural := CHAN_POWER_WIDTH - ESM_THRESHOLD_FILTER_FACTOR;
  constant THRESHOLD_RAW_WIDTH  : natural := POWER_SCALED_WIDTH + ESM_THRESHOLD_FACTOR_WIDTH;

  signal m_channel_accum        : unsigned_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0)(CHAN_POWER_WIDTH - 1 downto 0);
  signal w_accum_wr_en          : std_logic;
  signal w_accum_wr_index       : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_accum_wr_data        : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r_clear_index          : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0) := (others => '0');

  signal r_dwell_active         : std_logic;
  signal r_dwell_thresh_fac     : unsigned(ESM_THRESHOLD_FACTOR_WIDTH - 1 downto 0);

  signal r0_input_ctrl          : channelizer_control_t;
  signal r0_input_data          : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r0_input_pwr           : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r0_input_pwr_scaled    : unsigned(POWER_SCALED_WIDTH - 1 downto 0);
  signal r0_accum               : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal r1_input_ctrl          : channelizer_control_t;
  signal r1_input_data          : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r1_input_pwr           : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r1_input_pwr_scaled    : unsigned(POWER_SCALED_WIDTH - 1 downto 0);
  signal r1_accum               : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal r2_input_ctrl          : channelizer_control_t;
  signal r2_input_data          : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r2_input_pwr           : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r2_input_pwr_scaled    : unsigned(POWER_SCALED_WIDTH - 1 downto 0);
  signal r2_accum_scaled        : unsigned(POWER_SCALED_WIDTH - 1 downto 0);
  signal r2_accum_feedback      : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal r3_input_ctrl          : channelizer_control_t;
  signal r3_input_data          : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r3_input_pwr           : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r3_accum_next          : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r3_threshold           : unsigned(THRESHOLD_RAW_WIDTH - 1 downto 0);

  signal r4_input_ctrl          : channelizer_control_t;
  signal r4_input_data          : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r4_input_pwr           : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r4_threshold           : unsigned(THRESHOLD_RAW_WIDTH - 1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_dwell_active      <= Dwell_active;
      r_dwell_thresh_fac  <= Dwell_threshold_factor;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_input_ctrl <= Input_ctrl;
      r0_input_data <= Input_data;
      r0_input_pwr  <= Input_pwr;

      r0_input_pwr_scaled <= Input_pwr(CHAN_POWER_WIDTH - 1 downto ESM_THRESHOLD_FILTER_FACTOR);
      if (or_reduce(Input_pwr(CHAN_POWER_WIDTH - 1 downto ESM_THRESHOLD_FILTER_FACTOR)) = '0') then
        r0_input_pwr_scaled(0) <= '1';  -- round up for small signals
      end if

      r0_accum <= m_channel_accum(to_integer(Input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_input_ctrl       <= r0_input_ctrl;
      r1_input_data       <= r0_input_data;
      r1_input_pwr        <= r0_input_pwr;
      r1_input_pwr_scaled <= r0_input_pwr_scaled;
      r1_accum            <= r0_accum;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_input_ctrl       <= r1_input_ctrl;
      r2_input_data       <= r1_input_data;
      r2_input_pwr        <= r1_input_pwr;
      r2_input_pwr_scaled <= r1_input_pwr_scaled;
      r2_accum_scaled     <= r1_accum(CHAN_POWER_WIDTH - 1 downto ESM_THRESHOLD_FILTER_FACTOR);
      r2_accum_feedback   <= r1_accum - r1_accum(CHAN_POWER_WIDTH - 1 downto ESM_THRESHOLD_FILTER_FACTOR);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_input_ctrl <= r2_input_ctrl;
      r3_input_data <= r2_input_data;
      r3_input_pwr  <= r2_input_pwr;
      r3_accum_next <= r2_accum_feedback + r2_input_pwr_scaled;
      r3_threshold  <= r2_accum_scaled * r_dwell_thresh_fac;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r4_input_ctrl <= r3_input_ctrl;
      r4_input_data <= r3_input_data;
      r4_input_pwr  <= r3_input_pwr;
      r4_threshold  <= r3_threshold;
    end if;
  end process;

  Output_ctrl      <= r4_input_ctrl;
  Output_data      <= r4_input_data;
  Output_pwr       <= r4_input_pwr;
  Output_threshold <= resize_up(r4_threshold(THRESHOLD_RAW_WIDTH - 1 downto ESM_THRESHOLD_FRAC_WIDTH), CHAN_POWER_WIDTH);

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_clear_index <= r_clear_index + 1;
    end if;
  end process;

  process(all)
  begin
    if (r_dwell_active = '0') then
      w_accum_wr_en     <= '1';
      w_accum_wr_index  <= r_clear_index;
      w_accum_wr_data   <= (others => '0');
    else
      w_accum_wr_en     <= r3_input_ctrl.valid;
      w_accum_wr_index  <= r3_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0);
      w_accum_wr_data   <= r3_accum_next;
    end if;
  end

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_accum_wr_en = '1') then
        m_channel_accum(to_integer(w_accum_wr_index)) <= w_accum_wr_data;
      end if;
    end if;
  end process;

end architecture rtl;
