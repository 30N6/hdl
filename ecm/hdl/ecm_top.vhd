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
  constant ENABLE_SYNTHESIZER         : boolean := true;
  constant ENABLE_DWELL_STATS         : boolean := true;
  constant ENABLE_DRFM                : boolean := true;
  constant ENABLE_DEBUG               : boolean := false;

  constant AXI_FIFO_DEPTH             : natural := 64;  --TODO: increase?
  constant NUM_D2H_MUX_INPUTS         : natural := 3;
  constant CHANNELIZER16_DATA_WIDTH   : natural := IQ_WIDTH + 4 + 4; -- +4 for filter, +4 for ifft
  constant SYNTHESIZER16_DATA_WIDTH   : natural := 16;

  constant PLL_PRE_LOCK_DELAY_CYCLES  : natural := 2048;
  constant PLL_POST_LOCK_DELAY_CYCLES : natural := 2048;

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

  --signal w_dwell_active               : std_logic;
  --signal w_dwell_data                 : esm_dwell_metadata_t;
  --signal w_dwell_sequence_num         : unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);

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

  signal w_channelizer16_control      : channelizer_control_t;
  signal w_channelizer16_data         : signed_array_t(1 downto 0)(CHANNELIZER16_DATA_WIDTH - 1 downto 0);
  signal w_channelizer16_pwr          : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal w_synthesizer16_control      : channelizer_control_t;
  signal w_synthesizer16_data         : signed_array_t(1 downto 0)(SYNTHESIZER16_DATA_WIDTH - 1 downto 0);

  signal w_dds_command                : dds_control_t;
  signal w_dds_sync                   : channelizer_control_t;
  signal w_dds_control                : channelizer_control_t;
  signal w_dds_data                   : signed_array_t(1 downto 0)(ECM_DDS_OUTPUT_WIDTH - 1 downto 0)

  signal w_channelizer_warnings       : ecm_channelizer_warnings_t;
  signal w_channelizer_errors         : ecm_channelizer_errors_t;
  signal w_synthesizer_errors         : ecm_synthesizer_errors_t;
  signal w_dwell_stats_errors         : ecm_dwell_stats_errors_t;
  signal w_drfm_errors                : ecm_drfm_errors_t;

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
    Enable_synth  => w_enable_synth,

    Module_config => w_module_config
  );

  i_dwell_controller : entity ecm_lib.ecm_dwell_controller
  generic map (
    PLL_PRE_LOCK_DELAY_CYCLES   => PLL_PRE_LOCK_DELAY_CYCLES,
    PLL_POST_LOCK_DELAY_CYCLES  => PLL_POST_LOCK_DELAY_CYCLES
  )
  port map (
    Clk                 => Adc_clk_x4,
    Rst                 => r_combined_rst,

    Module_config       => w_module_config,

    Ad9361_control      => w_ad9361_control,
    Ad9361_status       => r_ad9361_status(AD9361_BIT_PIPE_DEPTH - 1),

    Dwell_active        => w_dwell_active,
    Dwell_data          => w_dwell_data,
    Dwell_sequence_num  => w_dwell_sequence_num,

    Dds_control         => w_dds_command,
    Drfm_control        => w_drfm_command

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

      Output_chan_ctrl      => w_channelizer16_control,
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
  else generate
    w_channelizer_warnings.demux_gap     <= '0';
    w_channelizer_errors.demux_overflow  <= '0';
    w_channelizer_errors.filter_overflow <= '0';
    w_channelizer_errors.mux_overflow    <= '0';
    w_channelizer_errors.mux_underflow   <= '0';
    w_channelizer_errors.mux_collision   <= '0';

    w_channelizer16_control <= (valid => '0', last => '0', data_index => (others => '0'));
    w_channelizer16_data    <= (others => (others => '0'));
    w_channelizer16_pwr     <= (others => '0');
  end generate g_channelizer;

  g_synthesizer : if (ENABLE_SYNTHESIZER) generate
    i_channelizer : entity dsp_lib.synthesizer_16
    generic map (
      INPUT_DATA_WIDTH  => SYNTHESIZER16_DATA_WIDTH,
      OUTPUT_DATA_WIDTH => IQ_WIDTH
    )
    port map (
      Clk                       => Adc_clk_x4,
      Rst                       => r_combined_rst,

      Input_ctrl                => w_synthesizer16_control,
      Input_data                => w_synthesizer16_data,

      Output_valid              => w_dac_valid_out,
      Output_data               => w_dac_data_out,

      Error_stretcher_overflow  => w_synthesizer_errors.stretcher_overflow,
      Error_stretcher_underflow => w_synthesizer_errors.stretcher_underflow,
      Error_filter_overflow     => w_synthesizer_errors.filter_overflow,
      Error_mux_input_overflow  => w_synthesizer_errors.mux_input_overflow,
      Error_mux_fifo_overflow   => w_synthesizer_errors.mux_fifo_overflow,
      Error_mux_fifo_underflow  => w_synthesizer_errors.mux_fifo_underflow
    );
  else generate
    w_synthesizer_errors.stretcher_overflow  <= '0';
    w_synthesizer_errors.stretcher_underflow <= '0';
    w_synthesizer_errors.filter_overflow     <= '0';
    w_synthesizer_errors.mux_input_overflow  <= '0';
    w_synthesizer_errors.mux_fifo_overflow   <= '0';
    w_synthesizer_errors.mux_fifo_underflo   <= '0';

    w_dac_valid_out <= '1';
    w_dac_data_out  <= (others => '0');
  end generate g_synthesizer;

  g_dwell_stats : if (ENABLE_DWELL_STATS) generate
    i_dwell_stats : entity ecm_lib.ecm_dwell_stats
    generic map (
      AXI_DATA_WIDTH  => AXI_DATA_WIDTH,
      DATA_WIDTH      => CHANNELIZER16_DATA_WIDTH,
      NUM_CHANNELS    => 16,
      MODULE_ID       => ECM_MODULE_ID_DWELL_STATS
    )
    port map (
      Clk_axi                 => M_axis_clk,
      Clk                     => Adc_clk_x4,
      Rst                     => r_combined_rst,

      Enable                  => w_enable_chan,

      Dwell_active            => w_dwell_active,    --TODO: measurement active
      Dwell_data              => w_dwell_data,
      Dwell_sequence_num      => w_dwell_sequence_num,

      Input_ctrl              => w_channelizer_chan_control,
      Input_data              => w_channelizer_chan_data,
      Input_pwr               => w_channelizer_chan_pwr,

      Axis_ready              => w_d2h_fifo_in_ready(0),
      Axis_valid              => w_d2h_fifo_in_valid(0),
      Axis_data               => w_d2h_fifo_in_data(0),
      Axis_last               => w_d2h_fifo_in_last(0),

      Error_reporter_timeout  => w_dwell_stats_errors.reporter_timeout,
      Error_reporter_overflow => w_dwell_stats_errors.reporter_overflow
    );
  else generate
    w_d2h_fifo_in_valid(0)  <= '0';
    w_d2h_fifo_in_data(0)   <= (others => '0');
    w_d2h_fifo_in_last(0)   <= '0';

    w_dwell_stats_errors.reporter_timeout  <= '0';
    w_dwell_stats_errors.reporter_overflow <= '0';
  end generate g_dwell_stats;

  g_drfm : if (ENABLE_DRFM) generate
    --i_drfm : entity ecm_lib.drfm
    --generic map (
    --  AXI_DATA_WIDTH  => AXI_DATA_WIDTH,
    --  DATA_WIDTH      => CHANNELIZER64_DATA_WIDTH,
    --  NUM_CHANNELS    => 64,
    --  MODULE_ID       => ESM_MODULE_ID_PDW_NARROW,
    --  WIDE_BANDWIDTH  => FALSE,
    --  DEBUG_ENABLE    => ENABLE_DEBUG
    --)
    --port map (
    --  Clk_axi                       => M_axis_clk,
    --  Clk                           => Adc_clk_x4,
    --  Rst                           => r_combined_rst,
    --
    --  Enable                        => w_enable_pdw(1),
    --
    --  Dwell_active                  => w_dwell_active,
    --  Dwell_data                    => w_dwell_data,
    --  Dwell_sequence_num            => w_dwell_sequence_num,
    --
    --  Input_ctrl                    => w_channelizer64_chan_control,
    --  Input_data                    => w_channelizer64_chan_data,
    --  Input_power                   => w_channelizer64_chan_pwr,
    --
    --  Axis_ready                    => w_d2h_fifo_in_ready(3),
    --  Axis_valid                    => w_d2h_fifo_in_valid(3),
    --  Axis_data                     => w_d2h_fifo_in_data(3),
    --  Axis_last                     => w_d2h_fifo_in_last(3),
    --
    --  Error_pdw_fifo_overflow       => w_pdw_encoder_errors(1).pdw_fifo_overflow,
    --  Error_pdw_fifo_underflow      => w_pdw_encoder_errors(1).pdw_fifo_underflow,
    --  Error_sample_buffer_busy      => w_pdw_encoder_errors(1).sample_buffer_busy,
    --  Error_sample_buffer_underflow => w_pdw_encoder_errors(1).sample_buffer_underflow,
    --  Error_sample_buffer_overflow  => w_pdw_encoder_errors(1).sample_buffer_overflow,
    --  Error_reporter_timeout        => w_pdw_encoder_errors(1).reporter_timeout,
    --  Error_reporter_overflow       => w_pdw_encoder_errors(1).reporter_overflow
    --);
  else generate
    w_d2h_fifo_in_valid(1)  <= '0';
    w_d2h_fifo_in_data(1)   <= (others => '0');
    w_d2h_fifo_in_last(1)   <= '0';

    w_drfm_errors.todo       <= '0';
  end generate g_drfm;

  i_dds : entity dsp_lib.channelized_dds
  generic map (
    OUTPUT_DATA_WIDTH   => ECM_DDS_OUTPUT_WIDTH,
    NUM_CHANNELS        => ECM_NUM_CHANNELS,
    CHANNEL_INDEX_WIDTH => ECM_CHANNEL_INDEX_WIDTH,
    LATENCY             => 7 --TODO
  )
  port map (
    Clk           => Adc_clk_x4,
    Rst           => r_combined_rst,

    Dwell_active  => w_dwell_active,  --TODO: right signal?
    Control_data  => w_dds_command,
    Sync_data     => w_dds_sync,

    Output_ctrl   => w_dds_control,
    Output_data   => w_dds_data
  );

  i_status_reporter : entity ecm_lib.ecm_status_reporter
  generic map (
    AXI_DATA_WIDTH        => AXI_DATA_WIDTH,
    MODULE_ID             => ECM_MODULE_ID_STATUS,
    HEARTBEAT_INTERVAL    => HEARTBEAT_INTERVAL
  )
  port map (
    Clk_axi               => M_axis_clk,
    Clk                   => Adc_clk_x4,
    Rst                   => r_combined_rst,

    Enable_status         => w_enable_status,
    Enable_channelizer    => w_enable_chan,
    Enable_synthesizer    => w_enable_synth,

    Channelizer_warnings  => w_channelizer_warnings,
    Channelizer_errors    => w_channelizer_errors,
    Synthesizer_errors    => w_synthesizer_errors,
    Dwell_stats_errors    => w_dwell_stats_errors,
    Drfm_errors           => w_drfm_errors,

    Axis_ready            => w_d2h_fifo_in_ready(2),
    Axis_valid            => w_d2h_fifo_in_valid(2),
    Axis_data             => w_d2h_fifo_in_data(2),
    Axis_last             => w_d2h_fifo_in_last(2)
  );

  --TODO: remove?
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
