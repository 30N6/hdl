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
  use esm_lib.esm_debug_pkg.all;

entity esm_pdw_encoder is
generic (
  AXI_DATA_WIDTH  : natural;
  DATA_WIDTH      : natural;
  NUM_CHANNELS    : natural;
  MODULE_ID       : unsigned;
  WIDE_BANDWIDTH  : boolean
);
port (
  Clk_axi                       : in  std_logic;
  Clk                           : in  std_logic;
  Rst                           : in  std_logic;

  Enable                        : in  std_logic;

  Dwell_active                  : in  std_logic;
  Dwell_data                    : in  esm_dwell_metadata_t;
  Dwell_sequence_num            : in  unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);

  Input_ctrl                    : in  channelizer_control_t;
  Input_data                    : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  Input_power                   : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Axis_ready                    : in  std_logic;
  Axis_valid                    : out std_logic;
  Axis_data                     : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last                     : out std_logic;

  Error_pdw_fifo_overflow       : out std_logic;
  Error_pdw_fifo_underflow      : out std_logic;
  Error_sample_buffer_busy      : out std_logic;
  Error_sample_buffer_underflow : out std_logic;
  Error_sample_buffer_overflow  : out std_logic;
  Error_reporter_timeout        : out std_logic;
  Error_reporter_overflow       : out std_logic
);
begin
  -- PSL default clock is rising_edge(Clk);
end entity esm_pdw_encoder;

architecture rtl of esm_pdw_encoder is

  constant CHANNEL_INDEX_WIDTH        : natural := clog2(NUM_CHANNELS);
  constant DWELL_STOP_WAIT_CYCLES     : natural := NUM_CHANNELS * 4;
  constant IQ_WIDTH                   : natural := 16;
  constant IQ_DELAY_SAMPLES           : natural := 8;
  constant IQ_DELAY_LATENCY           : natural := 4;
  constant BUFFERED_SAMPLES_PER_FRAME : natural := 40;
  constant BUFFERED_SAMPLE_PADDING    : natural := 16;
  constant PDW_FIFO_DEPTH             : natural := 32;

  type state_t is
  (
    S_IDLE,
    S_DWELL_ACTIVE,
    S_DWELL_STOP_WAIT,
    S_DWELL_DONE,
    S_CLEAR --TODO: still needed? might have originally been for the threshold module
  );

  signal r_rst                      : std_logic;
  signal r_enable                   : std_logic;

  signal r_timestamp                : unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);

  signal s_state                    : state_t;
  signal r_stop_wait_count          : unsigned(clog2(DWELL_STOP_WAIT_CYCLES) - 1 downto 0);
  signal r_clear_index              : unsigned(clog2(NUM_CHANNELS) - 1 downto 0);

  signal r_dwell_active             : std_logic;
  signal r_dwell_data               : esm_dwell_metadata_t;
  signal r_dwell_sequence_num       : unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  signal r_dwell_timestamp          : unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);
  signal r_dwell_duration           : unsigned(ESM_DWELL_DURATION_WIDTH - 1 downto 0);

  signal w_iq_scaled                : signed_array_t(1 downto 0)(IQ_WIDTH - 1 downto 0);
  signal w_threshold                : unsigned(ESM_THRESHOLD_WIDTH - 1 downto 0);

  signal w_pipelined_ctrl           : channelizer_control_t;
  signal w_pipelined_power          : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal w_delayed_iq_data          : signed_array_t(1 downto 0)(IQ_WIDTH - 1 downto 0);

  signal w_pdw_ready                : std_logic;
  signal w_pdw_valid                : std_logic;
  signal w_pdw_data                 : esm_pdw_fifo_data_t;
  signal w_frame_req                : esm_pdw_sample_buffer_req_t;
  signal w_frame_ack                : esm_pdw_sample_buffer_ack_t;
  signal w_frame_data               : signed_array_t(1 downto 0)(IQ_WIDTH - 1 downto 0);

  signal w_dwell_active             : std_logic;
  signal w_dwell_done               : std_logic;
  signal w_report_ack               : std_logic;

  signal w_pdw_fifo_overflow        : std_logic;
  signal w_pdw_fifo_underflow       : std_logic;
  signal w_sample_buffer_busy       : std_logic;
  signal w_sample_buffer_underflow  : std_logic;
  signal w_sample_buffer_overflow   : std_logic;
  signal w_reporter_timeout         : std_logic;
  signal w_reporter_overflow        : std_logic;

  signal w_debug_pdw_encoder        : esm_pdw_encoder_debug_t;
  signal w_debug_sample_processor   : esm_pdw_sample_processor_debug_t;

begin

  w_debug_pdw_encoder.r_timestamp                      <= std_logic_vector(r_timestamp);
  w_debug_pdw_encoder.s_state                          <= "000" when (s_state = S_IDLE) else
                                                          "001" when (s_state = S_DWELL_ACTIVE) else
                                                          "010" when (s_state = S_DWELL_STOP_WAIT) else
                                                          "011" when (s_state = S_DWELL_DONE) else
                                                          "100";
  w_debug_pdw_encoder.r_dwell_active                   <= r_dwell_active;
  w_debug_pdw_encoder.r_dwell_data_tag                 <= std_logic_vector(r_dwell_data.tag);
  w_debug_pdw_encoder.w_pdw_ready                      <= w_pdw_ready;
  w_debug_pdw_encoder.w_pdw_valid                      <= w_pdw_valid;
  w_debug_pdw_encoder.w_pdw_data_sequence_num          <= std_logic_vector(w_pdw_data.sequence_num);
  w_debug_pdw_encoder.w_pdw_data_channel               <= std_logic_vector(w_pdw_data.channel);
  w_debug_pdw_encoder.w_pdw_data_power_accum           <= std_logic_vector(w_pdw_data.power_accum);
  w_debug_pdw_encoder.w_pdw_data_duration              <= std_logic_vector(w_pdw_data.duration);
  w_debug_pdw_encoder.w_pdw_data_buffered_frame_index  <= std_logic_vector(w_pdw_data.buffered_frame_index);
  w_debug_pdw_encoder.w_pdw_data_buffered_frame_valid  <= w_pdw_data.buffered_frame_valid;
  w_debug_pdw_encoder.w_frame_req_index                <= std_logic_vector(w_frame_req.frame_index);
  w_debug_pdw_encoder.w_frame_req_read                 <= w_frame_req.frame_read;
  w_debug_pdw_encoder.w_frame_req_drop                 <= w_frame_req.frame_drop;
  w_debug_pdw_encoder.w_frame_ack_index                <= std_logic_vector(w_frame_ack.sample_index);
  w_debug_pdw_encoder.w_frame_ack_valid                <= w_frame_ack.sample_valid;
  w_debug_pdw_encoder.w_frame_ack_last                 <= w_frame_ack.sample_last;
  w_debug_pdw_encoder.w_frame_data_i                   <= std_logic_vector(w_frame_data(0));
  w_debug_pdw_encoder.w_frame_data_q                   <= std_logic_vector(w_frame_data(1));
  w_debug_pdw_encoder.w_dwell_active                   <= w_dwell_active;
  w_debug_pdw_encoder.w_dwell_done                     <= w_dwell_done;
  w_debug_pdw_encoder.w_report_ack                     <= w_report_ack;
  w_debug_pdw_encoder.w_pdw_fifo_overflow              <= w_pdw_fifo_overflow;
  w_debug_pdw_encoder.w_pdw_fifo_underflow             <= w_pdw_fifo_underflow;
  w_debug_pdw_encoder.w_sample_buffer_busy             <= w_sample_buffer_busy;
  w_debug_pdw_encoder.w_sample_buffer_underflow        <= w_sample_buffer_underflow;
  w_debug_pdw_encoder.w_sample_buffer_overflow         <= w_sample_buffer_overflow;
  w_debug_pdw_encoder.w_reporter_timeout               <= w_reporter_timeout;
  w_debug_pdw_encoder.w_reporter_overflow              <= w_reporter_overflow;

  i_debug : entity esm_lib.esm_pdw_encoder_debug
  port map (
    Clk_axi                 => Clk_axi,
    Clk                     => Clk,
    Rst                     => r_rst,

    Debug_sample_processor  => w_debug_sample_processor,
    Debug_pdw_encoder       => w_debug_pdw_encoder
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst     <= Rst;
      r_enable  <= Enable;
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
      r_dwell_active <= Dwell_active;

      if (s_state = S_IDLE) then
        r_dwell_data          <= Dwell_data;
        r_dwell_sequence_num  <= Dwell_sequence_num;
        r_dwell_timestamp     <= r_timestamp;
      end if;

      if (s_state = S_IDLE) then
        r_dwell_duration <= (others => '0');
      elsif (s_state = S_DWELL_ACTIVE) then
        r_dwell_duration <= r_dwell_duration + 1;
      end if;
    end if;
  end process;

  assert (DATA_WIDTH >= IQ_WIDTH)
    report "DATA_WIDTH expected to be >= IQ_WIDTH."
    severity failure;

  --TODO: test scaling in TB - try wider data_width
  w_iq_scaled(0) <= Input_data(0)(DATA_WIDTH - 1 downto (DATA_WIDTH - IQ_WIDTH));
  w_iq_scaled(1) <= Input_data(1)(DATA_WIDTH - 1 downto (DATA_WIDTH - IQ_WIDTH));

  i_iq_delay : entity esm_lib.esm_pdw_iq_delay
  generic map (
    DATA_WIDTH          => IQ_WIDTH,
    CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
    LATENCY             => IQ_DELAY_LATENCY,
    DELAY_SAMPLES       => IQ_DELAY_SAMPLES
  )
  port map (
    Clk                     => Clk,

    Input_ctrl              => Input_ctrl,
    Input_data              => w_iq_scaled,
    Input_power             => Input_power,

    Output_pipelined_ctrl   => w_pipelined_ctrl,
    Output_pipelined_power  => w_pipelined_power,
    Output_delayed_data     => w_delayed_iq_data
  );

  w_threshold <= r_dwell_data.threshold_wide when WIDE_BANDWIDTH else r_dwell_data.threshold_narrow;

  i_sample_processor : entity esm_lib.esm_pdw_sample_processor
  generic map (
    CHANNEL_INDEX_WIDTH         => CHANNEL_INDEX_WIDTH,
    DATA_WIDTH                  => IQ_WIDTH,
    BUFFERED_SAMPLES_PER_FRAME  => BUFFERED_SAMPLES_PER_FRAME,
    BUFFERED_SAMPLE_PADDING     => BUFFERED_SAMPLE_PADDING,
    PDW_FIFO_DEPTH              => PDW_FIFO_DEPTH
  )
  port map (
    Clk                     => Clk,
    Rst                     => r_rst,

    Debug_out               => w_debug_sample_processor,

    Timestamp               => r_timestamp,

    Dwell_active            => r_dwell_active,

    Input_ctrl              => w_pipelined_ctrl,
    Input_iq_delayed        => w_delayed_iq_data,
    Input_power             => w_pipelined_power,
    Input_threshold         => w_threshold,

    Pdw_ready               => w_pdw_ready,
    Pdw_valid               => w_pdw_valid,
    Pdw_data                => w_pdw_data,

    Buffered_frame_req      => w_frame_req,
    Buffered_frame_ack      => w_frame_ack,
    Buffered_frame_data     => w_frame_data,

    Error_fifo_overflow     => w_pdw_fifo_overflow,
    Error_fifo_underflow    => w_pdw_fifo_underflow,
    Error_buffer_busy       => w_sample_buffer_busy,
    Error_buffer_underflow  => w_sample_buffer_overflow,
    Error_buffer_overflow   => w_sample_buffer_underflow
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        s_state <= S_CLEAR;
      else
        case s_state is
        when S_IDLE =>
          if ((r_enable = '1') and (r_dwell_active = '1')) then
            s_state <= S_DWELL_ACTIVE;
          else
            s_state <= S_IDLE;
          end if;

        when S_DWELL_ACTIVE =>
          if (r_dwell_active = '0') then
            s_state <= S_DWELL_STOP_WAIT;
          else
            s_state <= S_DWELL_ACTIVE;
          end if;

        when S_DWELL_STOP_WAIT =>
          if (r_stop_wait_count = (DWELL_STOP_WAIT_CYCLES - 1)) then
            s_state <= S_DWELL_DONE;
          else
            s_state <= S_DWELL_STOP_WAIT;
          end if;

        when S_DWELL_DONE =>
          if (w_report_ack = '1') then
            s_state <= S_CLEAR;
          else
            s_state <= S_DWELL_DONE;
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

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state /= S_DWELL_STOP_WAIT) then
        r_stop_wait_count <= (others => '0');
      else
        r_stop_wait_count <= r_stop_wait_count + 1;
      end if;

      if (s_state /= S_CLEAR) then
        r_clear_index <= (others => '0');
      else
        r_clear_index <= r_clear_index + 1;
      end if;
    end if;
  end process;

  w_dwell_active <= to_stdlogic(s_state = S_DWELL_ACTIVE);
  w_dwell_done <= to_stdlogic(s_state = S_DWELL_DONE);

  i_reporter : entity esm_lib.esm_pdw_reporter
  generic map (
    AXI_DATA_WIDTH      => AXI_DATA_WIDTH,
    CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
    DATA_WIDTH          => IQ_WIDTH,
    MODULE_ID           => MODULE_ID
  )
  port map (
    Clk_axi             => Clk_axi,
    Clk                 => Clk,
    Rst                 => r_rst,

    Dwell_active        => w_dwell_active,
    Dwell_done          => w_dwell_done,
    Dwell_data          => r_dwell_data,
    Dwell_sequence_num  => r_dwell_sequence_num,
    Dwell_timestamp     => r_dwell_timestamp,
    Dwell_duration      => r_dwell_duration,

    Pdw_ready           => w_pdw_ready,
    Pdw_valid           => w_pdw_valid,
    Pdw_data            => w_pdw_data,

    Buffered_frame_req  => w_frame_req,
    Buffered_frame_ack  => w_frame_ack,
    Buffered_frame_data => w_frame_data,

    Report_ack          => w_report_ack,

    Axis_ready          => Axis_ready,
    Axis_valid          => Axis_valid,
    Axis_data           => Axis_data,
    Axis_last           => Axis_last,

    Error_timeout       => w_reporter_timeout,
    Error_overflow      => w_reporter_overflow
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_pdw_fifo_overflow       <= w_pdw_fifo_overflow;
      Error_pdw_fifo_underflow      <= w_pdw_fifo_underflow;
      Error_sample_buffer_busy      <= w_sample_buffer_busy;
      Error_sample_buffer_underflow <= w_sample_buffer_underflow;
      Error_sample_buffer_overflow  <= w_sample_buffer_overflow;
      Error_reporter_timeout        <= w_reporter_timeout;
      Error_reporter_overflow       <= w_reporter_overflow;
    end if;
  end process;

end architecture rtl;
