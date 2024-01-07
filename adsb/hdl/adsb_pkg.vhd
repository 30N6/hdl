library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package adsb_pkg is

  constant TIMESTAMP_WIDTH    : natural := 64;
  subtype timestamp_t is unsigned(TIMESTAMP_WIDTH - 1 downto 0);

  constant ADSB_MESSAGE_WIDTH : natural := 112;
  subtype adsb_message_t is std_logic_vector(ADSB_MESSAGE_WIDTH - 1 downto 0);

  constant ADSB_REPORT_MAGIC_NUM  : std_logic_vector(31 downto 0) := x"AD5B0001";
  constant ADSB_REPORT_WIDTH      : natural := 352;

  type adsb_report_t is record
    magic_num     : std_logic_vector(31 downto 0);
    sequence_num  : unsigned(31 downto 0);
    timestamp     : unsigned(63 downto 0);

    preamble_s    : unsigned(31 downto 0);
    preamble_sn   : unsigned(31 downto 0);
    message_crc   : std_logic_vector(31 downto 0);
    message_data  : std_logic_vector(127 downto 0);
  end record;

  constant ADSB_CONFIG_MAGIC_NUM  : std_logic_vector(31 downto 0) := x"AD5B0101";
  constant ADSB_CONFIG_WIDTH      : natural := 64;

  type adsb_config_t is record
    magic_num     : std_logic_vector(31 downto 0);
    reset         : std_logic_vector(7 downto 0);
    enable        : std_logic_vector(7 downto 0);

    padding       : std_logic_vector(15 downto 0);
  end record;

  function pack(v : adsb_report_t) return std_logic_vector;
  function unpack(v : std_logic_vector) return adsb_config_t;

  --type adsb_message_t is record
  --  std_logic_vector(
  --
  --end record;

end package adsb_pkg;

package body adsb_pkg is

  function pack(v : adsb_report_t) return std_logic_vector is
    variable r : std_logic_vector(ADSB_REPORT_WIDTH - 1 downto 0);
  begin
    r := (others => '0');

    r( 31 downto   0) := std_logic_vector(v.magic_num);
    r( 63 downto  32) := std_logic_vector(v.sequence_num);
    r(127 downto  64) := std_logic_vector(v.timestamp);
    r(159 downto 128) := std_logic_vector(v.preamble_s);
    r(191 downto 160) := std_logic_vector(v.preamble_sn);
    r(223 downto 192) := v.message_crc;
    r(351 downto 224) := v.message_data;
    return r;
  end function;

  function unpack(v : std_logic_vector) return adsb_config_t is
    variable r : adsb_config_t;
  begin
    r.magic_num := v(31 downto 0);
    r.reset     := v(39 downto 32);
    r.enable    := v(47 downto 40);
    return r;
  end function;

end package body adsb_pkg;
