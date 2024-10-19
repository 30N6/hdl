library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity ram_sdp is
generic (
  ADDR_WIDTH    : natural;
  DATA_WIDTH    : natural;
  LATENCY       : natural;
  MEMORY_STYLE  : string := "block"
);
port (
  Clk       : in  std_logic;

  Wr_en     : in  std_logic;
  Wr_addr   : in  unsigned(ADDR_WIDTH - 1 downto 0);
  Wr_data   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);

  Rd_en     : in  std_logic;
  Rd_reg_ce : in  std_logic;
  Rd_addr   : in  unsigned(ADDR_WIDTH - 1 downto 0);
  Rd_data   : out std_logic_vector(DATA_WIDTH - 1 downto 0)
);
end entity ram_sdp;

architecture rtl of ram_sdp is
  type data_array_t is array (integer range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

  signal m_ram                  : data_array_t(2**ADDR_WIDTH - 1 downto 0);
  signal r1_ram_out             : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal r2_ram_out             : std_logic_vector(DATA_WIDTH - 1 downto 0);

  attribute ram_style           : string;
  attribute ram_style of m_ram  : signal is MEMORY_STYLE;

begin

  assert ((LATENCY > 0) or (MEMORY_STYLE = "block"))
    report "Incompatible latency and memory_style."
    severity failure;

  assert (LATENCY <= 3)
    report "LATENCY must be 3 or less."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if ( Wr_en = '1' ) then
        m_ram(to_integer(Wr_addr)) <= Wr_data;
      end if;
    end if;
  end process;

  g_read : if (LATENCY = 0) generate

    Rd_data <= m_ram(to_integer(Rd_addr));

  elsif (LATENCY = 1) generate

    process(Clk)
    begin
      if rising_edge(Clk) then
        if ( Rd_en = '1' ) then
          Rd_data <= m_ram(to_integer(Rd_addr));
        end if;
      end if;
    end process;

  elsif (LATENCY = 2) generate

    process(Clk)
    begin
      if rising_edge(Clk) then
        if ( Rd_en = '1' ) then
          r1_ram_out <= m_ram(to_integer(Rd_addr));
        end if;
      end if;
    end process;

    process(Clk)
    begin
      if rising_edge(Clk) then
        if ( Rd_reg_ce = '1' ) then
          Rd_data <= r1_ram_out;
        end if;
      end if;
    end process;

  elsif (LATENCY = 3) generate

    process(Clk)
    begin
      if rising_edge(Clk) then
        if ( Rd_en = '1' ) then
          r1_ram_out <= m_ram(to_integer(Rd_addr));
        end if;
      end if;
    end process;

    process(Clk)
    begin
      if rising_edge(Clk) then
        if ( Rd_reg_ce = '1' ) then
          r2_ram_out <= r1_ram_out;
          Rd_data    <= r2_ram_out;
        end if;
      end if;
    end process;

  end generate;

end architecture rtl;
