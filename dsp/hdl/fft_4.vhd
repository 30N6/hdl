library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library mem_lib;

entity fft_4 is
generic (
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural;
  LATENCY           : natural
);
port (
  Clk             : in  std_logic;

  Input_control   : in  fft_control_t;
  Input_i         : in  signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  Input_q         : in  signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  Output_control  : out fft_control_t;
  Output_i        : out signed_array_t(3 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_q        : out signed_array_t(3 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0)
);
end entity fft_4;

architecture rtl of fft_4 is
  constant ACTUAL_OUTPUT_DATA_WIDTH : natural := minimum(INPUT_DATA_WIDTH + 2, OUTPUT_DATA_WIDTH);

  signal r0_input_resized_i    : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal r0_input_resized_q    : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal r0_input_i_inv        : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal r0_input_q_inv        : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal r0_input_i_x_plus_j   : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal r0_input_q_x_plus_j   : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal r0_input_i_x_minus_j  : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal r0_input_q_x_minus_j  : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);

  signal r1_output_i_0         : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal r1_output_q_0         : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal r1_output_i_1         : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal r1_output_q_1         : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal w1_output_i           : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal w1_output_q           : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);

  signal w1_output_trimmed_i   : signed_array_t(3 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  signal w1_output_trimmed_q   : signed_array_t(3 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  signal r_input_control      : fft_control_t;

begin

  assert (LATENCY = 2)
    report "LATENCY expected to be 2."
    severity failure;

  assert (OUTPUT_DATA_WIDTH >= INPUT_DATA_WIDTH)
    report "OUTPUT_DATA_WIDTH expected to be greater than or equal to INPUT_DATA_WIDTH."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      for i in 0 to 3 loop
        r0_input_resized_i(i)   <= resize_up(Input_i(i), INPUT_DATA_WIDTH + 2);
        r0_input_resized_q(i)   <= resize_up(Input_q(i), INPUT_DATA_WIDTH + 2);

        r0_input_i_inv(i)       <= invert_sign(resize_up(Input_i(i),  INPUT_DATA_WIDTH + 2), false);
        r0_input_q_inv(i)       <= invert_sign(resize_up(Input_q(i),  INPUT_DATA_WIDTH + 2), false);

        r0_input_i_x_plus_j(i)  <= invert_sign(resize_up(Input_q(i),  INPUT_DATA_WIDTH + 2), false);
        r0_input_q_x_plus_j(i)  <= resize_up(Input_i(i),              INPUT_DATA_WIDTH + 2);

        r0_input_i_x_minus_j(i) <= resize_up(Input_q(i),              INPUT_DATA_WIDTH + 2);
        r0_input_q_x_minus_j(i) <= invert_sign(resize_up(Input_i(i),  INPUT_DATA_WIDTH + 2), false);
      end loop;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_output_i_0(0)  <= r0_input_resized_i(0) + r0_input_resized_i(1);
      r1_output_q_0(0)  <= r0_input_resized_q(0) + r0_input_resized_q(1);
      r1_output_i_0(1)  <= r0_input_resized_i(0) + r0_input_i_x_minus_j(1);
      r1_output_q_0(1)  <= r0_input_resized_q(0) + r0_input_q_x_minus_j(1);
      r1_output_i_0(2)  <= r0_input_resized_i(0) + r0_input_i_inv(1);
      r1_output_q_0(2)  <= r0_input_resized_q(0) + r0_input_q_inv(1);
      r1_output_i_0(3)  <= r0_input_resized_i(0) + r0_input_i_x_plus_j(1);
      r1_output_q_0(3)  <= r0_input_resized_q(0) + r0_input_q_x_plus_j(1);

      r1_output_i_1(0)  <= r0_input_resized_i(2) + r0_input_resized_i(3);
      r1_output_q_1(0)  <= r0_input_resized_q(2) + r0_input_resized_q(3);
      r1_output_i_1(1)  <= r0_input_i_inv(2)     + r0_input_i_x_plus_j(3);
      r1_output_q_1(1)  <= r0_input_q_inv(2)     + r0_input_q_x_plus_j(3);
      r1_output_i_1(2)  <= r0_input_resized_i(2) + r0_input_i_inv(3);
      r1_output_q_1(2)  <= r0_input_resized_q(2) + r0_input_q_inv(3);
      r1_output_i_1(3)  <= r0_input_i_inv(2)     + r0_input_i_x_minus_j(3);
      r1_output_q_1(3)  <= r0_input_q_inv(2)     + r0_input_q_x_minus_j(3);
    end if;
  end process;

  process(all)
  begin
    for i in 0 to 3 loop
      w1_output_i(i) <= r1_output_i_0(i) + r1_output_i_1(i);
      w1_output_q(i) <= r1_output_q_0(i) + r1_output_q_1(i);
    end loop;
  end process;

  process(all)
  begin
    for i in 0 to 3 loop
      w1_output_trimmed_i(i) <= (others => '0');
      w1_output_trimmed_i(i)(OUTPUT_DATA_WIDTH - 1 downto (OUTPUT_DATA_WIDTH - ACTUAL_OUTPUT_DATA_WIDTH)) <= w1_output_i(i)(INPUT_DATA_WIDTH + 1 downto (INPUT_DATA_WIDTH + 2 - ACTUAL_OUTPUT_DATA_WIDTH));
      w1_output_trimmed_q(i) <= (others => '0');
      w1_output_trimmed_q(i)(OUTPUT_DATA_WIDTH - 1 downto (OUTPUT_DATA_WIDTH - ACTUAL_OUTPUT_DATA_WIDTH)) <= w1_output_q(i)(INPUT_DATA_WIDTH + 1 downto (INPUT_DATA_WIDTH + 2 - ACTUAL_OUTPUT_DATA_WIDTH));
    end loop;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_control <= Input_control;
      Output_control  <= r_input_control;
    end if;
  end process;

  Output_i <= w1_output_trimmed_i;
  Output_q <= w1_output_trimmed_q;

end architecture rtl;
