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

  constant CHANNEL_INDEX_WIDTH        : natural := clog2(NUM_CHANNELS);
  constant THRESHOLD_LATENCY          : natural := 5;
  constant THRESHOLD_WAIT_CYCLES      : natural := 128;
  constant IQ_WIDTH                   : natural := 16;
  constant IQ_DELAY                   : natural := 8;
  constant BUFFERED_SAMPLES_PER_FRAME : natural := 40;
  constant BUFFERED_SAMPLE_PADDING    : natural := 4;
  constant PDW_FIFO_DEPTH             : natural := 32;

  type state_t is
  (
    S_IDLE,
    S_THRESHOLD_WAIT,
    S_ACTIVE,
    S_DWELL_DONE,
    S_FLUSH_REPORTS
  );

  signal r_rst                      : std_logic;
  signal r_enable                   : std_logic;

  signal s_state                    : state_t;
  signal r_threshold_wait_count     : unsigned(clog2(THRESHOLD_WAIT_CYCLES) - 1 downto 0);

  signal r_dwell_active             : std_logic;
  signal r_dwell_data               : esm_dwell_metadata_t;
  signal r_dwell_sequence_num       : unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);

  signal w_iq_scaled                : signed_array_t(1 downto 0)(IQ_WIDTH - 1 downto 0);
  signal w_threshold_factor         : unsigned(ESM_THRESHOLD_FACTOR_WIDTH - 1 downto 0);

  signal w_piped_ctrl               : channelizer_control_t;
  --signal w_piped_data               : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);  --TODO: IFM?
  signal w_piped_pwr                : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal w_piped_threshold          : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal w_delayed_iq_ctrl          : channelizer_control_t;
  signal w_delayed_iq_data          : signed_array_t(1 downto 0)(IQ_WIDTH - 1 downto 0);

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

    Input_ctrl              => w_piped_ctrl
    Input_iq_delayed        => w_delayed_iq_data,
    Input_pwr               => w_piped_pwr,
    Input_threshold         => w_piped_threshold,

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
            s_state <= S_THRESHOLD_WAIT;
          else
            s_state <= S_IDLE;
          end if;

        when S_THRESHOLD_WAIT =>
          if (r_threshold_wait_count = (THRESHOLD_WAIT_CYCLES - 1)) then
            s_state <= S_ACTIVE;
          else
            s_state <= S_THRESHOLD_WAIT;
          end if;

        when S_ACTIVE =>
          if (r_dwell_active = '0') then
            s_state <= S_DWELL_DONE;
          else
            s_state <= S_ACTIVE;
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
      if (s_state /= S_THRESHOLD_WAIT) then
        r_threshold_wait_count <= (others => '0');
      else
        r_threshold_wait_count <= r_threshold_wait_count + 1;
      end if;
    end if;
  end process;

  w_dwell_done <= to_stdlogic(s_state = S_DWELL_DONE);

  i_reporter : entity esm_lib.esm_dwell_reporter
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
