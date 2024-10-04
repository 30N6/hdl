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

entity esm_pdw_encoder is
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
  Input_power         : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Axis_ready          : in  std_logic;
  Axis_valid          : out std_logic;
  Axis_data           : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last           : out std_logic
);
end entity esm_pdw_encoder;

architecture rtl of esm_pdw_encoder is

  constant CHANNEL_INDEX_WIDTH        : natural := clog2(NUM_CHANNELS);
  constant DWELL_STOP_WAIT_CYCLES     : natural := NUM_CHANNELS * 4;
  constant IQ_WIDTH                   : natural := 16;
  constant IQ_DELAY_SAMPLES           : natural := 8;
  constant IQ_DELAY_LATENCY           : natural := 4;
  constant BUFFERED_SAMPLES_PER_FRAME : natural := 40;
  constant BUFFERED_SAMPLE_PADDING    : natural := 4;
  constant PDW_FIFO_DEPTH             : natural := 32;

  type state_t is
  (
    S_IDLE,
    S_ACTIVE,
    S_DWELL_DONE,
    S_FLUSH_REPORTS
  );

  signal r_rst                      : std_logic;
  signal r_enable                   : std_logic;

  signal s_state                    : state_t;
  signal r_stop_wait_count          : unsigned(clog2(DWELL_STOP_WAIT_CYCLES) - 1 downto 0);
  signal r_clear_index              : unsigned(clog2(NUM_CHANNELS) - 1 downto 0);

  signal r_dwell_active             : std_logic;
  signal r_dwell_data               : esm_dwell_metadata_t;
  signal r_dwell_sequence_num       : unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);

  signal w_iq_scaled                : signed_array_t(1 downto 0)(IQ_WIDTH - 1 downto 0);
  signal w_threshold                : unsigned(ESM_THRESHOLD_FACTOR_WIDTH - 1 downto 0);

  signal w_delayed_iq_ctrl          : channelizer_control_t;
  signal w_delayed_iq_data          : signed_array_t(1 downto 0)(IQ_WIDTH - 1 downto 0);
  signal w_delayed_iq_power         : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal w_pdw_ready                : std_logic;
  signal w_pdw_valid                : std_logic;
  signal w_pdw_data                 : esm_pdw_fifo_data_t;
  signal w_frame_req                : esm_pdw_sample_buffer_req_t;
  signal w_frame_ack                : esm_pdw_sample_buffer_ack_t;
  signal w_frame_data               : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  signal w_pdw_fifo_overflow        : std_logic;
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

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_dwell_active <= Dwell_active;

      if (s_state = S_IDLE) then
        r_dwell_data          <= Dwell_data;
        r_dwell_sequence_num  <= Dwell_sequence_num;
      end if;
    end if;
  end process;

  assert (DATA_WIDTH >= IQ_WIDTH)
    report "DATA_WIDTH expected to be >= IQ_WIDTH."
    severity failure;

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
    Clk           => Clk,

    Input_ctrl    => Input_ctrl,
    Input_data    => w_iq_scaled,
    Input_power   => Input_power,

    Output_ctrl   => w_delayed_iq_ctrl,
    Output_data   => w_delayed_iq_data,
    Output_power  => w_delayed_iq_power
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
    Rst                     => r_rst

    Dwell_active            => r_dwell_active,

    Input_ctrl              => w_delayed_iq_ctrl
    Input_iq_delayed        => w_delayed_iq_data,
    Input_power             => w_delayed_iq_power,
    Input_threshold         => w_threshold,

    Pdw_ready               => w_pdw_ready,
    Pdw_valid               => w_pdw_valid,
    Pdw_data                => w_pdw_data,

    Buffered_frame_req      => w_frame_req,
    Buffered_frame_ack      => w_frame_ack,
    Buffered_frame_data     => w_frame_data,

    Error_fifo_overflow     => w_pdw_fifo_overflow,
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
            s_state <= S_ACTIVE;
          else
            s_state <= S_IDLE;
          end if;

        when S_ACTIVE =>
          if (r_dwell_active = '0') then
            s_state <= S_DWELL_DONE;
          else
            s_state <= S_ACTIVE;
          end if;

        when S_DWELL_STOP =>
          if (r_stop_wait_count = (DWELL_STOP_CYCLES - 1)) then
            s_state <= S_DWELL_DONE;
          else
            s_state <= S_DWELL_STOP;
          end if;

        when S_DWELL_DONE =>
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

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state /= S_DWELL_STOP) then
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

  w_dwell_done <= to_stdlogic(s_state = S_DWELL_DONE);

  i_reporter : entity esm_lib.esm_pdw_reporter
  generic map (
    AXI_DATA_WIDTH      => AXI_DATA_WIDTH,
    CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
    DATA_WIDTH          => IQ_WIDTH,
    MODULE_ID           => MODULE_ID
  )
  port map (
    Clk                 => Clk,
    Rst                 => r_rst,

    Dwell_done          => w_dwell_done,
    Dwell_data          => r_dwell_data,
    Dwell_sequence_num  => r_dwell_sequence_num,

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
    Axis_last           => Axis_last
  );

end architecture rtl;
