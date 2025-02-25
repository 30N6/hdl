library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

package udp_intf_pkg is

  constant UDP_SETUP_MAGIC_NUM_0  : std_logic_vector(31 downto 0) := x"53504455";
  constant UDP_SETUP_MAGIC_NUM_1  : std_logic_vector(31 downto 0) := x"50555445";

end package udp_intf_pkg;

package body udp_intf_pkg is

end package body udp_intf_pkg;
