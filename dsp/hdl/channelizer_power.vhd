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
  signal r_power_trunc      : unsigned(DATA_WIDTH + MAX_MULT_WIDTH_B - 1 downto 0);
  signal r_power_full       : unsigned(2*DATA_WIDTH - 1 downto 0);

begin

  assert (DATA_WIDTH <= MAX_MULT_WIDTH_A)
    report "DATA_WIDTH is too large."
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

  g_mult_type : if (DATA_WIDTH >= MAX_MULT_WIDTH_B) generate
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
        r_power_trunc <= unsigned('0' & r_squared_data_d1(0)(DATA_WIDTH + MAX_MULT_WIDTH_B - 2 downto 0)) + unsigned('0' & r_squared_data_d1(1)(DATA_WIDTH + MAX_MULT_WIDTH_B - 2 downto 0));
      end if;
    end process;

    Output_data <= r_power_trunc(DATA_WIDTH + MAX_MULT_WIDTH_B - 1 downto (DATA_WIDTH + MAX_MULT_WIDTH_B - CHAN_POWER_WIDTH));
  else generate
    g_mult : for i in 0 to 1 generate
      process(Clk)
      begin
        if rising_edge(Clk) then
          r_squared_data_d0(i) <= r_input_data(i) * r_input_data(i);
          r_squared_data_d1(i) <= r_squared_data_d0(i);
        end if;
      end process;

    end generate g_mult;

    process(Clk)
    begin
      if rising_edge(Clk) then
        -- squared data is always positive
        r_power_full <= unsigned('0' & r_squared_data_d1(0)(2*DATA_WIDTH - 2 downto 0)) + unsigned('0' & r_squared_data_d1(1)(2*DATA_WIDTH - 2 downto 0));
      end if;
    end process;

    g_output : if (CHAN_POWER_WIDTH <= 2*DATA_WIDTH) generate
      Output_data <= r_power_full(2*DATA_WIDTH - 1 downto (2*DATA_WIDTH - CHAN_POWER_WIDTH));
    else generate
      Output_data <= resize_up(r_power_full, CHAN_POWER_WIDTH);
    end generate g_output;
  end generate g_mult_type;

end architecture rtl;
