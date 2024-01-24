library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity channelizer_8 is
generic (
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural
);
port (
  Clk             : in  std_logic;
  Rst             : in  std_logic;

  Input_valid     : in  std_logic;
  Input_data      : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  Output_valid    : out std_logic;
  Output_index    : out unsigned(2 downto 0);
  Output_data     : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  Error_overflow  : out std_logic
);
end entity channelizer_8;

architecture rtl of channelizer_8 is

  constant NUM_CHANNELS         : natural := 8;
  constant CHANNEL_INDEX_WIDTH  : natural := clog2(NUM_CHANNELS);

  constant NUM_COEFS            : natural := 96;
  constant COEF_WIDTH           : natural := 18;
  constant FILTER_DATA_WIDTH    : natural := INPUT_DATA_WIDTH + clog2(NUM_COEFS / NUM_CHANNELS);
  constant FFT_DATA_WIDTH       : natural := FILTER_DATA_WIDTH + clog2(NUM_CHANNELS);

  constant COEF_DATA                : signed_array_t(NUM_COEFS - 1 downto 0)(COEF_WIDTH - 1 downto 0) := (
      0 => "111111111111111101",   1 => "111111111111111010",   2 => "111111111111111001",   3 => "111111111111111110",   4 => "000000000000001100",   5 => "000000000000100100",   6 => "000000000001000010",   7 => "000000000001011001",
      8 => "000000000001011010",   9 => "000000000000110001",  10 => "111111111111010101",  11 => "111111111101001010",  12 => "111111111010101110",  13 => "111111111000110110",  14 => "111111111000100011",  15 => "111111111010110010",
     16 => "000000000000000000",  17 => "000000000111110000",  18 => "000000010000011101",  19 => "000000010111100100",  20 => "000000011001111111",  21 => "000000010101000110",  22 => "000000000111101000",  23 => "111111110010101111",
     24 => "111111011010011010",  25 => "111111000101000010",  26 => "111110111010001111",  27 => "111111000000101111",  28 => "111111011100000101",  29 => "000000001010100001",  30 => "000001000100000100",  31 => "000001111011000100",
     32 => "000010011110101110",  33 => "000010011111000110",  34 => "000001110001111001",  35 => "000000010110110110",  36 => "111110011010011100",  37 => "111100010101110010",  38 => "111010101011011001",  39 => "111010000000111000",
     40 => "111010110110111100",  41 => "111101100001001010",  42 => "000001111111101000",  43 => "000111111100001011",  44 => "001110101100001001",  45 => "010101010110101101",  46 => "011010111110101011",  47 => "011110101101110000",
     48 => "011111111110111110",  49 => "011110100101110110",  50 => "011010110000110100",  51 => "010101000110010001",  52 => "001110011101000100",  53 => "000111110001111111",  54 => "000001111100100011",  55 => "111101100101100111",
     56 => "111011000001100001",  57 => "111010001110101111",  58 => "111010111001000111",  59 => "111100100000001100",  60 => "111110011111011000",  61 => "000000010101101001",  62 => "000001101011011000",  63 => "000010010101010011",
     64 => "000010010100010000",  65 => "000001110010011001",  66 => "000000111110111101",  67 => "000000001001101100",  68 => "111111011111000111",  69 => "111111000110011001",  70 => "111111000000110101",  71 => "111111001010111011",
     72 => "111111011110010111",  73 => "111111110100001101",  74 => "000000000110101111",  75 => "000000010010100001",  76 => "000000010110101010",  77 => "000000010100011000",  78 => "000000001110001000",  79 => "000000000110100110",
     80 => "000000000000000000",  81 => "111111111011101001",  82 => "111111111001110110",  83 => "111111111010001010",  84 => "111111111011101111",  85 => "111111111101101111",  86 => "111111111111011110",  87 => "000000000000100110",
     88 => "000000000001000100",  89 => "000000000001000010",  90 => "000000000000101111",  91 => "000000000000011001",  92 => "000000000000001000",  93 => "111111111111111111",  94 => "111111111111111100",  95 => "111111111111111101"
  );

  signal r_rst                : std_logic;

  signal w_demux_valid        : std_logic;
  signal w_demux_index        : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_demux_last         : std_logic;
  signal w_demux_data         : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  signal w_filter_valid       : std_logic;
  signal w_filter_index       : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_filter_last        : std_logic;
  signal w_filter_data        : signed_array_t(1 downto 0)(FILTER_DATA_WIDTH - 1 downto 0);
  signal w_filter_overflow    : std_logic;

  signal w_fft_input_control  : fft_control_t;
  signal w_fft_output_control : fft_control_t;
  signal w_fft_data           : signed_array_t(1 downto 0)(FFT_DATA_WIDTH - 1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst <= Rst;
    end if;
  end process;

  i_demux : entity dsp_lib.pfb_demux_2x
  generic map (
    CHANNEL_COUNT       => NUM_CHANNELS,  --TODO: consistent naming of generics
    CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
    DATA_WIDTH          => INPUT_DATA_WIDTH
  )
  port map (
    Clk             => Clk,
    Rst             => r_rst,

    Input_valid     => Input_valid,
    Input_i         => Input_data(0),
    Input_q         => Input_data(1),

    Output_valid    => w_demux_valid,
    Output_channel  => w_demux_index,
    Output_last     => w_demux_last,
    Output_i        => w_demux_data(0),
    Output_q        => w_demux_data(1)
  );

  i_filter : entity dsp_lib.pfb_filter
  generic map (
    NUM_CHANNELS        => NUM_CHANNELS,
    CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
    INPUT_DATA_WIDTH    => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH   => FILTER_DATA_WIDTH,
    COEF_WIDTH          => COEF_WIDTH,
    NUM_COEFS           => NUM_COEFS,
    COEF_DATA           => COEF_DATA
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

  w_fft_input_control.valid       <= w_filter_valid;
  w_fft_input_control.last        <= w_filter_last;
  w_fft_input_control.reverse     <= '1';
  w_fft_input_control.data_index  <= resize_up(w_filter_index, w_fft_input_control.data_index'length);
  w_fft_input_control.tag         <= (others => '0');

  i_ifft : entity dsp_lib.fft_pipelined
  generic map (
    NUM_POINTS        => NUM_CHANNELS,
    INDEX_WIDTH       => CHANNEL_INDEX_WIDTH,
    INPUT_DATA_WIDTH  => FILTER_DATA_WIDTH,
    OUTPUT_DATA_WIDTH => FFT_DATA_WIDTH
  )
  port map (
    Clk             => Clk,
    Rst             => r_rst,

    Input_control   => w_fft_input_control,
    Input_i         => w_filter_data(0),
    Input_q         => w_filter_data(1),

    Output_control  => w_fft_output_control,
    Output_i        => w_fft_data(0),
    Output_q        => w_fft_data(1)
  );

  i_baseband : entity dsp_lib.pfb_baseband_2x
  generic map (
    CHANNEL_INDEX_WIDTH => CHANNEL_INDEX_WIDTH,
    DATA_WIDTH          => FFT_DATA_WIDTH
  )
  port map (
    Clk           => Clk,

    Input_valid   => w_fft_output_control.valid,
    Input_index   => w_fft_output_control.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0),
    Input_data    => w_fft_data,

    Output_valid  => Output_valid,
    Output_index  => Output_index,
    Output_data   => Output_data
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_overflow <= w_filter_overflow;
    end if;
  end process;

end architecture rtl;
