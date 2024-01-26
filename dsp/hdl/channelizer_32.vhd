library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity channelizer_32 is
generic (
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural
);
port (
  Clk                 : in  std_logic;
  Rst                 : in  std_logic;

  Input_valid         : in  std_logic;
  Input_data          : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  Output_chan_control : out channelizer_control_t;
  Output_chan_data    : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  Output_fft_control  : out channelizer_control_t;
  Output_fft_data     : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  Error_overflow      : out std_logic
);
end entity channelizer_32;

architecture rtl of channelizer_32 is

  constant NUM_CHANNELS             : natural := 32;
  constant CHANNEL_INDEX_WIDTH      : natural := clog2(NUM_CHANNELS);

  constant NUM_COEFS                : natural := 384;
  constant COEF_WIDTH               : natural := 18;
  constant FILTER_DATA_WIDTH        : natural := INPUT_DATA_WIDTH + clog2(NUM_COEFS / NUM_CHANNELS);
  constant FFT_DATA_WIDTH           : natural := FILTER_DATA_WIDTH + clog2(NUM_CHANNELS);

  constant COEF_DATA                : signed_array_t(NUM_COEFS - 1 downto 0)(COEF_WIDTH - 1 downto 0) := (
      0 => "000000000000000000",   1 => "111111111111111110",   2 => "111111111111111011",   3 => "111111111111110111",   4 => "111111111111110011",   5 => "111111111111101110",   6 => "111111111111101001",   7 => "111111111111100011",
      8 => "111111111111011100",   9 => "111111111111010110",  10 => "111111111111001111",  11 => "111111111111001001",  12 => "111111111111000011",  13 => "111111111110111110",  14 => "111111111110111001",  15 => "111111111110110111",
     16 => "111111111110110101",  17 => "111111111110110110",  18 => "111111111110111000",  19 => "111111111110111101",  20 => "111111111111000101",  21 => "111111111111001111",  22 => "111111111111011101",  23 => "111111111111101101",
     24 => "000000000000000000",  25 => "000000000000010110",  26 => "000000000000101111",  27 => "000000000001001010",  28 => "000000000001100111",  29 => "000000000010000101",  30 => "000000000010100100",  31 => "000000000011000100",
     32 => "000000000011100011",  33 => "000000000100000001",  34 => "000000000100011101",  35 => "000000000100110110",  36 => "000000000101001011",  37 => "000000000101011011",  38 => "000000000101100110",  39 => "000000000101101001",
     40 => "000000000101100101",  41 => "000000000101011001",  42 => "000000000101000100",  43 => "000000000100100110",  44 => "000000000011111110",  45 => "000000000011001100",  46 => "000000000010010001",  47 => "000000000001001101",
     48 => "000000000000000000",  49 => "111111111110101011",  50 => "111111111101010000",  51 => "111111111011101111",  52 => "111111111010001010",  53 => "111111111000100011",  54 => "111111110110111101",  55 => "111111110101011000",
     56 => "111111110011111000",  57 => "111111110010011111",  58 => "111111110001010000",  59 => "111111110000001100",  60 => "111111101111010111",  61 => "111111101110110010",  62 => "111111101110100001",  63 => "111111101110100100",
     64 => "111111101110111110",  65 => "111111101111110000",  66 => "111111110000111011",  67 => "111111110010011111",  68 => "111111110100011101",  69 => "111111110110110100",  70 => "111111111001100011",  71 => "111111111100100111",
     72 => "000000000000000000",  73 => "000000000011101010",  74 => "000000000111100001",  75 => "000000001011100011",  76 => "000000001111101010",  77 => "000000010011110001",  78 => "000000010111110100",  79 => "000000011011101101",
     80 => "000000011111010110",  81 => "000000100010101001",  82 => "000000100101100010",  83 => "000000100111111001",  84 => "000000101001101010",  85 => "000000101010110000",  86 => "000000101011000111",  87 => "000000101010101010",
     88 => "000000101001010111",  89 => "000000100111001100",  90 => "000000100100000111",  91 => "000000100000001001",  92 => "000000011011010010",  93 => "000000010101100101",  94 => "000000001111000101",  95 => "000000000111110110",
     96 => "000000000000000000",  97 => "111111110111101000",  98 => "111111101110111000",  99 => "111111100101110111", 100 => "111111011100110000", 101 => "111111010011101110", 102 => "111111001010111100", 103 => "111111000010100110",
    104 => "111110111010111000", 105 => "111110110011111110", 106 => "111110101110000011", 107 => "111110101001010011", 108 => "111110100101110111", 109 => "111110100011111001", 110 => "111110100011100010", 111 => "111110100100111000",
    112 => "111110101000000000", 113 => "111110101100111101", 114 => "111110110011110001", 115 => "111110111100011010", 116 => "111111000110110101", 117 => "111111010010111100", 118 => "111111100000100111", 119 => "111111101111101101",
    120 => "000000000000000000", 121 => "000000010001010001", 122 => "000000100011010001", 123 => "000000110101101011", 124 => "000001001000001011", 125 => "000001011010011101", 126 => "000001101100001010", 127 => "000001111100111010",
    128 => "000010001100010111", 129 => "000010011010001000", 130 => "000010100101111000", 131 => "000010101111010001", 132 => "000010110101111111", 133 => "000010111001110000", 134 => "000010111010010100", 135 => "000010110111011111",
    136 => "000010110001000111", 137 => "000010100111000101", 138 => "000010011001011000", 139 => "000010001000000001", 140 => "000001110011000110", 141 => "000001011010110000", 142 => "000000111111010000", 143 => "000000100000111000",
    144 => "000000000000000000", 145 => "111111011101000011", 146 => "111110111000100001", 147 => "111110010010111110", 148 => "111101101101000000", 149 => "111101000111010000", 150 => "111100100010011010", 151 => "111011111111001100",
    152 => "111011011110010101", 153 => "111011000000100010", 154 => "111010100110100100", 155 => "111010010001001000", 156 => "111010000000111001", 157 => "111001110110100100", 158 => "111001110010101101", 159 => "111001110101110111",
    160 => "111010000000100011", 161 => "111010010011001000", 162 => "111010101101111011", 163 => "111011010001001001", 164 => "111011111100111011", 165 => "111100110001010000", 166 => "111101101110000010", 167 => "111110110011000100",
    168 => "000000000000000000", 169 => "000001010100011011", 170 => "000010101111110010", 171 => "000100010001011011", 172 => "000101111000100111", 173 => "000111100100100000", 174 => "001001010100001011", 175 => "001011000110101001",
    176 => "001100111010110111", 177 => "001110101111101101", 178 => "010000100100000101", 179 => "010010010110110101", 180 => "010100000110110010", 181 => "010101110010110011", 182 => "010111011001110001", 183 => "011000111010100101",
    184 => "011010010100010000", 185 => "011011100101110010", 186 => "011100101110010100", 187 => "011101101101000100", 188 => "011110100001010100", 189 => "011111001010100010", 190 => "011111101000001111", 191 => "011111111010000111",
    192 => "011111111111111101", 193 => "011111111001101101", 194 => "011111100111011011", 195 => "011111001001010110", 196 => "011110011111110001", 197 => "011101101011001011", 198 => "011100101100001000", 199 => "011011100011010101",
    200 => "011010010001100101", 201 => "011000110111101111", 202 => "010111010110110010", 203 => "010101101111110000", 204 => "010100000011101101", 205 => "010010010011110011", 206 => "010000100001001001", 207 => "001110101100111001",
    208 => "001100111000001110", 209 => "001011000100001111", 210 => "001001010010000011", 211 => "000111100010101011", 212 => "000101110111000111", 213 => "000100010000010010", 214 => "000010101111000001", 215 => "000001010100000010",
    216 => "000000000000000000", 217 => "111110110011011100", 218 => "111101101110110010", 219 => "111100110010010111", 220 => "111011111110010111", 221 => "111011010010111010", 222 => "111010101111111101", 223 => "111010010101011001",
    224 => "111010000011000000", 225 => "111001111000011110", 226 => "111001110101011010", 227 => "111001111001010101", 228 => "111010000011101011", 229 => "111010010011110110", 230 => "111010101001001101", 231 => "111011000011000011",
    232 => "111011100000101010", 233 => "111100000001010101", 234 => "111100100100010011", 235 => "111101001000110111", 236 => "111101101110010100", 237 => "111110010011111110", 238 => "111110111001001100", 239 => "111111011101011001",
    240 => "000000000000000000", 241 => "000000100000100011", 242 => "000000111110100111", 243 => "000001011001110100", 244 => "000001110001110111", 245 => "000010000110100010", 246 => "000010010111101011", 247 => "000010100101001101",
    248 => "000010101111000100", 249 => "000010110101010101", 250 => "000010111000000110", 251 => "000010110111011111", 252 => "000010110011101110", 253 => "000010101101000011", 254 => "000010100011101111", 255 => "000010011000000111",
    256 => "000010001010011111", 257 => "000001111011001110", 258 => "000001101010101011", 259 => "000001011001001100", 260 => "000001000111001001", 261 => "000000110100111001", 262 => "000000100010101111", 263 => "000000010001000001",
    264 => "000000000000000000", 265 => "111111101111111101", 266 => "111111100001000111", 267 => "111111010011101010", 268 => "111111000111110000", 269 => "111110111101100001", 270 => "111110110101000010", 271 => "111110101110010111",
    272 => "111110101001100001", 273 => "111110100110011110", 274 => "111110100101001011", 275 => "111110100101100011", 276 => "111110100111100000", 277 => "111110101010111001", 278 => "111110101111100101", 279 => "111110110101011011",
    280 => "111110111100001110", 281 => "111111000011110011", 282 => "111111001100000000", 283 => "111111010100100111", 284 => "111111011101011110", 285 => "111111100110011001", 286 => "111111101111001111", 287 => "111111110111110100",
    288 => "000000000000000000", 289 => "000000000111101011", 290 => "000000001110101111", 291 => "000000010101000110", 292 => "000000011010101010", 293 => "000000011111011001", 294 => "000000100011010001", 295 => "000000100110010000",
    296 => "000000101000011000", 297 => "000000101001101000", 298 => "000000101010000011", 299 => "000000101001101100", 300 => "000000101000100111", 301 => "000000100110111000", 302 => "000000100100100011", 303 => "000000100001101111",
    304 => "000000011110100001", 305 => "000000011010111101", 306 => "000000010111001011", 307 => "000000010011001110", 308 => "000000001111001110", 309 => "000000001011001110", 310 => "000000000111010100", 311 => "000000000011100011",
    312 => "000000000000000000", 313 => "111111111100101110", 314 => "111111111001101111", 315 => "111111110111000110", 316 => "111111110100110100", 317 => "111111110010111011", 318 => "111111110001011010", 319 => "111111110000010010",
    320 => "111111101111100010", 321 => "111111101111001001", 322 => "111111101111000110", 323 => "111111101111011000", 324 => "111111101111111011", 325 => "111111110000101111", 326 => "111111110001110001", 327 => "111111110010111110",
    328 => "111111110100010101", 329 => "111111110101110001", 330 => "111111110111010010", 331 => "111111111000110110", 332 => "111111111010011001", 333 => "111111111011111010", 334 => "111111111101010111", 335 => "111111111110101111",
    336 => "000000000000000000", 337 => "000000000001001010", 338 => "000000000010001011", 339 => "000000000011000100", 340 => "000000000011110011", 341 => "000000000100011001", 342 => "000000000100110110", 343 => "000000000101001001",
    344 => "000000000101010101", 345 => "000000000101011000", 346 => "000000000101010101", 347 => "000000000101001011", 348 => "000000000100111011", 349 => "000000000100100111", 350 => "000000000100001111", 351 => "000000000011110100",
    352 => "000000000011010111", 353 => "000000000010111010", 354 => "000000000010011011", 355 => "000000000001111110", 356 => "000000000001100001", 357 => "000000000001000101", 358 => "000000000000101100", 359 => "000000000000010101",
    360 => "000000000000000000", 361 => "111111111111101110", 362 => "111111111111011111", 363 => "111111111111010011", 364 => "111111111111001001", 365 => "111111111111000010", 366 => "111111111110111101", 367 => "111111111110111011",
    368 => "111111111110111011", 369 => "111111111110111100", 370 => "111111111110111111", 371 => "111111111111000011", 372 => "111111111111001000", 373 => "111111111111001110", 374 => "111111111111010100", 375 => "111111111111011010",
    376 => "111111111111100000", 377 => "111111111111100110", 378 => "111111111111101011", 379 => "111111111111110000", 380 => "111111111111110100", 381 => "111111111111111000", 382 => "111111111111111100", 383 => "111111111111111110"
  );

  signal r_rst                : std_logic;

  signal w_demux_valid          : std_logic;
  signal w_demux_index          : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_demux_last           : std_logic;
  signal w_demux_data           : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

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
      r_fft_filt_data               <= w_filter_data;

      r_fft_raw_control.valid       <= Input_valid;
      r_fft_raw_control.last        <= to_stdlogic(r_fft_raw_index = (2**CHANNEL_INDEX_WIDTH - 1));
      r_fft_raw_control.data_index  <= resize_up(r_fft_raw_index, r_fft_raw_control.data_index'length);
      r_fft_raw_data(0)             <= resize_up(Input_data(0), FILTER_DATA_WIDTH);
      r_fft_raw_data(1)             <= resize_up(Input_data(1), FILTER_DATA_WIDTH);
    end if;
  end process;

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

  Output_chan_control.valid      <= w_baseband_valid;
  Output_chan_control.data_index <= resize_up(w_baseband_index, Output_chan_control.data_index'length);
  Output_chan_control.last       <= w_baseband_last;
  Output_chan_data               <= w_baseband_data;

  Output_fft_control.valid      <= w_raw_output_valid;
  Output_fft_control.data_index <= w_fft_output_control.data_index;
  Output_fft_control.last       <= w_fft_output_control.last;
  Output_fft_data               <= w_fft_data;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_overflow <= w_filter_overflow;
    end if;
  end process;

end architecture rtl;
