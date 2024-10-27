library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library xpm;
  use xpm.vcomponents.all;

entity axis_async_fifo is
generic (
  FIFO_DEPTH        : natural;
  ALMOST_FULL_LEVEL : natural;
  AXI_DATA_WIDTH    : natural
);
port (
  S_axis_clk          : in  std_logic;
  S_axis_resetn       : in  std_logic;
  S_axis_ready        : out std_logic;
  S_axis_valid        : in  std_logic;
  S_axis_data         : in  std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  S_axis_last         : in  std_logic;
  S_axis_almost_full  : out std_logic;

  M_axis_clk          : in  std_logic;
  M_axis_ready        : in  std_logic;
  M_axis_valid        : out std_logic;
  M_axis_data         : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  M_axis_last         : out std_logic
);
end entity axis_async_fifo;

architecture rtl of axis_async_fifo is
begin

  xpm_fifo_axis_inst : xpm_fifo_axis
  generic map (
     CASCADE_HEIGHT       => 0,
     CDC_SYNC_STAGES      => 2,
     CLOCKING_MODE        => "independent_clock",
     ECC_MODE             => "no_ecc",
     FIFO_DEPTH           => FIFO_DEPTH,
     FIFO_MEMORY_TYPE     => "auto",
     PACKET_FIFO          => "false",
     PROG_EMPTY_THRESH    => 10,
     PROG_FULL_THRESH     => ALMOST_FULL_LEVEL,
     RD_DATA_COUNT_WIDTH  => 1,
     RELATED_CLOCKS       => 0,
     SIM_ASSERT_CHK       => 0,
     TDATA_WIDTH          => AXI_DATA_WIDTH,
     TDEST_WIDTH          => 1,
     TID_WIDTH            => 1,
     TUSER_WIDTH          => 1,
     USE_ADV_FEATURES     => "2",
     WR_DATA_COUNT_WIDTH  => 1
  )
  port map (
     s_aclk             => S_axis_clk,
     s_aresetn          => S_axis_resetn,
     s_axis_tready      => S_axis_ready,
     s_axis_tdata       => S_axis_data,
     s_axis_tdest       => (others => '0'),
     s_axis_tid         => (others => '0'),
     s_axis_tkeep       => (others => '0'),
     s_axis_tlast       => S_axis_last,
     s_axis_tstrb       => (others => '0'),
     s_axis_tuser       => (others => '0'),
     s_axis_tvalid      => S_axis_valid,

     m_aclk             => M_axis_clk,
     m_axis_tready      => M_axis_ready,
     m_axis_tdata       => M_axis_data,
     m_axis_tdest       => open,
     m_axis_tid         => open,
     m_axis_tkeep       => open,
     m_axis_tlast       => M_axis_last,
     m_axis_tstrb       => open,
     m_axis_tuser       => open,
     m_axis_tvalid      => M_axis_valid,

     prog_empty_axis    => open,
     prog_full_axis     => S_axis_almost_full,
     rd_data_count_axis => open,

     almost_empty_axis  => open,
     almost_full_axis   => open,
     dbiterr_axis       => open,
     sbiterr_axis       => open,
     wr_data_count_axis => open,
     injectdbiterr_axis => '0',
     injectsbiterr_axis => '0'
  );

end architecture rtl;
