library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity ecm_dwell_tx_engine is
generic (
  SYNC_TO_DRFM_READ_LATENCY : natural
);
port (
  Clk                     : in  std_logic;
  Rst                     : in  std_logic;

  Tx_instruction_valid    : in  std_logic;
  Tx_instruction_index    : in  unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
  Tx_instruction_data     : in  std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0);

  Tx_program_req_valid    : in  std_logic;
  Tx_program_req_channel  : in  unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  Tx_program_req_index    : in  unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
  Drfm_write_req          : in  ecm_drfm_write_req_t;

  Dwell_channel_clear     : in  std_logic;
  Dwell_transmit_active   : in  std_logic;
  Dwell_transmit_done     : out std_logic;

  Sync_data               : in  channelizer_control_t;

  Drfm_read_req           : out ecm_drfm_read_req_t;
  Dds_control             : out dds_control_t;
  Output_control          : out ecm_output_control_t
);
begin
  -- PSL default clock is rising_edge(Clk);
  -- PSL channel_clear : assert always (rose(Dwell_channel_clear)) -> next_a![0 to ECM_NUM_CHANNELS] (Dwell_channel_clear = '1');
end entity ecm_dwell_tx_engine;

architecture rtl of ecm_dwell_tx_engine is

  type channel_program_state_t is (S_IDLE, S_DECODE, S_EXECUTE);

  type channel_state_t is record
    program_state       : channel_program_state_t;
    instruction_index   : unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
    wait_count          : unsigned(ECM_TX_INSTRUCTION_WAIT_DURATION_WIDTH - 1 downto 0);
    loop_count          : unsigned(ECM_TX_INSTRUCTION_LOOP_COUNTER_WIDTH - 1 downto 0);
    playback_count      : unsigned(ECM_TX_INSTRUCTION_PLAYBACK_COUNTER_WIDTH - 1 downto 0);
    playback_addr_curr  : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
    playback_addr_first : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
    playback_addr_last  : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  end record;

  type drfm_state_t is record
    valid : std_logic;
    addr  : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  end record;

  type instruction_data_array_t is array (natural range <>) of std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0);
  type channel_state_array_t    is array (natural range <>) of channel_state_t;
  type drfm_state_array_t       is array (natural range <>) of drfm_state_t;

  constant DDS_CONTROL_CLEAR            : dds_control_t := (valid => '0', channel_index => (others => '-'),
                                                            setup_data => (dds_sin_phase_inc_select => '0', dds_output_select => (others => '0')),
                                                            control_type => (others => '0'), control_data => (others => '0'));
  constant OUTPUT_CONTROL_CLEAR         : ecm_output_control_t := (valid => '0', channel_index => (others => '-'), control => (others => '0'));

  signal w_rand                         : unsigned(31 downto 0);

  signal m_instruction_data             : instruction_data_array_t(ECM_NUM_TX_INSTRUCTIONS - 1 downto 0);
  signal m_channel_state                : channel_state_array_t(ECM_NUM_CHANNELS - 1 downto 0);
  signal m_drfm_state_first             : drfm_state_array_t(ECM_NUM_CHANNELS - 1 downto 0);
  signal m_drfm_state_last              : drfm_state_array_t(ECM_NUM_CHANNELS - 1 downto 0);

  signal r0_sync_data                   : channelizer_control_t;
  signal r0_channel_state               : channel_state_t;

  signal r1_sync_data                   : channelizer_control_t;
  signal r1_channel_state               : channel_state_t;

  signal r2_sync_data                   : channelizer_control_t;
  signal r2_channel_state               : channel_state_t;
  signal r2_drfm_state_first            : drfm_state_t;
  signal r2_drfm_state_last             : drfm_state_t;
  signal r2_instruction_data            : std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0);

  signal r3_sync_data                   : channelizer_control_t;
  signal r3_channel_state               : channel_state_t;
  signal r3_drfm_state_first            : drfm_state_t;
  signal r3_drfm_state_last             : drfm_state_t;
  signal r3_instruction_data            : std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0);
  signal r3_segment_done                : std_logic;
  signal r3_instruction_index_next      : unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
  signal r3_wait_count_next             : unsigned(ECM_TX_INSTRUCTION_WAIT_DURATION_WIDTH - 1 downto 0);
  signal r3_loop_count_next             : unsigned(ECM_TX_INSTRUCTION_LOOP_COUNTER_WIDTH - 1 downto 0);
  signal r3_playback_count_next         : unsigned(ECM_TX_INSTRUCTION_PLAYBACK_COUNTER_WIDTH - 1 downto 0);
  signal r3_playback_addr_next          : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  signal r3_wait_done                   : std_logic;
  signal r3_playback_done               : std_logic;
  signal w3_instruction_header          : ecm_tx_instruction_header_t;
  signal w3_instruction_playback        : ecm_tx_instruction_playback_t;
  signal w3_instruction_wait            : ecm_tx_instruction_wait_t;
  signal w3_instruction_jump            : ecm_tx_instruction_jump_t;

  signal r4_sync_data                   : channelizer_control_t;
  signal r4_channel_state               : channel_state_t;
  signal r4_drfm_read_req               : ecm_drfm_read_req_t;
  signal r4_dds_control                 : dds_control_t;
  signal r4_output_control              : ecm_output_control_t;

  signal r_tx_program_req_valid         : std_logic;
  signal r_tx_program_req_channel       : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_tx_program_req_data          : channel_state_t;

  signal r_channel_clear_index          : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal w_channel_state_wr_data        : channel_state_t;
  signal w_channel_state_wr_index       : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_channel_state_wr_en          : std_logic;

  signal r_drfm_write_req               : ecm_drfm_write_req_t;
  signal w_drfm_state_wr_data           : drfm_state_t;
  signal w_drfm_state_wr_index          : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_drfm_state_wr_en_first       : std_logic;
  signal w_drfm_state_wr_en_last        : std_logic;

  signal r_transmit_pending             : std_logic_vector(ECM_NUM_CHANNELS - 1 downto 0);

  signal w_error_program_req_overflow   : std_logic;

begin

  assert (SYNC_TO_DRFM_READ_LATENCY = 5)
    report "SYNC_TO_DRFM_READ_LATENCY expected to be 5."
    severity failure;

  i_rand : entity common_lib.xorshift_32
  port map (
    Clk     => Clk,
    Rst     => Rst,

    Output  => w_rand
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Tx_instruction_valid = '1') then
        m_instruction_data(to_integer(Tx_instruction_index)) <= Tx_instruction_data;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_sync_data      <= Sync_data;
      r0_channel_state  <= m_channel_state(to_integer(Sync_data.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0)));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_sync_data      <= r0_sync_data;
      r1_channel_state  <= r0_channel_state;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_sync_data        <= r1_sync_data;
      r2_channel_state    <= r1_channel_state;
      r2_drfm_state_first <= m_drfm_state_first(to_integer(r1_sync_data.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0)));
      r2_drfm_state_last  <= m_drfm_state_last(to_integer(r1_sync_data.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0)));
      r2_instruction_data <= m_instruction_data(to_integer(r1_channel_state.instruction_index));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_sync_data              <= r2_sync_data;
      r3_channel_state          <= r2_channel_state;
      r3_instruction_data       <= r2_instruction_data;
      r3_drfm_state_first       <= r2_drfm_state_first;
      r3_drfm_state_last        <= r2_drfm_state_last;
      r3_segment_done           <= to_stdlogic(r2_channel_state.playback_addr_curr = r2_channel_state.playback_addr_last);

      r3_instruction_index_next <= r2_channel_state.instruction_index + 1;
      r3_wait_count_next        <= r2_channel_state.wait_count - 1;
      r3_loop_count_next        <= r2_channel_state.loop_count + 1;
      r3_playback_count_next    <= r2_channel_state.playback_count - 1;
      r3_wait_done              <= to_stdlogic(r2_channel_state.wait_count <= 1);
      r3_playback_done          <= to_stdlogic(r2_channel_state.playback_count <= 1);

      if (r2_channel_state.playback_addr_curr = r2_channel_state.playback_addr_last) then
        r3_playback_addr_next   <= r2_channel_state.playback_addr_first;
      else
        r3_playback_addr_next   <= r2_channel_state.playback_addr_curr + 1;
      end if;
    end if;
  end process;

  w3_instruction_header   <= unpack(r3_instruction_data(ECM_TX_INSTRUCTION_HEADER_PACKED_WIDTH - 1 downto 0));
  w3_instruction_playback <= unpack(r3_instruction_data);
  w3_instruction_wait     <= unpack(r3_instruction_data);
  w3_instruction_jump     <= unpack(r3_instruction_data);

  process(Clk)
  begin
    if rising_edge(Clk) then
      r4_sync_data                    <= r3_sync_data;
      r4_channel_state                <= r3_channel_state;

      r4_drfm_read_req.valid          <= r3_sync_data.valid and to_stdlogic((r3_channel_state.program_state = S_EXECUTE) and
                                                                            (w3_instruction_header.instruction_type = ECM_TX_INSTRUCTION_TYPE_PLAYBACK));
      r4_drfm_read_req.address        <= r3_channel_state.playback_addr_curr;
      r4_drfm_read_req.channel_index  <= r3_sync_data.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
      r4_drfm_read_req.channel_last   <= r3_sync_data.last;

      r4_dds_control                  <= DDS_CONTROL_CLEAR;
      r4_dds_control.channel_index    <= resize_up(r3_sync_data.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0), r4_dds_control.channel_index'length);
      r4_dds_control.control_data     <= r3_instruction_data(ECM_TX_INSTRUCTION_HEADER_PACKED_WIDTH + DDS_CONTROL_ENTRY_PACKED_WIDTH - 1 downto ECM_TX_INSTRUCTION_HEADER_PACKED_WIDTH);

      r4_output_control               <= OUTPUT_CONTROL_CLEAR;
      r4_output_control.channel_index <= r3_sync_data.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);

      if (Dwell_transmit_active = '0') then
        r4_dds_control.valid                        <= '1';
        r4_dds_control.setup_data.dds_output_select <= "00";
        r4_output_control.valid                     <= '1';
        r4_output_control.control                   <= to_unsigned(ECM_TX_OUTPUT_CONTROL_DISABLED, ECM_TX_OUTPUT_CONTROL_WIDTH);
      elsif (r3_channel_state.program_state = S_DECODE) then
        if (w3_instruction_header.valid = '0') then
          r4_channel_state.program_state              <= S_IDLE;
          r4_dds_control.valid                        <= '1';
          r4_dds_control.setup_data.dds_output_select <= "00";
          r4_output_control.valid                     <= '1';
          r4_output_control.control                   <= to_unsigned(ECM_TX_OUTPUT_CONTROL_DISABLED, ECM_TX_OUTPUT_CONTROL_WIDTH);
        else
          r4_dds_control.valid                        <= '1';
          r4_dds_control.setup_data                   <= w3_instruction_header.dds_control;
          r4_output_control.valid                     <= '1';
          r4_output_control.control                   <= w3_instruction_header.output_control;

          r4_channel_state.instruction_index          <= r3_instruction_index_next;
          r4_channel_state.wait_count                 <= (others => '0');
          r4_channel_state.playback_count             <= (others => '0');
          r4_channel_state.playback_addr_curr         <= r3_drfm_state_first.addr;
          r4_channel_state.playback_addr_first        <= r3_drfm_state_first.addr;
          r4_channel_state.playback_addr_last         <= r3_drfm_state_last.addr;

          if (w3_instruction_header.instruction_type = ECM_TX_INSTRUCTION_TYPE_DDS_SETUP_BPSK) then
            r4_dds_control.control_type               <= to_unsigned(DDS_CONTROL_TYPE_LFSR, DDS_CONTROL_TYPE_WIDTH);
          elsif (w3_instruction_header.instruction_type = ECM_TX_INSTRUCTION_TYPE_DDS_SETUP_CW_SWEEP) then
            r4_dds_control.control_type               <= to_unsigned(DDS_CONTROL_TYPE_SIN_SWEEP, DDS_CONTROL_TYPE_WIDTH);
          elsif (w3_instruction_header.instruction_type = ECM_TX_INSTRUCTION_TYPE_DDS_SETUP_CW_STEP) then
            r4_dds_control.control_type               <= to_unsigned(DDS_CONTROL_TYPE_SIN_STEP, DDS_CONTROL_TYPE_WIDTH);
          elsif (w3_instruction_header.instruction_type = ECM_TX_INSTRUCTION_TYPE_PLAYBACK) then
            r4_channel_state.program_state            <= S_EXECUTE;
            r4_channel_state.instruction_index        <= r3_channel_state.instruction_index;
            r4_channel_state.playback_count           <= w3_instruction_playback.base_count + (w3_instruction_playback.rand_offset_mask and w_rand(ECM_TX_INSTRUCTION_PLAYBACK_COUNTER_WIDTH - 1 downto 0));
          elsif (w3_instruction_header.instruction_type = ECM_TX_INSTRUCTION_TYPE_WAIT) then
            r4_channel_state.program_state            <= S_EXECUTE;
            r4_channel_state.instruction_index        <= r3_channel_state.instruction_index;
            r4_channel_state.wait_count               <= w3_instruction_wait.base_duration + (w3_instruction_wait.rand_offset_mask and w_rand(ECM_TX_INSTRUCTION_WAIT_DURATION_WIDTH - 1 downto 0));
          elsif (w3_instruction_header.instruction_type = ECM_TX_INSTRUCTION_TYPE_JUMP) then
            r4_channel_state.loop_count               <= r3_loop_count_next;
            if ((w3_instruction_jump.counter_check = '0') or (r3_channel_state.loop_count /= w3_instruction_jump.counter_value)) then
              r4_channel_state.instruction_index      <= w3_instruction_jump.dest_index;
            end if;
          end if;
        end if;
      elsif(r3_channel_state.program_state = S_EXECUTE) then

        r4_channel_state.playback_addr_curr           <= r3_playback_addr_next;

        if (w3_instruction_header.instruction_type = ECM_TX_INSTRUCTION_TYPE_PLAYBACK) then
          if ((w3_instruction_playback.mode = '1') or (r3_segment_done = '1')) then
            r4_channel_state.playback_count           <= r3_playback_count_next;

            if (r3_playback_done = '1') then
              r4_channel_state.program_state          <= S_DECODE;
              r4_channel_state.instruction_index      <= r3_instruction_index_next;
            end if;
          end if;
        elsif (w3_instruction_header.instruction_type = ECM_TX_INSTRUCTION_TYPE_WAIT) then
          r4_channel_state.wait_count                 <= r3_wait_count_next;

          if (r3_wait_done = '1') then
            r4_channel_state.program_state            <= S_DECODE;
            r4_channel_state.instruction_index        <= r3_instruction_index_next;
          end if;
        else
          r4_channel_state.program_state              <= S_IDLE;
          r4_dds_control.valid                        <= '1';
          r4_dds_control.setup_data.dds_output_select <= "00";
          r4_output_control.valid                     <= '1';
          r4_output_control.control                   <= to_unsigned(ECM_TX_OUTPUT_CONTROL_DISABLED, ECM_TX_OUTPUT_CONTROL_WIDTH);
        end if;

      end if;

    end if;
  end process;

  Drfm_read_req   <= r4_drfm_read_req;
  Dds_control     <= r4_dds_control;
  Output_control  <= r4_output_control;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_drfm_write_req <= Drfm_write_req;
    end if;
  end process;

  process(all)
  begin
    if (Dwell_channel_clear = '1') then
      w_drfm_state_wr_data        <= (valid => '0', addr => (others => '-'));
      w_drfm_state_wr_index       <= r_channel_clear_index;
      w_drfm_state_wr_en_first    <= '1';
      w_drfm_state_wr_en_last     <= '1';
    else
      w_drfm_state_wr_data.valid  <= '1';
      w_drfm_state_wr_data.addr   <= r_drfm_write_req.address;
      w_drfm_state_wr_index       <= r_drfm_write_req.channel_index;
      w_drfm_state_wr_en_first    <= r_drfm_write_req.valid and r_drfm_write_req.first;
      w_drfm_state_wr_en_last     <= r_drfm_write_req.valid and r_drfm_write_req.last;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_drfm_state_wr_en_first = '1') then
        m_drfm_state_first(to_integer(w_drfm_state_wr_index)) <= w_drfm_state_wr_data;
      end if;
      if (w_drfm_state_wr_en_last = '1') then
        m_drfm_state_last(to_integer(w_drfm_state_wr_index)) <= w_drfm_state_wr_data;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_tx_program_req_valid    <= '0';
        r_tx_program_req_channel  <= (others => '-');
        r_tx_program_req_data     <= (program_state => S_IDLE, others => (others => '-'));
      else
        if (Tx_program_req_valid = '1') then
          r_tx_program_req_valid    <= '1';
          r_tx_program_req_channel  <= Tx_program_req_channel;
          r_tx_program_req_data     <= (program_state => S_DECODE, instruction_index => Tx_program_req_index, others => (others => '0'));
        elsif (r4_sync_data.valid = '0') then
          r_tx_program_req_valid    <= '0';
          r_tx_program_req_channel  <= (others => '-');
          r_tx_program_req_data     <= (program_state => S_IDLE, others => (others => '-'));
        end if;
      end if;
    end if;
  end process;

  w_error_program_req_overflow <= Tx_program_req_valid and r_tx_program_req_valid and r4_sync_data.valid;

  process(all)
  begin
    if (Dwell_channel_clear = '1') then
      w_channel_state_wr_data   <= (program_state => S_IDLE, others => (others => '-'));
      w_channel_state_wr_index  <= r_channel_clear_index;
      w_channel_state_wr_en     <= '1';
    elsif (r4_sync_data.valid = '1') then
      w_channel_state_wr_data   <= r4_channel_state;
      w_channel_state_wr_index  <= r4_sync_data.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
      w_channel_state_wr_en     <= '1';
    else
      w_channel_state_wr_data   <= r_tx_program_req_data;
      w_channel_state_wr_index  <= r_tx_program_req_channel;
      w_channel_state_wr_en     <= r_tx_program_req_valid;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_channel_state_wr_en = '1') then
        m_channel_state(to_integer(w_channel_state_wr_index))     <= w_channel_state_wr_data;
        r_transmit_pending(to_integer(w_channel_state_wr_index))  <= to_stdlogic(w_channel_state_wr_data.program_state /= S_IDLE);
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Dwell_transmit_done <= not(or_reduce(r_transmit_pending));
    end if;
  end process;

end architecture rtl;
