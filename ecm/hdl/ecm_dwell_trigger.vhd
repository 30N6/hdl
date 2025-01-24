library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity ecm_dwell_trigger is
generic (
  CHANNELIZER_DATA_WIDTH  : natural;
);
port (
  Clk                         : in  std_logic;
  Rst                         : in  std_logic;

  Channel_entry_valid         : in  std_logic;
  Channel_entry_index         : in  unsigned(ECM_DWELL_CHANNEL_CONTROL_ENTRY_INDEX_WIDTH - 1 downto 0);
  Channel_entry_data          : in  ecm_channel_control_entry_t;

  Channelizer_ctrl            : in  channelizer_control_t;
  Channelizer_data            : in  signed_array_t(1 downto 0)(CHANNELIZER_DATA_WIDTH - 1 downto 0);
  Channelizer_pwr             : in  unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Dwell_channel_clear         : in  std_logic;
  Dwell_start_measurement     : in  std_logic;
  Dwell_active_measurement    : in  std_logic;
  Dwell_data                  : in  ecm_dwell_entry_t;
  Dwell_index                 : in  unsigned(ECM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
  Dwell_immediate_tx          : out std_logic;  --TODO

  Trigger_pending             : out std_logic;

  Tx_program_req_valid        : out std_logic;
  Tx_program_req_channel      : out unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  Tx_program_req_index        : out unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);

  Drfm_write_req              : out ecm_drfm_write_req_t
);
end entity ecm_dwell_trigger;

architecture rtl of ecm_dwell_trigger is

  type channel_trigger_state_t is (S_IDLE, S_ACTIVE, S_COMPLETE);

  type channel_state_t is record
    trigger_state       : channel_trigger_state_t;
    continued_threshold : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
    recording_length    : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
    recording_address   : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  end record;

  type channel_state_array_t is array (natural range <>) of channel_state_t;

  signal m_channel_control            : ecm_channel_control_entry_array_t(ECM_NUM_CHANNEL_CONTROL_ENTRIES - 1 downto 0);
  signal m_channel_state              : channel_state_array_t(ECM_NUM_CHANNELS - 1 downto 0);

  signal w_channel_control_rd_index   : unsigned(ECM_DWELL_CHANNEL_CONTROL_ENTRY_INDEX_WIDTH - 1 downto 0);
  signal w_channel_state_rd_index     : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);

  signal r0_channelizer_ctrl          : channelizer_control_t;
  signal r0_channelizer_data          : signed_array_t(1 downto 0)(CHANNELIZER_DATA_WIDTH - 1 downto 0);
  signal r0_channelizer_pwr           : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r0_channel_control           : ecm_channel_control_entry_t;
  signal r0_channel_state             : channel_state_t;

  signal r1_channelizer_ctrl          : channelizer_control_t;
  signal r1_channelizer_data          : signed_array_t(1 downto 0)(CHANNELIZER_DATA_WIDTH - 1 downto 0);
  signal r1_channelizer_pwr           : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r1_channel_control           : ecm_channel_control_entry_t;
  signal r1_channel_state             : channel_state_t;

  signal r2_channelizer_ctrl          : channelizer_control_t;
  signal r2_channelizer_data          : signed_array_t(1 downto 0)(CHANNELIZER_DATA_WIDTH - 1 downto 0);
  signal r2_channelizer_pwr           : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
  signal r2_channel_control           : ecm_channel_control_entry_t;
  signal r2_channel_state             : channel_state_t;

  signal r2_trigger_valid             : std_logic;
  signal r2_trigger_is_noise_only     : std_logic;
  signal r2_trigger_is_forced         : std_logic;
  signal r2_trigger_is_threshold      : std_logic;
  signal r2_threshold_check_new       : std_logic;
  signal r2_threshold_check_cont      : std_logic;
  signal r2_duration_finished         : std_logic;
  signal r2_duration_next             : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  signal r2_address_next              : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);

  signal r3_channel_state_wr_en       : std_logic;
  signal r3_channel_state_wr_index    : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal r3_channel_state_wr_data     : channel_state_t;
  signal r3_drfm_write_req            : ecm_drfm_write_req_t;

  signal r_trigger_pending            : std_logic_vector(ECM_NUM_CHANNELS - 1 downto 0);

  signal r_channel_clear_index        : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0) := (others => '0');
  signal w_channel_state_wr_data      : channel_state_t;
  signal w_channel_state_wr_index     : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  signal w_channel_state_wr_en        : std_logic;


begin

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Channel_entry_valid = '1') then
        m_channel_control(to_integer(Channel_entry_index)) <= Channel_entry_data;
      end if;
    end if;
  end process;

  w_channel_control_rd_index  <= Dwell_index & Channelizer_ctrl.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  w_channel_state_rd_index    <= Channelizer_ctrl.data_index(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);

  process(Clk)
  begin
    if rising_edge(Clk) then
      r0_channelizer_ctrl <= Channelizer_ctrl;
      r0_channelizer_data <= Channelizer_data;
      r0_channelizer_pwr  <= Channelizer_pwr;
      r0_channel_control  <= m_channel_control(to_integer(w_channel_control_rd_index));
      r0_channel_state    <= m_channel_state(to_integer(w_channel_state_rd_index));
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r1_channelizer_ctrl <= r0_channelizer_ctrl;
      r1_channelizer_data <= r0_channelizer_data;
      r1_channelizer_pwr  <= r0_channelizer_pwr;
      r1_channel_control  <= r0_channel_control;
      r1_channel_state    <= r0_channel_state;
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

      r2_trigger_is_noise_only  <= Dwell_active_measurement and r1_channel_control.enable and to_stdlogic(r1_channel_control.trigger_mode = ECM_CHANNEL_TRIGGER_MODE_NOISE_ONLY);
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
      r2_channelizer_ctrl       <= r0_channelizer_ctrl;
      r2_channelizer_data       <= r0_channelizer_data;
      r2_channelizer_pwr        <= r0_channelizer_pwr;
      r2_channel_control        <= r0_channel_control;
      r2_channel_state          <= r0_channel_state;

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
        if (r2_trigger_is_noise_only = '1') then
          r3_channel_state_wr_en                        <= '1';
          r3_channel_state_wr_data.trigger_state        <= S_COMPLETE;
          r3_channel_state_wr_data.recording_length     <= (others => '0');
        elsif ((r2_trigger_is_forced = '1') or ((r2_trigger_is_threshold = '1') and (r2_threshold_check_new = '1'))) then
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
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      --check immediate triggers

      --check at the end of each trigger
      if ((r3_channel_state_wr_en = '1') and (r3_channel_state_wr_data.trigger_state = S_COMPLETE)) then

      end if;
    end if;
  end process;

  --Tx_program_req_valid        : out std_logic;
  --Tx_program_req_channel      : out unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  --Tx_program_req_index        : out unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);


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
