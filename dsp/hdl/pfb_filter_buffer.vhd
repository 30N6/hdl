library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

entity pfb_filter_buffer is
generic (
  CHANNEL_INDEX_WIDTH : natural;
  DATA_WIDTH          : natural
);
port (
  Clk           : in  std_logic;

  Input_valid   : in  std_logic;
  Input_index   : in  unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Input_data    : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Output_index  : in  unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Output_data   : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0)
);
end entity pfb_filter_buffer;

architecture rtl of pfb_filter_buffer is

  signal m_buffer_i : signed_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal m_buffer_q : signed_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0)(DATA_WIDTH - 1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Input_valid = '1') then
        m_buffer_i(to_integer(Input_index)) <= Input_data(1);
        m_buffer_q(to_integer(Input_index)) <= Input_data(0);
      end if;
    end if;
  end process;

  Output_data(1) <= m_buffer_i(to_integer(Output_index));
  Output_data(0) <= m_buffer_q(to_integer(Output_index));

end architecture rtl;
