library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library xpm;
  use xpm.vcomponents.all;

entity xpm_async_fifo is
generic (
  FIFO_DEPTH        : natural;
  FIFO_WIDTH        : natural;
  ALMOST_FULL_LEVEL : natural := 8
);
port (
  Clk_wr        : in  std_logic;
  Clk_rd        : in  std_logic;
  Rst_wr        : in  std_logic;

  Wr_en         : in  std_logic;
  Wr_data       : in  std_logic_vector(FIFO_WIDTH - 1 downto 0);
  Almost_full   : out std_logic;
  Full          : out std_logic;

  Rd_en         : in  std_logic;
  Rd_data       : out std_logic_vector(FIFO_WIDTH - 1 downto 0);
  Empty         : out std_logic;

  Overflow      : out std_logic;
  Underflow     : out std_logic
);
end entity xpm_async_fifo;

architecture rtl of xpm_async_fifo is
begin

  xpm_fifo_async_inst : xpm_fifo_async
  generic map (
   CASCADE_HEIGHT       => 0,
   CDC_SYNC_STAGES      => 2,
   DOUT_RESET_VALUE     => "0",
   ECC_MODE             => "no_ecc",
   FIFO_MEMORY_TYPE     => "auto",
   FIFO_READ_LATENCY    => 0,
   FIFO_WRITE_DEPTH     => FIFO_DEPTH,
   FULL_RESET_VALUE     => 0,
   PROG_EMPTY_THRESH    => 10,
   PROG_FULL_THRESH     => ALMOST_FULL_LEVEL,
   RD_DATA_COUNT_WIDTH  => 1,
   READ_DATA_WIDTH      => FIFO_WIDTH,
   READ_MODE            => "fwft",
   RELATED_CLOCKS       => 0,
   SIM_ASSERT_CHK       => 0,
   USE_ADV_FEATURES     => "0103",
   WAKEUP_TIME          => 0,
   WRITE_DATA_WIDTH     => FIFO_WIDTH,
   WR_DATA_COUNT_WIDTH  => 1
  )
  port map (
   almost_empty   => open,
   almost_full    => open,
   data_valid     => open,
   dbiterr        => open,
   dout           => Rd_data,
   empty          => Empty,
   full           => Full,
   overflow       => Overflow,
   prog_empty     => open,
   prog_full      => Almost_full,
   rd_data_count  => open,
   rd_rst_busy    => open,
   sbiterr        => open,
   underflow      => Underflow,
   wr_ack         => open,
   wr_data_count  => open,
   wr_rst_busy    => open,
   din            => Wr_data,
   injectdbiterr  => '0',
   injectsbiterr  => '0',
   rd_clk         => Clk_rd,
   rd_en          => Rd_en,
   rst            => Rst_wr,
   sleep          => '0',
   wr_clk         => Clk_wr,
   wr_en          => Wr_en
  );

end architecture rtl;
