library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library esm_lib;
  use esm_lib.esm_pkg.all;

entity esm_dwell_controller is
generic (
  AXI_DATA_WIDTH : natural
);
port (
  Clk             : in  std_logic;
  Rst             : in  std_logic;

  Module_config   : in  esm_config_data_t;

  Ad9361_control  : out std_logic_vector(3 downto 0);
  Ad9361_status   : in  std_logic_vector(7 downto 0);

);
end entity esm_dwell_controller;

architecture rtl of esm_dwell_controller is

begin


end architecture rtl;
