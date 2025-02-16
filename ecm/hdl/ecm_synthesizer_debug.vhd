library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;
  use ecm_lib.ecm_debug_pkg.all;

library mem_lib;

entity ecm_synthesizer_debug is
port (
  Clk_axi           : in  std_logic;
  Clk               : in  std_logic;
  Rst               : in  std_logic;

  Debug_synthesizer : in  ecm_synthesizer_debug_t
);
end entity ecm_synthesizer_debug;

architecture rtl of ecm_synthesizer_debug is

  constant FIFO_DEPTH                             : natural := 1024;
  constant DEBUG_COMBINED_WIDTH                   : natural := ECM_SYNTHESIZER_DEBUG_WIDTH;

  signal r_debug_synthesizer                      : ecm_synthesizer_debug_t;
  signal r_debug_synthesizer_d                    : ecm_synthesizer_debug_t;

  signal w_debug_synthesizer_packed               : std_logic_vector(ECM_SYNTHESIZER_DEBUG_WIDTH - 1 downto 0);

  signal r_fifo_wr_en                             : std_logic;
  signal r_fifo_wr_data                           : std_logic_vector(DEBUG_COMBINED_WIDTH - 1 downto 0);
  signal w_fifo_rd_en                             : std_logic;
  signal w_fifo_rd_data                           : std_logic_vector(DEBUG_COMBINED_WIDTH - 1 downto 0);
  signal w_fifo_empty                             : std_logic;

  signal w_fifo_debug_synthesizer                 : std_logic_vector(ECM_SYNTHESIZER_DEBUG_WIDTH - 1 downto 0);

  signal w_unpacked_synthesizer                   : ecm_synthesizer_debug_t;

  attribute MARK_DEBUG                            : string;
  attribute DONT_TOUCH                            : string;
  attribute MARK_DEBUG of w_fifo_rd_en            : signal is "TRUE";
  attribute DONT_TOUCH of w_fifo_rd_en            : signal is "TRUE";
  attribute MARK_DEBUG of w_unpacked_synthesizer  : signal is "TRUE";
  attribute DONT_TOUCH of w_unpacked_synthesizer  : signal is "TRUE";
begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_debug_synthesizer    <= Debug_synthesizer;
      r_debug_synthesizer_d  <= r_debug_synthesizer;
    end if;
  end process;

  w_debug_synthesizer_packed <= pack(r_debug_synthesizer);

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_fifo_wr_en <= (r_debug_synthesizer.w_synthesizer16_input_ctrl_valid and r_debug_synthesizer.w_synthesizer16_input_ctrl_tx_active) or
                      (r_debug_synthesizer.w_synthesizer16_output_valid and r_debug_synthesizer.w_synthesizer16_output_active);

      r_fifo_wr_data <= w_debug_synthesizer_packed;
    end if;
  end process;

  w_fifo_rd_en <= not(w_fifo_empty);

  i_fifo : entity mem_lib.xpm_async_fifo
  generic map (
    FIFO_DEPTH => FIFO_DEPTH,
    FIFO_WIDTH => DEBUG_COMBINED_WIDTH
  )
  port map (
    Clk_wr        => Clk,
    Clk_rd        => Clk_axi,
    Rst_wr        => Rst,

    Wr_en         => r_fifo_wr_en,
    Wr_data       => r_fifo_wr_data,
    Almost_full   => open,
    Full          => open,

    Rd_en         => w_fifo_rd_en,
    Rd_data       => w_fifo_rd_data,
    Empty         => w_fifo_empty,

    Overflow      => open,
    Underflow     => open
  );

  w_fifo_debug_synthesizer  <= w_fifo_rd_data;
  w_unpacked_synthesizer    <= unpack(w_fifo_debug_synthesizer);

end architecture rtl;
