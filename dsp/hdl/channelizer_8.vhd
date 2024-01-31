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
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Input_valid           : in  std_logic;
  Input_data            : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  Output_chan_ctrl      : out channelizer_control_t;
  Output_chan_data      : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_chan_pwr       : out unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Output_fft_ctrl       : out channelizer_control_t;
  Output_fft_data       : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  Error_filter_overflow : out std_logic;
  Error_mux_overflow    : out std_logic;
  Error_mux_underflow   : out std_logic;
  Error_mux_collision   : out std_logic
);
end entity channelizer_8;

architecture rtl of channelizer_8 is

  constant NUM_CHANNELS   : natural := 8;
  constant NUM_COEFS      : natural := 64;
  constant COEF_WIDTH     : natural := 18;
  constant COEF_DATA      : signed_array_t(NUM_COEFS - 1 downto 0)(COEF_WIDTH - 1 downto 0) := (
      0 => "000000000000000000",   1 => "000000000000010110",   2 => "000000000001001000",   3 => "000000000010010010",   4 => "000000000011010110",   5 => "000000000011011100",   6 => "000000000001100001",   7 => "111111111100110101",
      8 => "111111110101100000",   9 => "111111101101000011",  10 => "111111100110100100",  11 => "111111100110001010",  12 => "111111101111101111",  13 => "000000000101001111",  14 => "000000100100110100",  15 => "000001000111111010",
     16 => "000001100011100000",  17 => "000001101010010100",  18 => "000001010000101010",  19 => "000000010001000011",  20 => "111110110000100001",  21 => "111101000000101101",  22 => "111011011111000000",  23 => "111010101111110001",
     24 => "111011010110100011",  25 => "111101101100101101",  26 => "000001111000111100",  27 => "000111101010010001",  28 => "001110011000000010",  29 => "010101000111110000",  30 => "011010110111110110",  31 => "011110101100111001",
     32 => "011111111110000101",  33 => "011110011110000111",  34 => "011010011110000100",  35 => "010100101001011000",  36 => "001101111100011111",  37 => "000111010111111011",  38 => "000001110011100000",  39 => "111101110100011101",
     40 => "111011101000100000",  41 => "111011000110101100",  42 => "111011110101000000",  43 => "111101010000110101",  44 => "111110110111111000",  45 => "000000001111010101",  46 => "000001000111110000",  47 => "000001011101100110",
     48 => "000001010110101000",  49 => "000000111101111000",  50 => "000000011111010010",  51 => "000000000100011001",  52 => "111111110010100100",  53 => "111111101011000000",  54 => "111111101011101100",  55 => "111111110001001011",
     56 => "111111110111111110",  57 => "111111111101101001",  58 => "000000000001000110",  59 => "000000000010011000",  60 => "000000000010001101",  61 => "000000000001011001",  62 => "000000000000100111",  63 => "000000000000001001"
  );

begin

  i_channelizer : entity dsp_lib.channelizer_common
  generic map (
    INPUT_DATA_WIDTH  => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH,
    NUM_CHANNELS      => NUM_CHANNELS,
    NUM_COEFS         => NUM_COEFS,
    COEF_WIDTH        => COEF_WIDTH,
    COEF_DATA         => COEF_DATA,
    FFT_PATH_ENABLE   => false
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

    Error_filter_overflow => Error_filter_overflow,
    Error_mux_overflow    => Error_mux_overflow,
    Error_mux_underflow   => Error_mux_underflow,
    Error_mux_collision   => Error_mux_collision
  );

end architecture rtl;
