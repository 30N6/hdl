library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library mem_lib;

entity fft_mux is
generic (
  DATA_WIDTH          : natural;
  CHANNEL_INDEX_WIDTH : natural
);
port (
  Clk                 : in  std_logic;
  Rst                 : in  std_logic;

  Input_chan_control  : in  fft_control_t;  -- 1/2 rate
  Input_chan_data     : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Input_raw_control   : in  fft_control_t;      -- 1/4 rate
  Input_raw_data      : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Output_control      : out fft_control_t;
  Output_data         : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0)
);
end entity fft_mux;

architecture rtl of fft_mux is

  constant NUM_PAGES        : natural := 2;
  constant PAGE_INDEX_WIDTH : natural := clog2(NUM_PAGES);
  constant BUF_PIPE_STAGES  : natural := 2;

  signal w_chan_wr_data     : std_logic_vector(2*DATA_WIDTH - 1 downto 0);
  signal w_chan_valid       : std_logic;
  signal w_chan_last        : std_logic;
  signal w_chan_index       : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_chan_data        : std_logic_vector(2*DATA_WIDTH - 1 downto 0);

  signal w_raw_wr_data      : std_logic_vector(2*DATA_WIDTH - 1 downto 0);
  signal w_raw_valid        : std_logic;
  signal w_raw_last         : std_logic;
  signal w_raw_index        : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_raw_data         : std_logic_vector(2*DATA_WIDTH - 1 downto 0);
  signal w_raw_start        : std_logic;

begin

  w_chan_wr_data <= std_logic_vector(Input_chan_data(1)) & std_logic_vector(Input_chan_data(0));

  i_chan_buffer : entity dsp_lib.fft_sample_buffer
  generic map (
    DATA_WIDTH        => 2*DATA_WIDTH,
    DATA_INDEX_WIDTH  => CHANNEL_INDEX_WIDTH,
    READ_PIPE_STAGES  => 2,
    IMMEDIATE_READ    => true
  )
  port map (
    Clk           => Clk,
    Rst           => Rst,

    Input_valid   => Input_chan_control.valid,
    Input_last    => Input_chan_control.last,
    Input_index   => Input_chan_control.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0),
    Input_data    => w_chan_wr_data,

    Output_start  => '0',
    Output_valid  => w_chan_valid,
    Output_last   => w_chan_last,
    Output_index  => w_chan_index,
    Output_data   => w_chan_data
  );

  w_raw_wr_data <= std_logic_vector(Input_raw_data(1)) & std_logic_vector(Input_raw_data(0));

  i_raw_buffer : entity dsp_lib.fft_sample_buffer
  generic map (
    DATA_WIDTH        => 2*DATA_WIDTH,
    DATA_INDEX_WIDTH  => CHANNEL_INDEX_WIDTH,
    READ_PIPE_STAGES  => 2,
    IMMEDIATE_READ    => false
  )
  port map (
    Clk           => Clk,
    Rst           => Rst,

    Input_valid   => Input_raw_control.valid,
    Input_last    => Input_raw_control.last,
    Input_index   => Input_raw_control.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0),
    Input_data    => w_raw_wr_data,

    Output_start  => w_raw_start,
    Output_valid  => w_raw_valid,
    Output_last   => w_raw_last,
    Output_index  => w_raw_index,
    Output_data   => w_raw_data
  );

  --TODO: can't use this -- need a proper fifo since the raw buffer is filled at half the rate
  w_raw_start <= w_chan_valid and to_stdlogic(w_chan_index = (2**CHANNEL_INDEX_WIDTH - 1 - BUF_PIPE_STAGES));

  --TODO: collision error check
  --TODO: fifo underflow/overflow

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_chan_valid = '1') then
        Output_control.valid      <= '1';
        Output_control.last       <= w_chan_last;
        Output_control.data_index <= resize_up(w_chan_index, Output_control.data_index'length);
        Output_control.reverse    <= '1';
        Output_data(0)            <= signed(w_chan_data(DATA_WIDTH - 1 downto 0));
        Output_data(1)            <= signed(w_chan_data(2*DATA_WIDTH - 1 downto DATA_WIDTH));
      else
        Output_control.valid      <= w_raw_valid;
        Output_control.last       <= w_raw_last;
        Output_control.data_index <= resize_up(w_raw_index, Output_control.data_index'length);
        Output_control.reverse    <= '0';
        Output_data(0)            <= signed(w_raw_data(DATA_WIDTH - 1 downto 0));
        Output_data(1)            <= signed(w_raw_data(2*DATA_WIDTH - 1 downto DATA_WIDTH));
      end if;
    end if;
  end process;

end architecture rtl;
