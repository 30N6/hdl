library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library clock_lib;

entity esm_clocks is
port (
  Adc_clk         : in  std_logic;
  Adc_rst         : in  std_logic;

  Adc_clk_x4      : out std_logic
);
end entity esm_clocks;

architecture rtl of esm_clocks is

begin

  i_clocking : entity clock_lib.adc_clk_mult
  port map (
    Clk_x1  => Adc_clk,
    reset   => Adc_rst,

    locked  => open,
    Clk_x2  => open,
    Clk_x4  => Adc_clk_x4
  );

end architecture rtl;
