library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library adsb_lib;
  use adsb_lib.adsb_pkg.all;

entity adsb_config is
generic (
  AXI_DATA_WIDTH : natural
);
port (
  Clk         : in  std_logic;
  Rst         : in  std_logic;

  Axis_ready  : out std_logic;
  Axis_valid  : in  std_logic;
  Axis_last   : in  std_logic;
  Axis_data   : in  std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

  Rst_out     : out std_logic;
  Enable      : out std_logic
);
end entity adsb_config;

architecture rtl of adsb_config is

  constant CONFIG_TRANSFER_COUNT  : natural := (ADSB_CONFIG_WIDTH + AXI_DATA_WIDTH - 1) / AXI_DATA_WIDTH;
  constant CONFIG_PADDED_WIDTH    : natural := CONFIG_TRANSFER_COUNT * AXI_DATA_WIDTH;

  signal r_transfer_pending     : std_logic;
  signal r_transfer_index       : unsigned(clog2(CONFIG_TRANSFER_COUNT + 1) - 1 downto 0);

  signal r_config_data          : std_logic_vector(CONFIG_PADDED_WIDTH - 1 downto 0);
  signal r_config_valid         : std_logic;

  signal w_config_unpacked      : adsb_config_t;

begin

  Axis_ready <= '1';

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_transfer_pending <= '0';
      else
        if (Axis_valid = '1') then
          r_transfer_pending <= not(Axis_last);
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_transfer_pending = '0') then
        r_transfer_index  <= (others => '0');
        r_config_data     <= (others => '0');
        r_config_valid    <= '0';
      elsif (Axis_valid = '1') then
        r_config_valid <= to_stdlogic(r_transfer_index = (CONFIG_TRANSFER_COUNT - 1));
        if (r_transfer_index < CONFIG_TRANSFER_COUNT) then
          r_transfer_index  <= r_transfer_index + 1;
          r_config_data(AXI_DATA_WIDTH * to_integer(r_transfer_index) + AXI_DATA_WIDTH - 1 downto AXI_DATA_WIDTH * to_integer(r_transfer_index)) <= Axis_data;
        end if;
      end if;
    end if;
  end process;

  w_config_unpacked <= unpack(r_config_data);

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        Rst_out <= '0';
        Enable  <= '0';
      else
        if (r_config_valid = '1') then
          Rst_out <= w_config_unpacked.reset;
          Enable  <= w_config_unpacked.enable;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
