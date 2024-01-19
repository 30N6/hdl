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

  Input_control   : in  fft32_control_t;
  Input_i         : in  signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  Input_q         : in  signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  Output_control  : out fft32_control_t;
  Output_i        : out signed_array_t(3 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_q        : out signed_array_t(3 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0)
);
end entity fft_4;

architecture rtl of fft_4 is
  constant ACTUAL_OUTPUT_DATA_WIDTH : natural := minimum(INPUT_DATA_WIDTH + 2, OUTPUT_DATA_WIDTH);

  signal w_input_resized_i    : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal w_input_resized_q    : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);

  signal w_input_i_inv        : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal w_input_q_inv        : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal w_input_i_x_plus_j   : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal w_input_q_x_plus_j   : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal w_input_i_x_minus_j  : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal w_input_q_x_minus_j  : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);

  signal w_output_i           : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal w_output_q           : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH + 1 downto 0);
  signal w_output_trimmed_i   : signed_array_t(3 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  signal w_output_trimmed_q   : signed_array_t(3 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

begin

  assert ((LATENCY = 0) or (LATENCY = 1))
    report "LATENCY expected to be 0 or 1."
    severity failure;

  assert (OUTPUT_DATA_WIDTH >= INPUT_DATA_WIDTH)
    report "OUTPUT_DATA_WIDTH expected to be greater than or equal to INPUT_DATA_WIDTH."
    severity failure;

  process(all)
  begin
    for i in 0 to 3 loop
      w_input_resized_i(i)    <= resize_up(Input_i(i), INPUT_DATA_WIDTH + 2);
      w_input_resized_q(i)    <= resize_up(Input_q(i), INPUT_DATA_WIDTH + 2);

      w_input_i_inv(i)        <= resize_up(invert_sign(Input_i(i)), INPUT_DATA_WIDTH + 2);
      w_input_q_inv(i)        <= resize_up(invert_sign(Input_q(i)), INPUT_DATA_WIDTH + 2);

      w_input_i_x_plus_j(i)   <= resize_up(invert_sign(Input_q(i)), INPUT_DATA_WIDTH + 2);
      w_input_q_x_plus_j(i)   <= resize_up(Input_i(i),              INPUT_DATA_WIDTH + 2);

      w_input_i_x_minus_j(i)  <= resize_up(Input_q(i),              INPUT_DATA_WIDTH + 2);
      w_input_q_x_minus_j(i)  <= resize_up(invert_sign(Input_i(i)), INPUT_DATA_WIDTH + 2);
    end loop;
  end process;

  w_output_i(0) <= w_input_resized_i(0) + w_input_resized_i(1)  +  w_input_resized_i(2) +  w_input_resized_i(3);
  w_output_q(0) <= w_input_resized_q(0) + w_input_resized_q(1)  +  w_input_resized_q(2) +  w_input_resized_q(3);

  w_output_i(1) <= w_input_resized_i(0) + w_input_i_x_minus_j(1)  + w_input_i_inv(2)  + w_input_i_x_plus_j(3);
  w_output_q(1) <= w_input_resized_q(0) + w_input_q_x_minus_j(1)  + w_input_q_inv(2)  + w_input_q_x_plus_j(3);

  w_output_i(2) <= w_input_resized_i(0) + w_input_i_inv(1)        + w_input_resized_i(2)        + w_input_i_inv(3);
  w_output_q(2) <= w_input_resized_q(0) + w_input_q_inv(1)        + w_input_resized_q(2)        + w_input_q_inv(3);

  w_output_i(3) <= w_input_resized_i(0) + w_input_i_x_plus_j(1)   + w_input_i_inv(2)  + w_input_i_x_minus_j(3);
  w_output_q(3) <= w_input_resized_q(0) + w_input_q_x_plus_j(1)   + w_input_q_inv(2)  + w_input_q_x_minus_j(3);

  process(all)
  begin
    for i in 0 to 3 loop
      w_output_trimmed_i(i) <= (others => '0');
      w_output_trimmed_i(i)(OUTPUT_DATA_WIDTH - 1 downto (OUTPUT_DATA_WIDTH - ACTUAL_OUTPUT_DATA_WIDTH)) <= w_output_i(i)(INPUT_DATA_WIDTH + 1 downto (INPUT_DATA_WIDTH + 2 - ACTUAL_OUTPUT_DATA_WIDTH));
      w_output_trimmed_q(i) <= (others => '0');
      w_output_trimmed_q(i)(OUTPUT_DATA_WIDTH - 1 downto (OUTPUT_DATA_WIDTH - ACTUAL_OUTPUT_DATA_WIDTH)) <= w_output_q(i)(INPUT_DATA_WIDTH + 1 downto (INPUT_DATA_WIDTH + 2 - ACTUAL_OUTPUT_DATA_WIDTH));
    end loop;
  end process;

  g_output : if (LATENCY = 0) generate

    Output_control  <= Input_control;
    Output_i        <= w_output_trimmed_i;
    Output_q        <= w_output_trimmed_q;

  elsif (LATENCY = 1) generate

    process(Clk)
    begin
      if rising_edge(Clk) then
        Output_control  <= Input_control;
        Output_i        <= w_output_trimmed_i;
        Output_q        <= w_output_trimmed_q;
      end if;
    end process;

  end generate;

end architecture rtl;
