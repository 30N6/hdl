library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity channelizer_16 is
generic (
  INPUT_DATA_WIDTH    : natural;
  OUTPUT_DATA_WIDTH   : natural;
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
end entity channelizer_16;

architecture rtl of channelizer_16 is

  constant NUM_CHANNELS : natural := 16;
  constant NUM_COEFS    : natural := 128;
  constant COEF_WIDTH   : natural := 16;
  constant COEF_DATA    : signed_array_t(NUM_COEFS - 1 downto 0)(COEF_WIDTH - 1 downto 0) := (
      0 => "0000000000000000",   1 => "0000000000000111",   2 => "0000000000010010",   3 => "0000000000100001",   4 => "0000000000110011",   5 => "0000000001001000",   6 => "0000000001011100",   7 => "0000000001101101",
      8 => "0000000001111001",   9 => "0000000001111100",  10 => "0000000001110010",  11 => "0000000001011001",  12 => "0000000000101111",  13 => "1111111111110010",  14 => "1111111110100101",  15 => "1111111101001001",
     16 => "1111111011100100",  17 => "1111111001111100",  18 => "1111111000011011",  19 => "1111110111001010",  20 => "1111110110010101",  21 => "1111110110000110",  22 => "1111110110100111",  23 => "1111111000000000",
     24 => "1111111010010110",  25 => "1111111101100111",  26 => "0000000001110000",  27 => "0000000110100110",  28 => "0000001011111010",  29 => "0000010001010110",  30 => "0000010110100000",  31 => "0000011010111101",
     32 => "0000011110001110",  33 => "0000011111110110",  34 => "0000011111011011",  35 => "0000011100101000",  36 => "0000010111010000",  37 => "0000001111010001",  38 => "0000000100110100",  39 => "1111111000001110",
     40 => "1111101010000011",  41 => "1111011011000011",  42 => "1111001100001001",  43 => "1110111110011001",  44 => "1110110010111100",  45 => "1110101010111110",  46 => "1110100111101000",  47 => "1110101001111101",
     48 => "1110110010110011",  49 => "1111000010110001",  50 => "1111011010001011",  51 => "1111111000111111",  52 => "0000011110110010",  53 => "0001001010110010",  54 => "0001111011111000",  55 => "0010110000100110",
     56 => "0011100111001101",  57 => "0100011101110101",  58 => "0101010010011101",  59 => "0110000011000100",  60 => "0110101101110001",  61 => "0111010000110111",  62 => "0111101010111000",  63 => "0111111010110010",
     64 => "0111111111111010",  65 => "0111111010000011",  66 => "0111101001011101",  67 => "0111001110110101",  68 => "0110101011010001",  69 => "0110000000010000",  70 => "0101001111011111",  71 => "0100011010111010",
     72 => "0011100100100000",  73 => "0010101110010001",  74 => "0001111010000100",  75 => "0001001001100101",  76 => "0000011110001111",  77 => "1111111001000111",  78 => "1111011010111101",  79 => "1111000100001000",
     80 => "1110110100101001",  81 => "1110101100001001",  82 => "1110101010000000",  83 => "1110101101011001",  84 => "1110110101010000",  85 => "1111000000011110",  86 => "1111001101111000",  87 => "1111011100010110",
     88 => "1111101010110111",  89 => "1111111000100001",  90 => "0000000100100111",  91 => "0000001110101000",  92 => "0000010110001111",  93 => "0000011011010100",  94 => "0000011101111011",  95 => "0000011110010001",
     96 => "0000011100101010",  97 => "0000011001100000",  98 => "0000010101010000",  99 => "0000010000010101", 100 => "0000001011001100", 101 => "0000000110001100", 102 => "0000000001101001", 103 => "1111111101110001",
    104 => "1111111010101111", 105 => "1111111000100110", 106 => "1111110111010101", 107 => "1111110110111000", 108 => "1111110111001000", 109 => "1111110111111010", 110 => "1111111001000110", 111 => "1111111010100000",
    112 => "1111111011111111", 113 => "1111111101011011", 114 => "1111111110101111", 115 => "1111111111110100", 116 => "0000000000101001", 117 => "0000000001001110", 118 => "0000000001100100", 119 => "0000000001101011",
    120 => "0000000001101000", 121 => "0000000001011101", 122 => "0000000001001101", 123 => "0000000000111011", 124 => "0000000000101010", 125 => "0000000000011010", 126 => "0000000000001110", 127 => "0000000000000101"
  );

begin

  i_channelizer : entity dsp_lib.channelizer_common
  generic map (
    INPUT_DATA_WIDTH    => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH   => OUTPUT_DATA_WIDTH,
    NUM_CHANNELS        => NUM_CHANNELS,
    NUM_COEFS           => NUM_COEFS,
    COEF_WIDTH          => COEF_WIDTH,
    COEF_DATA           => COEF_DATA,
    FFT_PATH_ENABLE     => false,
    BASEBANDING_ENABLE  => BASEBANDING_ENABLE
  )
  port map (
    Clk                   => Clk,
    Rst                   => Rst,

    Input_valid           => Input_valid,
    Input_data            => Input_data,

    Output_chan_ctrl      => Output_chan_ctrl,
    Output_chan_data      => Output_chan_data,
    Output_chan_pwr       => Output_chan_pwr,

    Output_fft_ctrl       => Output_fft_ctrl,
    Output_fft_data       => Output_fft_data,

    Warning_demux_gap     => Warning_demux_gap,
    Error_demux_overflow  => Error_demux_overflow,
    Error_filter_overflow => Error_filter_overflow,
    Error_mux_overflow    => Error_mux_overflow,
    Error_mux_underflow   => Error_mux_underflow,
    Error_mux_collision   => Error_mux_collision
  );

end architecture rtl;
