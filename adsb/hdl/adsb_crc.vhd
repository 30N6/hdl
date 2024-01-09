library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library dsp_lib;

library adsb_lib;
  use adsb_lib.adsb_pkg.all;

entity adsb_crc is
port (
  Clk               : in  std_logic;

  Input_valid       : in  std_logic;
  Input_data        : in  adsb_message_t;

  Output_valid      : out std_logic;
  Output_remainder  : out std_logic_vector(ADSB_CRC_WIDTH - 1 downto 0)
);
end entity adsb_crc;

architecture rtl of adsb_crc is

  constant POLY           : std_logic_vector(0 to ADSB_CRC_WIDTH) := "1111111111111010000001001";

  signal r_input_valid    : std_logic;
  signal r_input_swapped  : std_logic_vector(0 to ADSB_MESSAGE_WIDTH - 1);
  signal w_remainder      : std_logic_vector(0 to ADSB_CRC_WIDTH - 1);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_valid <= Input_valid;
      for i in 0 to (ADSB_MESSAGE_WIDTH - 1) loop
        r_input_swapped(i) <= Input_data(ADSB_MESSAGE_WIDTH - 1 - i);
      end loop;
    end if;
  end process;

  process(all)
    variable v_data : std_logic_vector(0 to ADSB_MESSAGE_WIDTH - 1);
  begin
    v_data := r_input_swapped;
    for i in 0 to (ADSB_MESSAGE_WIDTH - ADSB_CRC_WIDTH - 1) loop
      if (v_data(i) = '1') then
        v_data(i to (ADSB_CRC_WIDTH + i)) := v_data(i to (ADSB_CRC_WIDTH + i)) xor POLY;
      end if;
    end loop;
    w_remainder <= v_data((ADSB_MESSAGE_WIDTH - ADSB_CRC_WIDTH) to ADSB_MESSAGE_WIDTH - 1);
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Output_valid <= r_input_valid;

      for i in 0 to (ADSB_CRC_WIDTH - 1) loop
        Output_remainder(i) <= w_remainder(i);
      end loop;
    end if;
  end process;

end architecture rtl;
