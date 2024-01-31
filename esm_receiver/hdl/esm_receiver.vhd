library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library clock_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library esm_lib;
  use esm_lib.esm_pkg.all;

entity esm_receiver is
generic (
  AXI_DATA_WIDTH  : natural;
  ADC_WIDTH       : natural;
  IQ_WIDTH        : natural
);
port (
  Adc_clk         : in  std_logic;
  Adc_rst         : in  std_logic;

  Ad9361_control  : out std_logic_vector(3 downto 0);
  Ad9361_status   : in  std_logic_vector(7 downto 0);

  Adc_valid       : in  std_logic;
  Adc_data_i      : in  signed(ADC_WIDTH - 1 downto 0);
  Adc_data_q      : in  signed(ADC_WIDTH - 1 downto 0);

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
end entity esm_receiver;

architecture rtl of esm_receiver is

  constant AXI_FIFO_DEPTH           : natural := 64;
  constant CHANNELIZER8_DATA_WIDTH  : natural := IQ_WIDTH + 3 + 3; -- +4 for filter, +3 for ifft
  constant CHANNELIZER64_DATA_WIDTH : natural := IQ_WIDTH + 4 + 6; -- +4 for filter, +6 for ifft

  constant AD9361_BIT_PIPE_DEPTH    : natural := 3;

  signal data_clk                     : std_logic;

  signal w_config_rst                 : std_logic;
  signal r_combined_rst               : std_logic;

  signal w_enable_chan                : std_logic_vector(1 downto 0);
  signal w_enable_pdw                 : std_logic_vector(1 downto 0);
  signal w_module_config              : esm_config_data_t;

  signal w_ad9361_control             : std_logic_vector(3 downto 0);
  signal r_ad9361_control             : std_logic_vector_array_t(AD9361_BIT_PIPE_DEPTH - 1 downto 0)(3 downto 0);
  signal r_ad9361_status              : std_logic_vector_array_t(AD9361_BIT_PIPE_DEPTH - 1 downto 0)(7 downto 0); --TODO: async reg

  signal w_dwell_active               : std_logic;
  signal w_dwell_data                 : esm_dwell_metadata_t;
  signal w_dwell_sequence_num         : unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);

  signal r_adc_valid                  : std_logic;
  signal r_adc_data_i                 : signed(IQ_WIDTH - 1 downto 0);
  signal r_adc_data_q                 : signed(IQ_WIDTH - 1 downto 0);

  signal w_adc_data_in                : signed_array_t(1 downto 0)(IQ_WIDTH - 1 downto 0);

  signal w_channelizer8_chan_control  : channelizer_control_t;
  signal w_channelizer8_chan_data     : signed_array_t(1 downto 0)(CHANNELIZER8_DATA_WIDTH - 1 downto 0);
  signal w_channelizer8_fft_control   : channelizer_control_t;
  signal w_channelizer8_fft_data      : signed_array_t(1 downto 0)(CHANNELIZER8_DATA_WIDTH - 1 downto 0);
  signal w_channelizer8_overflow      : std_logic;

  signal w_channelizer64_chan_control : channelizer_control_t;
  signal w_channelizer64_chan_data    : signed_array_t(1 downto 0)(CHANNELIZER64_DATA_WIDTH - 1 downto 0);
  signal w_channelizer64_fft_control  : channelizer_control_t;
  signal w_channelizer64_fft_data     : signed_array_t(1 downto 0)(CHANNELIZER64_DATA_WIDTH - 1 downto 0);
  signal w_channelizer64_overflow     : std_logic;

  signal r_test_8_chn                 : std_logic;
  signal r_test_8_fft                 : std_logic;
  signal r_test_64_chn                : std_logic;
  signal r_test_64_fft                : std_logic;
  signal r_test                       : std_logic;
  signal r_test_dwell                 : std_logic;

  signal w_reporter_axis_ready        : std_logic;
  signal w_reporter_axis_valid        : std_logic;
  signal w_reporter_axis_data         : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_reporter_axis_last         : std_logic;

  signal w_config_axis_ready          : std_logic;
  signal w_config_axis_valid          : std_logic;
  signal w_config_axis_data           : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_config_axis_last           : std_logic;

begin

  --TODO: use axi clock to generate 250 MHz
  --TODO: cdc fifo for adc data_clk -- limit max rate to 1/4
  --TODO: handle gaps in pfb -- need fifo-based design?
  i_clocking : entity clock_lib.adc_clk_mult
  port map (
    Clk_x1  => Adc_clk,
    reset   => Adc_rst,

    locked  => open,
    Clk_x2  => open,
    Clk_x4  => data_clk
  );

  process(data_clk)
  begin
    if rising_edge(data_clk) then
      r_combined_rst <= Adc_rst or w_config_rst;
    end if;
  end process;

  i_config : entity esm_lib.esm_config
  generic map (
    AXI_DATA_WIDTH => AXI_DATA_WIDTH
  )
  port map (
    Clk           => data_clk,
    Rst           => Adc_rst,

    Axis_ready    => w_config_axis_ready,
    Axis_valid    => w_config_axis_valid,
    Axis_last     => w_config_axis_last,
    Axis_data     => w_config_axis_data,

    Rst_out       => w_config_rst,
    Enable_chan   => w_enable_chan,
    Enable_pdw    => w_enable_pdw,

    Module_config => w_module_config
  );

  i_dwell_controller : entity esm_lib.esm_dwell_controller
  generic map (
    PLL_PRE_LOCK_DELAY_CYCLES   => 2048,
    PLL_POST_LOCK_DELAY_CYCLES  => 2048
  )
  port map (
    Clk                 => data_clk,
    Rst                 => r_combined_rst,

    Module_config       => w_module_config,

    Ad9361_control      => w_ad9361_control,
    Ad9361_status       => r_ad9361_status(AD9361_BIT_PIPE_DEPTH - 1),

    Dwell_active        => w_dwell_active,
    Dwell_data          => w_dwell_data,
    Dwell_sequence_num  => w_dwell_sequence_num
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
    end if;
  end process;

  w_adc_data_in <= (r_adc_data_q, r_adc_data_i);

  i_channelizer_8 : entity dsp_lib.channelizer_8
  generic map (
    INPUT_DATA_WIDTH  => IQ_WIDTH,
    OUTPUT_DATA_WIDTH => CHANNELIZER8_DATA_WIDTH
  )
  port map (
    Clk                   => data_clk,
    Rst                   => r_combined_rst,

    Input_valid           => r_adc_valid, --TODO: gated x4
    Input_data            => w_adc_data_in,

    Output_chan_ctrl      => w_channelizer8_chan_control,
    Output_chan_data      => w_channelizer8_chan_data,

    Output_fft_ctrl       => w_channelizer8_fft_control,
    Output_fft_data       => w_channelizer8_fft_data,

    Error_filter_overflow => w_channelizer8_overflow,
    Error_mux_overflow    => open,
    Error_mux_underflow   => open,
    Error_mux_collision   => open
  );

  i_channelizer_64 : entity dsp_lib.channelizer_64
  generic map (
    INPUT_DATA_WIDTH  => IQ_WIDTH,
    OUTPUT_DATA_WIDTH => CHANNELIZER64_DATA_WIDTH
  )
  port map (
    Clk                   => data_clk,
    Rst                   => r_combined_rst,

    Input_valid           => r_adc_valid, --TODO: gated
    Input_data            => w_adc_data_in,

    Output_chan_ctrl      => w_channelizer64_chan_control,
    Output_chan_data      => w_channelizer64_chan_data,

    Output_fft_ctrl       => w_channelizer64_fft_control,
    Output_fft_data       => w_channelizer64_fft_data,

    Error_filter_overflow => w_channelizer64_overflow,
    Error_mux_overflow    => open,
    Error_mux_underflow   => open,
    Error_mux_collision   => open
  );

  process(data_clk)
  begin
    if rising_edge(data_clk) then
      r_test_8_chn  <= w_channelizer8_chan_control.valid  or or_reduce(std_logic_vector(w_channelizer8_chan_control.data_index)  & std_logic_vector(w_channelizer8_chan_data(0))  & std_logic_vector(w_channelizer8_chan_data(1)))  or w_channelizer8_overflow;
      r_test_8_fft  <= w_channelizer8_fft_control.valid  or or_reduce(std_logic_vector(w_channelizer8_fft_control.data_index)  & std_logic_vector(w_channelizer8_fft_data(0))  & std_logic_vector(w_channelizer8_fft_data(1)));
      r_test_64_chn <= w_channelizer64_chan_control.valid or or_reduce(std_logic_vector(w_channelizer64_chan_control.data_index) & std_logic_vector(w_channelizer64_chan_data(0)) & std_logic_vector(w_channelizer64_chan_data(1))) or w_channelizer64_overflow;
      r_test_64_fft <= w_channelizer64_fft_control.valid or or_reduce(std_logic_vector(w_channelizer64_fft_control.data_index) & std_logic_vector(w_channelizer64_fft_data(0)) & std_logic_vector(w_channelizer64_fft_data(1)));
      r_test_dwell  <= w_dwell_active or or_reduce(w_dwell_data.tag) or or_reduce(w_dwell_data.frequency) or or_reduce(w_dwell_data.duration) or or_reduce(w_dwell_data.gain) or or_reduce(w_dwell_data.fast_lock_profile) or or_reduce(w_dwell_data.threshold_narrow) or or_reduce(w_dwell_data.threshold_wide) or or_reduce(w_dwell_data.channel_mask_narrow) or or_reduce(w_dwell_data.channel_mask_wide);
      r_test        <= r_test_8_chn or r_test_8_fft or r_test_64_chn or r_test_64_fft or r_test_dwell;
      --r_test <= w_channelizer_valid or or_reduce(std_logic_vector(w_channelizer_index) & std_logic_vector(w_channelizer_data(0)) & std_logic_vector(w_channelizer_data(1))) or w_channelizer_overflow;
    end if;
  end process;

  i_master_axis_fifo : entity axi_lib.axis_async_fifo
  generic map (
    FIFO_DEPTH      => AXI_FIFO_DEPTH,
    AXI_DATA_WIDTH  => AXI_DATA_WIDTH
  )
  port map (
    S_axis_clk      => data_clk,
    S_axis_resetn   => not(r_combined_rst),
    S_axis_ready    => w_reporter_axis_ready,
    S_axis_valid    => w_reporter_axis_valid,
    S_axis_data     => w_reporter_axis_data,
    S_axis_last     => w_reporter_axis_last,

    M_axis_clk      => M_axis_clk,
    M_axis_ready    => M_axis_ready,
    M_axis_valid    => M_axis_valid,
    M_axis_data     => M_axis_data,
    M_axis_last     => M_axis_last
  );

  i_slave_axis_fifo : entity axi_lib.axis_async_fifo
  generic map (
    FIFO_DEPTH      => AXI_FIFO_DEPTH,
    AXI_DATA_WIDTH  => AXI_DATA_WIDTH
  )
  port map (
    S_axis_clk      => S_axis_clk,
    S_axis_resetn   => S_axis_resetn,
    S_axis_ready    => S_axis_ready,
    S_axis_valid    => S_axis_valid,
    S_axis_data     => S_axis_data,
    S_axis_last     => S_axis_last,

    M_axis_clk      => data_clk,
    M_axis_ready    => w_config_axis_ready,
    M_axis_valid    => w_config_axis_valid,
    M_axis_data     => w_config_axis_data,
    M_axis_last     => w_config_axis_last
  );

  w_reporter_axis_valid <= r_test; --TODO
  w_reporter_axis_data  <= (others => '0');
  w_reporter_axis_last  <= '1';
  --w_config_axis_ready   <= ; --TODO --'1';

end architecture rtl;
