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
  use esm_lib.esm_debug_pkg.all;

entity esm_pdw_sample_processor is
generic (
  CHANNEL_INDEX_WIDTH         : natural;
  DATA_WIDTH                  : natural;
  BUFFERED_SAMPLES_PER_FRAME  : natural;
  BUFFERED_SAMPLE_PADDING     : natural;
  PDW_FIFO_DEPTH              : natural;
  DEBUG_ENABLE                : boolean
);
port (
  Clk                     : in  std_logic;
  Rst                     : in  std_logic;

  Debug_out               : out esm_pdw_sample_processor_debug_t;

  Timestamp               : in  unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);

  Dwell_active            : in  std_logic;
  Dwell_done              : in  std_logic;
  Dwell_ack               : out std_logic;

  Thresh_override_channel : out unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  Thresh_override_valid   : out std_logic;
  Thresh_override_wr_en   : out std_logic;

  Input_ctrl              : in  channelizer_control_t;
  Input_iq_delayed        : in  signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  Input_power             : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  Input_threshold_value   : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  Input_threshold_valid   : in  std_logic;

  Pdw_ready               : in  std_logic;
  Pdw_valid               : out std_logic;
  Pdw_data                : out esm_pdw_fifo_data_t;

  Buffered_frame_req      : in  esm_pdw_sample_buffer_req_t;
  Buffered_frame_ack      : out esm_pdw_sample_buffer_ack_t;
  Buffered_frame_data     : out signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);

  Error_fifo_busy         : out std_logic;
  Error_fifo_overflow     : out std_logic;
  Error_fifo_underflow    : out std_logic;
  Error_buffer_busy       : out std_logic;
  Error_buffer_underflow  : out std_logic;
  Error_buffer_overflow   : out std_logic
);
begin
  -- PSL default clock is rising_edge(Clk);
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
    pulse_seq_num             : unsigned(ESM_PDW_SEQUENCE_NUM_WIDTH - 1 downto 0);
    threshold                 : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
    power_accum_a             : unsigned(ESM_PDW_POWER_ACCUM_WIDTH - 16 - 1 downto 0);
    power_accum_ac            : std_logic;
    power_accum_b             : unsigned(15 downto 0);
    duration                  : unsigned(ESM_PDW_CYCLE_COUNT_WIDTH - 1 downto 0);
    recording_skipped         : std_logic;
    recording_active          : std_logic;
    recording_frame_index     : unsigned(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
    recording_sample_index    : unsigned(ESM_PDW_SAMPLE_BUFFER_SAMPLE_INDEX_WIDTH - 1 downto 0);
    recording_sample_padding  : unsigned(SAMPLE_PADDING_INDEX - 1 downto 0);
    ts_start                  : unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);
  end record;

  type channel_context_array_t is array (natural range <>) of channel_context_t;

  signal r_reset_index              : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0) := (others => '0');

  signal m_channel_context          : channel_context_array_t(2**CHANNEL_INDEX_WIDTH - 1 downto 0);

  signal r0_input_ctrl              : channelizer_control_t;
  signal r0_input_iq                : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r0_input_power             : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r0_input_threshold_value   : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r0_input_threshold_valid   : std_logic;
  signal r0_context                 : channel_context_t;

  signal r1_input_ctrl              : channelizer_control_t;
  signal r1_input_iq                : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r1_input_power             : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r1_input_threshold_value   : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r1_input_threshold_valid   : std_logic;
  signal r1_context                 : channel_context_t;

  signal r2_input_ctrl              : channelizer_control_t;
  signal r2_input_iq                : signed_array_t(1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal r2_input_power             : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r2_input_threshold_value   : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r2_context                 : channel_context_t;
  signal r2_new_detect              : std_logic;
  signal r2_continued_detect        : std_logic;
  signal r2_seq_num_next            : unsigned(ESM_PDW_SEQUENCE_NUM_WIDTH - 1 downto 0);

  signal r3_input_ctrl              : channelizer_control_t;
  signal r3_context                 : channel_context_t;
  signal r3_context_wr_index        : unsigned(CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r3_context_wr_valid        : std_logic;
  signal r3_pulse_seq_num           : unsigned(ESM_PDW_SEQUENCE_NUM_WIDTH - 1 downto 0);

  signal r3_update_power            : std_logic;
  signal r3_new_power_accum_a       : unsigned(ESM_PDW_POWER_ACCUM_WIDTH - 16 - 1 downto 0);
  signal r3_new_power_accum_ac      : std_logic;
  signal r3_new_power_accum_b       : unsigned(15 downto 0);

  signal w3_context                 : channel_context_t;
  signal w3_power_accum_b           : unsigned(15 downto 0);

  signal w_buffer_empty             : std_logic;
  signal w_buffer_full              : std_logic;
  signal w_buffer_next_index        : unsigned(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
  signal w_buffer_next_start        : std_logic;
  signal w_buffer_wr_en             : std_logic;

  signal w_pending_fifo_wr_en       : std_logic;
  signal w_pending_fifo_full        : std_logic;
  signal w_pending_fifo_rd_en       : std_logic;
  signal w_pending_fifo_empty       : std_logic;

  signal w_fifo_full                : std_logic;
  signal r_fifo_wr_data             : esm_pdw_fifo_data_t;
  signal r_fifo_wr_en               : std_logic;
  signal w_fifo_empty               : std_logic;
  signal w_fifo_rd_data             : std_logic_vector(ESM_PDW_FIFO_DATA_WIDTH - 1 downto 0);

  signal r_dwell_ack_pending        : std_logic;
  signal r_dwell_active             : std_logic;

  signal w_pending_fifo_busy        : std_logic;
  signal w_pending_fifo_overflow    : std_logic;
  signal w_pending_fifo_underflow   : std_logic;
  signal w_fifo_overflow            : std_logic;
  signal w_sample_buffer_busy       : std_logic;
  signal w_sample_buffer_overflow   : std_logic;
  signal w_sample_buffer_underflow  : std_logic;

begin

  g_debug : if (DEBUG_ENABLE) generate
    Debug_out.w_buffer_empty                      <= w_buffer_empty;
    Debug_out.w_buffer_full                       <= w_buffer_full;
    Debug_out.w_buffer_next_index                 <= std_logic_vector(w_buffer_next_index);
    Debug_out.w_buffer_next_start                 <= w_buffer_next_start;
    Debug_out.w_buffer_wr_en                      <= w_buffer_wr_en;
    Debug_out.w_pending_fifo_wr_en                <= w_pending_fifo_wr_en;
    Debug_out.w_pending_fifo_full                 <= w_pending_fifo_full;
    Debug_out.w_pending_fifo_rd_en                <= w_pending_fifo_rd_en;
    Debug_out.w_pending_fifo_empty                <= w_pending_fifo_empty;
    Debug_out.w_fifo_full                         <= w_fifo_full;
    Debug_out.r_fifo_wr_en                        <= r_fifo_wr_en;
    Debug_out.r_fifo_wr_data_channel              <= std_logic_vector(r_fifo_wr_data.channel);
    Debug_out.w_fifo_empty                        <= w_fifo_empty;
    Debug_out.r2_context_state                    <= "00" when (r2_context.state = S_IDLE) else
                                                     "01" when (r2_context.state = S_ACTIVE) else
                                                     "10" when (r2_context.state = S_PAD_RECORDING) else
                                                     "11";
    Debug_out.r2_context_pulse_seq_num            <= std_logic_vector(r2_context.pulse_seq_num);
    Debug_out.r2_context_power_accum_a            <= std_logic_vector(r2_context.power_accum_a);
    Debug_out.r2_context_duration                 <= std_logic_vector(r2_context.duration);
    Debug_out.r2_context_recording_skipped        <= r2_context.recording_skipped;
    Debug_out.r2_context_recording_active         <= r2_context.recording_active;
    Debug_out.r2_context_recording_frame_index    <= std_logic_vector(r2_context.recording_frame_index);
    Debug_out.r2_context_recording_sample_index   <= std_logic_vector(r2_context.recording_sample_index);
    Debug_out.r2_context_recording_sample_padding <= std_logic_vector(r2_context.recording_sample_padding);
    Debug_out.r2_input_ctrl_valid                 <= r2_input_ctrl.valid;
    Debug_out.r2_input_ctrl_last                  <= r2_input_ctrl.last;
    Debug_out.r2_input_ctrl_index                 <= std_logic_vector(r2_input_ctrl.data_index);
    Debug_out.r2_input_i                          <= std_logic_vector(r2_input_iq(0));
    Debug_out.r2_input_q                          <= std_logic_vector(r2_input_iq(1));
    Debug_out.r2_input_power                      <= std_logic_vector(r2_input_power);
    Debug_out.r2_new_detect                       <= r2_new_detect;
    Debug_out.r2_continued_detect                 <= r2_continued_detect;
  end generate g_debug;

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
      r0_input_ctrl             <= Input_ctrl;
      r0_input_iq               <= Input_iq_delayed;
      r0_input_power            <= Input_power;
      r0_input_threshold_value  <= Input_threshold_value;
      r0_input_threshold_valid  <= Input_threshold_valid;
      r0_context                <= m_channel_context(to_integer(Input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0)));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_input_ctrl             <= r0_input_ctrl;
      r1_input_iq               <= r0_input_iq;
      r1_input_power            <= r0_input_power;
      r1_input_threshold_value  <= r0_input_threshold_value;
      r1_input_threshold_valid  <= r0_input_threshold_valid;
      r1_context                <= r0_context;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_input_ctrl             <= r1_input_ctrl;
      r2_input_iq               <= r1_input_iq;
      r2_input_power            <= r1_input_power;
      r2_input_threshold_value  <= r1_input_threshold_value;
      r2_context                <= r1_context;
      r2_new_detect             <= to_stdlogic(r1_input_power > r1_input_threshold_value) and r1_input_threshold_valid;
      r2_continued_detect       <= to_stdlogic(r1_input_power > shift_right(r1_context.threshold, 1)); -- reduce threshold by 3 dB after pulse has started
      r2_seq_num_next           <= r1_context.pulse_seq_num + 1;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_input_ctrl     <= r2_input_ctrl;
      r3_context        <= r2_context;
      r3_pulse_seq_num  <= r2_context.pulse_seq_num;

      r3_update_power                               <= r2_continued_detect and to_stdlogic(r2_context.state = S_ACTIVE);
      (r3_new_power_accum_ac, r3_new_power_accum_a) <= ('0' & r2_context.power_accum_a) + r2_input_power; --TODO: clamp
      r3_new_power_accum_b                          <= r2_context.power_accum_b + unsigned'('0' & r2_context.power_accum_ac);

      case r2_context.state is
      when S_IDLE =>
        r3_context.threshold                <= r2_input_threshold_value;
        r3_context.power_accum_a            <= resize_up(r2_input_power, ESM_PDW_POWER_ACCUM_WIDTH - 16);
        r3_context.power_accum_ac           <= '0';
        r3_context.power_accum_b            <= (others => '0');
        r3_context.duration                 <= (0 => '1', others => '0');
        r3_context.recording_skipped        <= '0';
        r3_context.recording_active         <= '0';
        r3_context.recording_frame_index    <= (others => '-');
        r3_context.recording_sample_index   <= (others => '0');
        r3_context.recording_sample_padding <= (others => '0');
        r3_context.ts_start                 <= Timestamp;

        if ((Dwell_active = '1') and (r2_new_detect = '1') and (w_pending_fifo_full = '0')) then
          r3_context.state                  <= S_ACTIVE;
          r3_context.recording_skipped      <= w_buffer_full;
          r3_context.recording_active       <= not(w_buffer_full);
          r3_context.recording_frame_index  <= w_buffer_next_index;
        end if;

      when S_ACTIVE =>

        if (r2_continued_detect = '1') then
          r3_context.duration <= r2_context.duration + 1; --TODO: clamp
        end if;

        if (r2_context.recording_active = '1') then
          if (r2_context.recording_sample_index = (BUFFERED_SAMPLES_PER_FRAME - 1)) then
            r3_context.recording_active <= '0';
          else
            r3_context.recording_sample_index <= r2_context.recording_sample_index + 1;
          end if;
        end if;

        if ((Dwell_active = '0') or (r2_continued_detect = '0')) then
          if ((r2_context.recording_active = '0') or (r2_context.recording_sample_index = (BUFFERED_SAMPLES_PER_FRAME - 1))) then
            r3_context.state <= S_STORE_REPORT;
          else
            r3_context.state <= S_PAD_RECORDING;
          end if;
        end if;

      when S_PAD_RECORDING =>
        if (r2_context.recording_active = '1') then
          if ((r2_context.recording_sample_padding = (BUFFERED_SAMPLE_PADDING - 1)) or (r2_context.recording_sample_index = (BUFFERED_SAMPLES_PER_FRAME - 1))) then
            r3_context.recording_active         <= '0';
            r3_context.state                    <= S_STORE_REPORT;
          else
            r3_context.recording_sample_padding <= r2_context.recording_sample_padding + 1;
            r3_context.recording_sample_index   <= r2_context.recording_sample_index + 1;
          end if;
        else
          r3_context.state <= S_STORE_REPORT;
        end if;

      when S_STORE_REPORT =>
        r3_context.state          <= S_IDLE;
        r3_context.pulse_seq_num  <= r2_seq_num_next;

      end case;

      if (Rst = '1') then
        r3_context_wr_index       <= r_reset_index;
        r3_context_wr_valid       <= '1';
        r3_context.state          <= S_IDLE;
        r3_context.pulse_seq_num  <= (others => '0');
      else
        r3_context_wr_index <= r2_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0);
        r3_context_wr_valid <= r2_input_ctrl.valid;
      end if;
    end if;
  end process;

  process(all)
  begin
    w3_context <= r3_context;

    if (r3_update_power = '1') then
      w3_context.power_accum_a  <= r3_new_power_accum_a;
      w3_context.power_accum_ac <= r3_new_power_accum_ac;
      w3_context.power_accum_b  <= r3_new_power_accum_b;
    else
      w3_context.power_accum_a  <= r3_context.power_accum_a;
      w3_context.power_accum_ac <= r3_context.power_accum_ac;
      w3_context.power_accum_b  <= r3_context.power_accum_b;
    end if;
  end process;

  w3_power_accum_b <= r3_context.power_accum_b + unsigned'('0' & r3_context.power_accum_ac);

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r3_context_wr_valid = '1') then
        m_channel_context(to_integer(r3_context_wr_index)) <= w3_context;
      end if;
    end if;
  end process;

  Thresh_override_channel <= r3_context_wr_index;
  Thresh_override_valid   <= to_stdlogic(w3_context.state = S_ACTIVE);
  Thresh_override_wr_en   <= r3_context_wr_valid;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_fifo_wr_en                        <= r3_context_wr_valid and to_stdlogic(r3_context.state = S_STORE_REPORT);
      r_fifo_wr_data.sequence_num         <= r3_pulse_seq_num;
      r_fifo_wr_data.channel              <= resize_up(r3_input_ctrl.data_index(CHANNEL_INDEX_WIDTH - 1 downto 0), ESM_CHANNEL_INDEX_WIDTH);
      r_fifo_wr_data.power_accum          <= w3_power_accum_b & r3_context.power_accum_a;
      r_fifo_wr_data.power_threshold      <= r3_context.threshold;
      r_fifo_wr_data.duration             <= r3_context.duration;
      r_fifo_wr_data.frequency            <= (others => '0');
      r_fifo_wr_data.pulse_start_time     <= r3_context.ts_start;
      r_fifo_wr_data.buffered_frame_index <= r3_context.recording_frame_index;
      r_fifo_wr_data.buffered_frame_valid <= not(r3_context.recording_skipped);
    end if;
  end process;

  w_pending_fifo_wr_en <= r2_input_ctrl.valid and to_stdlogic(r2_context.state = S_IDLE) and Dwell_active and r2_new_detect and not(w_pending_fifo_full);
  w_pending_fifo_rd_en <= Pdw_ready and not(w_fifo_empty);

  i_pdw_pending_fifo : entity mem_lib.xpm_fallthough_fifo
  generic map (
    FIFO_DEPTH  => PDW_FIFO_DEPTH,
    FIFO_WIDTH  => 1
  )
  port map (
    Clk         => Clk,
    Rst         => Rst,

    Wr_en       => w_pending_fifo_wr_en,
    Wr_data     => (others => '0'),
    Almost_full => open,
    Full        => w_pending_fifo_full,

    Rd_en       => w_pending_fifo_rd_en,
    Rd_data     => open,
    Empty       => w_pending_fifo_empty,

    Overflow    => w_pending_fifo_overflow,
    Underflow   => w_pending_fifo_underflow
  );

  i_pdw_data_fifo : entity mem_lib.xpm_fallthough_fifo
  generic map (
    FIFO_DEPTH  => PDW_FIFO_DEPTH,
    FIFO_WIDTH  => ESM_PDW_FIFO_DATA_WIDTH
  )
  port map (
    Clk         => Clk,
    Rst         => Rst,

    Wr_en       => r_fifo_wr_en,
    Wr_data     => pack(r_fifo_wr_data),
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

  -- PSL assert always (w_pending_fifo_wr_en = '1') -> eventually! (r_fifo_wr_en = '1');
  -- PSL assert always (w_pending_fifo_full = '1') -> eventually! (w_fifo_full = '1');
  -- PSL assert always (w_fifo_full = '1') -> (w_pending_fifo_full = '1');
  -- PSL assert always rose(w_pending_fifo_empty) -> rose(w_fifo_empty);

  w_buffer_wr_en       <= r2_input_ctrl.valid and r2_context.recording_active;
  w_buffer_next_start  <= w_pending_fifo_wr_en and not(w_buffer_full);

  i_sample_buffer : entity esm_lib.esm_pdw_sample_buffer
  generic map (
    DATA_WIDTH        => DATA_WIDTH,
    SAMPLES_PER_FRAME => BUFFERED_SAMPLES_PER_FRAME
  )
  port map (
    Clk                 => Clk,
    Rst                 => Rst,

    Buffer_empty        => w_buffer_empty,
    Buffer_full         => w_buffer_full,
    Buffer_next_index   => w_buffer_next_index,
    Buffer_next_start   => w_buffer_next_start,

    Input_valid         => w_buffer_wr_en,
    Input_frame_index   => r2_context.recording_frame_index,
    Input_sample_index  => r2_context.recording_sample_index,
    Input_data          => r2_input_iq,

    Output_frame_req    => Buffered_frame_req,
    Output_frame_ack    => Buffered_frame_ack,
    Output_sample_data  => Buffered_frame_data,

    Error_underflow     => w_sample_buffer_underflow,
    Error_overflow      => w_sample_buffer_overflow
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Dwell_active = '1') then
        r_dwell_ack_pending <= '0';
      elsif (Dwell_done = '1') then
        r_dwell_ack_pending <= '1';
      end if;

      Dwell_ack <= r_dwell_ack_pending and w_pending_fifo_empty and w_buffer_empty;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_dwell_active <= Dwell_active;
    end if;
  end process;

  w_pending_fifo_busy  <= Dwell_active and not(r_dwell_active) and not(w_pending_fifo_empty);
  w_sample_buffer_busy <= Dwell_active and not(r_dwell_active) and not(w_buffer_empty);

  process(Clk)
  begin
    if rising_edge(Clk) then
      Error_fifo_busy         <= w_pending_fifo_busy;
      Error_fifo_overflow     <= w_fifo_overflow or w_pending_fifo_overflow;
      Error_fifo_underflow    <= w_pending_fifo_underflow;
      Error_buffer_busy       <= w_sample_buffer_busy;
      Error_buffer_underflow  <= w_sample_buffer_underflow;
      Error_buffer_overflow   <= w_sample_buffer_overflow;
    end if;
  end process;

end architecture rtl;
