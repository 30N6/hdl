library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library esm_lib;
  use esm_lib.esm_pkg.all;

entity esm_pdw_iq_delay is
generic (
  DATA_WIDTH          : natural;
  CHANNEL_INDEX_WIDTH : natural;
  LATENCY             : natural;
  DELAY               : natural
);
port (
  Clk         : in  std_logic;

  Input_ctrl  : in  channelizer_control_t;
  Input_data  : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Output_ctrl : out channelizer_control_t;
  Output_data : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
);
end entity esm_pdw_iq_delay;

architecture rtl of esm_pdw_iq_delay is

  constant DELAY_INDEX_WIDTH    : natural := clog2(DELAY);
  constant MEM_ADDR_WIDTH       : natural := CHANNEL_INDEX_WIDTH + DELAY_INDEX_WIDTH;
  constant MEM_DATA_WIDTH       : natural := 2*DATA_WIDTH;

  signal m_delay_mem            : std_logic_vector_array_t(2**MEM_ADDR_WIDTH - 1 downto 0)(MEM_DATA_WIDTH - 1 downto 0);
  signal m_index_mem            : unsigned_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0)(DELAY_INDEX_WIDTH - 1 downto 0) := (others => (others => '0'));

  signal r0_input_ctrl          : channelizer_control_t;
  signal r0_input_data          : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r0_wr_delay_index      : unsigned(DELAY_INDEX_WIDTH - 1 downto 0);

  signal w0_rd_delay_index      : unsigned(DELAY_INDEX_WIDTH - 1 downto 0);
  signal w0_rd_addr             : unsigned(MEM_ADDR_WIDTH - 1 downto 0);
  signal w0_wr_addr             : unsigned(MEM_ADDR_WIDTH - 1 downto 0);
  signal w0_wr_data             : std_logic_vector(MEM_DATA_WIDTH - 1 downto 0);

  signal r1_input_ctrl          : channelizer_control_t;
  signal r1_rd_data             : std_logic_vector(MEM_DATA_WIDTH - 1 downto 0);

  signal r2_input_ctrl          : channelizer_control_t;
  signal r2_rd_data             : std_logic_vector(MEM_DATA_WIDTH - 1 downto 0);
  signal r3_input_ctrl          : channelizer_control_t;
  signal r3_rd_data             : std_logic_vector(MEM_DATA_WIDTH - 1 downto 0);
  signal r4_input_ctrl          : channelizer_control_t;
  signal r4_rd_data             : std_logic_vector(MEM_DATA_WIDTH - 1 downto 0);

begin

  assert (2**clog2(DELAY) = DELAY)
    report "DELAY expected to be a power of two."
    severity failure;

  assert (LATENCY = 5)
    report "LATENCY expected to be 5."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_input_ctrl     <= Input_ctrl;
      r0_input_data     <= Input_data;
      r0_wr_delay_index <= m_index_mem(to_integer(Input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
    end if;
  end process;

  w0_rd_delay_index <= r0_wr_delay_index - DELAY;
  w0_rd_addr        <= r0_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0) & w0_rd_delay_index;
  w0_wr_addr        <= r0_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0) & r0_wr_delay_index;
  w0_wr_data        <= std_logic_vector(r0_input_data(1)) & std_logic_vector(r0_input_data(0));

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r0_input_ctrl.valid = '1') then
        m_delay_mem(to_integer(w0_wr_addr)) <= w0_wr_data;
      end if;

      r1_rd_data <= m_delay_mem(to_integer(w0_rd_addr));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_input_ctrl <= r0_input_ctrl;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_input_ctrl <= r1_input_ctrl;
      r2_rd_data    <= r1_rd_data;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_input_ctrl <= r2_input_ctrl;
      r3_rd_data    <= r2_rd_data;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r4_input_ctrl <= r3_input_ctrl;
      r4_rd_data    <= r3_rd_data;
    end if;
  end process;

  Output_ctrl    <= r4_input_ctrl;
  Output_data(1) <= signed(r4_rd_data(MEM_DATA_WIDTH - 1 downto DATA_WIDTH));
  Output_data(0) <= signed(r4_rd_data(DATA_WIDTH - 1 downto 0));

end architecture rtl;
