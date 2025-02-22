library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

entity ethernet_fcs is
port (
  Clk       : in  std_logic;
  Rst       : in  std_logic;

  In_valid  : in  std_logic;
  In_data   : in  std_logic_vector(7 downto 0);

  Out_fcs   : out std_logic_vector(31 downto 0)
);
end entity ethernet_fcs;

architecture rtl of ethernet_fcs is

  signal r_lfsr: std_logic_vector(31 downto 0);
  signal w_lfsr: std_logic_vector(31 downto 0);

begin

    w_lfsr(0) <= r_lfsr(24) xor r_lfsr(30) xor In_data(0) xor In_data(6);
    w_lfsr(1) <= r_lfsr(24) xor r_lfsr(25) xor r_lfsr(30) xor r_lfsr(31) xor In_data(0) xor In_data(1) xor In_data(6) xor In_data(7);
    w_lfsr(2) <= r_lfsr(24) xor r_lfsr(25) xor r_lfsr(26) xor r_lfsr(30) xor r_lfsr(31) xor In_data(0) xor In_data(1) xor In_data(2) xor In_data(6) xor In_data(7);
    w_lfsr(3) <= r_lfsr(25) xor r_lfsr(26) xor r_lfsr(27) xor r_lfsr(31) xor In_data(1) xor In_data(2) xor In_data(3) xor In_data(7);
    w_lfsr(4) <= r_lfsr(24) xor r_lfsr(26) xor r_lfsr(27) xor r_lfsr(28) xor r_lfsr(30) xor In_data(0) xor In_data(2) xor In_data(3) xor In_data(4) xor In_data(6);
    w_lfsr(5) <= r_lfsr(24) xor r_lfsr(25) xor r_lfsr(27) xor r_lfsr(28) xor r_lfsr(29) xor r_lfsr(30) xor r_lfsr(31) xor In_data(0) xor In_data(1) xor In_data(3) xor In_data(4) xor In_data(5) xor In_data(6) xor In_data(7);
    w_lfsr(6) <= r_lfsr(25) xor r_lfsr(26) xor r_lfsr(28) xor r_lfsr(29) xor r_lfsr(30) xor r_lfsr(31) xor In_data(1) xor In_data(2) xor In_data(4) xor In_data(5) xor In_data(6) xor In_data(7);
    w_lfsr(7) <= r_lfsr(24) xor r_lfsr(26) xor r_lfsr(27) xor r_lfsr(29) xor r_lfsr(31) xor In_data(0) xor In_data(2) xor In_data(3) xor In_data(5) xor In_data(7);
    w_lfsr(8) <= r_lfsr(0) xor r_lfsr(24) xor r_lfsr(25) xor r_lfsr(27) xor r_lfsr(28) xor In_data(0) xor In_data(1) xor In_data(3) xor In_data(4);
    w_lfsr(9) <= r_lfsr(1) xor r_lfsr(25) xor r_lfsr(26) xor r_lfsr(28) xor r_lfsr(29) xor In_data(1) xor In_data(2) xor In_data(4) xor In_data(5);
    w_lfsr(10) <= r_lfsr(2) xor r_lfsr(24) xor r_lfsr(26) xor r_lfsr(27) xor r_lfsr(29) xor In_data(0) xor In_data(2) xor In_data(3) xor In_data(5);
    w_lfsr(11) <= r_lfsr(3) xor r_lfsr(24) xor r_lfsr(25) xor r_lfsr(27) xor r_lfsr(28) xor In_data(0) xor In_data(1) xor In_data(3) xor In_data(4);
    w_lfsr(12) <= r_lfsr(4) xor r_lfsr(24) xor r_lfsr(25) xor r_lfsr(26) xor r_lfsr(28) xor r_lfsr(29) xor r_lfsr(30) xor In_data(0) xor In_data(1) xor In_data(2) xor In_data(4) xor In_data(5) xor In_data(6);
    w_lfsr(13) <= r_lfsr(5) xor r_lfsr(25) xor r_lfsr(26) xor r_lfsr(27) xor r_lfsr(29) xor r_lfsr(30) xor r_lfsr(31) xor In_data(1) xor In_data(2) xor In_data(3) xor In_data(5) xor In_data(6) xor In_data(7);
    w_lfsr(14) <= r_lfsr(6) xor r_lfsr(26) xor r_lfsr(27) xor r_lfsr(28) xor r_lfsr(30) xor r_lfsr(31) xor In_data(2) xor In_data(3) xor In_data(4) xor In_data(6) xor In_data(7);
    w_lfsr(15) <= r_lfsr(7) xor r_lfsr(27) xor r_lfsr(28) xor r_lfsr(29) xor r_lfsr(31) xor In_data(3) xor In_data(4) xor In_data(5) xor In_data(7);
    w_lfsr(16) <= r_lfsr(8) xor r_lfsr(24) xor r_lfsr(28) xor r_lfsr(29) xor In_data(0) xor In_data(4) xor In_data(5);
    w_lfsr(17) <= r_lfsr(9) xor r_lfsr(25) xor r_lfsr(29) xor r_lfsr(30) xor In_data(1) xor In_data(5) xor In_data(6);
    w_lfsr(18) <= r_lfsr(10) xor r_lfsr(26) xor r_lfsr(30) xor r_lfsr(31) xor In_data(2) xor In_data(6) xor In_data(7);
    w_lfsr(19) <= r_lfsr(11) xor r_lfsr(27) xor r_lfsr(31) xor In_data(3) xor In_data(7);
    w_lfsr(20) <= r_lfsr(12) xor r_lfsr(28) xor In_data(4);
    w_lfsr(21) <= r_lfsr(13) xor r_lfsr(29) xor In_data(5);
    w_lfsr(22) <= r_lfsr(14) xor r_lfsr(24) xor In_data(0);
    w_lfsr(23) <= r_lfsr(15) xor r_lfsr(24) xor r_lfsr(25) xor r_lfsr(30) xor In_data(0) xor In_data(1) xor In_data(6);
    w_lfsr(24) <= r_lfsr(16) xor r_lfsr(25) xor r_lfsr(26) xor r_lfsr(31) xor In_data(1) xor In_data(2) xor In_data(7);
    w_lfsr(25) <= r_lfsr(17) xor r_lfsr(26) xor r_lfsr(27) xor In_data(2) xor In_data(3);
    w_lfsr(26) <= r_lfsr(18) xor r_lfsr(24) xor r_lfsr(27) xor r_lfsr(28) xor r_lfsr(30) xor In_data(0) xor In_data(3) xor In_data(4) xor In_data(6);
    w_lfsr(27) <= r_lfsr(19) xor r_lfsr(25) xor r_lfsr(28) xor r_lfsr(29) xor r_lfsr(31) xor In_data(1) xor In_data(4) xor In_data(5) xor In_data(7);
    w_lfsr(28) <= r_lfsr(20) xor r_lfsr(26) xor r_lfsr(29) xor r_lfsr(30) xor In_data(2) xor In_data(5) xor In_data(6);
    w_lfsr(29) <= r_lfsr(21) xor r_lfsr(27) xor r_lfsr(30) xor r_lfsr(31) xor In_data(3) xor In_data(6) xor In_data(7);
    w_lfsr(30) <= r_lfsr(22) xor r_lfsr(28) xor r_lfsr(31) xor In_data(4) xor In_data(7);
    w_lfsr(31) <= r_lfsr(23) xor r_lfsr(29) xor In_data(5);


  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_lfsr <= (others => '1');
      else
        if (In_valid = '1') then
          r_lfsr <= w_lfsr;
        end if;
      end if;
    end if;
  end process;

  Out_fcs <= r_lfsr;

end architecture rtl;
