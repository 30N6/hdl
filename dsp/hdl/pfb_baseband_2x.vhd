library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

-- basebanding for 2x oversampled PFB data (odd channels multiplied by +1, -1, +1, -1, ...)

entity pfb_baseband_2x is
generic (
  CHANNEL_INDEX_WIDTH : natural;
  DATA_WIDTH          : natural
);
port (
  Clk           : in  std_logic;

  Input_valid   : in  std_logic;
  Input_index   : in  unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Input_data    : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Output_valid  : out std_logic;
  Output_index  : out unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Output_data   : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0)
);
end entity pfb_baseband_2x;

architecture rtl of pfb_baseband_2x is

  type mod_array_t is array (natural range <>) of std_logic;

  signal m_mod_state : mod_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_mod_state : std_logic;

begin

  w_mod_state <= m_mod_state(to_integer(Input_index));

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Input_valid = '1') then
        m_mod_state(to_integer(Input_index)) <= not(w_mod_state);
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(clk) then
      Output_valid  <= Input_valid;
      Output_index  <= Input_index;

      if ((Input_index(0) = '1') and (w_mod_state = '1')) then
        Output_data(0)  <= invert_sign(Input_data(0));
        Output_data(1)  <= invert_sign(Input_data(1));
      else
        Output_data     <= Input_data;
      end if;
    end if;
  end process;

end architecture rtl;
