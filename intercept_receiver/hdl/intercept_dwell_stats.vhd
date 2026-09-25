library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library intercept_lib;
  use intercept_lib.intercept_pkg.all;

entity intercept_dwell_stats is
generic (
  AXI_DATA_WIDTH : natural
);
port (
  Clk_axi                 : in  std_logic;
  Clk                     : in  std_logic;
  Rst                     : in  std_logic;

  Enable                  : in  std_logic;

  Dwell_data              : in  intercept_dwell_data_t;
  Dwell_active            : in  std_logic;

  Input_ctrl              : in  channelizer_control_t;
  Input_pwr               : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Axis_ready              : in  std_logic;
  Axis_valid              : out std_logic;
  Axis_data               : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last               : out std_logic;

  Error_reporter_busy     : out std_logic;
  Error_reporter_timeout  : out std_logic;
  Error_reporter_overflow : out std_logic
);
end entity intercept_dwell_stats;

architecture rtl of intercept_dwell_stats is

  constant POWER_ACCUM_WIDTH          : natural := 2*CHAN_POWER_WIDTH; --CHAN_POWER_WIDTH + INTERCEPT_DWELL_DURATION_WIDTH;

  signal r_rst                        : std_logic;
  signal r_enable                     : std_logic;

  signal r_input_ctrl                 : channelizer_control_t;
  signal r_input_pwr                  : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal r_dwell_active               : std_logic;

  signal r_dwell_data                 : intercept_dwell_data_t;
  signal r_window_duration_minus_two  : unsigned(INTERCEPT_DWELL_DURATION_WIDTH - 1 downto 0);
  signal r_window_seq_num_current     : unsigned(INTERCEPT_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  signal r_window_seq_num_report      : unsigned(INTERCEPT_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);

  signal m_channel_calc_accum         : unsigned_array_t(INTERCEPT_NUM_CHANNELS - 1 downto 0)(POWER_ACCUM_WIDTH - 1 downto 0);
  signal m_channel_calc_max           : unsigned_array_t(INTERCEPT_NUM_CHANNELS - 1 downto 0)(CHAN_POWER_WIDTH - 1 downto 0);
  signal m_channel_report_accum       : unsigned_array_t(INTERCEPT_NUM_CHANNELS - 1 downto 0)(POWER_ACCUM_WIDTH - 1 downto 0);
  signal m_channel_report_max         : unsigned_array_t(INTERCEPT_NUM_CHANNELS - 1 downto 0)(CHAN_POWER_WIDTH - 1 downto 0);

  signal w_channel_calc_wr_en         : std_logic;
  signal w_channel_report_wr_en       : std_logic;
  signal w_channel_wr_index           : unsigned(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_channel_wr_accum           : unsigned(POWER_ACCUM_WIDTH - 1 downto 0);
  signal w_channel_wr_max             : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal r_dwell_frame_index          : unsigned(INTERCEPT_DWELL_DURATION_WIDTH - 1 downto 0);
  signal r_dwell_first_frame          : std_logic;
  signal r_dwell_last_frame           : std_logic;

  signal r0_dwell_frame_index         : unsigned(INTERCEPT_DWELL_DURATION_WIDTH - 1 downto 0);
  signal r0_dwell_first_frame         : std_logic;
  signal r0_dwell_last_frame          : std_logic;
  signal r0_input_ctrl                : channelizer_control_t;
  signal r0_input_pwr                 : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r0_channel_calc_rd_accum     : unsigned(POWER_ACCUM_WIDTH - 1 downto 0);
  signal r0_channel_calc_rd_max       : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r0_channel_report_rd_accum   : unsigned(POWER_ACCUM_WIDTH - 1 downto 0);
  signal r0_channel_report_rd_max     : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r0_report_read_req           : std_logic;

  signal r1_dwell_first_frame         : std_logic;
  signal r1_dwell_last_frame          : std_logic;
  signal r1_input_ctrl                : channelizer_control_t;
  signal r1_input_pwr                 : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r1_channel_calc_rd_accum     : unsigned(POWER_ACCUM_WIDTH - 1 downto 0);
  signal r1_channel_calc_rd_max       : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r1_channel_report_rd_accum   : unsigned(POWER_ACCUM_WIDTH - 1 downto 0);
  signal r1_channel_report_rd_max     : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r1_report_read_req           : std_logic;

  signal r2_dwell_first_frame         : std_logic;
  signal r2_dwell_last_frame          : std_logic;
  signal r2_input_ctrl                : channelizer_control_t;
  signal r2_input_pwr                 : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r2_channel_new_accum_a       : unsigned(31 downto 0);
  signal r2_channel_new_accum_b       : unsigned(31 downto 0);
  signal r2_channel_new_accum_c       : unsigned(0 downto 0);
  signal r2_channel_new_max_valid     : std_logic;
  signal r2_channel_calc_rd_max       : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal r3_dwell_last_frame          : std_logic;
  signal r3_input_ctrl                : channelizer_control_t;
  signal r3_channel_new_accum         : unsigned(POWER_ACCUM_WIDTH - 1 downto 0);
  signal r3_channel_new_max           : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal r_timestamp                  : unsigned(INTERCEPT_TIMESTAMP_WIDTH - 1 downto 0);
  signal r_window_timestamp           : unsigned(INTERCEPT_TIMESTAMP_WIDTH - 1 downto 0);
  signal r_window_duration            : unsigned(INTERCEPT_DWELL_DURATION_WIDTH - 1 downto 0);

  signal w_window_done                : std_logic;

  signal w_report_read_req            : std_logic;
  signal w_report_read_index          : unsigned(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0);

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst           <= Rst;
      r_enable        <= Enable;
      r_dwell_active  <= Dwell_active;
      r_dwell_data    <= Dwell_data;
      r_input_ctrl    <= Input_ctrl;
      r_input_pwr     <= Input_pwr;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_window_duration_minus_two <= r_dwell_data.window_duration - 2;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_dwell_frame_index  <= (others => '0');
        r_dwell_first_frame  <= '0';
        r_dwell_last_frame   <= '0';
      else
        if (r_dwell_active = '0') then
          r_dwell_frame_index  <= (others => '0');
          r_dwell_first_frame  <= '1';
          r_dwell_last_frame   <= '0';
        elsif ((r_input_ctrl.valid = '1') and (r_input_ctrl.last = '1')) then
          if (r_dwell_last_frame = '1') then
            r_dwell_frame_index  <= (others => '0');
            r_dwell_first_frame  <= '1';
            r_dwell_last_frame   <= '0';
          else
            r_dwell_frame_index  <= r_dwell_frame_index + 1;
            r_dwell_first_frame  <= '0';
            r_dwell_last_frame   <= to_stdlogic(r_dwell_frame_index = r_window_duration_minus_two);
          end if;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_channel_calc_wr_en = '1') then
        m_channel_calc_accum(to_integer(w_channel_wr_index))    <= w_channel_wr_accum;
        m_channel_calc_max(to_integer(w_channel_wr_index))      <= w_channel_wr_max;
      end if;

      if (w_channel_report_wr_en = '1') then
        m_channel_report_accum(to_integer(w_channel_wr_index))  <= w_channel_wr_accum;
        m_channel_report_max(to_integer(w_channel_wr_index))    <= w_channel_wr_max;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_dwell_first_frame      <= r_dwell_first_frame;
      r0_dwell_last_frame       <= r_dwell_last_frame;
      r0_input_ctrl             <= r_input_ctrl;
      r0_input_pwr              <= r_input_pwr;
      r0_channel_calc_rd_accum  <= m_channel_calc_accum(to_integer(r_input_ctrl.data_index(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0)));
      r0_channel_calc_rd_max    <= m_channel_calc_max(to_integer(r_input_ctrl.data_index(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0)));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_dwell_first_frame      <= r0_dwell_first_frame;
      r1_dwell_last_frame       <= r0_dwell_last_frame;
      r1_input_ctrl             <= r0_input_ctrl;
      r1_input_pwr              <= r0_input_pwr;
      r1_channel_calc_rd_accum  <= r0_channel_calc_rd_accum;
      r1_channel_calc_rd_max    <= r0_channel_calc_rd_max;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      (r2_channel_new_accum_c, r2_channel_new_accum_a)  <= ('0' & r1_channel_calc_rd_accum(31 downto 0)) + ('0' & r1_input_pwr);
      r2_channel_new_accum_b                            <= r1_channel_calc_rd_accum(63 downto 32);
      r2_channel_new_max_valid                          <= to_stdlogic(r1_input_pwr > r1_channel_calc_rd_max);
      r2_channel_calc_rd_max                            <= r1_channel_calc_rd_max;
      r2_dwell_first_frame                              <= r1_dwell_first_frame;
      r2_dwell_last_frame                               <= r1_dwell_last_frame;
      r2_input_ctrl                                     <= r1_input_ctrl;
      r2_input_pwr                                      <= r1_input_pwr;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_input_ctrl       <= r2_input_ctrl;
      r3_dwell_last_frame <= r2_dwell_last_frame;

      if (r2_dwell_first_frame = '1') then
        r3_channel_new_accum(63 downto 32)  <= (others => '0');
        r3_channel_new_accum(31 downto 0)   <= r2_input_pwr;
      else
        r3_channel_new_accum(63 downto 32)  <= r2_channel_new_accum_b + r2_channel_new_accum_c;
        r3_channel_new_accum(31 downto 0)   <= r2_channel_new_accum_a;
      end if;

      if ((r2_dwell_first_frame = '1') or (r2_channel_new_max_valid = '1')) then
        r3_channel_new_max <= r2_input_pwr;
      else
        r3_channel_new_max <= r2_channel_calc_rd_max;
      end if;
    end if;
  end process;

  w_channel_calc_wr_en    <= r3_input_ctrl.valid;
  w_channel_report_wr_en  <= r3_input_ctrl.valid and r3_dwell_last_frame;
  w_channel_wr_index      <= r3_input_ctrl.data_index(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0);
  w_channel_wr_accum      <= r3_channel_new_accum;
  w_channel_wr_max        <= r3_channel_new_max;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_timestamp <= (others => '0');
      else
        r_timestamp <= r_timestamp + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if ((r_input_ctrl.valid = '1') and (r_input_ctrl.last = '1') and (r_dwell_last_frame = '1')) then
        r_window_timestamp  <= r_timestamp;
        r_window_duration   <= r_dwell_frame_index + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_window_seq_num_current  <= (others => '0');
        r_window_seq_num_report   <= (others => '-');
      else
        if ((r_input_ctrl.valid = '1') and (r_input_ctrl.last = '1') and (r_dwell_last_frame = '1')) then
          r_window_seq_num_current  <= r_window_seq_num_current + 1;
          r_window_seq_num_report   <= r_window_seq_num_current;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_channel_report_rd_accum  <= m_channel_report_accum(to_integer(w_report_read_index));
      r0_channel_report_rd_max    <= m_channel_report_max(to_integer(w_report_read_index));
      r0_report_read_req          <= w_report_read_req;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_channel_report_rd_accum  <= r0_channel_report_rd_accum;
      r1_channel_report_rd_max    <= r0_channel_report_rd_max;
      r1_report_read_req          <= r0_report_read_req;
    end if;
  end process;

  w_window_done <= r3_input_ctrl.valid and r3_input_ctrl.last and r3_dwell_last_frame;

  i_reporter : entity intercept_lib.intercept_dwell_reporter
  generic map (
    AXI_DATA_WIDTH => AXI_DATA_WIDTH
  )
  port map (
    Clk_axi             => Clk_axi,
    Clk                 => Clk,
    Rst                 => r_rst,

    Dwell_data          => r_dwell_data,
    Window_done         => w_window_done,
    Window_sequence_num => r_window_seq_num_report,
    Window_duration     => r_window_duration,
    Window_timestamp    => r_window_timestamp,

    Read_req            => w_report_read_req,
    Read_index          => w_report_read_index,
    Read_accum          => r1_channel_report_rd_accum,
    Read_max            => r1_channel_report_rd_max,
    Read_valid          => r1_report_read_req,

    Axis_ready          => Axis_ready,
    Axis_valid          => Axis_valid,
    Axis_data           => Axis_data,
    Axis_last           => Axis_last,

    Error_busy          => Error_reporter_busy,
    Error_timeout       => Error_reporter_timeout,
    Error_overflow      => Error_reporter_overflow
  );

end architecture rtl;
