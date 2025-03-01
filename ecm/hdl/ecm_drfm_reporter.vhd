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

entity ecm_drfm_reporter is
generic (
  AXI_DATA_WIDTH      : natural;
  MEM_WIDTH           : natural
);
port (
  Clk_axi                 : in  std_logic;
  Clk                     : in  std_logic;
  Rst                     : in  std_logic;

  Dwell_active            : in  std_logic;
  Dwell_start             : in  std_logic;
  Dwell_done              : in  std_logic;
  Dwell_sequence_num      : in  unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);

  Channel_report_pending  : in  std_logic_vector(ECM_NUM_CHANNELS - 1 downto 0);
  Channel_was_read        : in  std_logic_vector(ECM_NUM_CHANNELS - 1 downto 0);
  Channel_was_written     : in  std_logic_vector(ECM_NUM_CHANNELS - 1 downto 0);

  Channel_index           : out unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  Channel_timestamp       : in  unsigned(ECM_TIMESTAMP_WIDTH - 1 downto 0);
  Channel_seq_num         : in  unsigned(ECM_DRFM_SEGMENT_SEQUENCE_NUM_WIDTH - 1 downto 0);
  Channel_addr_first      : in  unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  Channel_addr_last       : in  unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  Channel_max_iq_bits     : in  unsigned(ECM_DRFM_DATA_WIDTH_WIDTH - 1 downto 0);

  Read_valid              : out std_logic;
  Read_addr               : out unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  Read_result_valid       : in  std_logic;
  Read_result_data        : in  std_logic_vector(MEM_WIDTH - 1 downto 0);

  Channel_reports_done    : out std_logic;
  Dwell_reports_done      : out std_logic;

  Axis_ready              : in  std_logic;
  Axis_valid              : out std_logic;
  Axis_data               : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last               : out std_logic;

  Error_timeout           : out std_logic;
  Error_overflow          : out std_logic
);
end entity ecm_drfm_reporter;

architecture rtl of ecm_drfm_reporter is

  constant FIFO_DEPTH             : natural := 16384;
  constant FIFO_ALMOST_FULL_LEVEL : natural := FIFO_DEPTH - ECM_WORDS_PER_DMA_PACKET - 16;
  constant TIMEOUT_CYCLES         : natural := 1024;

  type state_t is
  (
    S_IDLE,

    S_START_WAIT,
    S_READ_CHANNEL_0,
    S_READ_CHANNEL_1,
    S_START_CHANNEL,
    S_CONTINUE_CHANNEL,
    S_START_SUMMARY,

    S_CHANNEL_HEADER_0,
    S_CHANNEL_HEADER_1,
    S_CHANNEL_HEADER_2,
    S_CHANNEL_DWELL_SEQ_NUM,
    S_CHANNEL_INFO,
    S_CHANNEL_SEGMENT_SEQ_NUM,
    S_CHANNEL_SEGMENT_TIMESTAMP_0,
    S_CHANNEL_SEGMENT_TIMESTAMP_1,
    S_CHANNEL_SEGMENT_INFO,
    S_CHANNEL_SLICE_INFO,
    S_CHANNEL_IQ_READ_START,
    S_CHANNEL_IQ_RESULT,
    S_CHANNEL_PAD,
    S_CHANNEL_DONE_0,
    S_CHANNEL_DONE_1,

    S_SUMMARY_HEADER_0,
    S_SUMMARY_HEADER_1,
    S_SUMMARY_HEADER_2,
    S_SUMMARY_DWELL_SEQ_NUM,
    S_SUMMARY_CHANNEL_STATE,
    S_SUMMARY_REPORT_DELAY_CHANNEL_WRITE,
    S_SUMMARY_REPORT_DELAY_SUMMARY_WRITE,
    S_SUMMARY_REPORT_DELAY_SUMMARY_START,
    S_SUMMARY_PAD,
    S_SUMMARY_DONE,

    S_WAIT_IDLE
  );

  signal s_state                          : state_t;

  signal r_channel_report_pending_any     : std_logic;

  signal r_packet_seq_num                 : unsigned(31 downto 0);
  signal r_channel_index                  : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_words_in_msg                   : unsigned(clog2(ECM_WORDS_PER_DMA_PACKET) - 1 downto 0);

  signal r_report_delay_channel_write     : unsigned(31 downto 0);
  signal r_report_delay_summary_write     : unsigned(31 downto 0);
  signal r_report_delay_summary_start     : unsigned(31 downto 0);

  signal r_channel_samples_remaining      : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);

  signal r_segment_first_addr             : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal r_segment_last_addr              : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal r_segment_addr                   : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal r_segment_addr_next              : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal r_slice_samples_remaining        : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  signal r_slice_samples_remaining_next   : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  signal r_segment_samples_remaining      : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  signal r_segment_samples_remaining_next : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);

  signal r_read_samples_remaining         : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  signal r_read_samples_remaining_next    : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  signal r_read_delay                     : std_logic;
  signal r_read_addr                      : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal r_read_addr_next                 : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal r_read_valid                     : std_logic;

  signal w_fifo_almost_full               : std_logic;
  signal w_fifo_ready                     : std_logic;

  signal r_fifo_almost_full               : std_logic;

  signal w_fifo_valid                     : std_logic;
  signal w_fifo_valid_opt                 : std_logic;
  signal w_fifo_last                      : std_logic;
  signal w_fifo_partial_0_data            : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_fifo_partial_1_data            : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

  signal r0_fifo_valid                    : std_logic;
  signal r0_fifo_last                     : std_logic;
  signal r0_fifo_partial_0_data           : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal r0_fifo_partial_1_data           : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal r0_fifo_almost_full              : std_logic;

  signal r1_fifo_valid                    : std_logic;
  signal r1_fifo_last                     : std_logic;
  signal r1_fifo_data                     : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal r1_fifo_almost_full              : std_logic;

  signal r_timeout                        : unsigned(clog2(TIMEOUT_CYCLES) - 1 downto 0);

begin

  assert (AXI_DATA_WIDTH = 32)
    report "AXI_DATA_WIDTH expected to be 32."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_channel_report_pending_any <= not(Dwell_start) and or_reduce(Channel_report_pending);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        s_state <= S_IDLE;
      else
        case s_state is
        when S_IDLE =>
          if (Dwell_active = '1') then
            s_state <= S_START_WAIT;
          else
            s_state <= S_IDLE;
          end if;

        when S_START_WAIT =>
          if (r_channel_report_pending_any = '1') then
            s_state <= S_READ_CHANNEL_0;
          elsif (Dwell_done = '1') then
            s_state <= S_START_SUMMARY;
          else
            s_state <= S_START_WAIT;
          end if;

        when S_READ_CHANNEL_0 =>
          s_state <= S_READ_CHANNEL_1;

        when S_READ_CHANNEL_1 =>
          s_state <= S_START_CHANNEL;

        when S_START_CHANNEL =>
          if (r1_fifo_almost_full = '0') then
            s_state <= S_CHANNEL_HEADER_0;
          else
            s_state <= S_START_CHANNEL;
          end if;

        when S_CONTINUE_CHANNEL =>
          if (r1_fifo_almost_full = '0') then
            s_state <= S_CHANNEL_HEADER_0;
          else
            s_state <= S_CONTINUE_CHANNEL;
          end if;

        when S_CHANNEL_HEADER_0 =>
          s_state <= S_CHANNEL_HEADER_1;
        when S_CHANNEL_HEADER_1 =>
          s_state <= S_CHANNEL_HEADER_2;
        when S_CHANNEL_HEADER_2 =>
          s_state <= S_CHANNEL_DWELL_SEQ_NUM;
        when S_CHANNEL_DWELL_SEQ_NUM =>
          s_state <= S_CHANNEL_INFO;
        when S_CHANNEL_INFO =>
          s_state <= S_CHANNEL_SEGMENT_SEQ_NUM;
        when S_CHANNEL_SEGMENT_SEQ_NUM =>
          s_state <= S_CHANNEL_SEGMENT_TIMESTAMP_0;
        when S_CHANNEL_SEGMENT_TIMESTAMP_0 =>
          s_state <= S_CHANNEL_SEGMENT_TIMESTAMP_1;
        when S_CHANNEL_SEGMENT_TIMESTAMP_1 =>
          s_state <= S_CHANNEL_SEGMENT_INFO;
        when S_CHANNEL_SEGMENT_INFO =>
          s_state <= S_CHANNEL_SLICE_INFO;
        when S_CHANNEL_SLICE_INFO =>
          if (r_slice_samples_remaining > 0) then
            s_state <= S_CHANNEL_IQ_READ_START;
          else
            s_state <= S_CHANNEL_PAD;
          end if;

        when S_CHANNEL_IQ_READ_START =>
          s_state <= S_CHANNEL_IQ_RESULT;

        when S_CHANNEL_IQ_RESULT =>
          s_state <= S_CHANNEL_IQ_RESULT;
          if ((Read_result_valid = '1') and (r_slice_samples_remaining = 1)) then
            s_state <= S_CHANNEL_PAD;
          end if;

        when S_CHANNEL_PAD =>
          if (r_words_in_msg = (ECM_WORDS_PER_DMA_PACKET - 1)) then
            s_state <= S_CHANNEL_DONE_0;
          else
            s_state <= S_CHANNEL_PAD;
          end if;

        when S_CHANNEL_DONE_0 => --extra state for Channel_report_pending propagation
          s_state <= S_CHANNEL_DONE_1;

        when S_CHANNEL_DONE_1 =>
          if (r_segment_samples_remaining > 0) then
            s_state <= S_CONTINUE_CHANNEL;
          else
            s_state <= S_START_WAIT;
          end if;

        when S_START_SUMMARY =>
          if (r1_fifo_almost_full = '0') then
            s_state <= S_SUMMARY_HEADER_0;
          else
            s_state <= S_START_SUMMARY;
          end if;

        when S_SUMMARY_HEADER_0 =>
          s_state <= S_SUMMARY_HEADER_1;
        when S_SUMMARY_HEADER_1 =>
          s_state <= S_SUMMARY_HEADER_2;
        when S_SUMMARY_HEADER_2 =>
          s_state <= S_SUMMARY_DWELL_SEQ_NUM;
        when S_SUMMARY_DWELL_SEQ_NUM =>
          s_state <= S_SUMMARY_CHANNEL_STATE;
        when S_SUMMARY_CHANNEL_STATE =>
          s_state <= S_SUMMARY_REPORT_DELAY_CHANNEL_WRITE;
        when S_SUMMARY_REPORT_DELAY_CHANNEL_WRITE =>
          s_state <= S_SUMMARY_REPORT_DELAY_SUMMARY_WRITE;
        when S_SUMMARY_REPORT_DELAY_SUMMARY_WRITE =>
          s_state <= S_SUMMARY_REPORT_DELAY_SUMMARY_START;
        when S_SUMMARY_REPORT_DELAY_SUMMARY_START =>
          s_state <= S_SUMMARY_PAD;

        when S_SUMMARY_PAD =>
          if (r_words_in_msg = (ECM_WORDS_PER_DMA_PACKET - 1)) then
            s_state <= S_SUMMARY_DONE;
          else
            s_state <= S_SUMMARY_PAD;
          end if;

        when S_SUMMARY_DONE =>
          s_state <= S_WAIT_IDLE;

        when S_WAIT_IDLE =>
          s_state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

  Channel_reports_done  <= to_stdlogic((s_state = S_CHANNEL_DONE_0) and (r_segment_samples_remaining = 0));

  process(Clk)
  begin
    if rising_edge(Clk) then
      Dwell_reports_done <= to_stdlogic(s_state = S_SUMMARY_DONE);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_report_delay_channel_write <= (others => '0');
      elsif (((s_state = S_START_CHANNEL) or (s_state = S_CONTINUE_CHANNEL)) and (r1_fifo_almost_full = '1')) then
        r_report_delay_channel_write <= r_report_delay_channel_write + 1;
      end if;

      if (s_state = S_IDLE) then
        r_report_delay_summary_write <= (others => '0');
      elsif ((s_state = S_START_SUMMARY) and (r1_fifo_almost_full = '1')) then
        r_report_delay_summary_write <= r_report_delay_summary_write + 1;
      end if;

      if (s_state = S_IDLE) then
        r_report_delay_summary_start <= (others => '0');
      elsif ((s_state = S_START_WAIT) and (r_channel_report_pending_any = '1') and (Dwell_done = '1')) then
        r_report_delay_summary_start <= r_report_delay_summary_start + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_packet_seq_num <= (others => '0');
      else
        if ((s_state = S_CHANNEL_DONE_0) or (s_state = S_SUMMARY_DONE)) then
          r_packet_seq_num <= r_packet_seq_num + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if ((s_state = S_START_CHANNEL) or (s_state = S_CONTINUE_CHANNEL) or (s_state = S_START_SUMMARY)) then
        r_words_in_msg <= (others => '0');
      elsif (w_fifo_valid_opt = '1') then
        r_words_in_msg <= r_words_in_msg + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_START_WAIT) then
        r_channel_index <= first_bit_index(Channel_report_pending);
      end if;
    end if;
  end process;

  Channel_index <= r_channel_index;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_channel_samples_remaining <= resize(Channel_addr_last - Channel_addr_first + 1, ECM_DRFM_SEGMENT_LENGTH_WIDTH);
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_segment_addr_next               <= r_segment_addr + 1;
      r_segment_samples_remaining_next  <= r_segment_samples_remaining - 1;
      r_slice_samples_remaining_next    <= r_slice_samples_remaining - 1;
      r_read_addr_next                  <= r_read_addr + 1;
      r_read_samples_remaining_next     <= r_read_samples_remaining - 1;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_START_CHANNEL) then
        r_segment_first_addr        <= Channel_addr_first;
        r_segment_last_addr         <= Channel_addr_last;
        r_segment_addr              <= Channel_addr_first;
        r_segment_samples_remaining <= r_channel_samples_remaining;
      elsif ((s_state = S_CHANNEL_IQ_RESULT) and (Read_result_valid = '1')) then
        r_segment_addr              <= r_segment_addr_next;
        r_segment_samples_remaining <= r_segment_samples_remaining_next;
      end if;

      if (s_state = S_CHANNEL_HEADER_0) then
        r_slice_samples_remaining   <= minimum(r_segment_samples_remaining, ECM_DRFM_MAX_PACKET_IQ_SAMPLES_PER_REPORT);
      elsif ((s_state = S_CHANNEL_IQ_RESULT) and (Read_result_valid = '1')) then
        r_slice_samples_remaining   <= r_slice_samples_remaining_next;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_read_valid              <= '0';
        r_read_delay              <= '0';
        r_read_samples_remaining  <= (others => '-');
        r_read_addr               <= (others => '-');
      else
        if (s_state = S_CHANNEL_HEADER_0) then
          r_read_delay <= '0';
        else
          r_read_delay <= not(r_read_delay);
        end if;

        if (s_state = S_CHANNEL_HEADER_0) then
          r_read_samples_remaining  <= minimum(r_segment_samples_remaining, ECM_DRFM_MAX_PACKET_IQ_SAMPLES_PER_REPORT);
          r_read_addr               <= r_segment_addr;
        elsif ((r_read_valid = '1') and (r_read_delay = '1')) then
          r_read_samples_remaining  <= r_read_samples_remaining_next;
          r_read_addr               <= r_read_addr_next;
        end if;

        if (s_state = S_CHANNEL_IQ_READ_START) then
          r_read_valid <= '1';
        elsif ((r_read_samples_remaining <= 1) and (r_read_delay = '1')) then
          r_read_valid <= '0';
        end if;
      end if;
    end if;
  end process;

  Read_valid  <= r_read_valid and r_read_delay;
  Read_addr   <= r_read_addr;

  process(all)
  begin
    w_fifo_valid          <= '0';
    w_fifo_last           <= '0';
    w_fifo_partial_0_data <= (others => '0');
    w_fifo_partial_1_data <= (others => '0');

    case s_state is
    when S_CHANNEL_HEADER_0 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= ECM_REPORT_MAGIC_NUM;

    when S_CHANNEL_HEADER_1 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(r_packet_seq_num);

    when S_CHANNEL_HEADER_2 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(ECM_MODULE_ID_DRFM) & std_logic_vector(ECM_REPORT_MESSAGE_TYPE_DRFM_CHANNEL_DATA) & x"0000";

    when S_CHANNEL_DWELL_SEQ_NUM =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(Dwell_sequence_num);

    when S_CHANNEL_INFO =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(resize_up(r_channel_index, 8)) & std_logic_vector(resize_up(Channel_max_iq_bits, 8)) & x"0000";

    when S_CHANNEL_SEGMENT_SEQ_NUM =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(Channel_seq_num);

    when S_CHANNEL_SEGMENT_TIMESTAMP_0 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(resize_up(Channel_timestamp(ECM_TIMESTAMP_WIDTH - 1 downto 32), 32));

    when S_CHANNEL_SEGMENT_TIMESTAMP_1 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(Channel_timestamp(31 downto 0));

    when S_CHANNEL_SEGMENT_INFO =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(resize_up(Channel_addr_first, 16)) & std_logic_vector(resize_up(Channel_addr_last, 16));

    when S_CHANNEL_SLICE_INFO =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(resize_up(r_segment_addr, 16)) & std_logic_vector(resize_up(r_slice_samples_remaining, 16));

    when S_CHANNEL_IQ_RESULT =>
      w_fifo_valid            <= Read_result_valid;
      w_fifo_partial_1_data   <= Read_result_data;

    when S_SUMMARY_HEADER_0 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= ECM_REPORT_MAGIC_NUM;

    when S_SUMMARY_HEADER_1 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(r_packet_seq_num);

    when S_SUMMARY_HEADER_2 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(ECM_MODULE_ID_DRFM) & std_logic_vector(ECM_REPORT_MESSAGE_TYPE_DRFM_SUMMARY) & x"0000";

    when S_SUMMARY_DWELL_SEQ_NUM =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(Dwell_sequence_num);

    when S_SUMMARY_CHANNEL_STATE =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= Channel_was_written & Channel_was_read;

    when S_SUMMARY_REPORT_DELAY_CHANNEL_WRITE =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(r_report_delay_channel_write);

    when S_SUMMARY_REPORT_DELAY_SUMMARY_WRITE =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(r_report_delay_summary_write);

    when S_SUMMARY_REPORT_DELAY_SUMMARY_START =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(r_report_delay_summary_start);

    when S_CHANNEL_PAD | S_SUMMARY_PAD =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= (others => '0');
      w_fifo_last             <= to_stdlogic(r_words_in_msg = (ECM_WORDS_PER_DMA_PACKET - 1));

    when others => null;
    end case;
  end process;

  process(all)
  begin
    w_fifo_valid_opt <= '1';
    case s_state is
    when S_IDLE                   =>  w_fifo_valid_opt <= '0';
    when S_START_WAIT             =>  w_fifo_valid_opt <= '0';
    when S_READ_CHANNEL_0         =>  w_fifo_valid_opt <= '0';
    when S_READ_CHANNEL_1         =>  w_fifo_valid_opt <= '0';
    when S_START_CHANNEL          =>  w_fifo_valid_opt <= '0';
    when S_CONTINUE_CHANNEL       =>  w_fifo_valid_opt <= '0';
    when S_START_SUMMARY          =>  w_fifo_valid_opt <= '0';
    when S_CHANNEL_IQ_READ_START  =>  w_fifo_valid_opt <= '0';
    when S_CHANNEL_IQ_RESULT      =>  w_fifo_valid_opt <= Read_result_valid;
    when S_CHANNEL_DONE_0         =>  w_fifo_valid_opt <= '0';
    when S_CHANNEL_DONE_1         =>  w_fifo_valid_opt <= '0';
    when S_SUMMARY_DONE           =>  w_fifo_valid_opt <= '0';
    when S_WAIT_IDLE              =>  w_fifo_valid_opt <= '0';
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
      r0_fifo_valid           <= w_fifo_valid_opt;
      r0_fifo_partial_0_data  <= w_fifo_partial_0_data;
      r0_fifo_partial_1_data  <= w_fifo_partial_1_data;
      r0_fifo_last            <= w_fifo_last;
    end if;
 end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_fifo_valid <= r0_fifo_valid;
      r1_fifo_data  <= r0_fifo_partial_0_data or r0_fifo_partial_1_data;
      r1_fifo_last  <= r0_fifo_last;
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
    S_axis_valid        => r1_fifo_valid,
    S_axis_data         => r1_fifo_data,
    S_axis_last         => r1_fifo_last,
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
      r0_fifo_almost_full <= w_fifo_almost_full;
      r1_fifo_almost_full <= r0_fifo_almost_full;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if ((s_state = S_IDLE) or (s_state = S_START_WAIT) or (s_state = S_START_CHANNEL) or (s_state = S_CONTINUE_CHANNEL) or (s_state = S_START_SUMMARY))  then
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
      Error_overflow  <= r1_fifo_valid and not(w_fifo_ready);
    end if;
  end process;

end architecture rtl;
