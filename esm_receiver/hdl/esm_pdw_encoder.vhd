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

entity esm_pdw_decoder is
generic (
  AXI_DATA_WIDTH  : natural;
  DATA_WIDTH      : natural;
  NUM_CHANNELS    : natural;
  MODULE_ID       : unsigned;
  WIDE_BANDWIDTH  : boolean
);
port (
  Clk                 : in  std_logic;
  Rst                 : in  std_logic;

  Enable              : in  std_logic;

  Dwell_active        : in  std_logic;
  Dwell_data          : in  esm_dwell_metadata_t;
  Dwell_sequence_num  : in  unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);

  Input_ctrl          : in  channelizer_control_t;
  Input_data          : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  Input_pwr           : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Axis_ready          : in  std_logic;
  Axis_valid          : out std_logic;
  Axis_data           : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last           : out std_logic
);
end entity esm_pdw_decoder;

architecture rtl of esm_pdw_decoder is

  constant CHANNEL_INDEX_WIDTH          : natural := clog2(NUM_CHANNELS);
  constant THRESHOLD_LATENCY            : natural := 5;
  constant IQ_WIDTH                     : natural := 16;
  constant IQ_DELAY                     : natural := 8;
  constant BUFFERED_FRAMES                : natural := 32;
  constant BUFFERED_SAMPLES_PER_FRAME     : natural := 40;
  constant BUFFERED_FRAME_INDEX_WIDTH     : natural := clog2(BUFFERED_FRAMES);
  constant BUFFERED_SAMPLE_INDEX_WIDTH    : natural := clog2(BUFFERED_SAMPLES_PER_FRAME);

  type global_state_t is
  (
    S_IDLE,
    S_THRESHOLD_WAIT,
    S_ACTIVE,
    S_FLUSH_REPORTS
  );

  signal r_rst                  : std_logic;
  signal r_enable               : std_logic;

  signal w_iq_scaled            : signed_array_t(1 downto 0)(IQ_WIDTH - 1 downto 0);

  signal w_threshold_factor     : unsigned(ESM_THRESHOLD_FACTOR_WIDTH - 1 downto 0);

  signal w_piped_ctrl           : channelizer_control_t;
  --signal w_piped_data           : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);  --TODO: IFM?
  signal w_piped_pwr            : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal w_piped_threshold      : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal w_delayed_iq_ctrl      : channelizer_control_t;
  signal w_delayed_iq_data      : signed_array_t(1 downto 0)(IQ_WIDTH - 1 downto 0);

  signal w_sample_buffer_underflow  : std_logic;  --TODO: use
  signal w_sample_buffer_overflow   : std_logic;  --TODO: use

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst     <= Rst;
      r_enable  <= Enable;
    end if;
  end process;

  assert (DATA_WIDTH >= IQ_WIDTH)
    report "DATA_WIDTH expected to be >= IQ_WIDTH."
    severity failure;

  w_iq_scaled(0) <= Input_data(0)(DATA_WIDTH - 1 downto (DATA_WIDTH - IQ_WIDTH));
  w_iq_scaled(1) <= Input_data(1)(DATA_WIDTH - 1 downto (DATA_WIDTH - IQ_WIDTH));

  w_threshold_factor <= Dwell_data.threshold_factor_wide when WIDE_BANDWIDTH else Dwell_data.threshold_factor_narrow;

  i_threshold : entity esm_lib.esm_pdw_threshold
  generic map (
    DATA_WIDTH          => IQ_WIDTH,
    CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
    LATENCY             => THRESHOLD_LATENCY
  )
  port map (
    Clk                     => Clk,

    Dwell_active            => Dwell_active,
    Dwell_threshold_factor  => w_threshold_factor,

    Input_ctrl              => Input_ctrl,
    Input_data              => w_iq_scaled,
    Input_pwr               => Input_pwr,

    Output_ctrl             => w_piped_ctrl,
    Output_data             => open, --w_piped_data, TODO: IFM?
    Output_pwr              => w_piped_pwr,
    Output_threshold        => w_piped_threshold
  );

  i_iq_delay : entity esm_lib.esm_pdw_iq_delay
  generic map (
    DATA_WIDTH          => IQ_WIDTH,
    CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
    LATENCY             => THRESHOLD_LATENCY,
    DELAY               => IQ_DELAY
  )
  port map (
    Clk         => Clk,

    Input_ctrl  => Input_ctrl,
    Input_data  => w_iq_scaled,

    Output_ctrl => w_delayed_iq_ctrl,
    Output_data => w_delayed_iq_data
  );

  assert (w_delayed_iq_ctrl = w_piped_ctrl)
    report "Threshold/IQ delay control mismatch."
    severity failure;





  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_ctrl   <= Input_ctrl;
      r_input_pwr    <= Input_pwr;
      r_dwell_active <= Dwell_active;

      if (s_state = S_IDLE) then
        r_dwell_data          <= Dwell_data;
        r_dwell_sequence_num  <= Dwell_sequence_num;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        s_state <= S_CLEAR;
      else
        case s_state is
        when S_IDLE =>
          if ((r_enable = '1') and (r_dwell_active = '1')) then
            s_state <= S_ACTIVE;
          else
            s_state <= S_IDLE;
          end if;

        when S_ACTIVE =>
          if (r_dwell_active = '0') then
            s_state <= S_DONE;
          else
            s_state <= S_ACTIVE;
          end if;

        when S_DONE =>
          s_state <= S_REPORT_WAIT;

        when S_REPORT_WAIT =>
          if (w_report_ack = '1') then
            s_state <= S_CLEAR;
          else
            s_state <= S_REPORT_WAIT;
          end if;

        when S_CLEAR =>
          if (r_clear_index = (NUM_CHANNELS - 1)) then
            s_state <= S_IDLE;
          else
            s_state <= S_CLEAR;
          end if;

        end case;
      end if;
    end if;
  end process;

  process(all)
  begin
    if (s_state = S_ACTIVE) then
      w_channel_rd_index <= r_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0);
    else
      w_channel_rd_index <= w_report_read_index;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_channel_wr_en = '1') then
        m_channel_accum(to_integer(w_channel_wr_index)) <= w_channel_wr_accum;
        m_channel_max(to_integer(w_channel_wr_index))   <= w_channel_wr_max;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_channel_rd_accum(0) <= m_channel_accum(to_integer(w_channel_rd_index));
      r_channel_rd_max(0)   <= m_channel_max(to_integer(w_channel_rd_index));

      r_channel_rd_accum(1) <= r_channel_rd_accum(0);
      r_channel_rd_max(1)   <= r_channel_rd_max(0);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_read_pipe_ctrl    <= r_read_pipe_ctrl(READ_PIPE_DEPTH - 2 downto 0)   & r_input_ctrl;
      r_read_pipe_active  <= r_read_pipe_active(READ_PIPE_DEPTH - 2 downto 0) & to_stdlogic(s_state = S_ACTIVE);
      r_read_pipe_req     <= r_read_pipe_req(READ_LATENCY - 2 downto 0)       & (w_report_read_req and to_stdlogic(s_state /= S_ACTIVE));
      r_read_pipe_pwr     <= r_read_pipe_pwr(READ_LATENCY - 1 downto 0)       & r_input_pwr;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      (r_channel_new_accum_d0_c, r_channel_new_accum_d0_a)  <= ('0' & r_channel_rd_accum(1)(31 downto 0)) + ('0' & r_read_pipe_pwr(1)(31 downto 0));
      r_channel_new_accum_d0_b                              <= r_channel_rd_accum(1)(63 downto 32);
      r_channel_new_max_valid_d0                            <= to_stdlogic(r_read_pipe_pwr(1) > r_channel_rd_max(1));
      r_channel_rd_max(2)                                   <= r_channel_rd_max(1);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_channel_new_accum_d1(63 downto 32)  <= r_channel_new_accum_d0_b + r_channel_new_accum_d0_c;
      r_channel_new_accum_d1(31 downto 0)   <= r_channel_new_accum_d0_a;
      r_channel_new_max_d1                  <= r_read_pipe_pwr(2) when (r_channel_new_max_valid_d0 = '1') else r_channel_rd_max(2);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state /= S_CLEAR) then
        r_clear_index <= (others => '0');
      else
        r_clear_index <= r_clear_index + 1;
      end if;
    end if;
  end process;

  process(all)
  begin
    if (s_state = S_CLEAR) then
      w_channel_wr_en     <= '1';
      w_channel_wr_index  <= r_clear_index;
      w_channel_wr_accum  <= (others => '0');
      w_channel_wr_max    <= (others => '0');
    else
      w_channel_wr_en     <= r_read_pipe_ctrl(READ_PIPE_DEPTH - 1).valid and r_read_pipe_active(READ_PIPE_DEPTH - 1);
      w_channel_wr_index  <= r_read_pipe_ctrl(READ_PIPE_DEPTH - 1).data_index(CHANNEL_INDEX_WIDTH - 1 downto 0);
      w_channel_wr_accum  <= r_channel_new_accum_d1;
      w_channel_wr_max    <= r_channel_new_max_d1;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_timestamp <= (others => '0');
      else
        r_timestamp <= r_timestamp + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_ts_dwell_start  <= r_timestamp;
        r_duration        <= (others => '0');
      elsif (s_state = S_ACTIVE) then
        r_ts_dwell_end    <= r_timestamp;
        r_duration        <= r_duration + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_num_samples <= (others => '0');
      elsif ((s_state = S_ACTIVE) and (r_input_ctrl.valid = '1')) then
        r_num_samples <= r_num_samples + 1;
      end if;
    end if;
  end process;

  w_dwell_done <= to_stdlogic(s_state = S_DONE);

  i_reporter : entity esm_lib.esm_dwell_reporter
  generic map (
    AXI_DATA_WIDTH        => AXI_DATA_WIDTH,
    NUM_CHANNELS          => NUM_CHANNELS,
    CHANNEL_INDEX_WIDTH   => CHANNEL_INDEX_WIDTH,
    MODULE_ID             => MODULE_ID
  )
  port map (
    Clk                 => Clk,
    Rst                 => r_rst,

    Dwell_done          => w_dwell_done,
    Dwell_data          => r_dwell_data,
    Dwell_sequence_num  => r_dwell_sequence_num,
    Dwell_duration      => r_duration,
    Dwell_num_samples   => r_num_samples,
    Timestamp_start     => r_ts_dwell_start,
    Timestamp_end       => r_ts_dwell_end,

    Read_req            => w_report_read_req,
    Read_index          => w_report_read_index,
    Read_accum          => r_channel_rd_accum(READ_LATENCY - 1),
    Read_max            => r_channel_rd_max(READ_LATENCY - 1),
    Read_valid          => r_read_pipe_req(READ_LATENCY - 1),

    Report_ack          => w_report_ack,

    Axis_ready          => Axis_ready,
    Axis_valid          => Axis_valid,
    Axis_data           => Axis_data,
    Axis_last           => Axis_last
  );

end architecture rtl;
