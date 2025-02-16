library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity synthesizer_16 is
generic (
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural
);
port (
  Clk                       : in  std_logic;
  Rst                       : in  std_logic;

  Input_ctrl                : in  synthesizer_control_t;
  Input_data                : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  Output_valid              : out std_logic;
  Output_active             : out std_logic;
  Output_data               : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  Error_stretcher_overflow  : out std_logic;
  Error_stretcher_underflow : out std_logic;
  Error_filter_overflow     : out std_logic;
  Error_mux_input_overflow  : out std_logic;
  Error_mux_fifo_overflow   : out std_logic;
  Error_mux_fifo_underflow  : out std_logic
);
end entity synthesizer_16;

architecture rtl of synthesizer_16 is

  constant NUM_CHANNELS : natural := 16;
  constant NUM_COEFS    : natural := 96;
  constant COEF_WIDTH   : natural := 20;
  constant COEF_DATA    : signed_array_t(NUM_COEFS - 1 downto 0)(COEF_WIDTH - 1 downto 0) := (
      0 => "11111111101110110001",   1 => "11111111110010110000",   2 => "11111111111011001101",   3 => "00000000001000110011",   4 => "00000000011011110101",   5 => "00000000110100010000",   6 => "00000001010001011101",   7 => "00000001110010010000",
      8 => "00000010010100111010",   9 => "00000010110111000100",  10 => "00000011010101110110",  11 => "00000011101101111110",  12 => "00000011111011111110",  13 => "00000011111100010010",  14 => "00000011101011100110",  15 => "00000011000111000111",
     16 => "00000010001100110001",  17 => "00000000111011100110",  18 => "11111111010011111010",  19 => "11111101010111100000",  20 => "11111011001001111000",  21 => "11111000110000001101",  22 => "11110110010001010110",  23 => "11110011110101101110",
     24 => "11110001100111000100",  25 => "11101111110000000110",  26 => "11101110011100001000",  27 => "11101101110110011111",  28 => "11101110001010000011",  29 => "11101111100000101001",  30 => "11110010000010011011",  31 => "11110101110101011001",
     32 => "11111010111100110111",  33 => "00000001011001001001",  34 => "00001001000111001101",  35 => "00010010000000100110",  36 => "00011011111011011100",  37 => "00100110101010101100",  38 => "00110001111110011011",  39 => "00111101100100010111",
     40 => "01001001001000100001",  41 => "01010100010101111001",  42 => "01011110110111011000",  43 => "01101000011000011101",  44 => "01110000100110001011",  45 => "01110111001111110101",  46 => "01111100000111110001",  47 => "01111111000011111000",
     48 => "01111111111110000100",  49 => "01111110110100100001",  50 => "01111011101001110001",  51 => "01110110100100100111",  52 => "01101111101111101110",  53 => "01100111011001010100",  54 => "01011101110010011011",  55 => "01010011001110010001",
     56 => "01001000000001011001",  57 => "00111100100000110110",  58 => "00110001000001010111",  59 => "00100101110110100100",  60 => "00011011010010001110",  61 => "00010001100011101011",  62 => "00001000110111011000",  63 => "00000001010110100011",
     64 => "11111011000111000000",  65 => "11110110001011001100",  66 => "11110010100010010101",  67 => "11110000001000101101",  68 => "11101110111000000001",  69 => "11101110100111111111",  70 => "11101111001110101111",  71 => "11110000100001100010",
     72 => "11110010010101001101",  73 => "11110100011110110010",  74 => "11110110110011111010",  75 => "11111001001011010010",  76 => "11111011011100111010",  77 => "11111101100010010111",  78 => "11111111010110111001",  79 => "00000000110111010111",
     80 => "00000010000010010000",  81 => "00000010110111011101",  82 => "00000011011000000111",  83 => "00000011100110010100",  84 => "00000011100100110111",  85 => "00000011010110111100",  86 => "00000010111111111110",  87 => "00000010100011001111",
     88 => "00000010000011110010",  89 => "00000001100100010000",  90 => "00000001000110110010",  91 => "00000000101100111001",  92 => "00000000010111100110",  93 => "00000000000111010101",  94 => "11111111111100000101",  95 => "11111111110101011100"
  );

begin

  i_synthesizer : entity dsp_lib.synthesizer_common
  generic map (
    INPUT_DATA_WIDTH  => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH,
    NUM_CHANNELS      => NUM_CHANNELS,
    NUM_COEFS         => NUM_COEFS,
    COEF_WIDTH        => COEF_WIDTH,
    COEF_DATA         => COEF_DATA
  )
  port map (
    Clk                       => Clk,
    Rst                       => Rst,


    Input_ctrl                => Input_ctrl,
    Input_data                => Input_data,

    Output_valid              => Output_valid,
    Output_active             => Output_active,
    Output_data               => Output_data,

    Error_stretcher_overflow  => Error_stretcher_overflow,
    Error_stretcher_underflow => Error_stretcher_underflow,
    Error_filter_overflow     => Error_filter_overflow,
    Error_mux_input_overflow  => Error_mux_input_overflow,
    Error_mux_fifo_overflow   => Error_mux_fifo_overflow,
    Error_mux_fifo_underflow  => Error_mux_fifo_underflow
  );

end architecture rtl;
