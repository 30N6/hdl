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
  SYNC_LATENCY : natural
);
port (
  Clk                     : in  std_logic;
  Rst                     : in  std_logic;

  Tx_instruction_valid    : in  std_logic;
  Tx_instruction_index    : in  unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
  Tx_instruction_data     : in  std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0);

  Tx_program_req_valid    : out std_logic;
  Tx_program_req_channel  : out unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  Tx_program_req_index    : out unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);

  Dwell_channel_clear     : in  std_logic;
  Dwell_active_transmit   : in  std_logic;

  Sync_data               : in  channelizer_control_t;

  Drfm_read_req           : out ecm_drfm_read_req_t;  --TODO
  Dds_control             : out dds_control_t;  --TODO
  Output_control          : out ecm_output_control_t  --TODO
);
begin
  -- PSL default clock is rising_edge(Clk);
  -- PSL channel_clear : assert always (rose(Dwell_channel_clear) = '1') -> next_a![0..ECM_NUM_CHANNELS] (Dwell_channel_clear = '1');
end entity ecm_dwell_tx_engine;

architecture rtl of ecm_dwell_tx_engine is

  type channel_program_state_t is (S_IDLE, S_DECODE, S_EXECUTE, S_COMPLETE);

  type channel_state_t is record
    program_state     : channel_program_state_t;
    instruction_index : unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
    wait_count        : unsigned(ECM_TX_INSTRUCTION_WAIT_DURATION_WIDTH - 1 downto 0);
    loop_count        : unsigned(ECM_TX_INSTRUCTION_LOOP_COUNTER_WIDTH - 1 downto 0);
    playback_count    : unsigned(ECM_TX_INSTRUCTION_PLAYBACK_COUNTER_WIDTH - 1 downto 0);
  end record;

  type instruction_data_array_t is array (natural range <>) of std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0);
  type channel_state_array_t    is array (natural range <>) of channel_state_t;

  signal m_instruction_data             : instruction_data_array_t(ECM_NUM_TX_INSTRUCTIONS - 1 downto 0);
  signal m_channel_state                : channel_state_array_t(ECM_NUM_CHANNELS - 1 downto 0);

  signal r0_sync_data                   : channelizer_control_t;
  signal r0_channel_state               : channel_state_t;

  signal r1_sync_data                   : channelizer_control_t;
  signal r1_channel_state               : channel_state_t;

  signal r2_sync_data                   : channelizer_control_t;
  signal r2_channel_state               : channel_state_t;
  signal r2_instruction_data            : std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0);

  signal r3_sync_data                   : channelizer_control_t;
  signal r3_channel_state               : channel_state_t;
  signal r3_instruction_data            : std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0);
  signal w3_instruction_header          : ecm_tx_instruction_header_t;
  signal w3_instruction_dds_setup_bpsk  : ecm_tx_instruction_dds_setup_bpsk_t;
  signal w3_instruction_dds_setup_sweep : ecm_tx_instruction_dds_setup_cw_sweep_t;
  signal w3_instruction_dds_setup_step  : ecm_tx_instruction_dds_setup_cw_step_t;
  signal w3_instruction_playback        : ecm_tx_instruction_playback_t;
  signal w3_instruction_wait            : ecm_tx_instruction_wait_t;
  signal w3_instruction_jump            : ecm_tx_instruction_jump_t;

  signal r4_sync_data                   : channelizer_control_t;
  signal r4_channel_state               : channel_state_t;
  signal r4_instruction_data            : std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0);


  signal r_tx_program_req_valid         : std_logic;
  signal r_tx_program_req_channel       : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r_tx_program_req_data          : channel_state_t;

  signal r_channel_clear_index          : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal w_channel_state_wr_data        : channel_state_t;
  signal w_channel_state_wr_index       : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_channel_state_wr_en          : std_logic;

  signal w_error_program_req_overflow   : std_logic;



  signal r0_channelizer_ctrl            : channelizer_control_t;
  signal r0_channelizer_data            : signed_array_t(1 downto 0)(CHANNELIZER_DATA_WIDTH - 1 downto 0);
  signal r0_channelizer_pwr             : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r0_channel_control             : ecm_channel_control_entry_t;
  signal r0_channel_state               : channel_state_t;

  signal r1_channelizer_ctrl            : channelizer_control_t;
  signal r1_channelizer_data            : signed_array_t(1 downto 0)(CHANNELIZER_DATA_WIDTH - 1 downto 0);
  signal r1_channelizer_pwr             : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r1_channel_control             : ecm_channel_control_entry_t;
  signal r1_channel_state               : channel_state_t;

  signal r2_channelizer_ctrl            : channelizer_control_t;
  signal r2_channelizer_data            : signed_array_t(1 downto 0)(CHANNELIZER_DATA_WIDTH - 1 downto 0);
  signal r2_channelizer_pwr             : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r2_channel_control             : ecm_channel_control_entry_t;
  signal r2_channel_state               : channel_state_t;
  signal r2_trigger_is_forced           : std_logic;
  signal r2_trigger_is_threshold        : std_logic;
  signal r2_threshold_check_new         : std_logic;
  signal r2_threshold_check_cont        : std_logic;
  signal r2_duration_finished           : std_logic;
  signal r2_duration_next               : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  signal r2_address_next                : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);

  signal r3_channel_control             : ecm_channel_control_entry_t;
  signal r3_channel_state_wr_en         : std_logic;
  signal r3_channel_state_wr_index      : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r3_channel_state_wr_data       : channel_state_t;
  signal r3_drfm_write_req              : ecm_drfm_write_req_t;
  signal r3_trigger_check_duration_min  : std_logic_vector(ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES - 1 downto 0);
  signal r3_trigger_check_duration_max  : std_logic_vector(ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES - 1 downto 0);
  signal r3_trigger_pending             : std_logic;

  signal r4_tx_program_req_valid        : std_logic;
  signal r4_tx_program_req_channel      : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r4_tx_program_req_index        : unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);

  signal r_trigger_pending              : std_logic_vector(ECM_NUM_CHANNELS - 1 downto 0);



begin

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
      r2_instruction_data <= m_instruction_data(to_integer(r1_channel_state.instruction_index));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_sync_data        <= r2_sync_data;
      r3_channel_state    <= r2_channel_state;
      r3_instruction_data <= r2_instruction_data;
    end if;
  end process;

  w3_instruction_header          <= unpack(r3_instruction_data(ECM_TX_INSTRUCTION_HEADER_PACKED_WIDTH - 1 downto 0));
  w3_instruction_dds_setup_bpsk  <= unpack(r3_instruction_data);
  w3_instruction_dds_setup_sweep <= unpack(r3_instruction_data);
  w3_instruction_dds_setup_step  <= unpack(r3_instruction_data);
  w3_instruction_playback        <= unpack(r3_instruction_data);
  w3_instruction_wait            <= unpack(r3_instruction_data);
  w3_instruction_jump            <= unpack(r3_instruction_data);

  process(Clk)
  begin
    if rising_edge(Clk) then
      r4_sync_data        <= r3_sync_data;
      r4_channel_state    <= r3_channel_state;
      r4_instruction_data <= r3_instruction_data;



    end if;
  end process;

  --TODO: add stretcher to channelizer?

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_tx_program_req_valid    <= '0';
        r_tx_program_req_channel  <= (others => '-');
        r_tx_program_req_data     <= (program_state => S_IDLE, others => '-');
      else
        if (Tx_program_req_valid = '1') then
          r_tx_program_req_valid    <= '1';
          r_tx_program_req_channel  <= Tx_program_req_channel;
          r_tx_program_req_data     <= (program_state => S_DECODE, instruction_index => Tx_program_req_index, others => (others => '0'));
        elsif (r3_channel_state_wr_en = '0') then
          r_tx_program_req_valid    <= '0';
          r_tx_program_req_channel  <= (others => '-');
          r_tx_program_req_data     <= (program_state => S_IDLE, others => '-');
        end if;
      end if;
    end if;
  end process;

  w_error_program_req_overflow <= Tx_program_req_valid and r_tx_program_req_valid and r3_channel_state_wr_en;

  process(all)
  begin
    if (Dwell_channel_clear = '1') then
      w_channel_state_wr_data   <= (program_state => S_IDLE, others => (others => '-'));
      w_channel_state_wr_index  <= r_channel_clear_index;
      w_channel_state_wr_en     <= '1';
    elsif (r3_channel_state_wr_en = '1') then
      w_channel_state_wr_data   <= r3_channel_state_wr_data;
      w_channel_state_wr_index  <= r3_channel_state_wr_index;
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
        m_channel_state(to_integer(w_channel_state_wr_index)) <= w_channel_state_wr_data;
      end if;
    end if;
  end process;


  process(Clk)
  begin
    if rising_edge(Clk) then
      r2_channelizer_ctrl       <= r1_channelizer_ctrl;
      r2_channelizer_data       <= r1_channelizer_data;
      r2_channelizer_pwr        <= r1_channelizer_pwr;
      r2_channel_control        <= r1_channel_control;
      r2_channel_state          <= r1_channel_state;

      r2_trigger_is_forced      <= Dwell_active_measurement and r1_channel_control.enable and to_stdlogic(r1_channel_control.trigger_mode = ECM_CHANNEL_TRIGGER_MODE_FORCE_TRIGGER);
      r2_trigger_is_threshold   <= Dwell_active_measurement and r1_channel_control.enable and to_stdlogic(r1_channel_control.trigger_mode = ECM_CHANNEL_TRIGGER_MODE_THRESHOLD_TRIGGER);
      r2_threshold_check_new    <= to_stdlogic(r1_channelizer_pwr >= r1_channel_control.trigger_threshold);
      r2_threshold_check_cont   <= to_stdlogic(r1_channelizer_pwr >= r1_channel_state.continued_threshold);
      r2_duration_finished      <= to_stdlogic(r1_channel_state.recording_length = r1_channel_state.trigger_duration_max_minus_one);
      r2_duration_next          <= r1_channel_state.recording_length + 1;
      r2_address_next           <= r1_channel_state.recording_address + 1;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r3_channel_control              <= r2_channel_control;
      r3_channel_state_wr_en          <= '0';
      r3_channel_state_wr_index       <= r2_channelizer_ctrl.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
      r3_channel_state_wr_data        <= r2_channel_state;

      r3_drfm_write_req.valid         <= '0';
      r3_drfm_write_req.first         <= '-';
      r3_drfm_write_req.last          <= '-';
      r3_drfm_write_req.address       <= (others => '-');
      r3_drfm_write_req.channel_index <= r2_channelizer_ctrl.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
      r3_drfm_write_req.data          <= r2_channelizer_data;

      if (r2_channel_state.trigger_state = S_IDLE) then
        if ((r2_trigger_is_forced = '1') or ((r2_trigger_is_threshold = '1') and (r2_threshold_check_new = '1'))) then
          r3_channel_state_wr_en                        <= '1';
          r3_channel_state_wr_data.trigger_state        <= S_ACTIVE;
          r3_channel_state_wr_data.continued_threshold  <= shift_right(r1_channel_control.trigger_threshold, r1_channel_control.trigger_hyst_shift);
          r3_channel_state_wr_data.recording_length     <= to_unsigned(1, ECM_DRFM_SEGMENT_LENGTH_WIDTH);
          r3_channel_state_wr_data.recording_address    <= r2_channel_control.recording_address;

          r3_drfm_write_req.valid                       <= r2_channelizer_ctrl.valid;
          r3_drfm_write_req.first                       <= '1';
          r3_drfm_write_req.last                        <= '0';
          r3_drfm_write_req.address                     <= r2_channel_control.recording_address;
        end if;
      elsif (r2_channel_state.trigger_state = S_ACTIVE)
        r3_channel_state_wr_en                          <= r2_channelizer_ctrl.valid;
        r3_channel_state_wr_data.recording_length       <= r2_duration_next;
        r3_channel_state_wr_data.recording_address      <= r2_address_next;

        r3_drfm_write_req.valid                         <= r2_channelizer_ctrl.valid;
        r3_drfm_write_req.first                         <= '0';
        r3_drfm_write_req.address                       <= r2_address_next;

        if (r2_trigger_is_forced = '1') then
          if (r2_duration_finished = '1') then
            r3_channel_state_wr_data.trigger_state      <= S_COMPLETE;
            r3_drfm_write_req.last                      <= '1';
          end if;
        elsif (r2_trigger_is_threshold = '1') then
          if ((r2_duration_finished = '1') or (r2_threshold_check_cont = '0')) then
            r3_channel_state_wr_data.trigger_state      <= S_COMPLETE;
            r3_drfm_write_req.last                      <= '1';
          end if;
        else
          r3_channel_state_wr_data.trigger_state        <= S_COMPLETE;
          r3_drfm_write_req.last                        <= '1';
        end if;
      end if;

      for i in 0 to (ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES - 1) loop
        r3_trigger_check_duration_min(i) <= to_stdlogic((r2_channel_state.trigger_state = S_ACTIVE) and (r2_channel_state.recording_length >= r2_channel_control.program_entries(i).duration_gate_min));
        r3_trigger_check_duration_max(i) <= to_stdlogic((r2_channel_state.trigger_state = S_ACTIVE) and (r2_channel_state.recording_length <= r2_channel_control.program_entries(i).duration_gate_max));
      end loop;

      r3_trigger_pending <= r_trigger_pending(to_integer(r2_channelizer_ctrl.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0)));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r4_tx_program_req_valid   <= '0';
      r4_tx_program_req_channel <= r3_channel_state_wr_index;
      r4_tx_program_req_index   <= (others => '-');
      r4_trigger_immediate      <= '0';

      if ((r3_channel_state_wr_en = '1') and (r3_trigger_pending = '0')) then
        if (r3_channel_state_wr_data.trigger_state = S_ACTIVE) then

          for i in 0 to (ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES - 1) loop
            if ((r3_channel_control.program_entries(i).valid = '1') and (r3_channel_control.program_entries(i).trigger_immediate_after_min = '1') and (r3_trigger_check_duration_min(i) = '1')) then
              r4_trigger_immediate    <= '1';
              r4_tx_program_req_valid <= '1';
              r3_tx_program_req_index <= r3_channel_control.program_entries(i).tx_program_index;
              exit;
            end if;
          end loop;

        elsif (r3_channel_state_wr_data.trigger_state = S_COMPLETE) then

          for i in 0 to (ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES - 1) loop
            if ((r3_channel_control.program_entries(i).valid = '1') and (r3_trigger_check_duration_min(i) = '1') and (r3_trigger_check_duration_max(i) = '1')) then
              r4_trigger_immediate    <= '1';
              r4_tx_program_req_valid <= '1';
              r3_tx_program_req_index <= r3_channel_control.program_entries(i).tx_program_index;
              exit;
            end if;
          end loop;

        end if;
      end if;

    end if;
  end process;

  Dwell_immediate_tx      <= r4_trigger_immediate;
  Tx_program_req_valid    <= r4_tx_program_req_valid;
  Tx_program_req_channel  <= r4_tx_program_req_channel;
  Tx_program_req_index    <= r3_tx_program_req_index;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_channel_clear_index <= r_channel_clear_index + 1;
    end if;
  end process;

  process(all)
  begin
    if (Dwell_channel_clear = '1') then
      w_channel_state_wr_data   <= (trigger_state => S_IDLE, others => (others => '-'));
      w_channel_state_wr_index  <= r_channel_clear_index;
      w_channel_state_wr_en     <= '1';
    else
      w_channel_state_wr_data   <= r3_channel_state_wr_data;
      w_channel_state_wr_index  <= r3_channel_state_wr_index;
      w_channel_state_wr_en     <= r3_channel_state_wr_en;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (w_channel_state_wr_en = '1') then
        m_channel_state(to_integer(w_channel_state_wr_index)) <= w_channel_state_wr_data;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      for i in 0 to (ECM_NUM_CHANNELS - 1) loop
        if (Dwell_start_measurement = '1') then
          r_trigger_pending(i) <= '0';
        elsif ((w_channel_state_wr_en = '1') and (w_channel_state_wr_index = i) and (w_channel_state_wr_data.trigger_state /= S_IDLE)) then
          r_trigger_pending(i) <= '1';
        end if;
      end loop;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      Trigger_pending <= or_reduce(r_trigger_pending);
    end if;
  end process;

end architecture rtl;
