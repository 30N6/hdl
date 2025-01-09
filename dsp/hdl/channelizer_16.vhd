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
  constant NUM_COEFS    : natural := 192;
  constant COEF_WIDTH   : natural := 16;
  constant COEF_DATA    : signed_array_t(NUM_COEFS - 1 downto 0)(COEF_WIDTH - 1 downto 0) := (
      0 => "1111111111111111",   1 => "1111111111111111",   2 => "1111111111111111",   3 => "1111111111111110",   4 => "1111111111111110",   5 => "1111111111111111",   6 => "0000000000000000",   7 => "0000000000000001",
      8 => "0000000000000011",   9 => "0000000000000110",  10 => "0000000000001001",  11 => "0000000000001101",  12 => "0000000000010000",  13 => "0000000000010100",  14 => "0000000000010110",  15 => "0000000000010111",
     16 => "0000000000010110",  17 => "0000000000010011",  18 => "0000000000001100",  19 => "0000000000000010",  20 => "1111111111110101",  21 => "1111111111100101",  22 => "1111111111010011",  23 => "1111111111000000",
     24 => "1111111110101101",  25 => "1111111110011100",  26 => "1111111110001111",  27 => "1111111110001000",  28 => "1111111110001010",  29 => "1111111110010110",  30 => "1111111110101110",  31 => "1111111111010001",
     32 => "0000000000000000",  33 => "0000000000111001",  34 => "0000000001111010",  35 => "0000000010111111",  36 => "0000000100000100",  37 => "0000000101000010",  38 => "0000000101110100",  39 => "0000000110010011",
     40 => "0000000110011010",  41 => "0000000110000100",  42 => "0000000101001101",  43 => "0000000011110011",  44 => "0000000001111000",  45 => "1111111111011111",  46 => "1111111100101111",  47 => "1111111001110000",
     48 => "1111110110101111",  49 => "1111110011111001",  50 => "1111110001011101",  51 => "1111101111101100",  52 => "1111101110110010",  53 => "1111101110111110",  54 => "1111110000011001",  55 => "1111110011000111",
     56 => "1111110111001001",  57 => "1111111100010111",  58 => "0000000010100110",  59 => "0000001001100011",  60 => "0000010000110100",  61 => "0000010111111100",  62 => "0000011110011010",  63 => "0000100011101100",
     64 => "0000100111001111",  65 => "0000101000100110",  66 => "0000100111010110",  67 => "0000100011010000",  68 => "0000011100001100",  69 => "0000010010001110",  70 => "0000000101101010",  71 => "1111110110111110",
     72 => "1111100110110110",  73 => "1111010110001010",  74 => "1111000101111100",  75 => "1110110111010101",  76 => "1110101011100001",  77 => "1110100011101011",  78 => "1110100000111010",  79 => "1110100100001100",
     80 => "1110101110010001",  81 => "1110111111101010",  82 => "1111011000100001",  83 => "1111111000101110",  84 => "0000011111110000",  85 => "0001001100101111",  86 => "0001111110100001",  87 => "0010110011100101",
     88 => "0011101010010000",  89 => "0100100000101001",  90 => "0101010100110101",  91 => "0110000100111000",  92 => "0110101110111111",  93 => "0111010001100001",  94 => "0111101011001001",  95 => "0111111010110100",
     96 => "0111111111111100",  97 => "0111111010010100",  98 => "0111101010001010",  99 => "0111010000001000", 100 => "0110101101010001", 101 => "0110000010111101", 102 => "0101010010110011", 103 => "0100011110101000",
    104 => "0011101000011000", 105 => "0010110001111110", 106 => "0001111101010000", 107 => "0001001011111001", 108 => "0000011111010111", 109 => "1111111000110100", 110 => "1111011001000100", 111 => "1111000000100111",
    112 => "1110101111100101", 113 => "1110100101110000", 114 => "1110100010101000", 115 => "1110100101011100", 116 => "1110101101001110", 117 => "1110111000111000", 118 => "1111000111001111", 119 => "1111010111001000",
    120 => "1111100111011101", 121 => "1111110111001100", 122 => "0000000101100000", 123 => "0000010001101110", 124 => "0000011011011000", 125 => "0000100010001101", 126 => "0000100110001001", 127 => "0000100111010011",
    128 => "0000100101111100", 129 => "0000100010011110", 130 => "0000011101010101", 131 => "0000010111000100", 132 => "0000010000001011", 133 => "0000001001001011", 134 => "0000000010100000", 135 => "1111111100100001",
    136 => "1111110111100001", 137 => "1111110011101011", 138 => "1111110001000110", 139 => "1111101111110001", 140 => "1111101111100111", 141 => "1111110000011111", 142 => "1111110010001100", 143 => "1111110100100001",
    144 => "1111110111001110", 145 => "1111111010000110", 146 => "1111111100111011", 147 => "1111111111100001", 148 => "0000000001110001", 149 => "0000000011100100", 150 => "0000000100111000", 151 => "0000000101101011",
    152 => "0000000101111111", 153 => "0000000101111000", 154 => "0000000101011010", 155 => "0000000100101011", 156 => "0000000011110001", 157 => "0000000010110001", 158 => "0000000001110001", 159 => "0000000000110101",
    160 => "0000000000000000", 161 => "1111111111010101", 162 => "1111111110110101", 163 => "1111111110100000", 164 => "1111111110010101", 165 => "1111111110010011", 166 => "1111111110011010", 167 => "1111111110100101",
    168 => "1111111110110101", 169 => "1111111111000110", 170 => "1111111111011000", 171 => "1111111111101000", 172 => "1111111111110111", 173 => "0000000000000010", 174 => "0000000000001011", 175 => "0000000000010000",
    176 => "0000000000010011", 177 => "0000000000010100", 178 => "0000000000010011", 179 => "0000000000010001", 180 => "0000000000001110", 181 => "0000000000001011", 182 => "0000000000000111", 183 => "0000000000000101",
    184 => "0000000000000010", 185 => "0000000000000001", 186 => "0000000000000000", 187 => "1111111111111111", 188 => "1111111111111111", 189 => "1111111111111111", 190 => "1111111111111111", 191 => "1111111111111111"
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

    Warning_demux_gap     => Warning_demux_gap,
    Error_demux_overflow  => Error_demux_overflow,
    Error_filter_overflow => Error_filter_overflow,
    Error_mux_overflow    => Error_mux_overflow,
    Error_mux_underflow   => Error_mux_underflow,
    Error_mux_collision   => Error_mux_collision
  );

end architecture rtl;
