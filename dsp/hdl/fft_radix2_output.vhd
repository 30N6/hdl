library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

-- twiddle factor multiplication: (a+bi) * (c+di)
--    k1 = c * (a+b)
--    k2 = a * (d-c)
--    k3 = b * (c+d)
--    re = k1 - k3
--    im = k1 + k2

entity fft_radix2_output is
generic (
  INPUT_DATA_WIDTH    : natural;
  OUTPUT_DATA_WIDTH   : natural;
  TWIDDLE_DATA_WIDTH  : natural;
  DATA_INDEX_WIDTH    : natural;
  LATENCY             : natural
);
port (
  Clk                     : in  std_logic;

  Input_valid             : in  std_logic;
  Input_i                 : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  Input_q                 : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  Input_twiddle_c         : in  signed(TWIDDLE_DATA_WIDTH - 1 downto 0);
  Input_twiddle_c_plus_d  : in  signed(TWIDDLE_DATA_WIDTH downto 0);
  Input_twiddle_d_minus_c : in  signed(TWIDDLE_DATA_WIDTH downto 0);
  Input_index             : in  unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  Input_last              : in  std_logic;

  Output_valid            : out std_logic;
  Output_i                : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_q                : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_index            : out unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  Output_last             : out std_logic
);
end entity fft_radix2_output;

architecture rtl of fft_radix2_output is

  constant OUTPUT_SUM_WIDTH : natural := INPUT_DATA_WIDTH + TWIDDLE_DATA_WIDTH + 2;

  signal r0_valid           : std_logic;
  signal r0_index           : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal r0_last            : std_logic;
  signal r0_chan1_a         : signed(INPUT_DATA_WIDTH - 1 downto 0);
  signal r0_chan1_b         : signed(INPUT_DATA_WIDTH - 1 downto 0);
  signal r0_chan1_a_plus_b  : signed(INPUT_DATA_WIDTH downto 0);
  signal r0_chan1_c         : signed(TWIDDLE_DATA_WIDTH - 1 downto 0);
  signal r0_chan1_c_plus_d  : signed(TWIDDLE_DATA_WIDTH downto 0);
  signal r0_chan1_d_minus_c : signed(TWIDDLE_DATA_WIDTH downto 0);

  signal r1_valid           : std_logic;
  signal r1_index           : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal r1_last            : std_logic;
  signal r1_k1              : signed(INPUT_DATA_WIDTH + TWIDDLE_DATA_WIDTH downto 0); -- k1 = c * (a+b)
  signal r1_k2              : signed(INPUT_DATA_WIDTH + TWIDDLE_DATA_WIDTH downto 0); -- k2 = a * (d-c)
  signal r1_k3              : signed(INPUT_DATA_WIDTH + TWIDDLE_DATA_WIDTH downto 0); -- k3 = b * (c+d)

  signal r2_valid           : std_logic;
  signal r2_index           : unsigned(DATA_INDEX_WIDTH - 1 downto 0);
  signal r2_last            : std_logic;
  signal r2_output_i        : signed(OUTPUT_SUM_WIDTH - 1 downto 0);
  signal r2_output_q        : signed(OUTPUT_SUM_WIDTH - 1 downto 0);

begin

  assert (OUTPUT_DATA_WIDTH <= (INPUT_DATA_WIDTH + TWIDDLE_DATA_WIDTH + 2))
    report "Invalid output width."
    severity failure;

  assert (LATENCY = 3)
    report "Invalid latency."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_valid            <= Input_valid;
      r0_index            <= Input_index;
      r0_last             <= Input_last;

      r0_chan1_c          <= Input_twiddle_c;
      r0_chan1_a_plus_b   <= Input_i(1) + Input_q(1);

      r0_chan1_a          <= Input_i(1);
      r0_chan1_d_minus_c  <= Input_twiddle_d_minus_c;

      r0_chan1_b          <= Input_q(1);
      r0_chan1_c_plus_d   <= Input_twiddle_c_plus_d;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_valid  <= r0_valid;
      r1_index  <= r0_index;
      r1_last   <= r0_last;
      r1_k1     <= r0_chan1_c * r0_chan1_a_plus_b;
      r1_k2     <= r0_chan1_a * r0_chan1_d_minus_c;
      r1_k3     <= r0_chan1_b * r0_chan1_c_plus_d;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_valid    <= r1_valid;
      r2_index    <= r1_index;
      r2_last     <= r1_last;
      r2_output_i <= r1_k1 - r1_k3;
      r2_output_q <= r1_k1 + r1_k2;
    end if;
  end process;

  Output_valid <= r2_valid;
  Output_index <= r2_index;
  Output_i     <= r2_output_i(OUTPUT_SUM_WIDTH - 1 downto (OUTPUT_SUM_WIDTH - OUTPUT_DATA_WIDTH));
  Output_q     <= r2_output_q(OUTPUT_SUM_WIDTH - 1 downto (OUTPUT_SUM_WIDTH - OUTPUT_DATA_WIDTH));

end architecture rtl;
