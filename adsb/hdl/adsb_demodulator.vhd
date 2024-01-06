library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library dsp_lib;

library adsb_lib;
  use adsb_lib.adsb_pkg.all;

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
  constant PREAMBLE_LENGTH            : natural := 64;            -- 8 MHz sampling rate assumed    --TODO: move to package
  constant PREAMBLE_SN_WIDTH          : natural := IQ_WIDTH;      -- scale the output by 1/64 for a total gain of 1
  constant PREAMBLE_S_WIDTH           : natural := IQ_WIDTH + 2;  -- scale the output by 1/16 for a total gain of 1
  constant MAG_FILTER_LENGTH          : natural := 4;             -- 0.5 us matched filter
  constant FILTERED_MAG_WIDTH         : natural := IQ_WIDTH + clog2(MAG_FILTER_LENGTH);
  constant SSNR_THRESHOLD             : natural := 2;

  constant PREAMBLE_DATA              : std_logic_vector(0 to PREAMBLE_LENGTH-1) := "1111000011110000000000000000111100001111000000000000000000000000";

  signal w_rst_from_config        : std_logic;
  signal w_combined_rst           : std_logic;
  signal w_extended_rst           : std_logic;
  signal w_enable                 : std_logic;

  signal r_timestamp              : timestamp_t;

  signal r_adc_valid              : std_logic;
  signal r_adc_data_i             : signed(IQ_WIDTH - 1 downto 0);
  signal r_adc_data_q             : signed(IQ_WIDTH - 1 downto 0);

  signal w_mag_valid              : std_logic;
  signal w_mag_data               : unsigned(IQ_WIDTH - 1 downto 0);

  signal w_filtered_sn_valid      : std_logic;
  signal w_filtered_sn_data       : unsigned(PREAMBLE_SN_WIDTH - 1 downto 0);
  signal w_filtered_s_valid       : std_logic;
  signal w_filtered_s_data        : unsigned(PREAMBLE_S_WIDTH - 1 downto 0);
  signal w_delayed_mag_valid      : std_logic;
  signal w_delayed_mag_data       : unsigned(IQ_WIDTH - 1 downto 0);

  signal w_detector_valid         : std_logic;
  signal w_detector_start         : std_logic;
  signal w_detector_filtered_mag  : unsigned(FILTERED_MAG_WIDTH - 1 downto 0);
  signal w_detector_preamble_s    : unsigned(PREAMBLE_S_WIDTH - 1 downto 0);
  signal w_detector_preamble_sn   : unsigned(PREAMBLE_SN_WIDTH - 1 downto 0);

  signal w_sampler_valid          : std_logic;
  signal w_sampler_message_data   : adsb_message_t;
  signal w_sampler_preamble_s     : unsigned(PREAMBLE_S_WIDTH - 1 downto 0);
  signal w_sampler_preamble_sn    : unsigned(PREAMBLE_SN_WIDTH - 1 downto 0);
  signal w_sampler_crc_match      : std_logic;
  signal w_sampler_timestamp      : timestamp_t;

  signal w_reporter_axis_ready    : std_logic;
  signal w_reporter_axis_valid    : std_logic;
  signal w_reporter_axis_data     : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_reporter_axis_last     : std_logic;

  signal w_config_axis_ready      : std_logic;
  signal w_config_axis_valid      : std_logic;
  signal w_config_axis_data       : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_config_axis_last       : std_logic;

begin

  w_combined_rst <= Data_rst or w_rst_from_config;

  i_reset : entity common_lib.reset_extender
  generic map (
    RESET_LENGTH => 2*PREAMBLE_LENGTH
  )
  port map (
    Clk     => Data_clk,
    Rst_in  => w_combined_rst,
    Rst_out => w_extended_rst
  );

  process(Data_clk)
  begin
    if rising_edge(Data_clk) then
      if (w_extended_rst = '1') then
        r_timestamp <= (others => '0');
      else
        r_timestamp <= r_timestamp + 1;
      end if;
    end if;
  end process;

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
    DATA_WIDTH  => IQ_WIDTH,
    LATENCY     => 0
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
    OUTPUT_WIDTH  => PREAMBLE_SN_WIDTH
  )
  port map (
    Clk           => Data_clk,
    Rst           => w_extended_rst,

    Input_valid   => w_mag_valid,
    Input_data    => w_mag_data,

    Output_valid  => w_filtered_sn_valid,
    Output_data   => w_filtered_sn_data
  );

  -- preamble: signal only
  i_filter_s : entity dsp_lib.correlator_simple
  generic map (
    CORRELATION_LENGTH  => PREAMBLE_LENGTH,
    CORRELATION_DATA    => PREAMBLE_DATA,
    LATENCY             => PREAMBLE_LENGTH + 1,
    INPUT_WIDTH         => IQ_WIDTH,
    OUTPUT_WIDTH        => PREAMBLE_S_WIDTH
  )
  port map (
    Clk           => Data_clk,
    Rst           => w_extended_rst,

    Input_valid   => w_mag_valid,
    Input_data    => w_mag_data,

    Output_valid  => w_filtered_s_valid,
    Output_data   => w_filtered_s_data
  );

  -- delayed magnitude to match preamble correlator
  i_delayed_mag : entity dsp_lib.pipeline_delay
  generic map (
    DATA_WIDTH    => IQ_WIDTH,
    LATENCY       => PREAMBLE_LENGTH + 1
  )
  port map (
    Clk           => Data_clk,

    Input_valid   => w_mag_valid,
    Input_data    => w_mag_data,

    Output_valid  => w_delayed_mag_valid,
    Output_data   => w_delayed_mag_data
  );

  i_preamble_detector : entity adsb_lib.preamble_detector
  generic map (
    MAG_WIDTH             => IQ_WIDTH,
    MOVING_AVG_WIDTH      => PREAMBLE_SN_WIDTH,
    CORRELATOR_WIDTH      => PREAMBLE_S_WIDTH,
    FILTERED_MAG_WIDTH    => FILTERED_MAG_WIDTH,
    MAG_FILTER_LENGTH     => MAG_FILTER_LENGTH,
    SSNR_THRESHOLD        => SSNR_THRESHOLD
  )
  port map (
    Clk                   => Data_clk,
    Rst                   => w_extended_rst,

    Mag_valid             => w_delayed_mag_valid,
    Mag_data              => w_delayed_mag_data,
    Moving_avg_valid      => w_filtered_sn_valid,
    Moving_avg_data       => w_filtered_sn_data,
    Correlator_valid      => w_filtered_s_valid,
    Correlator_data       => w_filtered_s_data,

    Output_valid          => w_detector_valid,
    Output_start          => w_detector_start,
    Output_filtered_mag   => w_detector_filtered_mag,
    Output_preamble_s     => w_detector_preamble_s,
    Output_preamble_sn    => w_detector_preamble_sn
  );

  i_sampler : entity adsb_lib.message_sampler
  generic map (
    PREAMBLE_LENGTH     => PREAMBLE_LENGTH,
    PREAMBLE_S_WIDTH    => PREAMBLE_S_WIDTH,
    PREAMBLE_SN_WIDTH   => PREAMBLE_SN_WIDTH,
    FILTERED_MAG_WIDTH  => FILTERED_MAG_WIDTH
  )
  port map (
    Clk                 => Data_clk,
    Rst                 => w_extended_rst,

    Enable              => w_enable,
    Timestamp           => r_timestamp,

    Input_valid         => w_detector_valid,
    Input_start         => w_detector_start,
    Input_filtered_mag  => w_detector_filtered_mag,
    Input_preamble_s    => w_detector_preamble_s,
    Input_preamble_sn   => w_detector_preamble_sn,

    Output_valid        => w_sampler_valid,
    Output_message_data => w_sampler_message_data,
    Output_preamble_s   => w_sampler_preamble_s,
    Output_preamble_sn  => w_sampler_preamble_sn,
    Output_crc_match    => w_sampler_crc_match,
    Output_timestamp    => w_sampler_timestamp
  );

  i_reporter : entity adsb_lib.adsb_reporter
  generic map (
    AXI_DATA_WIDTH      => AXI_DATA_WIDTH,
    PREAMBLE_S_WIDTH    => PREAMBLE_S_WIDTH,
    PREAMBLE_SN_WIDTH   => PREAMBLE_SN_WIDTH
  )
  port map (
    Clk                 => Data_clk,
    Rst                 => w_extended_rst,

    Message_valid       => w_sampler_valid,
    Message_data        => w_sampler_message_data,
    Message_preamble_s  => w_sampler_preamble_s,
    Message_preamble_sn => w_sampler_preamble_sn,
    Message_crc_match   => w_sampler_crc_match,
    Message_timestamp   => w_sampler_timestamp,

    Axis_ready          => w_reporter_axis_ready,
    Axis_valid          => w_reporter_axis_valid,
    Axis_data           => w_reporter_axis_data,
    Axis_last           => w_reporter_axis_last
  );

  i_master_axis_fifo : entity axi_lib.axis_async_fifo
  generic map (
    FIFO_DEPTH      => AXI_FIFO_DEPTH,
    AXI_DATA_WIDTH  => AXI_DATA_WIDTH
  )
  port map (
    S_axis_clk      => Data_clk,
    S_axis_resetn   => not(w_extended_rst),
    S_axis_ready    => w_reporter_axis_ready,
    S_axis_valid    => w_reporter_axis_valid,
    S_axis_data     => w_reporter_axis_data,
    S_axis_last     => w_reporter_axis_last,

    M_axis_clk      => M_axis_clk,
    M_axis_ready    => M_axis_ready,
    M_axis_valid    => M_axis_valid,
    M_axis_data     => M_axis_data,
    M_axis_last     => M_axis_last
  );

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
    M_axis_ready    => w_config_axis_ready,
    M_axis_valid    => w_config_axis_valid,
    M_axis_data     => w_config_axis_data,
    M_axis_last     => w_config_axis_last
  );

  i_config : entity adsb_lib.adsb_config
  generic map (
    AXI_DATA_WIDTH => AXI_DATA_WIDTH
  )
  port map (
    Clk            => Data_clk,
    Rst            => Data_rst,

    Axis_ready     => w_config_axis_ready,
    Axis_valid     => w_config_axis_valid,
    Axis_last      => w_config_axis_last,
    Axis_data      => w_config_axis_data,

    Rst_out        => w_rst_from_config,
    Enable         => w_enable
  );

end architecture rtl;
