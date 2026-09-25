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

entity intercept_stream_reporter is
generic (
  AXI_DATA_WIDTH : natural
);
port (
  Clk_axi         : in  std_logic;
  Clk             : in  std_logic;
  Rst             : in  std_logic;

  Stream_req      : in  std_logic;
  Stream_sample   : in  intercept_stream_sample_t;
  Stream_dwell    : in  intercept_dwell_data_t;
  Stream_ack      : out std_logic;

  Axis_ready      : in  std_logic;
  Axis_valid      : out std_logic;
  Axis_data       : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last       : out std_logic;

  Error_timeout   : out std_logic;
  Error_overflow  : out std_logic
);
end entity intercept_stream_reporter;

architecture rtl of intercept_stream_reporter is

  constant FIFO_DEPTH             : natural := 4096;
  constant FIFO_ALMOST_FULL_LEVEL : natural := FIFO_DEPTH - INTERCEPT_MAX_WORDS_PER_PACKET_LARGE - 10;
  constant TIMEOUT_CYCLES         : natural := 256 * 1024;

  type state_t is
  (
    S_IDLE,

    S_HEADER_0,
    S_HEADER_1,
    S_HEADER_2,
    S_HEADER_3,

    S_DWELL_DATA_0,
    S_DWELL_DATA_1,
    S_DWELL_DATA_2,
    S_PADDING_0,
    S_TIMESTAMP_0,
    S_TIMESTAMP_1,

    S_SAMPLE_CHECK,
    S_SAMPLE_DATA_0,
    S_SAMPLE_DATA_1,
    S_SAMPLE_DATA_2,
    S_SAMPLE_DATA_3,

    S_DONE
  );

  signal r_timestamp              : unsigned(INTERCEPT_TIMESTAMP_WIDTH - 1 downto 0);

  signal s_state                  : state_t;

  signal w_sample_data_aligned    : intercept_stream_sample_aligned_t;
  signal w_sample_data_packed     : std_logic_vector(INTERCEPT_STREAM_SAMPLE_ALIGNED_WIDTH - 1 downto 0);

  signal r_packet_seq_num         : unsigned(31 downto 0);
  signal r_words_in_msg           : unsigned(clog2(INTERCEPT_MAX_WORDS_PER_PACKET_LARGE) - 1 downto 0);

  signal w_fifo_almost_full       : std_logic;
  signal w_fifo_ready             : std_logic;

  signal w_fifo_valid             : std_logic;
  signal w_fifo_valid_opt         : std_logic;
  signal w_fifo_last              : std_logic;
  signal w_fifo_partial_0_data    : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_fifo_partial_1_data    : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

  signal r_fifo_valid             : std_logic;
  signal r_fifo_last              : std_logic;
  signal r_fifo_partial_0_data    : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal r_fifo_partial_1_data    : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

  signal r_timeout                : unsigned(clog2(TIMEOUT_CYCLES) - 1 downto 0);

begin

  assert (AXI_DATA_WIDTH = 32)
    report "AXI_DATA_WIDTH expected to be 32."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_timestamp <= (others => '0');
      else
        r_timestamp <= r_timestamp + 1;
      end if;
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
          if ((Stream_req = '1') and (w_fifo_almost_full = '0')) then
            s_state <= S_HEADER_0;
          else
            s_state <= S_IDLE;
          end if;

        when S_HEADER_0 =>
          s_state <= S_HEADER_1;
        when S_HEADER_1 =>
          s_state <= S_HEADER_2;
        when S_HEADER_2 =>
          s_state <= S_HEADER_3;
        when S_HEADER_3 =>
          s_state <= S_DWELL_DATA_0;

        when S_DWELL_DATA_0 =>
          s_state <= S_DWELL_DATA_1;
        when S_DWELL_DATA_1 =>
          s_state <= S_DWELL_DATA_2;
        when S_DWELL_DATA_2 =>
          s_state <= S_PADDING_0;
        when S_PADDING_0 =>
          s_state <= S_TIMESTAMP_0;
        when S_TIMESTAMP_0 =>
          s_state <= S_TIMESTAMP_1;
        when S_TIMESTAMP_1 =>
          s_state <= S_SAMPLE_CHECK;

        when S_SAMPLE_CHECK =>
          if ((Stream_req = '1') and (r_words_in_msg <= (INTERCEPT_MAX_WORDS_PER_PACKET_LARGE - 5))) then  -- 4 sample words + 1 eof word
            s_state <= S_SAMPLE_DATA_0;
          else
            s_state <= S_DONE;
          end if;

        when S_SAMPLE_DATA_0 =>
          s_state <= S_SAMPLE_DATA_1;
        when S_SAMPLE_DATA_1 =>
          s_state <= S_SAMPLE_DATA_2;
        when S_SAMPLE_DATA_2 =>
          s_state <= S_SAMPLE_DATA_3;
        when S_SAMPLE_DATA_3 =>
          if (Stream_sample.trigger_type = INTERCEPT_STREAM_TRIGGER_TYPE_LAST) then
            s_state <= S_DONE;
          else
            s_state <= S_SAMPLE_CHECK;
          end if;

        when S_DONE =>
          s_state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

  Stream_ack <= to_stdlogic(s_state = S_SAMPLE_DATA_3);

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_packet_seq_num <= (others => '0');
      else
        if (s_state = S_DONE) then
          r_packet_seq_num <= r_packet_seq_num + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_words_in_msg <= (others => '0');
      elsif (w_fifo_valid_opt = '1') then
        r_words_in_msg <= r_words_in_msg + 1;
      end if;
    end if;
  end process;


  w_sample_data_aligned.trigger_type  <= resize_up(Stream_sample.trigger_type, 8);
  w_sample_data_aligned.stream_index  <= resize_up(Stream_sample.stream_index, 8);
  w_sample_data_aligned.channel_index <= resize_up(Stream_sample.channel_index, 16);
  w_sample_data_aligned.sample_index  <= Stream_sample.sample_index;
  w_sample_data_aligned.data_i        <= resize_up(Stream_sample.data_i, 32);
  w_sample_data_aligned.data_q        <= resize_up(Stream_sample.data_q, 32);
  w_sample_data_packed                <= pack(w_sample_data_aligned);

  process(all)
  begin
    w_fifo_valid  <= '0';
    w_fifo_last   <= '0';
    w_fifo_partial_0_data   <= (others => '0');
    w_fifo_partial_1_data   <= (others => '0');

    case s_state is
    when S_HEADER_0 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= INTERCEPT_REPORT_MAGIC_NUM;

    when S_HEADER_1 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(r_packet_seq_num);

    when S_HEADER_2 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(INTERCEPT_MODULE_ID_STREAM_ENCODER) & std_logic_vector(INTERCEPT_REPORT_MESSAGE_TYPE_STREAM) & x"0000";

    when S_HEADER_3 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= (others => '0');

    when S_DWELL_DATA_0 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(Stream_dwell.sequence_num);

    when S_DWELL_DATA_1 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(Stream_dwell.frequency);

    when S_DWELL_DATA_2 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_0_data   <= std_logic_vector(Stream_dwell.tag) & x"0000";

    when S_PADDING_0 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= (others => '0');

    when S_TIMESTAMP_0 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= x"0000" & std_logic_vector(r_timestamp(47 downto 32));

    when S_TIMESTAMP_1 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= std_logic_vector(r_timestamp(31 downto 0));

    when S_SAMPLE_DATA_0 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= w_sample_data_packed(31 downto 0);

    when S_SAMPLE_DATA_1 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= w_sample_data_packed(63 downto 32);

    when S_SAMPLE_DATA_2 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= w_sample_data_packed(95 downto 64);

    when S_SAMPLE_DATA_3 =>
      w_fifo_valid            <= '1';
      w_fifo_partial_1_data   <= w_sample_data_packed(127 downto 96);

    when S_DONE =>
      w_fifo_valid            <= '1';
      w_fifo_last             <= '1';
      w_fifo_partial_1_data   <= x"CAFEF00D";

    when others => null;
    end case;
  end process;

  process(all)
  begin
    w_fifo_valid_opt <= '1';
    case s_state is
    when S_IDLE          => w_fifo_valid_opt <= '0';
    when S_SAMPLE_CHECK  => w_fifo_valid_opt <= '0';
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
      if (s_state = S_IDLE) then
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
