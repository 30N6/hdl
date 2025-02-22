library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library eth_lib;
  use eth_lib.eth_pkg.all;

entity gmii_arb is
generic (
  NUM_INPUTS      : natural;
  INTERFRAME_GAP  : natural
);
port (
  Clk           : in  std_logic;
  Rst           : in  std_logic;

  Input_data    : in  std_logic_vector_array_t(NUM_INPUTS - 1 downto 0)(7 downto 0);
  Input_valid   : in  std_logic_vector(NUM_INPUTS - 1 downto 0);
  Input_last    : in  std_logic_vector(NUM_INPUTS - 1 downto 0);
  Input_ready   : out std_logic_vector(NUM_INPUTS - 1 downto 0);

  Output_data   : out std_logic_vector(7 downto 0);
  Output_valid  : out std_logic;
  Output_last   : out std_logic
);
begin
  -- PSL default clock is rising_edge(Clk);
  -- PSL ifg : assert always (fell(Output_valid)) -> next_a![0:INTERFRAME_GAP] (Output_valid = '0');
end entity gmii_arb;

architecture rtl of gmii_arb is

  signal r_active     : std_logic;
  signal r_index      : unsigned(clog2(NUM_INPUTS) - 1 downto 0);
  signal r_ifg_count  : unsigned(clog2(INTERFRAME_GAP) - 1 downto 0) := (others => '0');

  signal w_sel_valid  : std_logic;
  signal w_sel_last   : std_logic;

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_active  <= '0';
        r_index   <= (others => '-');
      else
        if (r_active = '0') then
          if ((or_reduce(Input_valid) = '1') and (r_ifg_count = 0)) then
            r_active  <= '1';
            r_index   <= first_bit_index(Input_valid);
          end if;
        else
          if ((w_sel_valid = '1') and (w_sel_last = '1')) then
            r_active  <= '0';
            r_index   <= (others => '-');
          end if;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_active = '1') then
        r_ifg_count <= to_unsigned(INTERFRAME_GAP, r_ifg_count'length);
      elsif (r_ifg_count > 0) then
        r_ifg_count <= r_ifg_count - 1;
      end if;
    end if;
  end process;

  w_sel_valid <= Input_valid(to_integer(r_index));
  w_sel_last  <= Input_last(to_integer(r_index));

  process(all)
  begin
    for i in 0 to (NUM_INPUTS - 1) loop
      Input_ready(i) <= r_active and to_stdlogic(r_index = i);
    end loop;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Output_data   <= Input_data(to_integer(r_index));
      Output_valid  <= r_active and w_sel_valid;
      Output_last   <= w_sel_last;
    end if;
  end process;

end architecture rtl;
