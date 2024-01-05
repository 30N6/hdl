library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;

entity preamble_detector is
generic (
  MAG_WIDTH             : natural;
  MOVING_AVG_WIDTH      : natural;
  CORRELATOR_WIDTH      : natural;
  FILTERED_MAG_WIDTH    : natural;
  MAG_FILTER_LENGTH     : natural;
  SSNR_THRESHOLD        : natural
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Mag_valid             : in  std_logic;
  Mag_data              : in  unsigned(MAG_WIDTH - 1 downto 0);
  Moving_avg_valid      : in  std_logic;
  Moving_avg_data       : in  unsigned(MOVING_AVG_WIDTH - 1 downto 0);
  Correlator_valid      : in  std_logic;
  Correlator_data       : in  unsigned(CORRELATOR_WIDTH - 1 downto 0);

  Output_valid          : out std_logic;
  Output_start          : out std_logic;
  Output_filtered_mag   : out unsigned(FILTERED_MAG_WIDTH - 1 downto 0);
  Output_preamble_corr  : out unsigned(CORRELATOR_WIDTH - 1 downto 0)

  --TODO: errors? at least assert that the valids match?
);
end entity preamble_detector;

architecture rtl of preamble_detector is

  constant DETECTION_PIPE_DEPTH : natural := 2 * MAG_FILTER_LENGTH + 1;

  constant WINDOW_BIT_WIDTH : natural := clog2(CORRELATION_LENGTH);
  constant SUM_WIDTH        : natural := INPUT_WIDTH + WINDOW_BIT_WIDTH;

  type corr_data_array_t   is array (natural range <>) of unsigned(CORRELATOR_WIDTH - 1 downto 0);
  type sum_data_array_t     is array (natural range <>) of unsigned(SUM_WIDTH - 1 downto 0);

  signal r_rst              : std_logic;

  signal w_input_valid      : std_logic;
  signal w_input_data       : unsigned(INPUT_WIDTH - 1 downto 0);

  signal r_sum_pipe         : sum_data_array_t(CORRELATION_LENGTH - 1 downto 0);
  signal r_sum_valid        : std_logic;

  signal w_sn_threshold       : unsigned(MOVING_AVG_WIDTH + clog2(SSNR_THRESHOLD) - 1 downto 0);
  signal w_ssnr_exceeded      : std_logic;
  signal w_preamble_detected  : std_logic;

  signal r_det_pipe_valid     : std_logic_vector(DETECTION_PIPE_DEPTH - 1 downto 0);
  signal r_det_pipe_corr_data : corr_data_array_t(DETECTION_PIPE_DEPTH - 1 downto 0);

  signal w_filtered_mag_data  : unsigned(FILTERED_MAG_WIDTH - 1 downto 0);
  signal w_filtered_mag_valid : std_logic;

begin

  w_sn_threshold      <= SSNR_THRESHOLD * Moving_avg_data;
  w_ssnr_exceeded     <= to_stdlogic(Correlator_data >= w_sn_threshold);
  w_preamble_detected <= Moving_avg_valid and Correlator_valid and w_ssnr_exceeded;

  i_mag_filter : entity dsp_lib.filter_moving_avg
  generic map (
    WINDOW_LENGTH => MAG_FILTER_LENGTH,
    LATENCY       => MAG_FILTER_LENGTH + 1,
    INPUT_WIDTH   => MAG_WIDTH,
    OUTPUT_WIDTH  => FILTERED_MAG_WIDTH
  )
  port map (
    Clk           => Clk,
    Rst           => Rst,

    Input_valid   => Mag_valid,
    Input_data    => Mag_data,

    Output_valid  => w_filtered_mag_valid,
    Output_data   => w_filtered_mag_data
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Correlator_valid = '1') then
        r_det_pipe_valid      <= r_det_pipe_valid(DETECTION_PIPE_DEPTH - 2 downto 0)    & w_preamble_detected;
        r_det_pipe_corr_data  <= w_preamble_detected(DETECTION_PIPE_DEPTH - 2 downto 0) & Correlator_data;
      end if;
    end if;
  end process;

end architecture rtl;
