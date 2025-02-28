library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity synthesizer_common is
generic (
  INPUT_DATA_WIDTH    : natural;
  OUTPUT_DATA_WIDTH   : natural;
  NUM_CHANNELS        : natural;
  NUM_COEFS           : natural;
  COEF_WIDTH          : natural;
  COEF_DATA           : signed_array_t(NUM_COEFS - 1 downto 0)(COEF_WIDTH - 1 downto 0)
);
port (
  Clk                       : in  std_logic;
  Rst                       : in  std_logic;

  Input_ctrl                : in  synthesizer_control_t;
  Input_data                : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  Output_valid              : out std_logic;
  Output_data               : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  Error_stretcher_overflow  : out std_logic;
  Error_stretcher_underflow : out std_logic;
  Error_filter_overflow     : out std_logic;
  Error_mux_input_overflow  : out std_logic;
  Error_mux_fifo_overflow   : out std_logic;
  Error_mux_fifo_underflow  : out std_logic
);
end entity synthesizer_common;

architecture rtl of synthesizer_common is

  constant CHANNEL_INDEX_WIDTH  : natural := clog2(NUM_CHANNELS);
  constant FFT_DATA_WIDTH       : natural := INPUT_DATA_WIDTH + clog2(NUM_CHANNELS);
  constant FILTER_DATA_WIDTH    : natural := FFT_DATA_WIDTH + clog2(NUM_COEFS / NUM_CHANNELS);

  signal r_rst                  : std_logic;

  signal w_input_shift_code     : unsigned(SYNTHESIZER_SHIFT_CODE_WIDTH - 1 downto 0);

  signal r_fft_input_control    : fft_control_t;
  signal r_fft_input_data       : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  signal w_fft_output_control   : fft_control_t;
  signal w_fft_output_data      : signed_array_t(1 downto 0)(FFT_DATA_WIDTH - 1 downto 0);

  signal w_stretched_control    : fft_control_t;
  signal w_stretched_data       : signed_array_t(1 downto 0)(FFT_DATA_WIDTH - 1 downto 0);
  signal w_stretcher_overflow   : std_logic;
  signal w_stretcher_underflow  : std_logic;

  signal w_filter_valid         : std_logic;
  signal w_filter_index         : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_filter_last          : std_logic;
  signal w_filter_tag           : unsigned(SYNTHESIZER_SHIFT_CODE_WIDTH downto 0);
  signal w_filter_data          : signed_array_t(1 downto 0)(FILTER_DATA_WIDTH - 1 downto 0);
  signal w_filter_overflow      : std_logic;

  signal w_mux_valid            : std_logic;
  signal w_mux_tag              : unsigned(SYNTHESIZER_SHIFT_CODE_WIDTH downto 0);
  signal w_mux_shift_code       : unsigned(SYNTHESIZER_SHIFT_CODE_WIDTH - 1 downto 0);
  signal w_mux_transmit_active  : std_logic;
  signal w_mux_data             : signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  signal r_output_valid         : std_logic;
  signal r_output_data          : signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  signal w_mux_input_overflow   : std_logic;
  signal w_mux_fifo_overflow    : std_logic;
  signal w_mux_fifo_underflow   : std_logic;

begin

  assert (OUTPUT_DATA_WIDTH = (FILTER_DATA_WIDTH + 1))
    report "Unexpected output data width -- must be INPUT_DATA_WIDTH + clog2(NUM_CHANNELS) + clog2(NUM_COEFS / NUM_CHANNELS) + 1"
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst <= Rst;
    end if;
  end process;

  w_input_shift_code <= to_unsigned(SYNTHESIZER_COUNT_TO_SHIFT_CODE(to_integer(Input_ctrl.active_channel_count)), SYNTHESIZER_SHIFT_CODE_WIDTH);

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_fft_input_control.valid       <= Input_ctrl.valid;
      r_fft_input_control.last        <= Input_ctrl.last;
      r_fft_input_control.data_index  <= Input_ctrl.data_index;
      r_fft_input_control.tag         <= resize_up(Input_ctrl.transmit_active & std_logic_vector(w_input_shift_code), FFT_TAG_WIDTH);
      r_fft_input_control.reverse     <= '0';
      r_fft_input_data                <= Input_data;
    end if;
  end process;

  i_fft : entity dsp_lib.fft_pipelined
  generic map (
    NUM_POINTS        => NUM_CHANNELS,
    INDEX_WIDTH       => CHANNEL_INDEX_WIDTH,
    INPUT_DATA_WIDTH  => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH => FFT_DATA_WIDTH,
    INPUT_PIPE_STAGES => 2
  )
  port map (
    Clk             => Clk,
    Rst             => r_rst,

    Input_control   => r_fft_input_control,
    Input_i         => r_fft_input_data(0),
    Input_q         => r_fft_input_data(1),

    Output_control  => w_fft_output_control,
    Output_i        => w_fft_output_data(0),
    Output_q        => w_fft_output_data(1)
  );

  i_stretcher : entity dsp_lib.fft_stretcher_2x
  generic map (
    FIFO_DEPTH  => NUM_CHANNELS,
    DATA_WIDTH  => FFT_DATA_WIDTH
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Input_control         => w_fft_output_control,
    Input_data            => w_fft_output_data,

    Output_control        => w_stretched_control,
    Output_data           => w_stretched_data,

    Error_fifo_overflow   => w_stretcher_overflow,
    Error_fifo_underflow  => w_stretcher_underflow
  );

  i_filter : entity dsp_lib.pfb_filter
  generic map (
    NUM_CHANNELS        => NUM_CHANNELS,
    CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
    INPUT_DATA_WIDTH    => FFT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH   => FILTER_DATA_WIDTH,
    TAG_WIDTH           => SYNTHESIZER_SHIFT_CODE_WIDTH + 1,
    COEF_WIDTH          => COEF_WIDTH,
    NUM_COEFS           => NUM_COEFS,
    COEF_DATA           => COEF_DATA,
    ANALYSIS_MODE       => false
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Input_valid           => w_stretched_control.valid,
    Input_index           => w_stretched_control.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0),
    Input_last            => w_stretched_control.last,
    Input_tag             => unsigned(w_stretched_control.tag(SYNTHESIZER_SHIFT_CODE_WIDTH downto 0)),
    Input_i               => w_stretched_data(0),
    Input_q               => w_stretched_data(1),

    Output_valid          => w_filter_valid,
    Output_index          => w_filter_index,
    Output_last           => w_filter_last,
    Output_tag            => w_filter_tag,
    Output_i              => w_filter_data(0),
    Output_q              => w_filter_data(1),

    Error_input_overflow  => w_filter_overflow
  );

  i_mux : entity dsp_lib.pfb_mux_2x
  generic map (
    NUM_CHANNELS        => NUM_CHANNELS,
    CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
    INPUT_WIDTH         => FILTER_DATA_WIDTH,
    TAG_WIDTH           => SYNTHESIZER_SHIFT_CODE_WIDTH + 1
  )
  port map (
    Clk                   => Clk,
    Rst                   => r_rst,

    Input_valid           => w_filter_valid,
    Input_channel         => w_filter_index,
    Input_last            => w_filter_last,
    Input_tag             => w_filter_tag,
    Input_i               => w_filter_data(0),
    Input_q               => w_filter_data(1),

    Output_valid          => w_mux_valid,
    Output_tag            => w_mux_tag,
    Output_i              => w_mux_data(0),
    Output_q              => w_mux_data(1),

    Error_input_overflow  => w_mux_input_overflow,
    Error_fifo_overflow   => w_mux_fifo_overflow,
    Error_fifo_underflow  => w_mux_fifo_underflow
  );

  w_mux_shift_code      <= w_mux_tag(SYNTHESIZER_SHIFT_CODE_WIDTH - 1 downto 0);
  w_mux_transmit_active <= w_mux_tag(SYNTHESIZER_SHIFT_CODE_WIDTH);

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_output_valid    <= w_mux_valid;

      if (w_mux_transmit_active = '1') then
        r_output_data(0)  <= shift_left(w_mux_data(0), (OUTPUT_DATA_WIDTH - INPUT_DATA_WIDTH) - SYNTHESIZER_SHIFT_MAP(to_integer(w_mux_shift_code)));
        r_output_data(1)  <= shift_left(w_mux_data(1), (OUTPUT_DATA_WIDTH - INPUT_DATA_WIDTH) - SYNTHESIZER_SHIFT_MAP(to_integer(w_mux_shift_code)));
      else
        r_output_data(0)  <= (others => '0');
        r_output_data(1)  <= (others => '0');
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Output_valid  <= r_output_valid;
      Output_data   <= r_output_data;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_stretcher_overflow  <= w_stretcher_overflow;
      Error_stretcher_underflow <= w_stretcher_underflow;
      Error_filter_overflow     <= w_filter_overflow;
      Error_mux_input_overflow  <= w_mux_input_overflow;
      Error_mux_fifo_overflow   <= w_mux_fifo_overflow;
      Error_mux_fifo_underflow  <= w_mux_fifo_underflow;
    end if;
  end process;

end architecture rtl;
