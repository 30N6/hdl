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
  TWIDDLE_FRAC_WIDTH  : natural;
  LATENCY             : natural
);
port (
  Clk                     : in  std_logic;

  Input_i                 : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  Input_q                 : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  Input_twiddle_c         : in  signed(TWIDDLE_DATA_WIDTH - 1 downto 0);
  Input_twiddle_c_plus_d  : in  signed(TWIDDLE_DATA_WIDTH downto 0);
  Input_twiddle_d_minus_c : in  signed(TWIDDLE_DATA_WIDTH downto 0);

  Output_i                : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_q                : out signed(OUTPUT_DATA_WIDTH - 1 downto 0)
);
end entity fft_radix2_output;

architecture rtl of fft_radix2_output is

  constant K_WIDTH              : natural := INPUT_DATA_WIDTH + TWIDDLE_DATA_WIDTH + 1;
  constant OUTPUT_SCALED_WIDTH  : natural := K_WIDTH + 2; -- k + k + d

  signal r0_chan0_i             : signed(INPUT_DATA_WIDTH - 1 downto 0);
  signal r0_chan0_q             : signed(INPUT_DATA_WIDTH - 1 downto 0);
  signal r0_chan1_a             : signed(INPUT_DATA_WIDTH - 1 downto 0);
  signal r0_chan1_b             : signed(INPUT_DATA_WIDTH - 1 downto 0);
  signal r0_chan1_a_plus_b      : signed(INPUT_DATA_WIDTH downto 0);
  signal r0_chan1_c             : signed(TWIDDLE_DATA_WIDTH - 1 downto 0);
  signal r0_chan1_c_plus_d      : signed(TWIDDLE_DATA_WIDTH downto 0);
  signal r0_chan1_d_minus_c     : signed(TWIDDLE_DATA_WIDTH downto 0);

  signal r1_chan0_scaled_i      : signed(INPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH - 1 downto 0);
  signal r1_chan0_scaled_q      : signed(INPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH - 1 downto 0);
  signal r1_k1                  : signed(K_WIDTH - 1 downto 0); -- k1 = c * (a+b)
  signal r1_k2                  : signed(K_WIDTH - 1 downto 0); -- k2 = a * (d-c)
  signal r1_k3                  : signed(K_WIDTH - 1 downto 0); -- k3 = b * (c+d)

  signal r2_chan0_scaled_i      : signed(INPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH - 1 downto 0);
  signal r2_chan0_scaled_q      : signed(INPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH - 1 downto 0);
  signal r2_k1                  : signed(K_WIDTH - 1 downto 0);
  signal r2_k2                  : signed(K_WIDTH - 1 downto 0);
  signal r2_k3                  : signed(K_WIDTH - 1 downto 0);

  signal r3_chan0_scaled_i      : signed(INPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH - 1 downto 0);
  signal r3_chan0_scaled_q      : signed(INPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH - 1 downto 0);
  signal r3_k1                  : signed(K_WIDTH - 1 downto 0);
  signal r3_k2                  : signed(K_WIDTH - 1 downto 0);
  signal r3_k3                  : signed(K_WIDTH - 1 downto 0);

  signal r4_chan0_scaled_i      : signed(INPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH - 1 downto 0);
  signal r4_chan0_scaled_q      : signed(INPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH - 1 downto 0);
  signal r4_k1                  : signed(K_WIDTH - 1 downto 0);
  signal r4_k2                  : signed(K_WIDTH - 1 downto 0);
  signal r4_k3                  : signed(K_WIDTH - 1 downto 0);

  signal r5_chan0_scaled_i      : signed(INPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH - 1 downto 0);
  signal r5_chan0_scaled_q      : signed(INPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH - 1 downto 0);
  signal r5_k_sum_i             : signed(K_WIDTH downto 0);
  signal r5_k_sum_q             : signed(K_WIDTH downto 0);

  signal r6_output_scaled_i     : signed(OUTPUT_SCALED_WIDTH - 1 downto 0);
  signal r6_output_scaled_q     : signed(OUTPUT_SCALED_WIDTH - 1 downto 0);

begin

  assert (OUTPUT_DATA_WIDTH = (INPUT_DATA_WIDTH + 1))
    report "Invalid output width - expecting 1 bit of growth per stage."
    severity failure;

  assert (LATENCY = 8)
    report "Invalid latency."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_chan0_i          <= Input_i(0);
      r0_chan0_q          <= Input_q(0);

      r0_chan1_c          <= Input_twiddle_c;
      r0_chan1_a_plus_b   <= resize_up(Input_i(1), INPUT_DATA_WIDTH + 1) + Input_q(1);

      r0_chan1_a          <= Input_i(1);
      r0_chan1_d_minus_c  <= Input_twiddle_d_minus_c;

      r0_chan1_b          <= Input_q(1);
      r0_chan1_c_plus_d   <= Input_twiddle_c_plus_d;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_chan0_scaled_i <= shift_left(resize_up(r0_chan0_i, INPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH), TWIDDLE_FRAC_WIDTH);
      r1_chan0_scaled_q <= shift_left(resize_up(r0_chan0_q, INPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH), TWIDDLE_FRAC_WIDTH);
      r1_k1             <= r0_chan1_c * r0_chan1_a_plus_b;
      r1_k2             <= r0_chan1_a * r0_chan1_d_minus_c;
      r1_k3             <= r0_chan1_b * r0_chan1_c_plus_d;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_chan0_scaled_i <= r1_chan0_scaled_i;
      r2_chan0_scaled_q <= r1_chan0_scaled_q;
      r2_k1             <= r1_k1;
      r2_k2             <= r1_k2;
      r2_k3             <= r1_k3;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_chan0_scaled_i <= r2_chan0_scaled_i;
      r3_chan0_scaled_q <= r2_chan0_scaled_q;
      r3_k1             <= r2_k1;
      r3_k2             <= r2_k2;
      r3_k3             <= r2_k3;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r4_chan0_scaled_i <= r3_chan0_scaled_i;
      r4_chan0_scaled_q <= r3_chan0_scaled_q;
      r4_k1             <= r3_k1;
      r4_k2             <= r3_k2;
      r4_k3             <= r3_k3;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r5_chan0_scaled_i <= r4_chan0_scaled_i;
      r5_chan0_scaled_q <= r4_chan0_scaled_q;
      r5_k_sum_i        <= resize_up(r4_k1, K_WIDTH + 1) - r4_k3;
      r5_k_sum_q        <= resize_up(r4_k1, K_WIDTH + 1) + r4_k2;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r6_output_scaled_i  <= resize_up(r5_chan0_scaled_i, OUTPUT_SCALED_WIDTH) + r5_k_sum_i;
      r6_output_scaled_q  <= resize_up(r5_chan0_scaled_q, OUTPUT_SCALED_WIDTH) + r5_k_sum_q;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Output_i <= r6_output_scaled_i(OUTPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH - 1 downto TWIDDLE_FRAC_WIDTH);
      Output_q <= r6_output_scaled_q(OUTPUT_DATA_WIDTH + TWIDDLE_FRAC_WIDTH - 1 downto TWIDDLE_FRAC_WIDTH);
    end if;
  end process;

end architecture rtl;
