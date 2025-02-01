library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity xorshift_32 is
port (
  Clk     : in  std_logic;
  Rst     : in  std_logic;

  Output  : out unsigned(31 downto 0)
);
end entity xorshift_32;

architecture rtl of xorshift_32 is

  signal r_state        : unsigned(31 downto 0);
  signal w_next_state_0 : unsigned(31 downto 0);
  signal w_next_state_1 : unsigned(31 downto 0);
  signal w_next_state_2 : unsigned(31 downto 0);

begin

  w_next_state_0 <= r_state         xor shift_left(r_state, 13);
  w_next_state_1 <= w_next_state_0  xor shift_right(w_next_state_0, 17);
  w_next_state_2 <= w_next_state_1  xor shift_left(w_next_state_1, 5);

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_state <= (0 => '1', others => '0'); --TODO: try dontcare
      else
        r_state <= w_next_state_2;
      end if;
    end if;
  end process;

  Output <= r_state;

end architecture rtl;
