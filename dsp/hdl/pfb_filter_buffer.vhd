library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

-- FIR filter buffer -- 2x oversampling -> 2x sample delay

entity pfb_filter_buffer is
generic (
  CHANNEL_INDEX_WIDTH : natural;
  DATA_WIDTH          : natural
);
port (
  Clk           : in  std_logic;
  Rst           : in  std_logic;

  Input_valid   : in  std_logic;
  Input_index   : in  unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Input_last    : in  std_logic;
  Input_data    : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Output_valid  : in  std_logic;
  Output_index  : in  unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Output_last   : in  std_logic;
  Output_data   : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0)
);
end entity pfb_filter_buffer;

architecture rtl of pfb_filter_buffer is

  constant BUFFER_INDEX_WIDTH : natural := CHANNEL_INDEX_WIDTH + 1; -- 2x delay

  signal r_buf_wr_sub_index   : std_logic;
  signal r_buf_rd_sub_index   : std_logic;
  signal w_buf_wr_index       : unsigned(BUFFER_INDEX_WIDTH - 1 downto 0);
  signal w_buf_rd_index       : unsigned(BUFFER_INDEX_WIDTH - 1 downto 0);

  signal m_buffer_i   : signed_array_t(2**BUFFER_INDEX_WIDTH - 1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal m_buffer_q   : signed_array_t(2**BUFFER_INDEX_WIDTH - 1 downto 0)(DATA_WIDTH - 1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_buf_wr_sub_index <= '0';
        r_buf_rd_sub_index <= '0';
      else
        if ((Input_valid = '1') and (Input_last = '1')) then
          r_buf_wr_sub_index <= not(r_buf_wr_sub_index);
        end if;
        if ((Output_valid = '1') and (Output_last = '1')) then
          r_buf_rd_sub_index <= not(r_buf_rd_sub_index);
        end if;
      end if;
    end if;
  end process;

  w_buf_wr_index <= Input_index  & r_buf_wr_sub_index;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Input_valid = '1') then
        m_buffer_i(to_integer(w_buf_wr_index)) <= Input_data(1);
        m_buffer_q(to_integer(w_buf_wr_index)) <= Input_data(0);
      end if;
    end if;
  end process;

  w_buf_rd_index <= Output_index & r_buf_rd_sub_index;
  Output_data(1) <= m_buffer_i(to_integer(w_buf_rd_index));
  Output_data(0) <= m_buffer_q(to_integer(w_buf_rd_index));

end architecture rtl;
