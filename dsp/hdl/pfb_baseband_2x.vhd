library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

-- * basebanding for 2x oversampled PFB data (odd channels multiplied by +1, -1, +1, -1, ...)
-- * channels remapped here as well (0 = lowest freq, N-1 = highest freq)

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

  constant NUM_CHANNELS   : natural := 2**CHANNEL_INDEX_WIDTH;

  function get_channel_map return natural_array_t is
    variable r : natural_array_t(NUM_CHANNELS - 1 downto 0);
  begin
    for i in 0 to (NUM_CHANNELS/2 - 1) loop
      r(i) := i + NUM_CHANNELS/2;
    end loop;
    for i in (NUM_CHANNELS/2) to (NUM_CHANNELS - 1) loop
      r(i) := i - NUM_CHANNELS/2;
    end loop;
    return r;
  end function;

  constant CHANNEL_MAP    : natural_array_t(NUM_CHANNELS - 1 downto 0) := get_channel_map;

  signal m_mod_state      : mod_array_t(NUM_CHANNELS - 1 downto 0) := (others => '0');
  signal w_mod_state      : std_logic;

  signal r_mod_state      : std_logic;
  signal r_input_valid    : std_logic;
  signal r_input_index    : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_input_data     : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r_input_data_inv : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

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
    if rising_edge(Clk) then
      r_mod_state         <= w_mod_state;
      r_input_valid       <= Input_valid;
      r_input_index       <= Input_index;
      r_input_data        <= Input_data;
      r_input_data_inv(0) <= invert_sign(Input_data(0), true);
      r_input_data_inv(1) <= invert_sign(Input_data(1), true);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(clk) then
      Output_valid  <= r_input_valid;
      Output_index  <= to_unsigned(CHANNEL_MAP(to_integer(r_input_index)), CHANNEL_INDEX_WIDTH);

      if ((r_input_index(0) = '1') and (r_mod_state = '1')) then
        Output_data <= r_input_data_inv;
      else
        Output_data <= r_input_data;
      end if;
    end if;
  end process;

end architecture rtl;
