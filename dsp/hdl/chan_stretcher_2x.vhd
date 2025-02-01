library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library mem_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity chan_stretcher_2x is
generic (
  FIFO_DEPTH  : natural;
  DATA_WIDTH  : natural
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Input_control         : in  channelizer_control_t;
  Input_data            : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  Input_pwr             : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Output_control        : out channelizer_control_t;
  Output_data           : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  Output_pwr            : out unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Error_fifo_overflow   : out std_logic;
  Error_fifo_underflow  : out std_logic
);
end entity chan_stretcher_2x;

architecture rtl of chan_stretcher_2x is

  constant FIFO_WIDTH   : natural := 7 + DATA_WIDTH * 2 + CHAN_POWER_WIDTH;

  signal w_fifo_wr_data         : std_logic_vector(FIFO_WIDTH - 1 downto 0);
  signal w_fifo_rd_data_packed  : std_logic_vector(FIFO_WIDTH - 1 downto 0);
  signal w_fifo_rd_data_control : channelizer_control_t;
  signal w_fifo_rd_data_iq      : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal w_fifo_rd_en           : std_logic;
  signal w_fifo_empty           : std_logic;
  signal w_fifo_overflow        : std_logic;
  signal w_fifo_underflow       : std_logic;

  signal r_read_cycle           : std_logic;

begin

  w_fifo_wr_data <= Input_control.last & std_logic_vector(Input_control.data_index) &
                    std_logic_vector(Input_data(1)) & std_logic_vector(Input_data(0)) &
                    std_logic_vector(Input_pwr);

  i_fifo : entity mem_lib.xpm_fallthrough_fifo
  generic map (
    FIFO_DEPTH  => FIFO_DEPTH,
    FIFO_WIDTH  => FIFO_WIDTH
  )
  port map (
    Clk           => Clk,
    Rst           => Rst,

    Wr_en         => Input_control.valid,
    Wr_data       => w_fifo_wr_data,
    Almost_full   => open,
    Full          => open,

    Rd_en         => w_fifo_rd_en,
    Rd_data       => w_fifo_rd_data_packed,
    Empty         => w_fifo_empty,

    Overflow      => w_fifo_overflow,
    Underflow     => w_fifo_underflow
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_read_cycle <= '0';
      else
        r_read_cycle <= not(r_read_cycle);
      end if;
    end if;
  end process;

  w_fifo_rd_en <= not(w_fifo_empty) and not(r_read_cycle);

  process(all)
  begin
    Output_pwr                <= unsigned(w_fifo_rd_data_packed(CHAN_POWER_WIDTH - 1                      downto 0));
    Output_data(0)            <= signed(w_fifo_rd_data_packed(CHAN_POWER_WIDTH + DATA_WIDTH - 1           downto CHAN_POWER_WIDTH));
    Output_data(1)            <= signed(w_fifo_rd_data_packed(CHAN_POWER_WIDTH + DATA_WIDTH * 2 - 1       downto CHAN_POWER_WIDTH + DATA_WIDTH));
    Output_control.data_index <= unsigned(w_fifo_rd_data_packed(CHAN_POWER_WIDTH + DATA_WIDTH * 2 + 6 - 1 downto CHAN_POWER_WIDTH + DATA_WIDTH * 2));
    Output_control.last       <= w_fifo_rd_data_packed(CHAN_POWER_WIDTH + DATA_WIDTH * 2 + 6);
    Output_control.valid      <= w_fifo_rd_en;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_fifo_overflow   <= w_fifo_overflow;
      Error_fifo_underflow  <= w_fifo_underflow;
    end if;
  end process;

end architecture rtl;
