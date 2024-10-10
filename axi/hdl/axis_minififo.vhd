library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

entity axis_minififo is
generic (
  AXI_DATA_WIDTH    : natural
);
port (
  Clk           : in  std_logic;
  Rst           : in  std_logic;

  S_axis_ready  : out std_logic;
  S_axis_valid  : in  std_logic;
  S_axis_data   : in  std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  S_axis_last   : in  std_logic;

  M_axis_ready  : in  std_logic;
  M_axis_valid  : out std_logic;
  M_axis_data   : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  M_axis_last   : out std_logic
);
end entity axis_minififo;

--TODO: PSL assert

architecture rtl of axis_minififo is

  signal r_stage0_valid : std_logic;
  signal r_stage0_data  : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal r_stage0_last  : std_logic;

  signal r_stage1_valid : std_logic;
  signal r_stage1_data  : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal r_stage1_last  : std_logic;

begin

  S_axis_ready <= not(r_stage0_valid);

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_stage0_valid <= '0';
        r_stage0_data  <= (others => '-');
        r_stage0_last  <= '-';
      else
        if ((r_stage1_valid = '1') and (r_stage0_valid = '0') and (M_axis_ready = '0')) then
          r_stage0_valid  <= S_axis_valid;
          r_stage0_data   <= S_axis_data;
          r_stage0_last   <= S_axis_last;
        elsif ((M_axis_ready = '1') or (r_stage1_valid = '0')) then
          r_stage0_valid  <= '0';
          r_stage0_data   <= (others => '-');
          r_stage0_last   <= '-';
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_stage1_valid <= '0';
        r_stage1_data  <= (others => '-');
        r_stage1_last  <= '-';
      else
        if ((M_axis_ready = '1') or (r_stage1_valid = '0')) then
          if (r_stage0_valid = '1') then
            r_stage1_valid  <= '1';
            r_stage1_data   <= r_stage0_data;
            r_stage1_last   <= r_stage0_last;
          else
            r_stage1_valid  <= S_axis_valid;
            r_stage1_data   <= S_axis_data;
            r_stage1_last   <= S_axis_last;
          end if;
        end if;
      end if;
    end if;
  end process;

  M_axis_valid <= r_stage1_valid;
  M_axis_data  <= r_stage1_data;
  M_axis_last  <= r_stage1_last;

end architecture rtl;
