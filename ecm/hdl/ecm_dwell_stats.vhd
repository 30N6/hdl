library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;

entity ecm_dwell_stats is
generic (
  AXI_DATA_WIDTH : natural
);
port (
  Clk_axi                   : in  std_logic;
  Clk                       : in  std_logic;
  Rst                       : in  std_logic;

  Enable                    : in  std_logic;

  Dwell_active              : in  std_logic;
  Dwell_active_measurement  : in  std_logic;
  Dwell_active_transmit     : in  std_logic;
  Dwell_data                : in  ecm_dwell_entry_t;
  Dwell_sequence_num        : in  unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  Dwell_global_counter      : in  unsigned(ECM_DWELL_GLOBAL_COUNTER_WIDTH - 1 downto 0);
  Dwell_program_tag         : in  unsigned(ECM_DWELL_TAG_WIDTH - 1 downto 0);
  Dwell_report_done         : out std_logic;

  Input_ctrl                : in  channelizer_control_t;
  Input_pwr                 : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Axis_ready                : in  std_logic;
  Axis_valid                : out std_logic;
  Axis_data                 : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last                 : out std_logic;

  Error_reporter_timeout    : out std_logic;
  Error_reporter_overflow   : out std_logic
);
end entity ecm_dwell_stats;

architecture rtl of ecm_dwell_stats is

  constant READ_LATENCY         : natural := 2;
  constant READ_PIPE_DEPTH      : natural := READ_LATENCY + 2;

  type state_t is
  (
    S_IDLE,
    S_ACTIVE,
    S_WAIT_DONE,
    S_DONE,
    S_REPORT_WAIT,
    S_REPORT_ACK
  );

  signal r_rst                      : std_logic;
  signal r_enable                   : std_logic;

  signal r_dwell_active             : std_logic;
  signal r_dwell_active_meas        : std_logic;
  signal r_dwell_active_tx          : std_logic;
  signal r_dwell_data               : ecm_dwell_entry_t;
  signal r_dwell_sequence_num       : unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  signal r_dwell_global_counter     : unsigned(ECM_DWELL_GLOBAL_COUNTER_WIDTH - 1 downto 0);
  signal r_dwell_program_tag        : unsigned(ECM_DWELL_TAG_WIDTH - 1 downto 0);

  signal r_input_ctrl               : channelizer_control_t;
  signal r_input_pwr                : unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  signal s_state                    : state_t;

  signal m_channel_accum            : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_DWELL_POWER_ACCUM_WIDTH - 1 downto 0);
  signal m_channel_max              : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(CHAN_POWER_WIDTH - 1 downto 0);
  signal m_channel_cycles           : unsigned_array_t(ECM_NUM_CHANNELS - 1 downto 0)(ECM_DWELL_DURATION_WIDTH - 1 downto 0);

  signal w_channel_wr_en            : std_logic;
  signal w_channel_wr_index         : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_channel_wr_accum         : unsigned(ECM_DWELL_POWER_ACCUM_WIDTH - 1 downto 0);
  signal w_channel_wr_max           : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal w_channel_wr_cycles        : unsigned(ECM_DWELL_DURATION_WIDTH - 1 downto 0);
  signal w_channel_rd_index         : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);

  signal r_read_pipe_ctrl           : channelizer_control_array_t(READ_PIPE_DEPTH - 1 downto 0);
  signal r_read_pipe_active         : std_logic_vector(READ_PIPE_DEPTH - 1 downto 0);
  signal r_read_pipe_req            : std_logic_vector(READ_LATENCY - 1 downto 0);
  signal r_read_pipe_pwr            : unsigned_array_t(READ_LATENCY     downto 0)(CHAN_POWER_WIDTH - 1 downto 0);
  signal r_channel_rd_accum         : unsigned_array_t(READ_LATENCY - 1 downto 0)(ECM_DWELL_POWER_ACCUM_WIDTH - 1 downto 0);
  signal r_channel_rd_max           : unsigned_array_t(READ_LATENCY     downto 0)(CHAN_POWER_WIDTH - 1 downto 0);
  signal r_channel_rd_cycles        : unsigned_array_t(READ_LATENCY     downto 0)(ECM_DWELL_DURATION_WIDTH - 1 downto 0);

  signal r_channel_new_accum_d0_a   : unsigned(31 downto 0);
  signal r_channel_new_accum_d0_b   : unsigned(31 downto 0);
  signal r_channel_new_accum_d0_c   : unsigned(0 downto 0);
  signal r_channel_new_accum_d1     : unsigned(ECM_DWELL_POWER_ACCUM_WIDTH - 1 downto 0);
  signal r_channel_new_max_valid_d0 : std_logic;
  signal r_channel_new_max_d1       : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r_channel_new_cycles_d1    : unsigned(ECM_DWELL_DURATION_WIDTH - 1 downto 0);

  signal r_clear_index              : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0) := (others => '0');

  signal r_tx_active                : std_logic;
  signal r_duration_measurement     : unsigned(ECM_DWELL_DURATION_WIDTH - 1 downto 0);
  signal r_duration_total           : unsigned(ECM_DWELL_DURATION_WIDTH - 1 downto 0);
  signal r_timestamp                : unsigned(ECM_TIMESTAMP_WIDTH - 1 downto 0);
  signal r_ts_dwell_start           : unsigned(ECM_TIMESTAMP_WIDTH - 1 downto 0);

  signal w_dwell_done               : std_logic;
  signal w_report_read_req          : std_logic;
  signal w_report_read_index        : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_report_ack               : std_logic;
  signal w_clear_channels           : std_logic;

begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst     <= Rst;
      r_enable  <= Enable;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_ctrl        <= Input_ctrl;
      r_input_pwr         <= Input_pwr;
      r_dwell_active      <= Dwell_active;
      r_dwell_active_meas <= Dwell_active_measurement;
      r_dwell_active_tx   <= Dwell_active_transmit;

      if (s_state = S_IDLE) then
        r_dwell_data            <= Dwell_data;
        r_dwell_sequence_num    <= Dwell_sequence_num;
        r_dwell_global_counter  <= Dwell_global_counter;
        r_dwell_program_tag     <= Dwell_program_tag;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        s_state <= S_IDLE;
      else
        case s_state is
        when S_IDLE =>
          if ((r_enable = '1') and (r_dwell_active = '1') and (r_dwell_active_meas = '1')) then
            s_state <= S_ACTIVE;
          else
            s_state <= S_IDLE;
          end if;

        when S_ACTIVE =>
          if (r_dwell_active = '0') then
            s_state <= S_DONE;
          elsif (r_dwell_active_meas = '0') then
            s_state <= S_WAIT_DONE;
          else
            s_state <= S_ACTIVE;
          end if;

        when S_WAIT_DONE =>
          if (r_dwell_active = '0') then
            s_state <= S_DONE;
          else
            s_state <= S_WAIT_DONE;
          end if;

        when S_DONE =>
          s_state <= S_REPORT_WAIT;

        when S_REPORT_WAIT =>
          if (w_report_ack = '1') then
            s_state <= S_REPORT_ACK;
          else
            s_state <= S_REPORT_WAIT;
          end if;

        when S_REPORT_ACK =>
          s_state <= S_IDLE;
        end case;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Dwell_report_done <= to_stdlogic(s_state <= S_REPORT_ACK);
    end if;
  end process;

  process(all)
  begin
    if (s_state = S_ACTIVE) then
      w_channel_rd_index <= r_input_ctrl.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
    else
      w_channel_rd_index <= w_report_read_index;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_channel_wr_en = '1') then
        m_channel_accum(to_integer(w_channel_wr_index)) <= w_channel_wr_accum;
        m_channel_max(to_integer(w_channel_wr_index))   <= w_channel_wr_max;
        m_channel_cycles(to_integer(w_channel_wr_index)) <= w_channel_wr_cycles;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_channel_rd_accum(0)   <= m_channel_accum(to_integer(w_channel_rd_index));
      r_channel_rd_max(0)     <= m_channel_max(to_integer(w_channel_rd_index));
      r_channel_rd_cycles(0)  <= m_channel_cycles(to_integer(w_channel_rd_index));

      r_channel_rd_accum(1)   <= r_channel_rd_accum(0);
      r_channel_rd_max(1)     <= r_channel_rd_max(0);
      r_channel_rd_cycles(1)  <= r_channel_rd_cycles(0);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_read_pipe_ctrl    <= r_read_pipe_ctrl(READ_PIPE_DEPTH - 2 downto 0)   & r_input_ctrl;
      r_read_pipe_active  <= r_read_pipe_active(READ_PIPE_DEPTH - 2 downto 0) & to_stdlogic(s_state = S_ACTIVE);
      r_read_pipe_req     <= r_read_pipe_req(READ_LATENCY - 2 downto 0)       & (w_report_read_req and to_stdlogic(s_state /= S_ACTIVE));
      r_read_pipe_pwr     <= r_read_pipe_pwr(READ_LATENCY - 1 downto 0)       & r_input_pwr;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      (r_channel_new_accum_d0_c, r_channel_new_accum_d0_a)  <= ('0' & r_channel_rd_accum(1)(31 downto 0)) + ('0' & r_read_pipe_pwr(1)(31 downto 0));
      r_channel_new_accum_d0_b                              <= r_channel_rd_accum(1)(63 downto 32);
      r_channel_new_max_valid_d0                            <= to_stdlogic(r_read_pipe_pwr(1) > r_channel_rd_max(1));
      r_channel_rd_max(2)                                   <= r_channel_rd_max(1);
      r_channel_rd_cycles(2)                                <= r_channel_rd_cycles(1);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_channel_new_accum_d1(63 downto 32)  <= r_channel_new_accum_d0_b + r_channel_new_accum_d0_c;
      r_channel_new_accum_d1(31 downto 0)   <= r_channel_new_accum_d0_a;
      r_channel_new_max_d1                  <= r_read_pipe_pwr(2) when (r_channel_new_max_valid_d0 = '1') else r_channel_rd_max(2);
      r_channel_new_cycles_d1               <= r_channel_rd_cycles(2) + 1;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_clear_channels = '0') then
        r_clear_index <= (others => '0');
      else
        r_clear_index <= r_clear_index + 1;
      end if;
    end if;
  end process;

  process(all)
  begin
    if (w_clear_channels = '1') then
      w_channel_wr_en     <= '1';
      w_channel_wr_index  <= r_clear_index;
      w_channel_wr_accum  <= (others => '0');
      w_channel_wr_max    <= (others => '0');
      w_channel_wr_cycles <= (others => '0');
    else
      w_channel_wr_en     <= r_read_pipe_ctrl(READ_PIPE_DEPTH - 1).valid and r_read_pipe_active(READ_PIPE_DEPTH - 1);
      w_channel_wr_index  <= r_read_pipe_ctrl(READ_PIPE_DEPTH - 1).data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
      w_channel_wr_accum  <= r_channel_new_accum_d1;
      w_channel_wr_max    <= r_channel_new_max_d1;
      w_channel_wr_cycles <= r_channel_new_cycles_d1;
    end if;
  end process;

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
      if (s_state = S_IDLE) then
        r_ts_dwell_start <= r_timestamp;
      end if;

      if (s_state = S_IDLE) then
        r_duration_measurement <= (others => '0');
      elsif (s_state = S_ACTIVE) then
        r_duration_measurement <= r_duration_measurement + 1;
      end if;

      if (s_state = S_IDLE) then
        r_duration_total <= (others => '0');
      elsif ((s_state = S_ACTIVE) or (s_state = S_WAIT_DONE)) then
        r_duration_total <= r_duration_total + 1;
      end if;

      if (s_state = S_IDLE) then
        r_tx_active <= '0';
      elsif (r_dwell_active_tx = '1') then
        r_tx_active <= '1';
      end if;
    end if;
  end process;

  w_dwell_done <= to_stdlogic(s_state = S_DONE);

  i_reporter : entity ecm_lib.ecm_dwell_stats_reporter
  generic map (
    AXI_DATA_WIDTH => AXI_DATA_WIDTH
  )
  port map (
    Clk_axi                     => Clk_axi,
    Clk                         => Clk,
    Rst                         => r_rst,

    Dwell_done                  => w_dwell_done,
    Dwell_data                  => r_dwell_data,
    Dwell_sequence_num          => r_dwell_sequence_num,
    Dwell_global_counter        => r_dwell_global_counter,
    Dwell_program_tag           => r_dwell_program_tag,
    Dwell_measurement_duration  => r_duration_measurement,
    Dwell_total_duration        => r_duration_total,
    Dwell_tx_active             => r_tx_active,
    Timestamp_start             => r_ts_dwell_start,

    Read_req                    => w_report_read_req,
    Read_index                  => w_report_read_index,
    Read_accum                  => r_channel_rd_accum(READ_LATENCY - 1),
    Read_max                    => r_channel_rd_max(READ_LATENCY - 1),
    Read_cycles                 => r_channel_rd_cycles(READ_LATENCY - 1),
    Read_valid                  => r_read_pipe_req(READ_LATENCY - 1),

    Clear_channels              => w_clear_channels,
    Report_ack                  => w_report_ack,

    Axis_ready                  => Axis_ready,
    Axis_valid                  => Axis_valid,
    Axis_data                   => Axis_data,
    Axis_last                   => Axis_last,

    Error_timeout               => Error_reporter_timeout,
    Error_overflow              => Error_reporter_overflow
  );

end architecture rtl;
