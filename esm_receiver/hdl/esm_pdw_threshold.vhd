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

  constant FILTER_LENGTH        : natural := 32;
  constant COMB_INDEX_WIDTH     : natural := CHANNEL_INDEX_WIDTH + clog2(FILTER_LENGTH);

  constant SAT_POWER_WIDTH      : natural := CHAN_POWER_WIDTH - 4;
  constant INTEGRATOR_WIDTH     : natural := SAT_POWER_WIDTH + clog2(FILTER_LENGTH);

  signal m_channel_integrator   : unsigned_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0)(INTEGRATOR_WIDTH - 1 downto 0);
  signal m_channel_comb_data    : unsigned_array_t(2**COMB_INDEX_WIDTH - 1 downto 0)(INTEGRATOR_WIDTH - 1 downto 0);
  signal m_channel_comb_index   : unsigned_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0)(clog2(FILTER_LENGTH) - 1 downto 0);
  signal m_channel_comb_valid   : std_logic_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0);

  signal w_integrator_wr_en     : std_logic;
  signal w_integrator_wr_index  : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_integrator_wr_data   : unsigned(INTEGRATOR_WIDTH - 1 downto 0);
  signal w_comb_wr_index        : unsigned(COMB_INDEX_WIDTH - 1 downto 0);
  signal w_comb_index_wr_data   : unsigned(clog2(FILTER_LENGTH) - 1 downto 0);
  signal w_comb_valid_wr_data   : std_logic;
  signal r_clear_channel_index  : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal r_clear_comb_index     : unsigned(COMB_INDEX_WIDTH - 1 downto 0) := (others => '0');

  signal r_dwell_active         : std_logic;
  signal r_dwell_thresh_shift   : unsigned(ESM_THRESHOLD_SHIFT_WIDTH - 1 downto 0);

  signal r0_input_ctrl          : channelizer_control_t;
  signal r0_input_data          : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r0_input_pwr_sat       : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r0_integrated_pwr      : unsigned(INTEGRATOR_WIDTH - 1 downto 0);
  signal r0_comb_rd_index       : unsigned(clog2(FILTER_LENGTH) - 1 downto 0);
  signal r0_comb_rd_valid       : std_logic;

  signal r1_input_ctrl          : channelizer_control_t;
  signal r1_input_data          : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r1_input_pwr_sat       : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r1_integrated_pwr      : unsigned(INTEGRATOR_WIDTH - 1 downto 0);
  signal r1_comb_pwr            : unsigned(INTEGRATOR_WIDTH - 1 downto 0);
  signal r1_comb_rd_index       : unsigned(clog2(FILTER_LENGTH) - 1 downto 0);
  signal r1_comb_rd_valid       : std_logic;

  signal r2_input_ctrl          : channelizer_control_t;
  signal r2_input_data          : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r2_input_pwr_sat       : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r2_integrator_sum      : unsigned(INTEGRATOR_WIDTH - 1 downto 0);
  signal r2_comb_pwr            : unsigned(INTEGRATOR_WIDTH - 1 downto 0);
  signal r2_comb_rd_index       : unsigned(clog2(FILTER_LENGTH) - 1 downto 0);
  signal r2_comb_rd_valid       : std_logic;

  signal r3_input_ctrl          : channelizer_control_t;
  signal r3_input_data          : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r3_input_pwr_sat       : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r3_comb_diff           : unsigned(INTEGRATOR_WIDTH - 1 downto 0);
  signal r3_comb_rd_valid       : std_logic;

  signal w3_threshold_scaled    : unsigned(INTEGRATOR_WIDTH - 1 downto 0);

  signal r4_input_ctrl          : channelizer_control_t;
  signal r4_input_data          : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r4_input_pwr_sat       : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r4_threshold_value     : unsigned(SAT_POWER_WIDTH - 1 downto 0);
  signal r4_threshold_valid     : std_logic;

begin

  assert (LATENCY = 5)
    report "LATENCY expected to be 5."
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
      r0_input_ctrl       <= Input_ctrl;
      r0_input_data       <= Input_data;

      if (or_reduce(Input_power(CHAN_POWER_WIDTH - 1 downto SAT_POWER_WIDTH)) = '1') then
        r0_input_pwr_sat  <= (others => '1');
      else
        r0_input_pwr_sat  <= Input_power(SAT_POWER_WIDTH - 1 downto 0);
      end if;

      r0_integrated_pwr   <= m_channel_integrator(to_integer(Input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
      r0_comb_rd_index    <= m_channel_comb_index(to_integer(Input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
      r0_comb_rd_valid    <= m_channel_comb_valid(to_integer(Input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_input_ctrl     <= r0_input_ctrl;
      r1_input_data     <= r0_input_data;
      r1_input_pwr_sat  <= r0_input_pwr_sat;
      r1_integrated_pwr <= r0_integrated_pwr;
      r1_comb_pwr       <= m_channel_comb_data(to_integer(r0_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0) & r0_comb_rd_index));
      r1_comb_rd_index  <= r0_comb_rd_index;
      r1_comb_rd_valid  <= r0_comb_rd_valid;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_input_ctrl       <= r1_input_ctrl;
      r2_input_data       <= r1_input_data;
      r2_input_pwr_sat    <= r1_input_pwr_sat;
      r2_integrator_sum   <= r1_integrated_pwr + r1_input_pwr_sat;
      r2_comb_pwr         <= r1_comb_pwr;
      r2_comb_rd_index    <= r1_comb_rd_index;
      r2_comb_rd_valid    <= r1_comb_rd_valid;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_input_ctrl     <= r2_input_ctrl;
      r3_input_data     <= r2_input_data;
      r3_input_pwr_sat  <= r2_input_pwr_sat;
      r3_comb_diff      <= r2_integrator_sum - r2_comb_pwr - r2_input_pwr_sat;
      r3_comb_rd_valid  <= r2_comb_rd_valid;
    end if;
  end process;

  w3_threshold_scaled <= shift_left(r3_comb_diff, to_integer(r_dwell_thresh_shift));

  process(Clk)
  begin
    if rising_edge(Clk) then
      r4_input_ctrl       <= r3_input_ctrl;
      r4_input_data       <= r3_input_data;
      r4_input_pwr_sat    <= r3_input_pwr_sat;
      r4_threshold_value  <= w3_threshold_scaled(INTEGRATOR_WIDTH - 1 downto clog2(FILTER_LENGTH));
      r4_threshold_valid  <= r3_comb_rd_valid;
    end if;
  end process;

  Output_ctrl             <= r4_input_ctrl;
  Output_data             <= r4_input_data;
  Output_power            <= resize_up(r4_input_pwr_sat, CHAN_POWER_WIDTH);
  Output_threshold_value  <= resize_up(r4_threshold_value, CHAN_POWER_WIDTH);
  Output_threshold_valid  <= r4_threshold_valid;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_clear_channel_index <= r_clear_channel_index + 1;
      r_clear_comb_index    <= r_clear_comb_index + 1;
    end if;
  end process;

  process(all)
  begin
    if (r_dwell_active = '0') then
      w_integrator_wr_en    <= '1';
      w_integrator_wr_index <= r_clear_channel_index;
      w_integrator_wr_data  <= (others => '0');
      w_comb_wr_index       <= r_clear_comb_index;
      w_comb_index_wr_data  <= (others => '0');
      w_comb_valid_wr_data  <= '0';
    else
      w_integrator_wr_en    <= r2_input_ctrl.valid;
      w_integrator_wr_index <= r2_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0);
      w_integrator_wr_data  <= r2_integrator_sum;
      w_comb_wr_index       <= r2_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0) & r2_comb_rd_index;
      w_comb_index_wr_data  <= r2_comb_rd_index + 1;
      w_comb_valid_wr_data  <= to_stdlogic(r2_comb_rd_index = (FILTER_LENGTH - 1)) or r2_comb_rd_valid;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_integrator_wr_en = '1') then
        m_channel_integrator(to_integer(w_integrator_wr_index)) <= w_integrator_wr_data;
        m_channel_comb_index(to_integer(w_integrator_wr_index)) <= w_comb_index_wr_data;
        m_channel_comb_valid(to_integer(w_integrator_wr_index)) <= w_comb_valid_wr_data;
        m_channel_comb_data(to_integer(w_comb_wr_index))        <= w_integrator_wr_data;
      end if;
    end if;
  end process;

end architecture rtl;
