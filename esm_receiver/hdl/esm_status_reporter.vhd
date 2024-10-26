library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library esm_lib;
  use esm_lib.esm_pkg.all;

entity esm_status_reporter is
generic (
  AXI_DATA_WIDTH        : natural;
  MODULE_ID             : unsigned;
  HEARTBEAT_INTERVAL    : natural
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Enable_status         : in  std_logic;
  Enable_channelizer    : in  std_logic_vector(1 downto 0);
  Enable_pdw_encoder    : in  std_logic_vector(1 downto 0);

  Channelizer_warnings  : in  esm_channelizer_warnings_array_t(1 downto 0);
  Channelizer_errors    : in  esm_channelizer_errors_array_t(1 downto 0);
  Dwell_stats_errors    : in  esm_dwell_stats_errors_array_t(1 downto 0);
  Pdw_encoder_errors    : in  esm_pdw_encoder_errors_array_t(1 downto 0);

  Axis_ready            : in  std_logic;
  Axis_valid            : out std_logic;
  Axis_data             : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last             : out std_logic
);
end entity esm_status_reporter;

architecture rtl of esm_status_reporter is

  constant FIFO_DEPTH             : natural := 256;
  constant MAX_WORDS_PER_PACKET   : natural := 64;
  constant FIFO_ALMOST_FULL_LEVEL : natural := FIFO_DEPTH - MAX_WORDS_PER_PACKET - 10;

  constant TIMEOUT_CYCLES         : natural := 1024;

  type state_t is
  (
    S_IDLE,
    S_START,

    S_HEADER_0,
    S_HEADER_1,
    S_HEADER_2,

    S_ENABLES,
    S_STATUS,
    S_TIMESTAMP_0,
    S_TIMESTAMP_1,

    S_PAD,
    S_DONE
  );

  signal s_state                : state_t;

  signal r_timestamp            : unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);

  signal r_enable_status        : std_logic;
  signal r_enable_channelizer   : std_logic_vector(1 downto 0);
  signal r_enable_pdw_encoder   : std_logic_vector(1 downto 0);
  signal r_channelizer_warnings : esm_channelizer_warnings_array_t(1 downto 0);
  signal r_channelizer_errors   : esm_channelizer_errors_array_t(1 downto 0);
  signal r_dwell_stats_errors   : esm_dwell_stats_errors_array_t(1 downto 0);
  signal r_pdw_encoder_errors   : esm_pdw_encoder_errors_array_t(1 downto 0);

  signal w_status_flags         : esm_status_flags_t;
  signal r_status_flags_latched : std_logic_vector(ESM_STATUS_FLAGS_WIDTH - 1 downto 0);

  signal r_status_timer         : unsigned(clog2(HEARTBEAT_INTERVAL) - 1 downto 0);
  signal r_status_trigger       : std_logic;

  signal r_packet_seq_num       : unsigned(31 downto 0);
  signal r_trigger_timestamp    : unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);

  signal r_words_in_msg         : unsigned(clog2(MAX_WORDS_PER_PACKET) - 1 downto 0);

  signal w_fifo_almost_full     : std_logic;
  signal w_fifo_ready           : std_logic;
  signal w_fifo_valid           : std_logic;
  signal w_fifo_last            : std_logic;
  signal w_fifo_data            : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

  signal r_fifo_valid           : std_logic;
  signal r_fifo_last            : std_logic;
  signal r_fifo_data            : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

  signal r_timeout              : unsigned(clog2(TIMEOUT_CYCLES) - 1 downto 0);
  signal r_error_timeout        : std_logic;
  signal r_error_overflow       : std_logic;

  attribute MARK_DEBUG : string;
  attribute DONT_TOUCH : string;

  attribute MARK_DEBUG of s_state : signal is "TRUE";
  attribute DONT_TOUCH of s_state : signal is "TRUE";
  attribute MARK_DEBUG of r_status_trigger : signal is "TRUE";
  attribute DONT_TOUCH of r_status_trigger : signal is "TRUE";
  attribute MARK_DEBUG of r_status_timer : signal is "TRUE";
  attribute DONT_TOUCH of r_status_timer : signal is "TRUE";
  attribute MARK_DEBUG of r_words_in_msg : signal is "TRUE";
  attribute DONT_TOUCH of r_words_in_msg : signal is "TRUE";
  attribute MARK_DEBUG of w_fifo_almost_full : signal is "TRUE";
  attribute DONT_TOUCH of w_fifo_almost_full : signal is "TRUE";
  attribute MARK_DEBUG of w_fifo_ready : signal is "TRUE";
  attribute DONT_TOUCH of w_fifo_ready : signal is "TRUE";
  attribute MARK_DEBUG of w_fifo_valid : signal is "TRUE";
  attribute DONT_TOUCH of w_fifo_valid : signal is "TRUE";
  attribute MARK_DEBUG of w_fifo_last : signal is "TRUE";
  attribute DONT_TOUCH of w_fifo_last : signal is "TRUE";
  attribute MARK_DEBUG of w_fifo_data : signal is "TRUE";
  attribute DONT_TOUCH of w_fifo_data : signal is "TRUE";
  attribute MARK_DEBUG of r_timeout : signal is "TRUE";
  attribute DONT_TOUCH of r_timeout : signal is "TRUE";
  attribute MARK_DEBUG of r_error_timeout : signal is "TRUE";
  attribute DONT_TOUCH of r_error_timeout : signal is "TRUE";
  attribute MARK_DEBUG of r_error_overflow : signal is "TRUE";
  attribute DONT_TOUCH of r_error_overflow : signal is "TRUE";
  attribute MARK_DEBUG of r_status_flags_latched : signal is "TRUE";
  attribute DONT_TOUCH of r_status_flags_latched : signal is "TRUE";
begin

  assert (AXI_DATA_WIDTH = 32)
    report "AXI_DATA_WIDTH expected to be 32."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_enable_status         <= Enable_status;
      r_enable_channelizer    <= Enable_channelizer;
      r_enable_pdw_encoder    <= Enable_pdw_encoder;
      r_channelizer_warnings  <= Channelizer_warnings;
      r_channelizer_errors    <= Channelizer_errors;
      r_dwell_stats_errors    <= Dwell_stats_errors;
      r_pdw_encoder_errors    <= Pdw_encoder_errors;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_status_timer <= (others => '0');
      else
        if ((r_enable_status = '0') or (r_status_trigger = '1')) then
          r_status_timer <= (others => '0');
        else
          r_status_timer <= r_status_timer + 1;

        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_status_trigger <= to_stdlogic(r_status_timer = (HEARTBEAT_INTERVAL - 2));
    end if;
  end process;

  w_status_flags.channelizer_warnings                     <= r_channelizer_warnings;
  w_status_flags.channelizer_errors                       <= r_channelizer_errors;
  w_status_flags.dwell_stats_errors                       <= r_dwell_stats_errors;
  w_status_flags.pdw_encoder_errors                       <= r_pdw_encoder_errors;
  w_status_flags.status_reporter_errors.reporter_timeout  <= r_error_timeout;
  w_status_flags.status_reporter_errors.reporter_overflow <= r_error_overflow;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_status_flags_latched <= (others => '0');
      else
        if (or_reduce(pack(w_status_flags)) = '1') then
          r_status_flags_latched <= r_status_flags_latched or pack(w_status_flags);
        elsif (s_state = S_STATUS) then
          r_status_flags_latched <= (others => '0');
        end if;
      end if;
    end if;
  end process;

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
      if (s_state = S_IDLE) then
        r_trigger_timestamp <= r_timestamp;
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
          if (r_status_trigger = '1') then
            s_state <= S_START;
          else
            s_state <= S_IDLE;
          end if;

        when S_START =>
          if (w_fifo_almost_full = '0') then
            s_state <= S_HEADER_0;
          else
            s_state <= S_START;
          end if;

        when S_HEADER_0 =>
          s_state <= S_HEADER_1;
        when S_HEADER_1 =>
          s_state <= S_HEADER_2;
        when S_HEADER_2 =>
          s_state <= S_ENABLES;

        when S_ENABLES =>
          s_state <= S_STATUS;
        when S_STATUS =>
          s_state <= S_TIMESTAMP_0;
        when S_TIMESTAMP_0 =>
          s_state <= S_TIMESTAMP_1;
        when S_TIMESTAMP_1 =>
          s_state <= S_PAD;

        when S_PAD =>
          if (r_words_in_msg = (MAX_WORDS_PER_PACKET - 1)) then
            s_state <= S_DONE;
          else
            s_state <= S_PAD;
          end if;

        when S_DONE =>
          s_state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (s_state = S_IDLE) then
        r_words_in_msg <= (others => '0');
      elsif (w_fifo_valid = '1') then
        r_words_in_msg <= r_words_in_msg + 1;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    w_fifo_valid  <= '0';
    w_fifo_last   <= '0';
    w_fifo_data   <= (others => '0');

    case s_state is
    when S_HEADER_0 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= ESM_REPORT_MAGIC_NUM;

    when S_HEADER_1 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(r_packet_seq_num);

    when S_HEADER_2 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(MODULE_ID) & std_logic_vector(ESM_REPORT_MESSAGE_TYPE_STATUS) & x"0000";

    when S_ENABLES =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= x"000000" & "000" & r_enable_pdw_encoder & r_enable_channelizer & r_enable_status;

    when S_STATUS =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= resize_up(r_status_flags_latched, 32);

    when S_TIMESTAMP_0 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(resize_up(r_trigger_timestamp(ESM_TIMESTAMP_WIDTH - 1 downto 32), 32));

    when S_TIMESTAMP_1 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(r_trigger_timestamp(31 downto 0));

    when S_PAD =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= (others => '0');
      w_fifo_last   <= to_stdlogic(r_words_in_msg = (MAX_WORDS_PER_PACKET - 1));

    when others => null;
    end case;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_fifo_valid  <= w_fifo_valid;
      r_fifo_data   <= w_fifo_data;
      r_fifo_last   <= w_fifo_last;
    end if;
 end process;

  assert ((s_state = S_IDLE) or (w_fifo_ready = '1'))
    report "Ready expected to be high."
    severity failure;

  i_fifo : entity axi_lib.axis_sync_fifo
  generic map (
    FIFO_DEPTH        => FIFO_DEPTH,
    ALMOST_FULL_LEVEL => FIFO_ALMOST_FULL_LEVEL,
    AXI_DATA_WIDTH    => AXI_DATA_WIDTH
  )
  port map (
    Clk           => Clk,
    Rst           => Rst,

    Almost_full   => w_fifo_almost_full,

    S_axis_ready  => w_fifo_ready,
    S_axis_valid  => r_fifo_valid,
    S_axis_data   => r_fifo_data,
    S_axis_last   => r_fifo_last,

    M_axis_ready  => Axis_ready,
    M_axis_valid  => Axis_valid,
    M_axis_data   => Axis_data,
    M_axis_last   => Axis_last
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
      r_error_timeout   <= to_stdlogic(r_timeout = (TIMEOUT_CYCLES - 1));
      r_error_overflow  <= r_fifo_valid and not(w_fifo_ready);
    end if;
  end process;

end architecture rtl;
