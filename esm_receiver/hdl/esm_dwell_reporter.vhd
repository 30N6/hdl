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

entity esm_dwell_reporter is
generic (
  AXI_DATA_WIDTH        : natural;
  DATA_WIDTH            : natural;
  NUM_CHANNELS          : natural;
  CHANNEL_INDEX_WIDTH   : natural;
  MODULE_ID             : unsigned
);
port (
  Clk                 : in  std_logic;
  Rst                 : in  std_logic;

  Dwell_done          : in  std_logic;
  Dwell_data          : in  esm_dwell_metadata_t;
  Dwell_sequence_num  : in  unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  Dwell_duration      : in  unsigned(ESM_DWELL_DURATION_WIDTH - 1 downto 0);
  Timestamp_start     : in  unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);
  Timestamp_end       : in  unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);

  Read_req_accum      : out std_logic;
  Read_req_max        : out std_logic;
  Read_req_index      : out unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Read_data           : in  unsigned(63 downto 0);
  Read_valid          : in  std_logic;

  Report_ack          : out std_logic;

  Axis_ready          : in  std_logic;
  Axis_valid          : out std_logic;
  Axis_data           : out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  Axis_last           : out std_logic
);
end entity esm_dwell_reporter;

architecture rtl of esm_dwell_reporter is

  constant FIFO_DEPTH             : natural := 1024;
  constant MAX_WORDS_PER_PACKET   : natural := 64;
  constant FIFO_ALMOST_FULL_LEVEL : natural := FIFO_DEPTH - MAX_WORDS_PER_PACKET - 10;

  type state_t is
  (
    S_IDLE,

    S_START_NEW,
    S_START_CONTINUED,

    S_HEADER_0,
    S_HEADER_1,
    S_HEADER_2,

    S_SEQ_NUM,

    S_META_0,
    S_META_1,
    S_META_2,
    S_META_3,
    S_META_4,
    S_META_5,

    S_CHANNEL_INDEX,
    S_READ_CHANNEL,
    S_CHANNEL_ACCUM_0,
    S_CHANNEL_ACCUM_1,
    S_CHANNEL_MAX,

    S_PAD,

    S_DONE
  );

  signal s_state          : state_t;

  signal r_packet_seq_num : unsigned(31 downto 0);

  signal r_words_in_msg   : unsigned(clog2(MAX_WORDS_PER_PACKET) - 1 downto 0);

  signal w_fifo_ready     : std_logic;
  signal w_fifo_valid     : std_logic;
  signal w_fifo_data      : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
  signal w_fifo_last      : std_logic;

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
        if (w_fifo_ready = '1') then
          case s_state is
          when S_IDLE =>
            if (Dwell_done = '1') then
              s_state <= S_START_NEW;
            else
              s_state <= S_IDLE;
            end if;

          when S_START_NEW =>
            if (w_fifo_almost_full = '0') then
              s_state <= S_HEADER_0;
            else
              s_state <= S_START_NEW;
            end if;

          when S_START_CONTINUED =>
            if (w_fifo_almost_full = '0') then
              s_state <= S_HEADER_0;
            else
              s_state <= S_START_CONTINUED;
            end if;

          when S_HEADER_0 =>
            s_state <= S_HEADER_1;
          when S_HEADER_1 =>
            s_state <= S_HEADER_2;
          when S_HEADER_2 =>
            s_state <= S_SEQ_NUM;

          when S_SEQ_NUM =>
            s_state <= S_META_0;

          when S_META_0 =>
            s_state <= S_META_1;
          when S_META_1 =>
            s_state <= S_META_2;
          when S_META_2 =>
            s_state <= S_META_3;
          when S_META_3 =>
            s_state <= S_META_4;
          when S_META_4 =>
            s_state <= S_META_5;
          when S_META_5 =>
            s_state <= S_CHANNEL_INDEX; --TODO;

          when S_CHANNEL_INDEX =>
            s_state <= S_CHANNEL_ACCUM_0;

          when S_READ_CHANNEL =>
            if ( ) then
              s_state <= S_READ_CHANNEL;
          when S_CHANNEL_ACCUM_0 =>
            s_state <= S_CHANNEL_ACCUM_1;
          when S_CHANNEL_ACCUM_1 =>
            s_state <= S_CHANNEL_MAX;
          when S_CHANNEL_MAX =>
            if ( TODO ) then
              s_state <= S_READ_CHANNEL;
            else
              s_state <= S_PAD;
            end if;

          when S_PAD =>
            if ( TODO ) then
              s_state <= S_PAD;
            else
              s_state <= S_DONE;
            end if;

          when S_DONE =>
            if ( TODO ) then
              s_state <= S_START_CONTINUED;
            else
              s_state <= S_IDLE;
            end if;

          end case;
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

  process(all)
  begin
    w_fifo_data   <= (others => '-');
    w_fifo_last   <= (others => '-');
    w_fifo_valid  <= '0';

    case s_state is
    when S_HEADER_0 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= ESM_REPORT_MAGIC_NUM;

    when S_HEADER_1 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(r_packet_seq_num);

    when S_HEADER_2 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(MODULE_ID) & std_logic_vector(ESM_REPORT_MESSAGE_TYPE_DWELL_STATS) & x"0000";

    when S_SEQ_NUM =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(Dwell_sequence_num);

    when S_META_0 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(Dwell_data.tag) & std_logic_vector(Dwell_data.frequency);

    when S_META_1 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(Dwell_data.duration);

    when S_META_2 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(resize_up(Dwell_data.gain, 8)) & std_logic_vector(resize_up(Dwell_data.fast_lock_profile, 8)) & x"0000";

    when S_META_3 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(Dwell_data.threshold_narrow) & std_logic_vector(Dwell_data.threshold_wide);

    when S_META_4 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(Dwell_data.channel_mask_narrow(63 downto 32));

    when S_META_5 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(Dwell_data.channel_mask_narrow(31 downto 0));

    when S_META_6 =>
      w_fifo_valid  <= '1';
      w_fifo_data   <= std_logic_vector(Dwell_data.channel_mask_wide) & x"000000";

    when S_CHANNEL_INDEX =>

    when S_CHANNEL_ACCUM_0 =>

    when S_CHANNEL_ACCUM_1 =>

    when S_CHANNEL_MAX =>

    when S_PAD =>

    when others => null;
    end case;
  end process;


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
    S_axis_valid  => w_fifo_valid,
    S_axis_data   => w_fifo_data,
    S_axis_last   => w_fifo_last,

    M_axis_ready  => Axis_ready,
    M_axis_valid  => Axis_valid,
    M_axis_data   => Axis_data,
    M_axis_last   => Axis_last
  );

end architecture rtl;
