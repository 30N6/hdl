library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library xpm;
  use xpm.vcomponents.all;

entity axis_mux is
generic (
  NUM_INPUTS      : natural;
  AXI_DATA_WIDTH  : natural
);
port (
  Clk             : in  std_logic;
  Rst             : in  std_logic;

  S_axis_ready    : out std_logic_vector(NUM_INPUTS - 1 downto 0);
  S_axis_valid    : in  std_logic_vector(NUM_INPUTS - 1 downto 0);
  S_axis_data     : in  std_logic_vector_array_t(NUM_INPUTS - 1 downto 0)(AXI_DATA_WIDTH - 1 downto 0);
  S_axis_last     : in  std_logic_vector(NUM_INPUTS - 1 downto 0);

  M_axis_ready    : in  std_logic;
  M_axis_valid    : out std_logic;
  M_axis_data     : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  M_axis_last     : out std_logic
);
end entity axis_mux;

architecture rtl of axis_mux is

  signal r_sel            : unsigned(clog2(NUM_INPUTS) - 1 downto 0);
  signal r_active         : std_logic;

  signal w_selected_ready : std_logic;
  signal w_selected_valid : std_logic;
  signal w_selected_data  : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_selected_last  : std_logic;

begin

  assert (NUM_INPUTS > 1)
    report "NUM_INPUTS must be greater than 1."
    severity failure;

  process(all)
  begin
    S_axis_ready                    <= (others => '0');
    S_axis_ready(to_integer(r_sel)) <= r_active and M_axis_ready;
    w_selected_valid                <= S_axis_valid(to_integer(r_sel));
    w_selected_data                 <= S_axis_data(to_integer(r_sel));
    w_selected_last                 <= S_axis_last(to_integer(r_sel));
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_sel     <= (others => '0');
        r_active  <= '0';
      else
        if (r_active = '1') then
          if ((w_selected_valid = '1') and (w_selected_last = '1') and (M_axis_ready = '1')) then
            r_active <= '0';

            if (r_sel = (NUM_INPUTS - 1)) then
              r_sel <= (others => '0');
            else
              r_sel <= r_sel + 1;
            end if;
          end if;
        else
          if (w_selected_valid = '1') then
            r_active <= '1';
          else
            if (r_sel = (NUM_INPUTS - 1)) then
              r_sel <= (others => '0');
            else
              r_sel <= r_sel + 1;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  M_axis_valid <= r_active and w_selected_valid;
  M_axis_data  <= w_selected_data;
  M_axis_last  <= w_selected_last;

end architecture rtl;
