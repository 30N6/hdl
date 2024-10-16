library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity clk_x4_phase_marker is
port (
  Clk     : in  std_logic;
  Clk_x4  : in  std_logic;

  Clk_x4_p0 : out std_logic;
  Clk_x4_p1 : out std_logic;
  Clk_x4_p2 : out std_logic;
  Clk_x4_p3 : out std_logic
);
end entity clk_x4_phase_marker;

architecture rtl of clk_x4_phase_marker is

  signal r_tog_x1       : std_logic := '0';
  signal r_tog_x1_to_x4 : std_logic := '0';

  signal r_clk_x4_p0    : std_logic;
  signal r_clk_x4_p1    : std_logic;
  signal r_clk_x4_p2    : std_logic;
  signal r_clk_x4_p3    : std_logic;

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_tog_x1 <= not(r_tog_x1);
    end if;
  end process;

  process(Clk_x4)
  begin
    if rising_edge(Clk_x4) then
      r_tog_x1_to_x4 <= r_tog_x1;
    end if;
  end process;

  process(Clk_x4)
  begin
    if rising_edge(Clk_x4) then
      r_clk_x4_p1 <= r_tog_x1 xor r_tog_x1_to_x4;
      r_clk_x4_p2 <= r_clk_x4_p1;
      r_clk_x4_p3 <= r_clk_x4_p2;
      r_clk_x4_p0 <= r_clk_x4_p3;
    end if;
  end process;

  Clk_x4_p0 <= r_clk_x4_p0;
  Clk_x4_p1 <= r_clk_x4_p1;
  Clk_x4_p2 <= r_clk_x4_p2;
  Clk_x4_p3 <= r_clk_x4_p3;

end architecture rtl;
