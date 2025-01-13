library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity channelizer_common is
generic (
  INPUT_DATA_WIDTH    : natural;
  OUTPUT_DATA_WIDTH   : natural;
  NUM_CHANNELS        : natural;
  NUM_COEFS           : natural;
  COEF_WIDTH          : natural;
  COEF_DATA           : signed_array_t(NUM_COEFS - 1 downto 0)(COEF_WIDTH - 1 downto 0);
  FFT_PATH_ENABLE     : boolean;
  BASEBANDING_ENABLE  : boolean
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Input_valid           : in  std_logic;
  Input_data            : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  Output_chan_ctrl      : out channelizer_control_t;
  Output_chan_data      : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_chan_pwr       : out unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Output_fft_ctrl       : out channelizer_control_t;
  Output_fft_data       : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  Warning_demux_gap     : out std_logic;
  Error_demux_overflow  : out std_logic;
  Error_filter_overflow : out std_logic;
  Error_mux_overflow    : out std_logic;
  Error_mux_underflow   : out std_logic;
  Error_mux_collision   : out std_logic
);
end entity channelizer_common;

architecture rtl of channelizer_common is

  constant CHANNEL_INDEX_WIDTH  : natural := clog2(NUM_CHANNELS);
  constant FILTER_DATA_WIDTH    : natural := INPUT_DATA_WIDTH + clog2(NUM_COEFS / NUM_CHANNELS);
  constant FFT_DATA_WIDTH       : natural := FILTER_DATA_WIDTH + clog2(NUM_CHANNELS);
  constant POWER_LATENCY        : natural := 4;

  signal r_rst                  : std_logic;

  signal w_demux_valid          : std_logic;
  signal w_demux_index          : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_demux_last           : std_logic;
  signal w_demux_data           : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal w_demux_overflow       : std_logic;
  signal w_demux_gap            : std_logic;

  signal w_filter_valid         : std_logic;
  signal w_filter_index         : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_filter_last          : std_logic;
  signal w_filter_data          : signed_array_t(1 downto 0)(FILTER_DATA_WIDTH - 1 downto 0);
  signal w_filter_overflow      : std_logic;

  signal r_fft_filt_control     : fft_control_t;
  signal r_fft_filt_data        : signed_array_t(1 downto 0)(FILTER_DATA_WIDTH - 1 downto 0);

  signal r_fft_raw_index        : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_fft_raw_control      : fft_control_t;
  signal r_fft_raw_data         : signed_array_t(1 downto 0)(FILTER_DATA_WIDTH - 1 downto 0);

  signal w_fft_mux_control      : fft_control_t;
  signal w_fft_mux_data         : signed_array_t(1 downto 0)(FILTER_DATA_WIDTH - 1 downto 0);

  signal w_fft_output_control   : fft_control_t;
  signal w_fft_data             : signed_array_t(1 downto 0)(FFT_DATA_WIDTH - 1 downto 0);

  signal w_chan_output_valid    : std_logic;
  signal w_raw_output_valid     : std_logic;

  signal w_baseband_valid       : std_logic;
  signal w_baseband_index       : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_baseband_last        : std_logic;
  signal w_baseband_data        : signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  signal r_baseband_valid       : std_logic_vector(POWER_LATENCY - 1 downto 0);
  signal r_baseband_index       : unsigned_array_t(POWER_LATENCY - 1 downto 0)(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_baseband_last        : std_logic_vector(POWER_LATENCY - 1 downto 0);
  signal r_baseband_data_i      : signed_array_t(POWER_LATENCY - 1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  signal r_baseband_data_q      : signed_array_t(POWER_LATENCY - 1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  signal w_channelizer_power    : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal w_mux_error_overflow   : std_logic;
  signal w_mux_error_underflow  : std_logic;
  signal w_mux_error_collision  : std_logic;

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst <= Rst;
    end if;
  end process;

  i_demux : entity dsp_lib.pfb_demux_2x
  generic map (
    NUM_CHANNELS        => NUM_CHANNELS,
    CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
    DATA_WIDTH          => INPUT_DATA_WIDTH
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Input_valid           => Input_valid,
    Input_i               => Input_data(0),
    Input_q               => Input_data(1),

    Output_valid          => w_demux_valid,
    Output_channel        => w_demux_index,
    Output_last           => w_demux_last,
    Output_i              => w_demux_data(0),
    Output_q              => w_demux_data(1),

    Error_input_overflow  => w_demux_overflow,
    Warning_input_gap     => w_demux_gap
  );

  i_filter : entity dsp_lib.pfb_filter
  generic map (
    NUM_CHANNELS        => NUM_CHANNELS,
    CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
    INPUT_DATA_WIDTH    => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH   => FILTER_DATA_WIDTH,
    COEF_WIDTH          => COEF_WIDTH,
    NUM_COEFS           => NUM_COEFS,
    COEF_DATA           => COEF_DATA,
    ANALYSIS_MODE       => true
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Input_valid           => w_demux_valid,
    Input_index           => w_demux_index,
    Input_last            => w_demux_last,
    Input_i               => w_demux_data(0),
    Input_q               => w_demux_data(1),

    Output_valid          => w_filter_valid,
    Output_index          => w_filter_index,
    Output_last           => w_filter_last,
    Output_i              => w_filter_data(0),
    Output_q              => w_filter_data(1),

    Error_input_overflow  => w_filter_overflow
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_fft_raw_index <= (others => '0');
      else
        if (Input_valid = '1') then
          r_fft_raw_index <= r_fft_raw_index + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_fft_filt_control.valid      <= w_filter_valid;
      r_fft_filt_control.last       <= w_filter_last;
      r_fft_filt_control.data_index <= resize_up(w_filter_index, r_fft_filt_control.data_index'length);
      r_fft_filt_control.reverse    <= '1';
      r_fft_filt_data               <= w_filter_data;

      r_fft_raw_control.valid       <= Input_valid;
      r_fft_raw_control.last        <= to_stdlogic(r_fft_raw_index = (2**CHANNEL_INDEX_WIDTH - 1));
      r_fft_raw_control.data_index  <= resize_up(r_fft_raw_index, r_fft_raw_control.data_index'length);
      r_fft_raw_control.reverse     <= '0';
      r_fft_raw_data(0)             <= resize_up(Input_data(0), FILTER_DATA_WIDTH);
      r_fft_raw_data(1)             <= resize_up(Input_data(1), FILTER_DATA_WIDTH);
    end if;
  end process;

  g_mux : if (FFT_PATH_ENABLE) generate
    i_mux : entity dsp_lib.fft_mux
    generic map (
      DATA_WIDTH          => FILTER_DATA_WIDTH,
      CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH
    )
    port map (
      Clk             => Clk,
      Rst             => r_rst,

      Input_chan_ctrl => r_fft_filt_control,
      Input_chan_data => r_fft_filt_data,

      Input_raw_ctrl  => r_fft_raw_control,
      Input_raw_data  => r_fft_raw_data,

      Output_ctrl     => w_fft_mux_control,
      Output_data     => w_fft_mux_data,

      Error_overflow  => w_mux_error_overflow,
      Error_underflow => w_mux_error_underflow,
      Error_collision => w_mux_error_collision
    );
  else generate
    w_fft_mux_control     <= r_fft_filt_control;
    w_fft_mux_data        <= r_fft_filt_data;
    w_mux_error_overflow  <= '0';
    w_mux_error_underflow <= '0';
    w_mux_error_collision <= '0';
  end generate g_mux;

  i_fft : entity dsp_lib.fft_pipelined
  generic map (
    NUM_POINTS        => NUM_CHANNELS,
    INDEX_WIDTH       => CHANNEL_INDEX_WIDTH,
    INPUT_DATA_WIDTH  => FILTER_DATA_WIDTH,
    OUTPUT_DATA_WIDTH => FFT_DATA_WIDTH
  )
  port map (
    Clk             => Clk,
    Rst             => r_rst,

    Input_control   => w_fft_mux_control,
    Input_i         => w_fft_mux_data(0),
    Input_q         => w_fft_mux_data(1),

    Output_control  => w_fft_output_control,
    Output_i        => w_fft_data(0),
    Output_q        => w_fft_data(1)
  );

  w_chan_output_valid <= w_fft_output_control.valid and w_fft_output_control.reverse;
  w_raw_output_valid  <= w_fft_output_control.valid and not(w_fft_output_control.reverse);

  g_baseband : if (BASEBANDING_ENABLE) generate
    i_baseband : entity dsp_lib.pfb_baseband_2x
    generic map (
      CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
      DATA_WIDTH          => FFT_DATA_WIDTH
    )
    port map (
      Clk           => Clk,

      Input_valid   => w_chan_output_valid,
      Input_index   => w_fft_output_control.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0),
      Input_last    => w_fft_output_control.last,
      Input_data    => w_fft_data,

      Output_valid  => w_baseband_valid,
      Output_index  => w_baseband_index,
      Output_last   => w_baseband_last,
      Output_data   => w_baseband_data
    );
  else generate
    w_baseband_valid  <= w_chan_output_valid;
    w_baseband_index  <= w_fft_output_control.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0);
    w_baseband_last   <= w_fft_output_control.last;
    w_baseband_data   <= w_fft_data;
  end generate g_baseband;

  i_power : entity dsp_lib.channelizer_power
  generic map (
    DATA_WIDTH  => FFT_DATA_WIDTH,
    LATENCY     => POWER_LATENCY
  )
  port map (
    Clk         => Clk,

    Input_data  => w_baseband_data,
    Output_data => w_channelizer_power
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_baseband_valid  <= r_baseband_valid(POWER_LATENCY - 2 downto 0)  & w_baseband_valid;
      r_baseband_index  <= r_baseband_index(POWER_LATENCY - 2 downto 0)  & w_baseband_index;
      r_baseband_last   <= r_baseband_last(POWER_LATENCY - 2 downto 0)   & w_baseband_last;
      r_baseband_data_i <= r_baseband_data_i(POWER_LATENCY - 2 downto 0) & w_baseband_data(0);
      r_baseband_data_q <= r_baseband_data_q(POWER_LATENCY - 2 downto 0) & w_baseband_data(1);
    end if;
  end process;

  Output_chan_ctrl.valid      <= r_baseband_valid(POWER_LATENCY - 1);
  Output_chan_ctrl.data_index <= resize_up(r_baseband_index(POWER_LATENCY - 1), Output_chan_ctrl.data_index'length);
  Output_chan_ctrl.last       <= r_baseband_last(POWER_LATENCY - 1);
  Output_chan_data(0)         <= r_baseband_data_i(POWER_LATENCY - 1);
  Output_chan_data(1)         <= r_baseband_data_q(POWER_LATENCY - 1);
  Output_chan_pwr             <= w_channelizer_power;

  g_raw_output : if (FFT_PATH_ENABLE) generate
    Output_fft_ctrl.valid       <= w_raw_output_valid;
    Output_fft_ctrl.data_index  <= w_fft_output_control.data_index;
    Output_fft_ctrl.last        <= w_fft_output_control.last;
    Output_fft_data             <= w_fft_data;
  else generate
    Output_fft_ctrl.valid       <= '0';
    Output_fft_ctrl.data_index  <= (others => '0');
    Output_fft_ctrl.last        <= '0';
    Output_fft_data             <= (others => (others => '0'));
  end generate;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Warning_demux_gap     <= w_demux_gap;
      Error_demux_overflow  <= w_demux_overflow;
      Error_filter_overflow <= w_filter_overflow;
      Error_mux_overflow    <= w_mux_error_overflow;
      Error_mux_underflow   <= w_mux_error_underflow;
      Error_mux_collision   <= w_mux_error_collision;
    end if;
  end process;

end architecture rtl;
