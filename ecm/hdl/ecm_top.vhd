library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library clock_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;

entity ecm_top is
generic (
  AXI_DATA_WIDTH  : natural;
  ADC_WIDTH       : natural;
  DAC_WIDTH       : natural;
  IQ_WIDTH        : natural
);
port (
  Adc_clk         : in  std_logic;
  Adc_clk_x4      : in  std_logic;
  Adc_rst         : in  std_logic;

  Ad9361_control  : out std_logic_vector(3 downto 0);
  Ad9361_status   : in  std_logic_vector(7 downto 0);

  Adc_valid       : in  std_logic;
  Adc_data_i      : in  signed(ADC_WIDTH - 1 downto 0);
  Adc_data_q      : in  signed(ADC_WIDTH - 1 downto 0);

  Dac_data_i      : out signed(DAC_WIDTH - 1 downto 0);
  Dac_data_q      : out signed(DAC_WIDTH - 1 downto 0);

  S_axis_clk      : in  std_logic;
  S_axis_resetn   : in  std_logic;
  S_axis_ready    : out std_logic;
  S_axis_valid    : in  std_logic;
  S_axis_data     : in  std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  S_axis_last     : in  std_logic;

  M_axis_clk      : in  std_logic;
  M_axis_resetn   : in  std_logic;
  M_axis_ready    : in  std_logic;
  M_axis_valid    : out std_logic;
  M_axis_data     : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  M_axis_last     : out std_logic
);
end entity ecm_top;

architecture rtl of ecm_top is
  constant ENABLE_CHANNELIZER         : boolean := true;
  constant ENABLE_SYNTHESIZER         : boolean := false;
  constant ENABLE_DWELL_STATS         : boolean := true;
  constant ENABLE_DRFM                : boolean := true;
  constant ENABLE_DDS                 : boolean := false;
  constant ENABLE_STATUS_REPORTER     : boolean := false;

  constant NUM_D2H_MUX_INPUTS         : natural := 3;
  constant CHANNELIZER16_DATA_WIDTH   : natural := IQ_WIDTH + clog2(8) + clog2(ECM_NUM_CHANNELS); -- 8 taps per channel
  constant SYNTHESIZER16_OUTPUT_WIDTH : natural := ECM_SYNTHESIZER_DATA_WIDTH + clog2(ECM_NUM_CHANNELS) + clog2(6) + 1; -- 6 taps per channel

  constant SYNC_TO_DRFM_READ_LATENCY  : natural := 7;
  constant DRFM_READ_LATENCY          : natural := 5;
  constant DDS_LATENCY                : natural := 8;
  constant SYNC_LATENCY_DDS           : natural := DDS_LATENCY;
  constant SYNC_LATENCY_DRFM          : natural := SYNC_TO_DRFM_READ_LATENCY + DRFM_READ_LATENCY;

  constant AD9361_BIT_PIPE_DEPTH      : natural := 3;
  constant HEARTBEAT_INTERVAL         : natural := 31250000;

  signal w_clk_x4_p0                  : std_logic;

  signal w_config_rst                 : std_logic;
  signal r_combined_rst               : std_logic;

  signal w_enable_status              : std_logic;
  signal w_enable_chan                : std_logic;
  signal w_enable_synth               : std_logic;
  signal w_module_config              : ecm_config_data_t;

  signal w_ad9361_control             : std_logic_vector(3 downto 0);
  signal r_ad9361_control             : std_logic_vector_array_t(AD9361_BIT_PIPE_DEPTH - 1 downto 0)(3 downto 0);
  signal r_ad9361_status              : std_logic_vector_array_t(AD9361_BIT_PIPE_DEPTH - 1 downto 0)(7 downto 0);

  signal w_dwell_active               : std_logic;
  signal w_dwell_active_meas          : std_logic;
  signal w_dwell_active_tx            : std_logic;
  signal w_dwell_done                 : std_logic;
  signal w_dwell_data                 : ecm_dwell_entry_t;
  signal w_dwell_sequence_num         : unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  signal w_dwell_global_counter       : unsigned(ECM_DWELL_GLOBAL_COUNTER_WIDTH - 1 downto 0);
  signal w_dwell_program_tag          : unsigned(ECM_DWELL_TAG_WIDTH - 1 downto 0);
  signal w_dwell_stats_report_done    : std_logic;
  signal w_dwell_drfm_reports_done    : std_logic;

  signal r_adc_valid                  : std_logic;
  signal r_adc_data_i                 : signed(IQ_WIDTH - 1 downto 0);
  signal r_adc_data_q                 : signed(IQ_WIDTH - 1 downto 0);
  signal r_adc_valid_x4               : std_logic;
  signal r_adc_data_i_x4              : signed(IQ_WIDTH - 1 downto 0);
  signal r_adc_data_q_x4              : signed(IQ_WIDTH - 1 downto 0);
  signal w_adc_data_in                : signed_array_t(1 downto 0)(IQ_WIDTH - 1 downto 0);

  signal r_dac_data_i                 : signed(IQ_WIDTH - 1 downto 0);
  signal r_dac_data_q                 : signed(IQ_WIDTH - 1 downto 0);
  signal r_dac_data_i_x4              : signed(IQ_WIDTH - 1 downto 0);
  signal r_dac_data_q_x4              : signed(IQ_WIDTH - 1 downto 0);
  signal w_dac_data_out               : signed_array_t(1 downto 0)(IQ_WIDTH - 1 downto 0);
  signal w_dac_valid_out              : std_logic;

  signal w_channelizer16_ctrl         : channelizer_control_t;
  signal w_channelizer16_data         : signed_array_t(1 downto 0)(CHANNELIZER16_DATA_WIDTH - 1 downto 0);
  signal w_channelizer16_pwr          : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal w_stretched_ctrl             : channelizer_control_t;
  signal w_stretched_data             : signed_array_t(1 downto 0)(CHANNELIZER16_DATA_WIDTH - 1 downto 0);
  signal w_stretched_pwr              : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal w_synthesizer16_input_ctrl   : channelizer_control_t;
  signal w_synthesizer16_input_data   : signed_array_t(1 downto 0)(ECM_SYNTHESIZER_DATA_WIDTH - 1 downto 0);
  signal w_synthesizer16_output_valid : std_logic;
  signal w_synthesizer16_output_data  : signed_array_t(1 downto 0)(SYNTHESIZER16_OUTPUT_WIDTH - 1 downto 0);

  signal w_drfm_write_req             : ecm_drfm_write_req_t;
  signal w_drfm_read_req              : ecm_drfm_read_req_t;
  signal w_drfm_ctrl                  : channelizer_control_t;
  signal w_drfm_data                  : signed_array_t(1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);

  signal w_dds_command                : dds_control_t;
  signal w_dds_ctrl                   : channelizer_control_t;
  signal w_dds_data                   : signed_array_t(1 downto 0)(ECM_DDS_DATA_WIDTH - 1 downto 0);

  signal w_sync_to_dwell_controller   : channelizer_control_t;
  signal w_sync_to_dds                : channelizer_control_t;
  signal w_output_control             : ecm_output_control_t;

  signal w_channelizer_warnings       : ecm_channelizer_warnings_t;
  signal w_channelizer_errors         : ecm_channelizer_errors_t;
  signal w_synthesizer_errors         : ecm_synthesizer_errors_t;
  signal w_dwell_stats_errors         : ecm_dwell_stats_errors_t;
  signal w_drfm_errors                : ecm_drfm_errors_t;
  signal w_output_block_errors        : ecm_output_block_errors_t;
  signal w_dwell_controller_errors    : ecm_dwell_controller_errors_t;

  signal w_d2h_fifo_in_ready          : std_logic_vector(NUM_D2H_MUX_INPUTS - 1 downto 0);
  signal w_d2h_fifo_in_valid          : std_logic_vector(NUM_D2H_MUX_INPUTS - 1 downto 0);
  signal w_d2h_fifo_in_data           : std_logic_vector_array_t(NUM_D2H_MUX_INPUTS -1 downto 0)(AXI_DATA_WIDTH - 1 downto 0);
  signal w_d2h_fifo_in_last           : std_logic_vector(NUM_D2H_MUX_INPUTS - 1 downto 0);

  signal w_d2h_mux_in_ready           : std_logic_vector(NUM_D2H_MUX_INPUTS - 1 downto 0);
  signal w_d2h_mux_in_valid           : std_logic_vector(NUM_D2H_MUX_INPUTS - 1 downto 0);
  signal w_d2h_mux_in_data            : std_logic_vector_array_t(NUM_D2H_MUX_INPUTS -1 downto 0)(AXI_DATA_WIDTH - 1 downto 0);
  signal w_d2h_mux_in_last            : std_logic_vector(NUM_D2H_MUX_INPUTS - 1 downto 0);

  signal w_d2h_mux_out_ready          : std_logic;
  signal w_d2h_mux_out_valid          : std_logic;
  signal w_d2h_mux_out_data           : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_d2h_mux_out_last           : std_logic;

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of r_ad9361_status : signal is "TRUE";

begin

  i_phase_marker : entity common_lib.clk_x4_phase_marker
  port map (
    Clk       => Adc_clk,
    Clk_x4    => Adc_clk_x4,

    Clk_x4_p0 => w_clk_x4_p0,
    Clk_x4_p1 => open,
    Clk_x4_p2 => open,
    Clk_x4_p3 => open
  );

  process(Adc_clk_x4)
  begin
    if rising_edge(Adc_clk_x4) then
      r_combined_rst <= Adc_rst or w_config_rst;
    end if;
  end process;

  i_config : entity ecm_lib.ecm_config
  generic map (
    AXI_DATA_WIDTH => AXI_DATA_WIDTH
  )
  port map (
    Clk_x4        => Adc_clk_x4,

    S_axis_clk    => S_axis_clk,
    S_axis_resetn => S_axis_resetn,
    S_axis_ready  => S_axis_ready,
    S_axis_valid  => S_axis_valid,
    S_axis_data   => S_axis_data,
    S_axis_last   => S_axis_last,

    Rst_out       => w_config_rst,
    Enable_status => w_enable_status,
    Enable_chan   => w_enable_chan,
    Enable_synth  => w_enable_synth,  --TODO: use

    Module_config => w_module_config
  );

  i_sync : entity ecm_lib.ecm_sync_block
  generic map (
    DDS_LATENCY   => SYNC_LATENCY_DDS,
    DRFM_LATENCY  => SYNC_LATENCY_DRFM
  )
  port map (
    Clk                 => Adc_clk_x4,
    Rst                 => r_combined_rst,

    Sync_dds            => w_sync_to_dds,
    Sync_dwell_to_drfm  => w_sync_to_dwell_controller
  );

  i_dwell_controller : entity ecm_lib.ecm_dwell_controller
  generic map (
    SYNC_TO_DRFM_READ_LATENCY => SYNC_TO_DRFM_READ_LATENCY,
    CHANNELIZER_DATA_WIDTH    => CHANNELIZER16_DATA_WIDTH
  )
  port map (
    Clk_axi                       => M_axis_clk,
    Clk                           => Adc_clk_x4,
    Rst                           => r_combined_rst,

    Module_config                 => w_module_config,

    Ad9361_control                => w_ad9361_control,
    Ad9361_status                 => r_ad9361_status(AD9361_BIT_PIPE_DEPTH - 1),

    Channelizer_ctrl              => w_stretched_ctrl,
    Channelizer_data              => w_stretched_data,
    Channelizer_pwr               => w_stretched_pwr,

    Sync_data                     => w_sync_to_dwell_controller,

    Dwell_active                  => w_dwell_active,
    Dwell_active_measurement      => w_dwell_active_meas,
    Dwell_active_transmit         => w_dwell_active_tx,
    Dwell_done                    => w_dwell_done,
    Dwell_data                    => w_dwell_data,
    Dwell_sequence_num            => w_dwell_sequence_num,    --TODO: cleanup - wrap into metadata struct
    Dwell_global_counter          => w_dwell_global_counter,
    Dwell_program_tag             => w_dwell_program_tag,
    Dwell_report_done_drfm        => w_dwell_drfm_reports_done,
    Dwell_report_done_stats       => w_dwell_stats_report_done,

    Drfm_write_req                => w_drfm_write_req,
    Drfm_read_req                 => w_drfm_read_req,
    Dds_control                   => w_dds_command,
    Output_control                => w_output_control,

    Error_program_fifo_overflow   => w_dwell_controller_errors.program_fifo_overflow,
    Error_program_fifo_underflow  => w_dwell_controller_errors.program_fifo_underflow
  );

  process(Adc_clk)
  begin
    if rising_edge(Adc_clk) then
      r_ad9361_control <= r_ad9361_control(AD9361_BIT_PIPE_DEPTH - 2 downto 0)  & w_ad9361_control;
      r_ad9361_status  <= r_ad9361_status(AD9361_BIT_PIPE_DEPTH - 2 downto 0)   & Ad9361_status;
      Ad9361_control   <= r_ad9361_control(AD9361_BIT_PIPE_DEPTH - 1);
    end if;
  end process;

  process(Adc_clk)
  begin
    if rising_edge(Adc_clk) then
      r_adc_valid   <= Adc_valid;
      r_adc_data_i  <= Adc_data_i(ADC_WIDTH - 1 downto (ADC_WIDTH - IQ_WIDTH));
      r_adc_data_q  <= Adc_data_q(ADC_WIDTH - 1 downto (ADC_WIDTH - IQ_WIDTH));

      r_dac_data_i  <= r_dac_data_i_x4;
      r_dac_data_q  <= r_dac_data_q_x4;
    end if;
  end process;

  Dac_data_i <= shift_left(resize_up(r_dac_data_i, DAC_WIDTH), DAC_WIDTH - IQ_WIDTH);
  Dac_data_q <= shift_left(resize_up(r_dac_data_q, DAC_WIDTH), DAC_WIDTH - IQ_WIDTH);

  process(Adc_clk_x4)
  begin
    if rising_edge(Adc_clk_x4) then
      r_adc_valid_x4   <= r_adc_valid and w_clk_x4_p0;
      r_adc_data_i_x4  <= r_adc_data_i;
      r_adc_data_q_x4  <= r_adc_data_q;

      if (w_dac_valid_out = '1') then
        r_dac_data_i_x4 <= w_dac_data_out(0);
        r_dac_data_q_x4 <= w_dac_data_out(1);
      end if;
    end if;
  end process;

  w_adc_data_in <= (r_adc_data_q_x4, r_adc_data_i_x4);

  g_channelizer : if (ENABLE_CHANNELIZER) generate
    i_channelizer : entity dsp_lib.channelizer_16
    generic map (
      INPUT_DATA_WIDTH    => IQ_WIDTH,
      OUTPUT_DATA_WIDTH   => CHANNELIZER16_DATA_WIDTH,
      BASEBANDING_ENABLE  => false
    )
    port map (
      Clk                   => Adc_clk_x4,
      Rst                   => r_combined_rst,

      Input_valid           => r_adc_valid_x4,
      Input_data            => w_adc_data_in,

      Output_chan_ctrl      => w_channelizer16_ctrl,
      Output_chan_data      => w_channelizer16_data,
      Output_chan_pwr       => w_channelizer16_pwr,

      Output_fft_ctrl       => open,
      Output_fft_data       => open,

      Warning_demux_gap     => w_channelizer_warnings.demux_gap,
      Error_demux_overflow  => w_channelizer_errors.demux_overflow,
      Error_filter_overflow => w_channelizer_errors.filter_overflow,
      Error_mux_overflow    => w_channelizer_errors.mux_overflow,
      Error_mux_underflow   => w_channelizer_errors.mux_underflow,
      Error_mux_collision   => w_channelizer_errors.mux_collision
    );

    i_stretcher : entity dsp_lib.chan_stretcher_2x
    generic map (
      FIFO_DEPTH => ECM_NUM_CHANNELS,
      DATA_WIDTH => CHANNELIZER16_DATA_WIDTH
    )
    port map (
      Clk                   => Adc_clk_x4,
      Rst                   => r_combined_rst,

      Input_control         => w_channelizer16_ctrl,
      Input_data            => w_channelizer16_data,
      Input_pwr             => w_channelizer16_pwr,

      Output_control        => w_stretched_ctrl,
      Output_data           => w_stretched_data,
      Output_pwr            => w_stretched_pwr,

      Error_fifo_overflow   => w_channelizer_errors.stretcher_overflow,
      Error_fifo_underflow  => w_channelizer_errors.stretcher_underflow
    );

  else generate
    w_channelizer_warnings  <= (others => '0');
    w_channelizer_errors    <= (others => '0');
    w_stretched_ctrl        <= (valid => '0', last => '0', data_index => (others => '0'));
    w_stretched_data        <= (others => (others => '0'));
    w_stretched_pwr         <= (others => '0');
  end generate g_channelizer;

  g_synthesizer : if (ENABLE_SYNTHESIZER) generate
    i_synthesizer : entity dsp_lib.synthesizer_16
    generic map (
      INPUT_DATA_WIDTH  => ECM_SYNTHESIZER_DATA_WIDTH,
      OUTPUT_DATA_WIDTH => SYNTHESIZER16_OUTPUT_WIDTH
    )
    port map (
      Clk                       => Adc_clk_x4,
      Rst                       => r_combined_rst,

      Input_ctrl                => w_synthesizer16_input_ctrl,
      Input_data                => w_synthesizer16_input_data,

      Output_valid              => w_synthesizer16_output_valid,
      Output_data               => w_synthesizer16_output_data,

      Error_stretcher_overflow  => w_synthesizer_errors.stretcher_overflow,
      Error_stretcher_underflow => w_synthesizer_errors.stretcher_underflow,
      Error_filter_overflow     => w_synthesizer_errors.filter_overflow,
      Error_mux_input_overflow  => w_synthesizer_errors.mux_input_overflow,
      Error_mux_fifo_overflow   => w_synthesizer_errors.mux_fifo_overflow,
      Error_mux_fifo_underflow  => w_synthesizer_errors.mux_fifo_underflow
    );

    w_dac_valid_out   <= w_synthesizer16_output_valid;
    w_dac_data_out(0) <= w_synthesizer16_output_data(0)(SYNTHESIZER16_OUTPUT_WIDTH - 1 downto (SYNTHESIZER16_OUTPUT_WIDTH - IQ_WIDTH));
    w_dac_data_out(1) <= w_synthesizer16_output_data(1)(SYNTHESIZER16_OUTPUT_WIDTH - 1 downto (SYNTHESIZER16_OUTPUT_WIDTH - IQ_WIDTH));
  else generate
    w_synthesizer_errors  <= (others => '0');
    w_dac_valid_out       <= '1';
    w_dac_data_out        <= (others => (others => '0'));
  end generate g_synthesizer;

  g_dwell_stats : if (ENABLE_DWELL_STATS) generate
    i_dwell_stats : entity ecm_lib.ecm_dwell_stats
    generic map (
      AXI_DATA_WIDTH => AXI_DATA_WIDTH
    )
    port map (
      Clk_axi                   => M_axis_clk,
      Clk                       => Adc_clk_x4,
      Rst                       => r_combined_rst,

      Enable                    => w_enable_chan,

      Dwell_active              => w_dwell_active,
      Dwell_active_measurement  => w_dwell_active_meas,
      Dwell_active_transmit     => w_dwell_active_tx,
      Dwell_data                => w_dwell_data,
      Dwell_sequence_num        => w_dwell_sequence_num,
      Dwell_global_counter      => w_dwell_global_counter,
      Dwell_program_tag         => w_dwell_program_tag,
      Dwell_report_done         => w_dwell_stats_report_done,

      Input_ctrl                => w_stretched_ctrl,
      Input_pwr                 => w_stretched_pwr,

      Axis_ready                => w_d2h_fifo_in_ready(0),
      Axis_valid                => w_d2h_fifo_in_valid(0),
      Axis_data                 => w_d2h_fifo_in_data(0),
      Axis_last                 => w_d2h_fifo_in_last(0),

      Error_reporter_timeout    => w_dwell_stats_errors.reporter_timeout,
      Error_reporter_overflow   => w_dwell_stats_errors.reporter_overflow
    );
  else generate
    w_d2h_fifo_in_valid(0)  <= '0';
    w_d2h_fifo_in_data(0)   <= (others => '0');
    w_d2h_fifo_in_last(0)   <= '0';
    w_dwell_stats_errors    <= (others => '0');
  end generate g_dwell_stats;

  g_drfm : if (ENABLE_DRFM) generate
    i_drfm : entity ecm_lib.ecm_drfm
    generic map (
      AXI_DATA_WIDTH    => AXI_DATA_WIDTH,
      READ_LATENCY      => DRFM_READ_LATENCY
    )
    port map (
      Clk_axi                 => M_axis_clk,
      Clk                     => Adc_clk_x4,
      Rst                     => r_combined_rst,

      Dwell_active            => w_dwell_active,
      Dwell_active_transmit   => w_dwell_active_tx,
      Dwell_done              => w_dwell_done,
      Dwell_sequence_num      => w_dwell_sequence_num,
      Dwell_reports_done      => w_dwell_drfm_reports_done,

      Write_req               => w_drfm_write_req,
      Read_req                => w_drfm_read_req,

      Output_read             => open, --simulation only
      Output_ctrl             => w_drfm_ctrl,
      Output_data             => w_drfm_data,

      Axis_ready              => w_d2h_fifo_in_ready(1),
      Axis_valid              => w_d2h_fifo_in_valid(1),
      Axis_data               => w_d2h_fifo_in_data(1),
      Axis_last               => w_d2h_fifo_in_last(1),

      Error_ext_read_overflow => w_drfm_errors.ext_read_overflow,
      Error_int_read_overflow => w_drfm_errors.int_read_overflow,
      Error_invalid_read      => w_drfm_errors.invalid_read,
      Error_reporter_timeout  => w_drfm_errors.reporter_timeout,
      Error_reporter_overflow => w_drfm_errors.reporter_overflow
    );
  else generate
    w_dwell_drfm_reports_done <= '1';
    w_drfm_ctrl               <= (valid => '0', last => '0', data_index => (others => '0'));
    w_drfm_data               <= (others => (others => '0'));
    w_d2h_fifo_in_valid(1)    <= '0';
    w_d2h_fifo_in_data(1)     <= (others => '0');
    w_d2h_fifo_in_last(1)     <= '0';
    w_drfm_errors             <= (others => '0');
  end generate g_drfm;

  g_dds : if (ENABLE_DDS) generate
    i_dds : entity dsp_lib.channelized_dds
    generic map (
      OUTPUT_DATA_WIDTH   => ECM_DDS_DATA_WIDTH,
      NUM_CHANNELS        => ECM_NUM_CHANNELS,
      CHANNEL_INDEX_WIDTH => ECM_CHANNEL_INDEX_WIDTH,
      LATENCY             => DDS_LATENCY
    )
    port map (
      Clk                   => Adc_clk_x4,
      Rst                   => r_combined_rst,

      Dwell_active_transmit => w_dwell_active_tx,
      Control_data          => w_dds_command,
      Sync_data             => w_sync_to_dds,

      Output_ctrl           => w_dds_ctrl,
      Output_data           => w_dds_data
    );
  else generate
    w_dds_ctrl <= (valid => '0', last => '0', data_index => (others => '0'));
    w_dds_data <= (others => (others => '0'));
  end generate g_dds;

  i_output : entity ecm_lib.ecm_output_block
  generic map (
    ENABLE_DDS  => ENABLE_DDS,
    ENABLE_DRFM => ENABLE_DRFM
  )
  port map (
    Clk                       => Adc_clk_x4,
    Rst                       => r_combined_rst,

    Dwell_active_transmit     => w_dwell_active_tx,
    Output_control            => w_output_control,

    Dds_ctrl                  => w_dds_ctrl,
    Dds_data                  => w_dds_data,

    Drfm_ctrl                 => w_drfm_ctrl,
    Drfm_data                 => w_drfm_data,

    Synthesizer_ctrl          => w_synthesizer16_input_ctrl,
    Synthesizer_data          => w_synthesizer16_input_data,

    Error_dds_drfm_sync       => w_output_block_errors.dds_drfm_sync_mismatch
  );

  g_status_reporter : if (ENABLE_STATUS_REPORTER) generate
    i_status_reporter : entity ecm_lib.ecm_status_reporter
    generic map (
      AXI_DATA_WIDTH      => AXI_DATA_WIDTH,
      HEARTBEAT_INTERVAL  => HEARTBEAT_INTERVAL
    )
    port map (
      Clk_axi                 => M_axis_clk,
      Clk                     => Adc_clk_x4,
      Rst                     => r_combined_rst,

      Enable_status           => w_enable_status,
      Enable_channelizer      => w_enable_chan,
      Enable_synthesizer      => w_enable_synth,

      Channelizer_warnings    => w_channelizer_warnings,
      Channelizer_errors      => w_channelizer_errors,
      Synthesizer_errors      => w_synthesizer_errors,
      Dwell_stats_errors      => w_dwell_stats_errors,
      Drfm_errors             => w_drfm_errors,
      Output_block_errors     => w_output_block_errors,
      Dwell_controller_errors => w_dwell_controller_errors,

      Axis_ready              => w_d2h_fifo_in_ready(2),
      Axis_valid              => w_d2h_fifo_in_valid(2),
      Axis_data               => w_d2h_fifo_in_data(2),
      Axis_last               => w_d2h_fifo_in_last(2)
    );
  else generate
    w_d2h_fifo_in_valid(2)  <= '0';
    w_d2h_fifo_in_data(2)   <= (others => '0');
    w_d2h_fifo_in_last(2)   <= '0';
  end generate g_status_reporter;

  g_d2h_fifo : for i in 0 to (NUM_D2H_MUX_INPUTS - 1) generate
    i_fifo : entity axi_lib.axis_minififo
    generic map (
      AXI_DATA_WIDTH => AXI_DATA_WIDTH
    )
    port map (
      Clk           => M_axis_clk,
      Rst           => not(M_axis_resetn),

      S_axis_ready  => w_d2h_fifo_in_ready(i),
      S_axis_valid  => w_d2h_fifo_in_valid(i),
      S_axis_data   => w_d2h_fifo_in_data(i),
      S_axis_last   => w_d2h_fifo_in_last(i),

      M_axis_ready  => w_d2h_mux_in_ready(i),
      M_axis_valid  => w_d2h_mux_in_valid(i),
      M_axis_data   => w_d2h_mux_in_data(i),
      M_axis_last   => w_d2h_mux_in_last(i)
    );
  end generate g_d2h_fifo;

  i_d2h_mux : entity axi_lib.axis_mux
  generic map (
    NUM_INPUTS      => NUM_D2H_MUX_INPUTS,
    AXI_DATA_WIDTH  => AXI_DATA_WIDTH
  )
  port map (
    Clk             => M_axis_clk,
    Rst             => not(M_axis_resetn),

    S_axis_ready    => w_d2h_mux_in_ready,
    S_axis_valid    => w_d2h_mux_in_valid,
    S_axis_data     => w_d2h_mux_in_data,
    S_axis_last     => w_d2h_mux_in_last,

    M_axis_ready    => w_d2h_mux_out_ready,
    M_axis_valid    => w_d2h_mux_out_valid,
    M_axis_data     => w_d2h_mux_out_data,
    M_axis_last     => w_d2h_mux_out_last
  );

  i_mux_fifo : entity axi_lib.axis_minififo
  generic map (
    AXI_DATA_WIDTH => AXI_DATA_WIDTH
  )
  port map (
    Clk           => M_axis_clk,
    Rst           => not(M_axis_resetn),

    S_axis_ready  => w_d2h_mux_out_ready,
    S_axis_valid  => w_d2h_mux_out_valid,
    S_axis_data   => w_d2h_mux_out_data,
    S_axis_last   => w_d2h_mux_out_last,

    M_axis_ready  => M_axis_ready,
    M_axis_valid  => M_axis_valid,
    M_axis_data   => M_axis_data,
    M_axis_last   => M_axis_last
  );

end architecture rtl;
