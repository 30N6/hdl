library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library axi_lib;

library mem_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

library esm_lib;
  use esm_lib.esm_pkg.all;

entity esm_pdw_sample_processor is
generic (
  CHANNEL_INDEX_WIDTH         : natural;
  DATA_WIDTH                  : natural;
  BUFFERED_SAMPLES_PER_FRAME  : natural;
  BUFFERED_SAMPLE_PADDING     : natural;
  PDW_FIFO_DEPTH              : natural
);
port (
  Clk                     : in  std_logic;
  Rst                     : in  std_logic;

  Dwell_active            : in  std_logic;

  Input_ctrl              : in  channelizer_control_t;
  Input_iq_delayed        : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  Input_pwr               : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  Input_threshold         : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0)

  Pdw_ready               : in  std_logic;
  Pdw_valid               : out std_logic;
  Pdw_data                : out esm_pdw_fifo_data_t;

  Buffered_frame_req      : in  esm_pdw_sample_buffer_req_t;
  Buffered_frame_ack      : out esm_pdw_sample_buffer_ack_t;
  Buffered_frame_data     : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Error_fifo_overflow     : out std_logic;
  Error_buffer_underflow  : out std_logic;
  Error_buffer_overflow   : out std_logic
);
end entity esm_pdw_sample_processor;

architecture rtl of esm_pdw_sample_processor is

  constant SAMPLE_PADDING_INDEX : natural := clog2(BUFFERED_SAMPLE_PADDING);

  type channel_state_t is
  (
    S_IDLE,
    S_ACTIVE,
    S_PAD_RECORDING,
    S_STORE_REPORT
  );

  type channel_context_t is record
    state                     : channel_state_t;
    threshold                 : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
    power_accum               : unsigned(ESM_PDW_POWER_ACCUM_WIDTH - 1 downto 0);
    duration                  : unsigned(ESM_PDW_CYCLE_COUNT_WIDTH - 1 downto 0);
    recording_skipped         : std_logic;
    recording_active          : std_logic;
    recording_frame_index     : unsigned(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
    recording_sample_index    : unsigned(ESM_PDW_SAMPLE_BUFFER_SAMPLE_INDEX_WIDTH - 1 downto 0);
    recording_sample_padding  : unsigned(SAMPLE_PADDING_INDEX - 1 downto 0);
    ts_start                  : unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);
  end record;

  type channel_context_array_t is array (natural range <>) of channel_context_t;

  signal r_timestamp                : unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);
  signal r_reset_index              : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0) := (others => '0');

  signal m_channel_context          : channel_context_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0);

  signal r0_input_ctrl              : channelizer_control_t;
  signal r0_input_iq                : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r0_input_pwr               : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r0_input_threshold         : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r0_context                 : channel_context_t;

  signal r1_input_ctrl              : channelizer_control_t;
  signal r1_input_iq                : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r1_input_pwr               : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r1_input_threshold         : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r1_context                 : channel_context_t;
  signal r1_new_detect              : std_logic;
  signal r1_continued_detect        : std_logic;

  signal r2_context                 : channel_context_t;
  signal r2_context_wr_index        : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r2_context_wr_valid        : std_logic;

  signal r_sequence_num             : unsigned(31 downto 0);

  signal w_buffer_full              : std_logic;
  signal w_buffer_next_index        : unsigned(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
  signal w_buffer_next_start        : std_logic;

  signal w_fifo_full                : std_logic;
  signal w_fifo_wr_data             : esm_pdw_fifo_data_t;
  signal w_fifo_wr_en               : std_logic;
  signal w_fifo_empty               : std_logic;
  signal w_fifo_rd_data             : std_logic_vector(ESM_PDW_FIFO_DATA_WIDTH - 1 downto 0);

  signal w_fifo_overflow            : std_logic;
  signal w_sample_buffer_overflow   : std_logic;
  signal w_sample_buffer_underflow  : std_logic;

begin

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
      r_reset_index <= r_reset_index + 1;
    end if;
  end process;

  --TODO: error check channel index collisions - need 3? cycles for processing a given channel

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_input_ctrl       <= Input_ctrl;
      r0_input_iq         <= Input_iq_delayed;
      r0_input_pwr        <= Input_pwr;
      r0_input_threshold  <= Input_threshold;
      r0_context          <= m_channel_context(to_integer(Input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_input_ctrl       <= r0_input_ctrl;
      r1_input_iq         <= r0_input_iq;
      r1_input_pwr        <= r0_input_pwr;
      r1_input_threshold  <= r0_input_threshold;
      r1_context          <= r0_context;
      r1_new_detect       <= to_stdlogic(r0_input_pwr > r0_input_threshold);
      r1_continued_detect <= to_stdlogic(r0_input_pwr > shift_right(r0_context.threshold, 1)); -- reduce threshold by 3 dB after pulse has started
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_context <= r1_context;

      case r1_context.state is
      when S_IDLE =>
        r2_context.threshold                <= r1_input_threshold;
        r2_context.power_accum              <= resize_up(r1_input_pwr, ESM_PDW_POWER_ACCUM_WIDTH);
        r2_context.duration                 <= (0 => 1, others => '0');
        r2_context.recording_skipped        <= '0';
        r2_context.recording_active         <= '0';
        r2_context.recording_frame_index    <= (others => '-');
        r2_context.recording_sample_index   <= (others => '-');
        r2_context.recording_sample_padding <= (others => '0');
        r2_context.ts_start                 <= r_timestamp;

        if ((Dwell_active = '1') and (r1_new_detect = '1') and (w_fifo_full = '0')) then
          r2_context.state                  <= S_ACTIVE;
          r2_context.recording_skipped      <= w_buffer_full;
          r2_context.recording_active       <= not(w_buffer_full);
          r2_context.recording_frame_index  <= w_buffer_next_index;
        end if;

      when S_ACTIVE =>
        r2_context.duration     <= r1_context.duration + 1; --TODO: clamp
        r2_context.power_accum  <= r1_context.power_accum + r1_input_pwr; --TODO: clamp

        if (r1_context.recording_active = '1') then
          if (r1_context.recording_sample_index = (BUFFERED_SAMPLES_PER_FRAME - 1)) then
            r2_context.recording_active <= '0';
          else
            r2_context.recording_sample_index <= r1_context.recording_sample_index + 1;
          end if;
        end if;

        if ((Dwell_active = '0') or (r1_continued_detect = '0')) then
          if ((r1_context.recording_active = '0') or (r1_context.recording_sample_index = (BUFFERED_SAMPLES_PER_FRAME - 1))) then
            r2_context.state <= S_STORE_REPORT;
          else
            r2_context.state <= S_PAD_RECORDING;
          end if;
        end if;

      when S_PAD_RECORDING =>
        if (r1_context.recording_active = '1') then
          if ((r1_context.recording_sample_padding = (BUFFERED_SAMPLE_PADDING - 1)) or (r1_context.recording_sample_index = (BUFFERED_SAMPLES_PER_FRAME - 1)) then
            r2_context.recording_active         <= '0';
            r2_context.state                    <= S_STORE_REPORT;
          else
            r2_context.recording_sample_padding <= r1_context.recording_sample_padding + 1;
            r2_context.recording_sample_index   <= r1_context.recording_sample_index + 1;
          end if;
        else
          r2_context.state <= S_STORE_REPORT;
        end if;

      when S_STORE_REPORT =>
        r2_context.state <= S_IDLE;

      end case;

      if (Rst = '1') then
        r2_context_wr_index <= r_reset_index;
        r2_context_wr_valid <= '1';
        r2_context.state    <= S_IDLE;
      else
        r2_context_wr_index <= r1_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0);
        r2_context_wr_valid <= r1_input_ctrl.valid;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_sequence_num <= (others => '0');
      else
        if (r1_context.state = S_STORE_REPORT) then
          r_sequence_num <= r_sequence_num + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r2_context_wr_valid = '1') then
        m_channel_context(to_integer(r2_context_wr_index)) <= r2_context;
      end if;
    end if;
  end process;

  w_fifo_wr_en                        <= to_stdlogic(r1_context.state = S_STORE_REPORT);
  w_fifo_wr_data.sequence_num         <= r_sequence_num;
  w_fifo_wr_data.channel              <= r1_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0);
  w_fifo_wr_data.power_accum          <= r1_context.power_accum;
  w_fifo_wr_data.power_threshold      <= r1_context.threshold;
  w_fifo_wr_data.num_samples          <= r1_context.duration;
  w_fifo_wr_data.frequency            <= (others => '0');
  w_fifo_wr_data.pulse_start_time     <= r1_context.ts_start;
  w_fifo_wr_data.buffered_frame_index <= r1_context.recording_frame_index;
  w_fifo_wr_data.buffered_frame_valid <= not(r1_context.recording_skipped);

  i_pdw_fifo : entity mem_lib.xpm_fallthough_fifo
  generic map (
    FIFO_DEPTH        => PDW_FIFO_DEPTH,
    FIFO_WIDTH        => ESM_PDW_FIFO_DATA_WIDTH,
    ALMOST_FULL_LEVEL => PDW_FIFO_DEPTH-1,
  )
  port (
    Clk         => Clk,
    Rst         => Rst,

    Wr_en       => w_fifo_wr_en,
    Wr_data     => pack(w_fifo_wr_data),
    Almost_full => open,
    Full        => w_fifo_full,

    Rd_en       => Pdw_ready,
    Rd_data     => w_fifo_rd_data,
    Empty       => w_fifo_empty,

    Overflow    => w_fifo_overflow,
    Underflow   => open --okay to underflow
  );

  Pdw_data  <= unpack(w_fifo_rd_data);
  Pdw_valid <= not(w_fifo_empty);

  w_buffer_next_start <= to_stdlogic(r1_context.state = S_IDLE) and Dwell_active and r1_new_detect;

  i_sample_buffer : entity esm_lib.esm_pdw_sample_buffer
  generic map (
    DATA_WIDTH        => IQ_WIDTH,
    SAMPLES_PER_FRAME => BUFFERED_SAMPLES_PER_FRAME
  )
  port map (
    Clk                 => Clk,
    Rst                 => r_rst,

    Buffer_full         => w_buffer_full,
    Buffer_next_index   => w_buffer_next_index,
    Buffer_next_start   => w_buffer_next_start,

    Input_valid         => r1_context.recording_active,
    Input_frame_index   => r1_context.recording_frame_index,
    Input_sample_index  => r1_context.recording_sample_index,
    Input_data          => r1_input_iq,

    Output_frame_req    => Buffered_frame_req,
    Output_frame_ack    => Buffered_frame_ack,
    Output_sample_data  => Buffered_frame_data,

    Error_underflow     => w_sample_buffer_underflow,
    Error_overflow      => w_sample_buffer_overflow
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_fifo_overflow     <= w_fifo_overflow;
      Error_buffer_underflow  <= w_sample_buffer_underflow;
      Error_buffer_overflow   <= w_sample_buffer_overflow;
    end if;
  end process;

end architecture rtl;
