library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library mem_lib;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;

entity ecm_drfm_mem is
generic (
  DATA_WIDTH    : natural;
  LATENCY       : natural
);
port (
  Clk       : in  std_logic;

  Wr_en     : in  std_logic;
  Wr_addr   : in  unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  Wr_data   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);

  Rd_addr   : in  unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  Rd_data   : out std_logic_vector(DATA_WIDTH - 1 downto 0)
);
end entity ecm_drfm_mem;

architecture rtl of ecm_drfm_mem is

  constant MEM0_DEPTH     : natural := 2**(ECM_DRFM_ADDR_WIDTH - 1);
  constant MEM1_DEPTH     : natural := 2**(ECM_DRFM_ADDR_WIDTH - 2);

  signal w0_mem0_wr_en    : std_logic;
  signal w0_mem1_wr_en    : std_logic;

  signal r1_rd_addr       : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);

  signal r2_rd_addr       : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal w2_mem0_rd_data  : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal w2_mem1_rd_data  : std_logic_vector(DATA_WIDTH - 1 downto 0);

begin

  assert (LATENCY = 3)
    report "LATENCY must be 3"
    severity failure;

  assert (ECM_DRFM_MEM_DEPTH = (MEM0_DEPTH + MEM1_DEPTH))
    report "Unexpected memory depth"
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_rd_addr <= Rd_addr;
      r2_rd_addr <= r1_rd_addr;
    end if;
  end process;

  w0_mem0_wr_en <= Wr_en and not(Wr_addr(ECM_DRFM_ADDR_WIDTH - 1));
  w0_mem1_wr_en <= Wr_en and Wr_addr(ECM_DRFM_ADDR_WIDTH - 1);

  i_mem_0 : entity mem_lib.ram_sdp
  generic map (
    ADDR_WIDTH  => ECM_DRFM_ADDR_WIDTH - 1,
    DATA_WIDTH  => DATA_WIDTH,
    LATENCY     => 2
  )
  port map (
    Clk       => Clk,

    Wr_en     => w0_mem0_wr_en,
    Wr_addr   => Wr_addr(ECM_DRFM_ADDR_WIDTH - 2 downto 0),
    Wr_data   => Wr_data,

    Rd_en     => '1',
    Rd_reg_ce => '1',
    Rd_addr   => Rd_addr(ECM_DRFM_ADDR_WIDTH - 2 downto 0),
    Rd_data   => w2_mem0_rd_data
  );

  i_mem_1 : entity mem_lib.ram_sdp
  generic map (
    ADDR_WIDTH  => ECM_DRFM_ADDR_WIDTH - 2,
    DATA_WIDTH  => DATA_WIDTH,
    LATENCY     => 2
  )
  port map (
    Clk       => Clk,

    Wr_en     => w0_mem1_wr_en,
    Wr_addr   => Wr_addr(ECM_DRFM_ADDR_WIDTH - 3 downto 0),
    Wr_data   => Wr_data,

    Rd_en     => '1',
    Rd_reg_ce => '1',
    Rd_addr   => Rd_addr(ECM_DRFM_ADDR_WIDTH - 3 downto 0),
    Rd_data   => w2_mem1_rd_data
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r2_rd_addr(ECM_DRFM_ADDR_WIDTH - 1) = '0') then
        Rd_data <= w2_mem0_rd_data;
      else
        Rd_data <= w2_mem1_rd_data;
      end if;
    end if;
  end process;

end architecture rtl;
