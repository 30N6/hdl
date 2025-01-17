library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

package ecm_pkg is


  constant ECM_CONTROL_MAGIC_NUM                        : std_logic_vector(31 downto 0) := x"45434D43";
  constant ECM_REPORT_MAGIC_NUM                         : std_logic_vector(31 downto 0) := x"45434D52";

  constant ECM_MODULE_ID_WIDTH                          : natural := 8;
  constant ECM_MODULE_ID_CONTROL                        : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0) := x"00";
  constant ECM_MODULE_ID_DWELL_CONTROLLER               : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0) := x"01";
  constant ECM_MODULE_ID_DWELL_STATS                    : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0) := x"02";
  constant ECM_MODULE_ID_DRFM                           : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0) := x"05";
  constant ECM_MODULE_ID_STATUS                         : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0) := x"06";

  constant ECM_MESSAGE_TYPE_WIDTH                       : natural := 8;
  constant ECM_CONTROL_MESSAGE_TYPE_ENABLE              : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"00";
  constant ECM_CONTROL_MESSAGE_TYPE_DWELL_ENTRY         : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"01";
  constant ECM_CONTROL_MESSAGE_TYPE_DWELL_PROGRAM       : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"02";
  constant ECM_CONTROL_MESSAGE_TYPE_CHANNEL_CONTROL     : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"03";
  constant ECM_CONTROL_MESSAGE_TYPE_TX_INSTRUCTION      : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"03";
  constant ECM_REPORT_MESSAGE_TYPE_DWELL_STATS          : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"10";
  constant ECM_REPORT_MESSAGE_TYPE_DRFM_CHANNEL_DATA    : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"20";
  constant ECM_REPORT_MESSAGE_TYPE_DRFM_SUMMARY         : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"21";
  constant ECM_REPORT_MESSAGE_TYPE_STATUS               : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"30";

  constant ECM_NUM_CHANNELS                           : natural := 16;
  constant ECM_CHANNEL_INDEX_WIDTH                    : natural := clog2(ECM_NUM_CHANNELS);

  constant ECM_TX_INSTRUCTION_TYPE_NOP                : natural := 0;
  constant ECM_TX_INSTRUCTION_TYPE_DDS_SETUP_BPSK     : natural := 1;
  constant ECM_TX_INSTRUCTION_TYPE_DDS_SETUP_CW_SWEEP : natural := 2;
  constant ECM_TX_INSTRUCTION_TYPE_DDS_SETUP_CW_STEP  : natural := 3;
  constant ECM_TX_INSTRUCTION_TYPE_PLAYBACK           : natural := 4;
  constant ECM_TX_INSTRUCTION_TYPE_WAIT               : natural := 5;
  constant ECM_TX_INSTRUCTION_TYPE_JUMP               : natural := 6;
  constant ECM_TX_INSTRUCTION_TYPE_WIDTH              : natural := 4;

  constant ECM_TX_OUTPUT_CONTROL_DISABLED             : natural := 0;
  constant ECM_TX_OUTPUT_CONTROL_DDS                  : natural := 1;
  constant ECM_TX_OUTPUT_CONTROL_DRFM                 : natural := 2;
  constant ECM_TX_OUTPUT_CONTROL_MIXER                : natural := 3;
  constant ECM_TX_OUTPUT_CONTROL_WIDTH                : natural := 2;

  constant ECM_NUM_TX_INSTRUCTIONS                    : natural := 512;
  constant ECM_TX_INSTRUCTION_INDEX_WIDTH             : natural := clog2(ECM_NUM_TX_INSTRUCTIONS);
  constant ECM_TX_INSTRUCTION_LOOP_COUNTER_WIDTH      : natural := 16;
  constant ECM_TX_INSTRUCTION_WAIT_DURATION_WIDTH     : natural := 20;
  constant ECM_TX_INSTRUCTION_PLAYBACK_COUNTER_WIDTH  : natural := 16;

  constant ECM_NUM_FAST_LOCK_PROFILES                 : natural := 8;
  constant ECM_FAST_LOCK_PROFILE_INDEX_WIDTH          : natural := clog2(ECM_NUM_FAST_LOCK_PROFILES);

  constant ECM_NUM_DWELL_ENTRIES                      : natural := 16;
  constant ECM_DWELL_ENTRY_INDEX_WIDTH                : natural := clog2(ECM_NUM_DWELL_ENTRIES);
  constant ECM_NUM_CHANNEL_CONTROL_ENTRIES            : natural := ECM_NUM_CHANNELS * ECM_NUM_DWELL_ENTRIES;

  constant ECM_CHANNEL_TX_MODE_NONE                   : natural := 0;
  constant ECM_CHANNEL_TX_MODE_NOISE_ONLY             : natural := 1;
  constant ECM_CHANNEL_TX_MODE_FORCE_TRIGGER          : natural := 2;
  constant ECM_CHANNEL_TX_MODE_THRESHOLD_TRIGGER      : natural := 3;
  constant ECM_CHANNEL_TX_MODE_WIDTH                  : natural := 2;
  constant ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES         : natural := 4;

  constant ECM_DRFM_SEGMENT_SEQUENCE_NUM_WIDTH        : natural := 32;
  constant ECM_DRFM_SEGMENT_LENGTH_WIDTH              : natural := 16;  --TODO: shrink?
  constant ECM_DRFM_SEGMENT_SLICE_LENGTH_WIDTH        : natural := 8;
  constant ECM_CHANNEL_TRIGGER_PARAMETER_WIDTH        : natural := maximum(ECM_DRFM_SEGMENT_LENGTH_WIDTH, CHAN_POWER_WIDTH);

  constant ECM_DWELL_DURATION_WIDTH                   : natural := 32;
  constant ECM_DWELL_SEQUENCE_NUM_WIDTH               : natural := 32;
  constant ECM_DWELL_REPEAT_COUNT_WIDTH               : natural := 4;
  constant ECM_DWELL_TAG_WIDTH                        : natural := 16;
  constant ECM_DWELL_FREQUENCY_WIDTH                  : natural := 16;
  constant ECM_DWELL_GLOBAL_COUNTER_WIDTH             : natural := 16;

  type ecm_tx_instruction_header_t is record
    valid               : std_logic;
    instruction_type    : unsigned(ECM_TX_INSTRUCTION_TYPE_WIDTH - 1 downto 0);
    channel_index       : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);   --TODO: remove? or use for error checking?
    output_control      : unsigned(ECM_TX_OUTPUT_CONTROL_WIDTH - 1 downto 0);
    dds_control         : dds_control_setup_entry_t;
  end record;

  type ecm_tx_instruction_dds_setup_bpsk_t is record
    header              : ecm_tx_instruction_header_t;
    dds_bpsk_setup      : dds_control_lfsr_entry_t;
  end record;

  type ecm_tx_instruction_dds_setup_cw_sweep_t is record
    header              : ecm_tx_instruction_header_t;
    dds_cw_sweep_setup  : dds_control_sin_sweep_entry_t;
  end record;

  type ecm_tx_instruction_dds_setup_cw_step_t is record
    header              : ecm_tx_instruction_header_t;
    dds_cw_step_setup   : dds_control_sin_step_entry_t;
  end record;

  type ecm_tx_instruction_playback_t is record
    header              : ecm_tx_instruction_header_t;
    mode                : std_logic; -- 0=segment count, 1=cycle count
    base_count          : unsigned(ECM_TX_INSTRUCTION_PLAYBACK_COUNTER_WIDTH - 1 downto 0);
    rand_offset_mask    : unsigned(ECM_TX_INSTRUCTION_PLAYBACK_COUNTER_WIDTH - 1 downto 0);
  end record;

  type ecm_tx_instruction_wait_t is record
    header              : ecm_tx_instruction_header_t;
    base_duration       : unsigned(ECM_TX_INSTRUCTION_WAIT_DURATION_WIDTH - 1 downto 0);
    rand_offset_mask    : unsigned(ECM_TX_INSTRUCTION_WAIT_DURATION_WIDTH - 1 downto 0);
  end record;

  type ecm_tx_instruction_jump_t is record
    header              : ecm_tx_instruction_header_t;
    dest_index          : unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
    counter_check       : std_logic;
    counter_value       : unsigned(ECM_TX_INSTRUCTION_LOOP_COUNTER_WIDTH - 1 downto 0);
  end record;

  type ecm_channel_tx_program_entry_t is record
    valid                 : std_logic;
    tx_program_index      : unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
    trigger_duration_min  : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
    trigger_duration_max  : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  end record;

  type ecm_channel_tx_program_entry_array_t is array (natural range <>) of ecm_channel_tx_program_entry_t;

  type ecm_channel_control_entry_t is record
    enable                : std_logic;
    tx_mode               : unsigned(ECM_CHANNEL_TX_MODE_WIDTH - 1 downto 0);
    trigger_parameter     : unsigned(ECM_CHANNEL_TRIGGER_PARAMETER_WIDTH - 1 downto 0); -- force trigger duration, or power threshold (rising + falling)
    program_entries       : ecm_channel_tx_program_entry_array_t(ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES - 1 downto 0);
  end record;

  type ecm_dwell_entry_t is record
    valid                     : std_logic;
    global_counter_check      : std_logic;
    global_counter_dec        : std_logic;
    skip_pll_prelock_wait     : std_logic;
    skip_pll_lock_check       : std_logic;
    skip_pll_postlock_wait    : std_logic;
    repeat_count              : unsigned(ECM_DWELL_REPEAT_COUNT_WIDTH - 1 downto 0);

    tag                       : unsigned(ECM_DWELL_TAG_WIDTH - 1 downto 0);
    frequency                 : unsigned(ECM_DWELL_FREQUENCY_WIDTH - 1 downto 0);
    measurement_duration      : unsigned(ECM_DWELL_DURATION_WIDTH - 1 downto 0);
    total_duration_max        : unsigned(ECM_DWELL_DURATION_WIDTH - 1 downto 0);
    fast_lock_profile         : unsigned(ECM_FAST_LOCK_PROFILE_INDEX_WIDTH - 1 downto 0);

    next_dwell_index          : unsigned(ECM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
  end record;

  type ecm_dwell_program_entry_t is record
    enable                    : std_logic;
    global_counter_init       : unsigned(ECM_DWELL_GLOBAL_COUNTER_WIDTH - 1 downto 0);
    initial_dwell_index       : unsigned(ECM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
  end record;

  type ecm_hardware_control_entry_t is record
    reset                     : std_logic;
    enable_channelizer        : std_logic;
    enable_synthesizer        : std_logic;
  end record;

  --type ecm_common_header_t is record
  --  magic_num                 : std_logic_vector(31 downto 0);
  --  sequence_num              : unsigned(31 downto 0);
  --  module_id                 : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0);
  --  message_type              : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0);
  --  address                   : unsigned(15 downto 0);
  --end record;

  --type ecm_report_dwell_stats_t is record
  --  dwell_entry               : ecm_dwell_entry_t;
  --  dwell_sequence_num        : unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  --  measurement_duration      : unsigned(31 downto 0);
  --  full_duration             : unsigned(31 downto 0);
  --  ts_dwell_start            : unsigned(63 downto 0);
  --  ts_dwell_end              : unsigned(63 downto 0);
  --
  --  -- array of 128? bit entries: num_samples, accum, max, padding? --TODO: update
  --end record;

  --type ecm_report_drfm_channel_data_t record
  --  dwell_sequence_num        : unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  --  segment_sequence_num      : unsigned(ECM_DRFM_SEGMENT_SEQUENCE_NUM_WIDTH - 1 downto 0);
  --  channel_index             : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  --  segment_timestamp         : unsigned(63 downto 0);
  --  segment_duration          : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  --  slice_start               : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  --  slice_length              : unsigned(ECM_DRFM_SEGMENT_SLICE_LENGTH_WIDTH - 1 downto 0);
  --
  --  iq_data : array of N 32-bit entries
  --end record;

  --type ecm_report_drfm_summary_t record
  --  dwell_sequence_num        : unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  --
  --  channel entry array: triggered flag, recorded flag, tx program index
  --end record;


  function unpack(v : std_logic_vector) return ecm_tx_instruction_header_t;
  function unpack(v : std_logic_vector) return ecm_tx_instruction_dds_setup_bpsk_t;
  function unpack(v : std_logic_vector) return ecm_tx_instruction_dds_setup_cw_sweep_t;
  function unpack(v : std_logic_vector) return ecm_tx_instruction_dds_setup_cw_step_t;
  function unpack(v : std_logic_vector) return ecm_tx_instruction_playback_t;
  function unpack(v : std_logic_vector) return ecm_tx_instruction_wait_t;
  function unpack(v : std_logic_vector) return ecm_tx_instruction_jump_t;


end package ecm_pkg;

package body ecm_pkg is


  --function unpack(v : std_logic_vector) return dds_control_sin_step_entry_t is
  --  variable vm : std_logic_vector(v'length - 1 downto 0);
  --  variable r  : dds_control_sin_step_entry_t;
  --begin
  --  assert (v'length = DDS_CONTROL_SIN_STEP_ENTRY_PACKED_WIDTH)
  --    report "Unexpected length"
  --    severity failure;
  --  vm := v;
  --
  --  r.sin_step_phase_inc_min              := signed(vm(15 downto 0));
  --  r.sin_step_phase_inc_rand_offset_mask := unsigned(vm(30 downto 16));
  --  r.sin_step_period_minus_one           := unsigned(vm(47 downto 32));
  --
  --  return r;
  --end function;


end package body ecm_pkg;
