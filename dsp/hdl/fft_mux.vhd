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
  Clk             : in  std_logic;
  Rst             : in  std_logic;

  Input_chan_ctrl : in  fft_control_t;  -- 1/2 rate
  Input_chan_data : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Input_raw_ctrl  : in  fft_control_t;      -- 1/4 rate
  Input_raw_data  : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Output_ctrl     : out fft_control_t;
  Output_data     : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Error_overflow  : out std_logic;
  Error_underflow : out std_logic;
  Error_collision : out std_logic
);
end entity fft_mux;

architecture rtl of fft_mux is

  constant FIFO_READ_LATENCY    : natural := 2;

  signal w_chan_fifo_ctrl       : fft_control_t;
  signal w_chan_fifo_data       : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  signal w_raw_fifo_read        : std_logic;
  signal w_raw_fifo_avail       : std_logic;
  signal w_raw_fifo_ctrl        : fft_control_t;
  signal w_raw_fifo_data        : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  signal w_chan_fifo_overflow   : std_logic;
  signal w_chan_fifo_underflow  : std_logic;
  signal w_raw_fifo_overflow    : std_logic;
  signal w_raw_fifo_underflow   : std_logic;
  signal r_chan_fifo_overflow   : std_logic;
  signal r_chan_fifo_underflow  : std_logic;
  signal r_raw_fifo_overflow    : std_logic;
  signal r_raw_fifo_underflow   : std_logic;
  signal r_collision            : std_logic;
begin

  i_chan_fifo : entity dsp_lib.fft_sample_fifo
  generic map (
    DATA_WIDTH        => DATA_WIDTH,
    DATA_INDEX_WIDTH  => CHANNEL_INDEX_WIDTH,
    READ_LATENCY      => FIFO_READ_LATENCY,
    IMMEDIATE_READ    => '1'
  )
  port map (
    Clk               => Clk,
    Rst               => Rst,

    Input_ctrl        => Input_chan_ctrl,
    Input_data        => Input_chan_data,

    Output_read       => '0',
    Output_available  => open,
    Output_ctrl       => w_chan_fifo_ctrl,
    Output_data       => w_chan_fifo_data,

    Error_overflow    => w_chan_fifo_overflow,
    Error_underflow   => w_chan_fifo_underflow
  );

  w_raw_fifo_read <= w_chan_fifo_ctrl.valid and to_stdlogic(w_chan_fifo_ctrl.data_index = (2**CHANNEL_INDEX_WIDTH - 1 - FIFO_READ_LATENCY)) and w_raw_fifo_avail;

  i_raw_fifo : entity dsp_lib.fft_sample_fifo
  generic map (
    DATA_WIDTH        => DATA_WIDTH,
    DATA_INDEX_WIDTH  => CHANNEL_INDEX_WIDTH,
    READ_LATENCY      => FIFO_READ_LATENCY,
    IMMEDIATE_READ    => '0'
  )
  port map (
    Clk               => Clk,
    Rst               => Rst,

    Input_ctrl        => Input_raw_ctrl,
    Input_data        => Input_raw_data,

    Output_read       => w_raw_fifo_read,
    Output_available  => w_raw_fifo_avail,
    Output_ctrl       => w_raw_fifo_ctrl,
    Output_data       => w_raw_fifo_data,

    Error_overflow    => w_raw_fifo_overflow,
    Error_underflow   => w_raw_fifo_underflow
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_chan_fifo_ctrl.valid = '1') then
        Output_ctrl         <= w_chan_fifo_ctrl;
        Output_ctrl.reverse <= '1';
        Output_data         <= w_chan_fifo_data;
      else
        Output_ctrl         <= w_raw_fifo_ctrl;
        Output_ctrl.reverse <= '0';
        Output_data         <= w_raw_fifo_data;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_chan_fifo_overflow  <= w_chan_fifo_overflow;
      r_chan_fifo_underflow <= w_chan_fifo_underflow;
      r_raw_fifo_overflow   <= w_raw_fifo_overflow;
      r_raw_fifo_underflow  <= w_raw_fifo_underflow;
      r_collision           <= w_chan_fifo_ctrl.valid and w_raw_fifo_ctrl.valid;

      Error_overflow        <= r_chan_fifo_overflow or r_raw_fifo_overflow;
      Error_underflow       <= r_chan_fifo_underflow or r_raw_fifo_underflow;
      Error_collision       <= r_collision;
    end if;
  end process;

end architecture rtl;
