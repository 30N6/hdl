library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

package eth_pkg is

  constant ETH_MIN_FRAME_SIZE             : natural := 64;
  constant ETH_MAX_FRAME_SIZE             : natural := 1522;

  constant ETH_MAC_HEADER_LENGTH          : natural := 14;
  constant ETH_IPV4_HEADER_LENGTH         : natural := 20;
  constant ETH_UDP_HEADER_LENGTH          : natural := 8;
  constant ETH_UDP_MAX_PAYLOAD_LENGTH     : natural := 1500 - ETH_IPV4_HEADER_LENGTH - ETH_UDP_HEADER_LENGTH;
  constant ETH_UDP_LENGTH_WIDTH           : natural := clog2(ETH_UDP_MAX_PAYLOAD_LENGTH);

  constant ETH_TX_HEADER_BYTE_LENGTH      : natural := ETH_MAC_HEADER_LENGTH + ETH_IPV4_HEADER_LENGTH + ETH_UDP_HEADER_LENGTH;
  constant ETH_TX_HEADER_WORD_LENGTH      : natural := (ETH_TX_HEADER_BYTE_LENGTH + 3)/4;
  constant ETH_TX_HEADER_ADDR_WIDTH       : natural := clog2(ETH_TX_HEADER_WORD_LENGTH);

  constant ETH_IP_UDP_HEADER_BYTE_LENGTH  : natural := ETH_IPV4_HEADER_LENGTH + ETH_UDP_HEADER_LENGTH;
  --constant ETH_IP_UDP_HEADER_WORD_LENGTH  : natural := (ETH_IP_UDP_HEADER_BYTE_LENGTH + 3)/4; --TODO: remove

  constant ETH_PREAMBLE_LENGTH            : natural := 7;
  constant ETH_SFD_LENGTH                 : natural := 1;
  constant ETH_MAC_LENGTH                 : natural := 6;
  constant ETH_TYPE_LENGTH                : natural := 2;
  constant ETH_FCS_LENGTH                 : natural := 4;
  constant ETH_IFG_LENGTH                 : natural := 12;

  constant ETH_PREAMBLE_BYTE              : std_logic_vector(7 downto 0)  := x"AA"; --TODO: swap?
  constant ETH_SFD_BYTE                   : std_logic_vector(7 downto 0)  := x"AB"; --TODO: swap?
  constant ETH_TYPE_IP                    : std_logic_vector(15 downto 0) := x"0008";
  constant ETH_IP_VER_IHL                 : std_logic_vector(7 downto 0)  := x"45";
  constant ETH_IP_PROTO_UDP               : std_logic_vector(7 downto 0)  := x"11";

end package eth_pkg;

package body eth_pkg is

end package body eth_pkg;
