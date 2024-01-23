library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity fft_4_serializer is
generic (
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Input_control         : in  fft_control_t;
  Input_i               : in  signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  Input_q               : in  signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  Output_control        : out fft_control_t;
  Output_i              : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_q              : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);

  Error_input_overflow  : out std_logic
);
end entity fft_4_serializer;

architecture rtl of fft_4_serializer is

  signal r_input_control    : fft_control_t;
  signal r_input_i          : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal r_input_q          : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  signal r_output_valid     : std_logic;
  signal r_output_sub_index : unsigned(1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Input_control.valid = '1') then
        r_input_control <= Input_control;
        r_input_i       <= Input_i;
        r_input_q       <= Input_q;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_output_valid      <= '0';
        r_output_sub_index  <= (others => '0');
      else
        if (Input_control.valid = '1') then
          r_output_valid      <= '1';
          r_output_sub_index  <= (others => '0');
        else
          if (r_output_sub_index = 3) then
            r_output_valid <= '0';
          end if;
          r_output_sub_index <= r_output_sub_index + 1;
        end if;
      end if;
    end if;
  end process;

  process(all)
  begin
    Output_control            <= r_input_control;
    Output_control.valid      <= r_output_valid;
    Output_control.last       <= r_input_control.last and to_stdlogic(r_output_sub_index = 3);
    Output_control.data_index <= r_input_control.data_index(Output_control.data_index'length - 1 downto 2) & r_output_sub_index;
    Output_i                  <= r_input_i(to_integer(r_output_sub_index));
    Output_q                  <= r_input_q(to_integer(r_output_sub_index));
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_input_overflow <= Input_control.valid and r_output_valid and to_stdlogic(r_output_sub_index /= 3);
    end if;
  end process;

end architecture rtl;
