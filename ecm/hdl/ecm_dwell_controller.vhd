library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity ecm_dwell_controller is
generic (
  SYNC_TO_DRFM_READ_LATENCY : natural;
  CHANNELIZER_DATA_WIDTH    : natural
);
port (
  Clk                       : in  std_logic;
  Rst                       : in  std_logic;

  Module_config             : in  ecm_config_data_t;

  Ad9361_control            : out std_logic_vector(3 downto 0);
  Ad9361_status             : in  std_logic_vector(7 downto 0);

  Channelizer_ctrl          : in  channelizer_control_t;
  Channelizer_data          : in  signed_array_t(1 downto 0)(CHANNELIZER_DATA_WIDTH - 1 downto 0);
  Channelizer_pwr           : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Sync_data                 : in  channelizer_control_t;

  Dwell_active              : out std_logic;
  Dwell_active_measurement  : out std_logic;
  Dwell_active_transmit     : out std_logic;
  Dwell_done                : out std_logic;
  Dwell_data                : out ecm_dwell_entry_t;
  Dwell_sequence_num        : out unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  Dwell_report_done_drfm    : in  std_logic;
  Dwell_report_done_stats   : in  std_logic;

  Drfm_write_req            : out ecm_drfm_write_req_t;
  Drfm_read_req             : out ecm_drfm_read_req_t;
  Dds_control               : out dds_control_t;
  Output_control            : out ecm_output_control_t
);
end entity ecm_dwell_controller;

architecture rtl of ecm_dwell_controller is

  type state_t is
  (
    S_IDLE,

    S_LOAD_DWELL_ENTRY_0,
    S_LOAD_DWELL_ENTRY_1,
    S_LOAD_DWELL_ENTRY_2,
    S_CHECK_DWELL_ENTRY,

    S_PLL_WAIT_PRE_LOCK,
    S_PLL_WAIT_POST_LOCK,

    S_DWELL_START_MEAS,
    S_DWELL_ACTIVE_MEAS,
    S_DWELL_FLUSH_MEAS,
    S_DWELL_START_TX,
    S_DWELL_ACTIVE_TX,

    S_DWELL_REPORT_WAIT,
    S_DWELL_DONE
  );

  type ecm_dwell_entry_array_t is array (natural range <>) of ecm_dwell_entry_t;

  constant MEAS_FLUSH_CYCLES        : natural := ECM_NUM_CHANNELS * 2 + 8;

  signal s_state                    : state_t;

  signal r_rst                      : std_logic;
  signal r_ad9361_status            : std_logic_vector(7 downto 0);
  signal r_channelizer_ctrl         : channelizer_control_t;
  signal r_channelizer_data         : signed_array_t(1 downto 0)(CHANNELIZER_DATA_WIDTH - 1 downto 0);
  signal r_channelizer_pwr          : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r_sync_data                : channelizer_control_t;
  signal r_dwell_report_done_drfm   : std_logic;
  signal r_dwell_report_done_stats  : std_logic;

  signal w_dwell_program_valid      : std_logic;
  signal w_dwell_program_data       : ecm_dwell_program_entry_t;

  signal w_dwell_entry_valid        : std_logic;
  signal w_dwell_entry_index        : unsigned(ECM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
  signal w_dwell_entry_data         : ecm_dwell_entry_t;

  signal w_channel_entry_valid      : std_logic;
  signal w_channel_entry_index      : unsigned(ECM_DWELL_CHANNEL_CONTROL_ENTRY_INDEX_WIDTH - 1 downto 0);
  signal w_channel_entry_data       : ecm_channel_control_entry_t;

  signal w_tx_instruction_valid     : std_logic;
  signal w_tx_instruction_index     : unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
  signal w_tx_instruction_data      : std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0);

  signal w_drfm_write_req           : ecm_drfm_write_req_t;

  signal r_dwell_program_data       : ecm_dwell_program_entry_t;
  signal r_dwell_program_valid      : std_logic;

  signal m_dwell_entry              : ecm_dwell_entry_array_t(ECM_NUM_DWELL_ENTRIES - 1 downto 0);

  signal r_dwell_entry_index        : unsigned(ECM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
  signal r_dwell_entry_index_d0     : unsigned(ECM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
  signal r_dwell_entry_index_d1     : unsigned(ECM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
  signal r_dwell_entry_d0           : ecm_dwell_entry_t;
  signal r_dwell_entry_d1           : ecm_dwell_entry_t;

  signal r_global_counter           : unsigned(ECM_DWELL_GLOBAL_COUNTER_WIDTH - 1 downto 0);
  signal r_global_counter_is_zero   : std_logic;

  signal w_current_dwell_valid      : std_logic;

  signal r_pll_pre_lock_cycles      : unsigned(ECM_DWELL_PLL_DELAY_WIDTH - 1 downto 0);
  signal r_pll_pre_lock_done        : std_logic;
  signal r_pll_post_lock_cycles     : unsigned(ECM_DWELL_PLL_DELAY_WIDTH - 1 downto 0);
  signal r_pll_post_lock_done       : std_logic;

  signal w_pll_pre_lock_done        : std_logic;
  signal w_pll_locked               : std_logic;
  signal w_pll_post_lock_done       : std_logic;

  signal r_dwell_repeat             : unsigned(3 downto 0);

  signal r_dwell_cycles             : unsigned(ECM_DWELL_DURATION_WIDTH - 1 downto 0);
  signal r_dwell_done_meas          : std_logic;
  signal r_dwell_done_total         : std_logic;
  signal r_dwell_meas_flush_cycles  : unsigned(clog2(MEAS_FLUSH_CYCLES) - 1 downto 0);
  signal r_dwell_meas_flush_done    : std_logic;

  signal r_report_received_drfm     : std_logic;
  signal r_report_received_stats    : std_logic;

  signal r_dwell_sequence_num       : unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);

  signal r_dwell_active             : std_logic;
  signal r_dwell_start_meas         : std_logic;
  signal r_dwell_active_meas        : std_logic;
  signal r_dwell_active_tx          : std_logic;
  signal r_dwell_report_wait        : std_logic;

  signal w_trigger_immediate_tx     : std_logic;
  signal w_trigger_pending          : std_logic;
  signal w_tx_program_req_valid     : std_logic;
  signal w_tx_program_req_channel   : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_tx_program_req_index     : unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);

  signal w_tx_programs_done         : std_logic;

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst                       <= Rst;
      r_ad9361_status             <= Ad9361_status;
      r_channelizer_ctrl         <= Channelizer_ctrl;
      r_channelizer_data         <= Channelizer_data;
      r_channelizer_pwr          <= Channelizer_pwr;
      r_sync_data                <= Sync_data;
      r_dwell_report_done_drfm   <= Dwell_report_done_drfm;
      r_dwell_report_done_stats  <= Dwell_report_done_stats;
    end if;
  end process;

  i_config : entity ecm_lib.ecm_dwell_config_decoder
  port map (
    Clk                         => Clk,
    Rst                         => r_rst,

    Module_config               => Module_config,

    Dwell_program_valid         => w_dwell_program_valid,
    Dwell_program_data          => w_dwell_program_data,

    Dwell_entry_valid           => w_dwell_entry_valid,
    Dwell_entry_index           => w_dwell_entry_index,
    Dwell_entry_data            => w_dwell_entry_data,

    Dwell_channel_entry_valid   => w_channel_entry_valid,
    Dwell_channel_entry_index   => w_channel_entry_index,
    Dwell_channel_entry_data    => w_channel_entry_data,

    Dwell_tx_instruction_valid  => w_tx_instruction_valid,
    Dwell_tx_instruction_index  => w_tx_instruction_index,
    Dwell_tx_instruction_data   => w_tx_instruction_data
  );

  i_trigger : entity ecm_lib.ecm_dwell_trigger
  generic map (
    CHANNELIZER_DATA_WIDTH => CHANNELIZER_DATA_WIDTH
  )
  port map (
    Clk                       => Clk,
    Rst                       => r_rst,

    Channel_entry_valid       => w_channel_entry_valid,
    Channel_entry_index       => w_channel_entry_index,
    Channel_entry_data        => w_channel_entry_data,

    Channelizer_ctrl          => r_channelizer_ctrl,
    Channelizer_data          => r_channelizer_data,
    Channelizer_pwr           => r_channelizer_pwr,

    Dwell_channel_clear       => r_dwell_report_wait,
    Dwell_start_measurement   => r_dwell_start_meas,
    Dwell_active_measurement  => r_dwell_active_meas,
    Dwell_index               => r_dwell_entry_index_d1,
    Dwell_immediate_tx        => w_trigger_immediate_tx,

    Trigger_pending           => w_trigger_pending,

    Tx_program_req_valid      => w_tx_program_req_valid,
    Tx_program_req_channel    => w_tx_program_req_channel,
    Tx_program_req_index      => w_tx_program_req_index,

    Drfm_write_req            => w_drfm_write_req
  );

  i_tx_engine : entity ecm_lib.ecm_dwell_tx_engine
  generic map (
    SYNC_TO_DRFM_READ_LATENCY => SYNC_TO_DRFM_READ_LATENCY - 1
  )
  port map (
    Clk                     => Clk,
    Rst                     => r_rst,

    Tx_instruction_valid    => w_tx_instruction_valid,
    Tx_instruction_index    => w_tx_instruction_index,
    Tx_instruction_data     => w_tx_instruction_data,

    Tx_program_req_valid    => w_tx_program_req_valid,
    Tx_program_req_channel  => w_tx_program_req_channel,
    Tx_program_req_index    => w_tx_program_req_index,
    Drfm_write_req          => w_drfm_write_req,

    Dwell_channel_clear     => r_dwell_report_wait,
    Dwell_transmit_active   => r_dwell_active_tx,
    Dwell_transmit_done     => w_tx_programs_done,

    Sync_data               => r_sync_data,

    Drfm_read_req           => Drfm_read_req,
    Dds_control             => Dds_control,
    Output_control          => Output_control
  );

  Drfm_write_req <= w_drfm_write_req;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_dwell_program_data <= (enable => '0', others => (others => '-'));
      else
        if (w_dwell_program_valid = '1') then
          r_dwell_program_data <= w_dwell_program_data;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_dwell_program_valid <= w_dwell_program_valid;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_dwell_entry_valid = '1') then
        m_dwell_entry(to_integer(w_dwell_entry_index)) <= w_dwell_entry_data;
      end if;
    end if;
  end process;

  w_current_dwell_valid <= r_dwell_entry_d1.valid and (not(r_dwell_entry_d1.global_counter_check) or not(r_global_counter_is_zero));
  w_pll_pre_lock_done   <= r_dwell_entry_d1.skip_pll_prelock_wait   or r_pll_pre_lock_done;
  w_pll_locked          <= r_dwell_entry_d1.skip_pll_lock_check     or r_ad9361_status(6);
  w_pll_post_lock_done  <= r_dwell_entry_d1.skip_pll_postlock_wait  or r_pll_post_lock_done;

  -- dwell_active       -> active for entire Dwell_active
  -- dwell_active_meas  -> initial portion
  -- dwell_active_tx    -> final portion, if triggered

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        s_state <= S_IDLE;
      else
        case s_state is
        when S_IDLE =>
          if ((r_dwell_program_valid = '1') and (r_dwell_program_data.enable = '1')) then
            s_state <= S_LOAD_DWELL_ENTRY_0;
          else
            s_state <= S_IDLE;
          end if;

        when S_LOAD_DWELL_ENTRY_0 =>
          s_state <= S_LOAD_DWELL_ENTRY_1;

        when S_LOAD_DWELL_ENTRY_1 =>
          s_state <= S_LOAD_DWELL_ENTRY_2;

        when S_LOAD_DWELL_ENTRY_2 =>
          s_state <= S_CHECK_DWELL_ENTRY;

        when S_CHECK_DWELL_ENTRY =>
          if (w_current_dwell_valid = '1') then
            s_state <= S_PLL_WAIT_PRE_LOCK;
          else
            s_state <= S_IDLE;
          end if;

        --TODO: skip PLL delays if not changing the fast lock profile?

        when S_PLL_WAIT_PRE_LOCK =>
          if ((w_pll_pre_lock_done = '1') and (w_pll_locked = '1')) then
            s_state <= S_PLL_WAIT_POST_LOCK;
          else
            s_state <= S_PLL_WAIT_PRE_LOCK;
          end if;

        when S_PLL_WAIT_POST_LOCK =>
          if (w_pll_post_lock_done = '1') then
            s_state <= S_DWELL_START_MEAS;
          else
            s_state <= S_PLL_WAIT_POST_LOCK;
          end if;

        when S_DWELL_START_MEAS =>
          s_state <= S_DWELL_ACTIVE_MEAS;

        when S_DWELL_ACTIVE_MEAS =>
          if ((r_dwell_done_meas = '1') or (w_trigger_immediate_tx = '1')) then
            s_state <= S_DWELL_FLUSH_MEAS;
          else
            s_state <= S_DWELL_ACTIVE_MEAS;
          end if;

        when S_DWELL_FLUSH_MEAS =>
          if (r_dwell_meas_flush_done = '1') then
            s_state <= S_DWELL_START_TX;
          else
            s_state <= S_DWELL_FLUSH_MEAS;
          end if;

        when S_DWELL_START_TX =>
          if (w_trigger_pending = '1') then
            s_state <= S_DWELL_ACTIVE_TX;
          else
            s_state <= S_DWELL_REPORT_WAIT;
          end if;

        when S_DWELL_ACTIVE_TX =>
          if ((w_tx_programs_done = '1') or (r_dwell_done_total = '1')) then
            s_state <= S_DWELL_REPORT_WAIT;
          else
            s_state <= S_DWELL_ACTIVE_TX;
          end if;

        when S_DWELL_REPORT_WAIT =>
          if ((r_report_received_drfm = '1') and (r_report_received_stats = '1')) then
            s_state <= S_DWELL_DONE;
          else
            s_state <= S_DWELL_REPORT_WAIT;
          end if;

        when S_DWELL_DONE =>
          if (w_current_dwell_valid = '0') then
            s_state <= S_IDLE;
          elsif (r_dwell_repeat > 0) then
            s_state <= S_CHECK_DWELL_ENTRY;
          else
            s_state <= S_LOAD_DWELL_ENTRY_0;
          end if;

        end case;

        if ((w_dwell_program_valid = '1') or (w_dwell_entry_valid = '1') or (w_channel_entry_valid = '1') or (w_tx_instruction_valid = '1')) then
          s_state <= S_IDLE;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_dwell_entry_d0        <= m_dwell_entry(to_integer(r_dwell_entry_index));
      r_dwell_entry_index_d0  <= r_dwell_entry_index;

      r_dwell_entry_d1        <= r_dwell_entry_d0;
      r_dwell_entry_index_d1  <= r_dwell_entry_index_d0;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_LOAD_DWELL_ENTRY_2) then
        r_dwell_repeat <= r_dwell_entry_d1.repeat_count;
      elsif (s_state = S_DWELL_DONE) then
        r_dwell_repeat <= r_dwell_repeat - 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_dwell_entry_index         <= r_dwell_program_data.initial_dwell_index;
        r_global_counter            <= r_dwell_program_data.global_counter_init;
        r_global_counter_is_zero    <= to_stdlogic(r_dwell_program_data.global_counter_init = 0);
      elsif (s_state = S_DWELL_DONE) then
        if (r_dwell_repeat = 0) then
          r_dwell_entry_index       <= r_dwell_entry_d1.next_dwell_index;
        end if;
        if (r_dwell_entry_d1.global_counter_dec = '1') then
          r_global_counter          <= r_global_counter - 1;
          r_global_counter_is_zero  <= to_stdlogic(r_global_counter = 1);
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_CHECK_DWELL_ENTRY) then
        r_pll_pre_lock_cycles <= (others => '0');
        r_pll_pre_lock_done   <= '0';
      else
        r_pll_pre_lock_cycles <= r_pll_pre_lock_cycles + 1;
        r_pll_pre_lock_done   <= to_stdlogic(r_pll_pre_lock_cycles = r_dwell_entry_d1.pll_pre_lock_delay);
      end if;

      if (s_state = S_PLL_WAIT_PRE_LOCK) then
        r_pll_post_lock_cycles <= (others => '0');
        r_pll_post_lock_done   <= '0';
      else
        r_pll_post_lock_cycles <= r_pll_post_lock_cycles + 1;
        r_pll_post_lock_done   <= to_stdlogic(r_pll_post_lock_cycles = r_dwell_entry_d1.pll_post_lock_delay);
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_DWELL_START_MEAS) then
        r_dwell_cycles        <= (others => '0');
        r_dwell_done_meas     <= '0';
        r_dwell_done_total    <= '0';
      else
        r_dwell_cycles        <= r_dwell_cycles + 1;
        r_dwell_done_meas     <= to_stdlogic(r_dwell_entry_d1.measurement_duration = r_dwell_cycles);
        r_dwell_done_total    <= to_stdlogic(r_dwell_entry_d1.total_duration_max = r_dwell_cycles);
      end if;

      if (s_state /= S_DWELL_FLUSH_MEAS) then
        r_dwell_meas_flush_cycles <= (others => '0');
        r_dwell_meas_flush_done   <= '0';
      else
        r_dwell_meas_flush_cycles <= r_dwell_meas_flush_cycles + 1;
        r_dwell_meas_flush_done   <= to_stdlogic(r_dwell_meas_flush_cycles = (MEAS_FLUSH_CYCLES - 1));
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_DWELL_START_MEAS) then
        r_report_received_drfm    <= '0';
        r_report_received_stats   <= '0';
      else
        if (r_dwell_report_done_drfm = '1') then
          r_report_received_drfm  <= '1';
        end if;
        if (r_dwell_report_done_stats = '1') then
          r_report_received_stats <= '1';
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_dwell_sequence_num <= (others => '0');
      else
        if (s_state = S_DWELL_DONE) then
          r_dwell_sequence_num <= r_dwell_sequence_num + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_dwell_active      <= to_stdlogic((s_state = S_DWELL_ACTIVE_MEAS) or (s_state = S_DWELL_FLUSH_MEAS) or (s_state = S_DWELL_START_TX) or (s_state = S_DWELL_ACTIVE_TX)); --include flush_meas and start_tx to avoid gaps
      r_dwell_start_meas  <= to_stdlogic(s_state = S_DWELL_START_MEAS);
      r_dwell_active_meas <= to_stdlogic(s_state = S_DWELL_ACTIVE_MEAS);
      r_dwell_active_tx   <= to_stdlogic(s_state = S_DWELL_ACTIVE_TX);
      r_dwell_report_wait <= to_stdlogic(s_state = S_DWELL_REPORT_WAIT);
    end if;
  end process;

  Dwell_active              <= r_dwell_active;
  Dwell_active_measurement  <= r_dwell_active_meas;
  Dwell_active_transmit     <= r_dwell_active_tx;
  Dwell_done                <= r_dwell_report_wait; --hold done for external modules until reports are sent


  Dwell_data          <= r_dwell_entry_d1;
  Dwell_sequence_num  <= r_dwell_sequence_num;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Ad9361_control <= std_logic_vector(r_dwell_entry_d1.fast_lock_profile & '0');
    end if;
  end process;

end architecture rtl;
