library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

package eth_pkg is

  constant ETH_MIN_FRAME_SIZE       : natural := 64;
  constant ETH_MAX_FRAME_SIZE       : natural := 1522;

  constant ETH_PREAMBLE_LENGTH      : natural := 7;
  constant ETH_SFD_LENGTH           : natural := 1;
  constant ETH_MAC_LENGTH           : natural := 6;
  constant ETH_TYPE_LENGTH          : natural := 2;
  constant ETH_FCS_LENGTH           : natural := 4;
  constant ETH_IFG_LENGTH           : natural := 12;

  constant ETH_PREAMBLE_BYTE        : std_logic_vector(7 downto 0)  := x"AA";
  constant ETH_SFD_BYTE             : std_logic_vector(7 downto 0)  := x"AB";
  constant ETH_TYPE_IP              : std_logic_vector(15 downto 0) := x"0008";

end package eth_pkg;

package body eth_pkg is

end package body eth_pkg;
