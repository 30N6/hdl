library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

entity reset_extender is
generic (
  RESET_LENGTH : natural
);
port (
  Clk     : in  std_logic;
  Rst_in  : in  std_logic;
  Rst_out : out std_logic
);
end entity reset_extender;

architecture rtl of reset_extender is

  constant COUNTER_WIDTH  : natural := clog2_min1bit(RESET_LENGTH);
  signal r_counter        : unsigned(COUNTER_WIDTH - 1 downto 0);

begin

  assert (RESET_LENGTH > 1)
    report "RESET_LENGTH expected to be greater than 1."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst_in = '1') then
        r_counter <= (others => '0');
      else
        if (r_counter < (RESET_LENGTH - 1)) then
          r_counter <= r_counter + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Rst_out <= to_stdlogic(r_counter < (RESET_LENGTH - 1));
    end if;
  end process;

end architecture rtl;
