library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity channelizer_power is
generic (
  DATA_WIDTH  : natural;
  LATENCY     : natural
);
port (
  Clk         : in  std_logic;

  Input_data  : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  Output_data : out unsigned(CHAN_POWER_WIDTH - 1 downto 0)
);
end entity channelizer_power;

architecture rtl of channelizer_power is

  constant MAX_MULT_WIDTH_A : natural := 25;
  constant MAX_MULT_WIDTH_B : natural := 18;

  signal r_input_data       : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal w_input_data_a     : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal w_input_data_b     : signed_array_t(1 downto 0)(MAX_MULT_WIDTH_B - 1 downto 0);
  signal r_squared_data_d0  : signed_array_t(1 downto 0)(DATA_WIDTH + MAX_MULT_WIDTH_B - 1 downto 0);
  signal r_squared_data_d1  : signed_array_t(1 downto 0)(DATA_WIDTH + MAX_MULT_WIDTH_B - 1 downto 0);
  signal r_power            : unsigned(DATA_WIDTH + MAX_MULT_WIDTH_B - 1 downto 0);

begin

  assert (DATA_WIDTH <= MAX_MULT_WIDTH_A)
    report "DATA_WIDTH is too large."
    severity failure;

  assert (DATA_WIDTH >= MAX_MULT_WIDTH_B)
    report "DATA_WIDTH is too small."
    severity failure;

  assert (LATENCY = 4)
    report "LATENCY expected to be 4."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_data <= Input_data;
    end if;
  end process;

  g_mult : for i in 0 to 1 generate
    w_input_data_a(i) <= r_input_data(i);
    w_input_data_b(i) <= r_input_data(i)(DATA_WIDTH - 1 downto (DATA_WIDTH - MAX_MULT_WIDTH_B));

    process(Clk)
    begin
      if rising_edge(Clk) then
        r_squared_data_d0(i) <= w_input_data_a(i) * w_input_data_b(i);
        r_squared_data_d1(i) <= r_squared_data_d0(i);
      end if;
    end process;

  end generate g_mult;

  process(Clk)
  begin
    if rising_edge(Clk) then
      -- squared data is always positive
      r_power <= unsigned('0' & r_squared_data_d1(0)(DATA_WIDTH + MAX_MULT_WIDTH_B - 2 downto 0)) + unsigned('0' & r_squared_data_d1(1)(DATA_WIDTH + MAX_MULT_WIDTH_B - 2 downto 0));
    end if;
  end process;

  Output_data <= r_power(DATA_WIDTH + MAX_MULT_WIDTH_B - 1 downto (DATA_WIDTH + MAX_MULT_WIDTH_B - CHAN_POWER_WIDTH));

end architecture rtl;
