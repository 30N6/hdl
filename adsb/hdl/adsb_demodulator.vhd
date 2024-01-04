library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library dsp_lib;

entity adsb_demodulator is
generic (
  AXI_DATA_WIDTH  : natural;
  IQ_WIDTH        : natural
);
port (
  Data_clk        : in  std_logic;
  Data_rst        : in  std_logic;

  Adc_valid       : in  std_logic;
  Adc_data_i      : in  signed(15 downto 0);
  Adc_data_q      : in  signed(15 downto 0);

  S_axis_clk      : in  std_logic;
  S_axis_resetn   : in  std_logic;
  S_axis_ready    : out std_logic;
  S_axis_valid    : in  std_logic;
  S_axis_data     : in  std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  S_axis_last     : in  std_logic;

  M_axis_clk      : in  std_logic;
  M_axis_resetn   : in  std_logic;
  M_axis_ready    : in  std_logic;
  M_axis_valid    : out std_logic;
  M_axis_data     : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  M_axis_last     : out std_logic
);
end entity adsb_demodulator;

architecture rtl of adsb_demodulator is

  constant AXI_FIFO_DEPTH             : natural := 64;
  constant PREAMBLE_LENGTH            : natural := 64;  -- 8 MHz sampling rate assumed
  constant PREAMBLE_FILTER_BIT_WIDTH  : natural := IQ_WIDTH + 2;

  signal w_data_rst           : std_logic;

  signal r_adc_valid          : std_logic;
  signal r_adc_data_i         : signed(IQ_WIDTH - 1 downto 0);
  signal r_adc_data_q         : signed(IQ_WIDTH - 1 downto 0);

  signal w_mag_valid          : std_logic;
  signal w_mag_data           : unsigned(IQ_WIDTH - 1 downto 0);

  signal w_filtered_sn_valid  : std_logic;
  signal w_filtered_sn_data   : unsigned(PREAMBLE_FILTER_BIT_WIDTH - 1 downto 0);
  signal w_filtered_s_valid   : std_logic;
  signal w_filtered_s_data    : unsigned(PREAMBLE_FILTER_BIT_WIDTH - 1 downto 0);

begin

  i_reset : entity common_lib.reset_extender
  generic map (
    RESET_LENGTH => 2*PREAMBLE_LENGTH
  )
  port map (
    Clk     => Data_clk,
    Rst_in  => Data_rst,
    Rst_out => w_data_rst
  );

  r_data_reset  <= Data_rst;

  process(Data_clk)
  begin
    if rising_edge(Data_clk) then
      r_adc_valid   <= Adc_valid;
      r_adc_data_i  <= Adc_data_i(IQ_WIDTH - 1 downto 0);
      r_adc_data_q  <= Adc_data_q(IQ_WIDTH - 1 downto 0);
    end if;
  end process;

  --TODO: clear filter pipeline on reset

  i_mag_approx : entity dsp_lib.mag_approximation
  generic map (
    INPUT_WIDTH => IQ_WIDTH
  )
  port map (
    Clk           => Data_clk,

    Input_valid   => r_adc_valid,
    Input_i       => r_adc_data_i,
    Input_q       => r_adc_data_q,

    Output_valid  => w_mag_valid,
    Output_data   => w_mag_data
  );

  -- preamble: signal + noise
  i_filter_s_plus_n : entity dsp_lib.filter_moving_avg
  generic map (
    WINDOW_LENGTH => PREAMBLE_LENGTH,
    LATENCY       => PREAMBLE_LENGTH + 1,
    INPUT_WIDTH   => IQ_WIDTH,
    OUTPUT_WIDTH  => PREAMBLE_FILTER_BIT_WIDTH
  )
  port map (
    Clk           => Data_clk,
    Rst           => w_data_rst,

    Input_valid   => w_mag_valid,
    Input_data    => w_mag_data,

    Output_valid  => w_filtered_sn_valid,
    Output_data   => w_filtered_sn_data
  );

  -- preamble: signal only
  i_filter_s : entity dsp_lib.mode_s_preamble_correlator
  generic map (
    WINDOW_LENGTH => PREAMBLE_LENGTH,
    LATENCY       => PREAMBLE_LENGTH + 1,
    INPUT_WIDTH   => IQ_WIDTH,
    OUTPUT_WIDTH  => PREAMBLE_FILTER_BIT_WIDTH
  )
  port map (
    Clk           => Data_clk,
    Rst           => w_data_rst,

    Input_valid   => w_mag_valid,
    Input_data    => w_mag_data,

    Output_valid  => w_filtered_s_valid,
    Output_data   => w_filtered_s_data
  );


  process(Data_clk)
  begin
    if rising_edge(Data_clk) then

    end if;
  end process;

  i_slave_axis_fifo : entity axi_lib.axis_async_fifo
  generic map (
    FIFO_DEPTH      => AXI_FIFO_DEPTH,
    AXI_DATA_WIDTH  => AXI_DATA_WIDTH
  )
  port map (
    S_axis_clk      => S_axis_clk,
    S_axis_resetn   => S_axis_resetn,
    S_axis_ready    => S_axis_ready,
    S_axis_valid    => S_axis_valid,
    S_axis_data     => S_axis_data,
    S_axis_last     => S_axis_last,

    M_axis_clk      => Data_clk,
    M_axis_ready    : in  std_logic;
    M_axis_valid    : out std_logic;
    M_axis_data     : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
    M_axis_last     : out std_logic
  );

  i_master_axis_fifo : entity axi_lib.axis_async_fifo
  generic map (
    FIFO_DEPTH      => AXI_FIFO_DEPTH,
    AXI_DATA_WIDTH  => AXI_DATA_WIDTH
  )
  port map (
    S_axis_clk      => Data_clk,
    S_axis_resetn   => not(r_data_reset),
    S_axis_ready    => ,
    S_axis_valid    => ,
    S_axis_data     => ,
    S_axis_last     => ,

    M_axis_clk      => M_axis_clk,
    M_axis_ready    => M_axis_ready,
    M_axis_valid    => M_axis_valid,
    M_axis_data     => M_axis_data,
    M_axis_last     => M_axis_last
  );

end architecture rtl;