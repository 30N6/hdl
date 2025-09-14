library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity channelizer_1 is
generic (
  INPUT_DATA_WIDTH    : natural;
  OUTPUT_DATA_WIDTH   : natural
);
port (
  Clk               : in  std_logic;
  Rst               : in  std_logic;

  Input_valid       : in  std_logic;
  Input_data        : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  Output_chan_ctrl  : out channelizer_control_t;
  Output_chan_data  : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_chan_pwr   : out unsigned(CHAN_POWER_WIDTH - 1 downto 0)
);
end entity channelizer_1;

architecture rtl of channelizer_1 is

  constant POWER_LATENCY  : natural := 4;

  signal r_input_valid    : std_logic_vector(POWER_LATENCY - 1 downto 0);
  signal r_input_data_i   : signed_array_t(POWER_LATENCY - 1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  signal r_input_data_q   : signed_array_t(POWER_LATENCY - 1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  signal w_output_power   : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

begin

  assert (INPUT_DATA_WIDTH = OUTPUT_DATA_WIDTH)
    report "Input width must match output width."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_valid  <= r_input_valid(POWER_LATENCY - 2 downto 0)  & Input_valid;
      r_input_data_i <= r_input_data_i(POWER_LATENCY - 2 downto 0) & Input_data(0);
      r_input_data_q <= r_input_data_q(POWER_LATENCY - 2 downto 0) & Input_data(1);
    end if;
  end process;

  i_power : entity dsp_lib.channelizer_power
  generic map (
    DATA_WIDTH  => INPUT_DATA_WIDTH,
    LATENCY     => POWER_LATENCY
  )
  port map (
    Clk         => Clk,

    Input_data  => Input_data,
    Output_data => w_output_power
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      Output_chan_ctrl.valid      <= r_input_valid(POWER_LATENCY - 1);
      Output_chan_ctrl.last       <= '1';
      Output_chan_ctrl.data_index <= (others => '0');

      Output_chan_data(0)         <= r_input_data_i(POWER_LATENCY - 1);
      Output_chan_data(1)         <= r_input_data_q(POWER_LATENCY - 1);

      Output_chan_pwr             <= w_output_power;
    end if;
  end process;

end architecture rtl;
