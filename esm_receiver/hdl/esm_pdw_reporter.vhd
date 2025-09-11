library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library esm_lib;
  use esm_lib.esm_pkg.all;

entity esm_pdw_reporter is
generic (
  AXI_DATA_WIDTH      : natural;
  CHANNEL_INDEX_WIDTH : natural;
  DATA_WIDTH          : natural;
  MODULE_ID           : unsigned
);
port (
  Clk_axi               : in  std_logic;
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Dwell_active          : in  std_logic;
  Dwell_done            : in  std_logic;
  Dwell_data            : in  esm_dwell_entry_t;
  Dwell_sequence_num    : in  unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  Dwell_timestamp       : in  unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);
  Dwell_duration        : in  unsigned(ESM_DWELL_DURATION_WIDTH - 1 downto 0);

  Ack_delay_report      : in  unsigned(31 downto 0);
  Ack_delay_sample_proc : in  unsigned(31 downto 0);

  Pdw_ready             : out std_logic;
  Pdw_valid             : in  std_logic;
  Pdw_data              : in  esm_pdw_fifo_data_t;

  Buffered_frame_req    : out esm_pdw_sample_buffer_req_t;
  Buffered_frame_ack    : in  esm_pdw_sample_buffer_ack_t;
  Buffered_frame_data   : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Report_ack            : out std_logic;

  Axis_ready            : in  std_logic;
  Axis_valid            : out std_logic;
  Axis_data             : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last             : out std_logic;

  Error_timeout         : out std_logic;
  Error_overflow        : out std_logic
);
end entity esm_pdw_reporter;

architecture rtl of esm_pdw_reporter is

  constant FIFO_DEPTH             : natural := 4096;
  constant FIFO_ALMOST_FULL_LEVEL : natural := FIFO_DEPTH - ESM_MAX_WORDS_PER_PACKET - 10;
  constant TIMEOUT_CYCLES         : natural := 1024;

  type state_t is
  (
    S_IDLE,

    S_CHECK_START,
    S_CHECK_PDW_DROP,

    S_SUMMARY_HEADER_0,
    S_SUMMARY_HEADER_1,
    S_SUMMARY_HEADER_2,
    S_SUMMARY_DWELL_SEQ_NUM,
    S_SUMMARY_DWELL_START_TIME_0,
    S_SUMMARY_DWELL_START_TIME_1,
    S_SUMMARY_DWELL_DURATION,
    S_SUMMARY_DWELL_PULSE_COUNT,
    S_SUMMARY_DWELL_DROP_COUNT,
    S_SUMMARY_ACK_DELAY_RPT,
    S_SUMMARY_ACK_DELAY_SAMPLE_PROC,
    S_SUMMARY_PAD,
    S_SUMMARY_DONE,

    S_PULSE_HEADER_0,
    S_PULSE_HEADER_1,
    S_PULSE_HEADER_2,
    S_PULSE_DWELL_SEQ_NUM,
    S_PULSE_SEQ_NUM,
    S_PULSE_CHANNEL,
    S_PULSE_THRESHOLD,
    S_PULSE_POWER_ACCUM_0,
    S_PULSE_POWER_ACCUM_1,
    S_PULSE_DURATION,
    S_PULSE_FREQUENCY,
    S_PULSE_START_TIME_0,
    S_PULSE_START_TIME_1,
    S_PULSE_BUFFER_STATUS,
    S_PULSE_PAD,
    S_PULSE_DONE,

    S_BUFFER_READ,
    S_BUFFER_DROP,
    S_BUFFERED_SAMPLE,
    S_PDW_DROP,
    S_PDW_READ,

    S_REPORT_ACK
  );

  signal s_state                : state_t;

  signal r_packet_seq_num       : unsigned(31 downto 0);
  signal r_words_in_msg         : unsigned(clog2(ESM_MAX_WORDS_PER_PACKET) - 1 downto 0);

  signal r_min_duration_valid   : std_logic;

  signal w_fifo_almost_full     : std_logic;
  signal w_fifo_ready           : std_logic;

  signal w_fifo_valid           : std_logic;
  signal w_fifo_valid_opt       : std_logic;
  signal w_fifo_last            : std_logic;
  signal w_fifo_partial_0_data  : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_fifo_partial_1_data  : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

  signal r_fifo_valid           : std_logic;
  signal r_fifo_last            : std_logic;
  signal r_fifo_partial_0_data  : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal r_fifo_partial_1_data  : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

  signal r_pulse_count          : unsigned(31 downto 0);
  signal r_drop_count           : unsigned(31 downto 0);

  signal r_timeout              : unsigned(clog2(TIMEOUT_CYCLES) - 1 downto 0);

begin

  assert (AXI_DATA_WIDTH = 32)
    report "AXI_DATA_WIDTH expected to be 32."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        s_state <= S_IDLE;
      else
        case s_state is
        when S_IDLE =>
          if (Dwell_active = '1') then
            s_state <= S_CHECK_START;
          else
            s_state <= S_IDLE;
          end if;

        when S_CHECK_START =>
          if (w_fifo_almost_full = '1') then
            s_state <= S_CHECK_START;
          elsif (Pdw_valid = '1') then
            s_state <= S_CHECK_PDW_DROP;
          elsif (Dwell_done = '1') then
            s_state <= S_SUMMARY_HEADER_0;
          else
            s_state <= S_CHECK_START;
          end if;

        when S_CHECK_PDW_DROP =>
          if (r_min_duration_valid = '1') then
            s_state <= S_PULSE_HEADER_0;
          elsif (Pdw_data.buffered_frame_valid = '1') then
            s_state <= S_BUFFER_DROP;
          else
            s_state <= S_PDW_DROP;
          end if;

        when S_BUFFER_DROP =>
          s_state <= S_PDW_DROP;

        when S_PULSE_HEADER_0 =>
          s_state <= S_PULSE_HEADER_1;
        when S_PULSE_HEADER_1 =>
          s_state <= S_PULSE_HEADER_2;
        when S_PULSE_HEADER_2 =>
          s_state <= S_PULSE_DWELL_SEQ_NUM;
        when S_PULSE_DWELL_SEQ_NUM =>
          s_state <= S_PULSE_SEQ_NUM;
        when S_PULSE_SEQ_NUM =>
          s_state <= S_PULSE_CHANNEL;
        when S_PULSE_CHANNEL =>
          s_state <= S_PULSE_THRESHOLD;
        when S_PULSE_THRESHOLD =>
          s_state <= S_PULSE_POWER_ACCUM_0;
        when S_PULSE_POWER_ACCUM_0 =>
          s_state <= S_PULSE_POWER_ACCUM_1;
        when S_PULSE_POWER_ACCUM_1 =>
          s_state <= S_PULSE_DURATION;
        when S_PULSE_DURATION =>
          s_state <= S_PULSE_FREQUENCY;
        when S_PULSE_FREQUENCY =>
          s_state <= S_PULSE_START_TIME_0;
        when S_PULSE_START_TIME_0 =>
          s_state <= S_PULSE_START_TIME_1;
        when S_PULSE_START_TIME_1 =>
          s_state <= S_PULSE_BUFFER_STATUS;
        when S_PULSE_BUFFER_STATUS =>
          if (Pdw_data.buffered_frame_valid = '1') then
            s_state <= S_BUFFER_READ;
          else
            s_state <= S_PULSE_PAD;
          end if;

        when S_BUFFER_READ =>
          s_state <= S_BUFFERED_SAMPLE;

        when S_BUFFERED_SAMPLE =>
          if ((Buffered_frame_ack.sample_valid = '1') and (Buffered_frame_ack.sample_last = '1')) then
            if (r_words_in_msg < (ESM_MAX_WORDS_PER_PACKET - 1)) then
              s_state <= S_PULSE_PAD;
            else
              s_state <= S_PDW_READ;
            end if;
          else
            s_state <= S_BUFFERED_SAMPLE;
          end if;

        when S_PULSE_PAD =>
          if (r_words_in_msg = (ESM_MAX_WORDS_PER_PACKET - 1)) then
            s_state <= S_PDW_READ;
          else
            s_state <= S_PULSE_PAD;
          end if;

        when S_PDW_READ =>
          s_state <= S_PULSE_DONE;
        when S_PDW_DROP =>
          s_state <= S_PULSE_DONE;

        when S_PULSE_DONE =>
          s_state <= S_CHECK_START;

        when S_SUMMARY_HEADER_0 =>
          s_state <= S_SUMMARY_HEADER_1;
        when S_SUMMARY_HEADER_1 =>
          s_state <= S_SUMMARY_HEADER_2;
        when S_SUMMARY_HEADER_2 =>
          s_state <= S_SUMMARY_DWELL_SEQ_NUM;
        when S_SUMMARY_DWELL_SEQ_NUM =>
          s_state <= S_SUMMARY_DWELL_START_TIME_0;
        when S_SUMMARY_DWELL_START_TIME_0 =>
          s_state <= S_SUMMARY_DWELL_START_TIME_1;
        when S_SUMMARY_DWELL_START_TIME_1 =>
          s_state <= S_SUMMARY_DWELL_DURATION;
        when S_SUMMARY_DWELL_DURATION =>
          s_state <= S_SUMMARY_DWELL_PULSE_COUNT;
        when S_SUMMARY_DWELL_PULSE_COUNT =>
          s_state <= S_SUMMARY_DWELL_DROP_COUNT;
        when S_SUMMARY_DWELL_DROP_COUNT =>
          s_state <= S_SUMMARY_ACK_DELAY_RPT;
        when S_SUMMARY_ACK_DELAY_RPT =>
          s_state <= S_SUMMARY_ACK_DELAY_SAMPLE_PROC;
        when S_SUMMARY_ACK_DELAY_SAMPLE_PROC =>
          s_state <= S_SUMMARY_PAD;
        when S_SUMMARY_PAD =>
          if (r_words_in_msg = (ESM_MAX_WORDS_PER_PACKET - 1)) then
            s_state <= S_SUMMARY_DONE;
          else
            s_state <= S_SUMMARY_PAD;
          end if;

        when S_SUMMARY_DONE =>
          s_state <= S_REPORT_ACK;

        when S_REPORT_ACK =>
          s_state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

  Buffered_frame_req.frame_index  <= Pdw_data.buffered_frame_index;
  Buffered_frame_req.frame_read   <= to_stdlogic(s_state = S_BUFFER_READ);
  Buffered_frame_req.frame_drop   <= to_stdlogic(s_state = S_BUFFER_DROP);
  Pdw_ready                       <= to_stdlogic((s_state = S_PDW_READ) or (s_state = S_PDW_DROP));
  Report_ack                      <= to_stdlogic(s_state = S_REPORT_ACK);

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_min_duration_valid <= to_stdlogic(Pdw_data.duration >= Dwell_data.min_pulse_duration);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_packet_seq_num <= (others => '0');
      else
        if ((s_state = S_PDW_READ) or (s_state = S_SUMMARY_DONE)) then
          r_packet_seq_num <= r_packet_seq_num + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_pulse_count <= (others => '0');
      elsif (s_state = S_PULSE_DONE) then
        r_pulse_count <= r_pulse_count + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_drop_count <= (others => '0');
      elsif (s_state = S_PDW_DROP) then
        r_drop_count <= r_drop_count + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_CHECK_START) then
        r_words_in_msg <= (others => '0');
      elsif (w_fifo_valid_opt = '1') then
        r_words_in_msg <= r_words_in_msg + 1;
      end if;
    end if;
  end process;

  process(all)
  begin
    w_fifo_valid  <= '0';
    w_fifo_last   <= '0';
    w_fifo_partial_0_data   <= (others => '0');
    w_fifo_partial_1_data   <= (others => '0');

    case s_state is
    when S_PULSE_HEADER_0 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= ESM_REPORT_MAGIC_NUM;

    when S_PULSE_HEADER_1 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(r_packet_seq_num);

    when S_PULSE_HEADER_2 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(MODULE_ID) & std_logic_vector(ESM_REPORT_MESSAGE_TYPE_PDW_PULSE) & x"0000";

    when S_PULSE_DWELL_SEQ_NUM =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(Dwell_sequence_num);

    when S_PULSE_SEQ_NUM =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(Pdw_data.sequence_num);

    when S_PULSE_CHANNEL =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(resize_up(Pdw_data.channel, 32));

    --TODO: report noise floor

    when S_PULSE_THRESHOLD =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(Pdw_data.power_threshold);

    when S_PULSE_POWER_ACCUM_0 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= x"0000" & std_logic_vector(Pdw_data.power_accum(47 downto 32));

    when S_PULSE_POWER_ACCUM_1 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(Pdw_data.power_accum(31 downto 0));

    when S_PULSE_DURATION =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(Pdw_data.duration);

    when S_PULSE_FREQUENCY =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= x"0000" & std_logic_vector(Pdw_data.frequency);

    when S_PULSE_START_TIME_0 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= x"0000" & std_logic_vector(Pdw_data.pulse_start_time(47 downto 32));

    when S_PULSE_START_TIME_1 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(Pdw_data.pulse_start_time(31 downto 0));

    when S_PULSE_BUFFER_STATUS =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= "0000000" & Pdw_data.buffered_frame_valid & std_logic_vector(resize_up(Pdw_data.buffered_frame_index, 8)) & x"0000";

    when S_BUFFERED_SAMPLE =>
      w_fifo_valid            <= Buffered_frame_ack.sample_valid;
      w_fifo_partial_1_data   <= std_logic_vector(Buffered_frame_data(1)) & std_logic_vector(Buffered_frame_data(0));

    when S_SUMMARY_HEADER_0 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= ESM_REPORT_MAGIC_NUM;

    when S_SUMMARY_HEADER_1 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(r_packet_seq_num);

    when S_SUMMARY_HEADER_2 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(MODULE_ID) & std_logic_vector(ESM_REPORT_MESSAGE_TYPE_PDW_SUMMARY) & x"0000";

    when S_SUMMARY_DWELL_SEQ_NUM =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(Dwell_sequence_num);

    when S_SUMMARY_DWELL_START_TIME_0 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= x"0000" & std_logic_vector(Dwell_timestamp(47 downto 32));

    when S_SUMMARY_DWELL_START_TIME_1 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(Dwell_timestamp(31 downto 0));

    when S_SUMMARY_DWELL_DURATION =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(Dwell_duration);

    when S_SUMMARY_DWELL_PULSE_COUNT =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(r_pulse_count);

    when S_SUMMARY_DWELL_DROP_COUNT =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(r_drop_count);

    when S_SUMMARY_ACK_DELAY_RPT  =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(Ack_delay_report);

    when S_SUMMARY_ACK_DELAY_SAMPLE_PROC =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(Ack_delay_sample_proc);

    when S_PULSE_PAD | S_SUMMARY_PAD =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= (others => '0');
      w_fifo_last             <= to_stdlogic(r_words_in_msg = (ESM_MAX_WORDS_PER_PACKET - 1));

    when others => null;
    end case;
  end process;

  process(all)
  begin
    w_fifo_valid_opt <= '1';
    case s_state is
    when S_IDLE             =>  w_fifo_valid_opt <= '0';
    when S_CHECK_START      =>  w_fifo_valid_opt <= '0';
    when S_CHECK_PDW_DROP   =>  w_fifo_valid_opt <= '0';
    when S_SUMMARY_DONE     =>  w_fifo_valid_opt <= '0';
    when S_PULSE_DONE       =>  w_fifo_valid_opt <= '0';
    when S_BUFFER_READ      =>  w_fifo_valid_opt <= '0';
    when S_BUFFER_DROP      =>  w_fifo_valid_opt <= '0';
    when S_BUFFERED_SAMPLE  =>  w_fifo_valid_opt <= Buffered_frame_ack.sample_valid;
    when S_PDW_READ         =>  w_fifo_valid_opt <= '0';
    when S_PDW_DROP         =>  w_fifo_valid_opt <= '0';
    when S_REPORT_ACK       =>  w_fifo_valid_opt <= '0';
    when others => null;
    end case;
  end process;

  assert (w_fifo_valid_opt = w_fifo_valid)
    report "w_fifo_valid_opt mismatch."
    severity failure;

  assert ((s_state = S_IDLE) or (w_fifo_ready = '1'))
    report "Ready expected to be high."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_fifo_valid          <= w_fifo_valid_opt;
      r_fifo_partial_0_data <= w_fifo_partial_0_data;
      r_fifo_partial_1_data <= w_fifo_partial_1_data;
      r_fifo_last           <= w_fifo_last;
    end if;
 end process;

  i_fifo : entity axi_lib.axis_async_fifo
  generic map (
    FIFO_DEPTH        => FIFO_DEPTH,
    ALMOST_FULL_LEVEL => FIFO_ALMOST_FULL_LEVEL,
    AXI_DATA_WIDTH    => AXI_DATA_WIDTH
  )
  port map (
    S_axis_clk          => Clk,
    S_axis_resetn       => not(Rst),
    S_axis_ready        => w_fifo_ready,
    S_axis_valid        => r_fifo_valid,
    S_axis_data         => r_fifo_partial_0_data or r_fifo_partial_1_data,
    S_axis_last         => r_fifo_last,
    S_axis_almost_full  => w_fifo_almost_full,

    M_axis_clk          => Clk_axi,
    M_axis_ready        => Axis_ready,
    M_axis_valid        => Axis_valid,
    M_axis_data         => Axis_data,
    M_axis_last         => Axis_last
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if ((s_state = S_IDLE) or (s_state = S_CHECK_START)) then
        r_timeout <= (others => '0');
      else
        r_timeout <= r_timeout + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_timeout   <= to_stdlogic(r_timeout = (TIMEOUT_CYCLES - 1));
      Error_overflow  <= r_fifo_valid and not(w_fifo_ready);
    end if;
  end process;

end architecture rtl;
