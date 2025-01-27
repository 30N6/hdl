library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

package ecm_pkg is

  constant ECM_WORDS_PER_DMA_PACKET                       : natural := 128;

  constant ECM_CONTROL_MAGIC_NUM                          : std_logic_vector(31 downto 0) := x"45434D43";
  constant ECM_REPORT_MAGIC_NUM                           : std_logic_vector(31 downto 0) := x"45434D52";

  constant ECM_MODULE_ID_WIDTH                            : natural := 8;
  constant ECM_MODULE_ID_CONTROL                          : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0) := x"00";
  constant ECM_MODULE_ID_DWELL_CONTROLLER                 : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0) := x"01";
  constant ECM_MODULE_ID_DWELL_STATS                      : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0) := x"02";
  constant ECM_MODULE_ID_DRFM                             : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0) := x"05";
  constant ECM_MODULE_ID_STATUS                           : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0) := x"06";

  constant ECM_MESSAGE_TYPE_WIDTH                         : natural := 8;
  constant ECM_CONTROL_MESSAGE_TYPE_ENABLE                : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"00";
  constant ECM_CONTROL_MESSAGE_TYPE_DWELL_PROGRAM         : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"01";
  constant ECM_CONTROL_MESSAGE_TYPE_DWELL_ENTRY           : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"02";
  constant ECM_CONTROL_MESSAGE_TYPE_DWELL_CHANNEL_CONTROL : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"03";
  constant ECM_CONTROL_MESSAGE_TYPE_DWELL_TX_INSTRUCTION  : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"04";
  constant ECM_REPORT_MESSAGE_TYPE_DWELL_STATS            : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"10";
  constant ECM_REPORT_MESSAGE_TYPE_DRFM_CHANNEL_DATA      : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"20";
  constant ECM_REPORT_MESSAGE_TYPE_DRFM_SUMMARY           : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"21";
  constant ECM_REPORT_MESSAGE_TYPE_STATUS                 : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"30";

  constant ECM_CONFIG_ADDRESS_WIDTH                       : natural := 16;

  constant ECM_NUM_CHANNELS                               : natural := 16;
  constant ECM_CHANNEL_INDEX_WIDTH                        : natural := clog2(ECM_NUM_CHANNELS);

  constant ECM_NUM_TX_INSTRUCTIONS                        : natural := 512; --TODO: increase?
  constant ECM_TX_INSTRUCTION_INDEX_WIDTH                 : natural := clog2(ECM_NUM_TX_INSTRUCTIONS);
  constant ECM_TX_INSTRUCTION_LOOP_COUNTER_WIDTH          : natural := 16;
  constant ECM_TX_INSTRUCTION_WAIT_DURATION_WIDTH         : natural := 20;
  constant ECM_TX_INSTRUCTION_PLAYBACK_COUNTER_WIDTH      : natural := 16;
  constant ECM_TX_INSTRUCTION_DATA_WIDTH                  : natural := 64;

  constant ECM_TX_INSTRUCTION_TYPE_NOP                    : natural := 0;
  constant ECM_TX_INSTRUCTION_TYPE_DDS_SETUP_BPSK         : natural := 1;
  constant ECM_TX_INSTRUCTION_TYPE_DDS_SETUP_CW_SWEEP     : natural := 2;
  constant ECM_TX_INSTRUCTION_TYPE_DDS_SETUP_CW_STEP      : natural := 3;
  constant ECM_TX_INSTRUCTION_TYPE_PLAYBACK               : natural := 4;
  constant ECM_TX_INSTRUCTION_TYPE_WAIT                   : natural := 5;
  constant ECM_TX_INSTRUCTION_TYPE_JUMP                   : natural := 6;
  constant ECM_TX_INSTRUCTION_TYPE_WIDTH                  : natural := 3;

  constant ECM_TX_OUTPUT_CONTROL_DISABLED                 : natural := 0;
  constant ECM_TX_OUTPUT_CONTROL_DDS                      : natural := 1;
  constant ECM_TX_OUTPUT_CONTROL_DRFM                     : natural := 2;
  constant ECM_TX_OUTPUT_CONTROL_MIXER                    : natural := 3;
  constant ECM_TX_OUTPUT_CONTROL_WIDTH                    : natural := 2;

  constant ECM_NUM_FAST_LOCK_PROFILES                     : natural := 8;
  constant ECM_FAST_LOCK_PROFILE_INDEX_WIDTH              : natural := clog2(ECM_NUM_FAST_LOCK_PROFILES);

  constant ECM_NUM_DWELL_ENTRIES                          : natural := 16;
  constant ECM_DWELL_ENTRY_INDEX_WIDTH                    : natural := clog2(ECM_NUM_DWELL_ENTRIES);
  constant ECM_NUM_CHANNEL_CONTROL_ENTRIES                : natural := ECM_NUM_CHANNELS * ECM_NUM_DWELL_ENTRIES;
  constant ECM_DWELL_CHANNEL_CONTROL_ENTRY_INDEX_WIDTH    : natural := clog2(ECM_NUM_CHANNEL_CONTROL_ENTRIES);

  constant ECM_CHANNEL_TRIGGER_MODE_NONE                  : natural := 0;
  constant ECM_CHANNEL_TRIGGER_MODE_FORCE_TRIGGER         : natural := 1;
  constant ECM_CHANNEL_TRIGGER_MODE_THRESHOLD_TRIGGER     : natural := 2;
  constant ECM_CHANNEL_TRIGGER_MODE_WIDTH                 : natural := 2;
  constant ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES             : natural := 4;

  constant ECM_DRFM_DATA_WIDTH                            : natural := 16;
  constant ECM_DRFM_DATA_WIDTH_WIDTH                      : natural := clog2(ECM_DRFM_DATA_WIDTH);
  constant ECM_DRFM_MEM_DEPTH                             : natural := 1024 * 24;
  constant ECM_DRFM_ADDR_WIDTH                            : natural := clog2(ECM_DRFM_MEM_DEPTH);
  constant ECM_DRFM_SEGMENT_SEQUENCE_NUM_WIDTH            : natural := 32;
  constant ECM_DRFM_SEGMENT_LENGTH_WIDTH                  : natural := 16;  --TODO: shrink?
  constant ECM_DRFM_SEGMENT_SLICE_LENGTH_WIDTH            : natural := 8;
  constant ECM_DRFM_SEGMENT_HYST_SHIFT_WIDTH              : natural := 2;
  constant ECM_DRFM_MAX_PACKET_IQ_SAMPLES_PER_REPORT      : natural := 116;

  constant ECM_DWELL_DURATION_WIDTH                       : natural := 32;
  constant ECM_DWELL_SEQUENCE_NUM_WIDTH                   : natural := 32;
  constant ECM_DWELL_REPEAT_COUNT_WIDTH                   : natural := 4;
  constant ECM_DWELL_TAG_WIDTH                            : natural := 16;
  constant ECM_DWELL_FREQUENCY_WIDTH                      : natural := 16;
  constant ECM_DWELL_GLOBAL_COUNTER_WIDTH                 : natural := 16;
  constant ECM_DWELL_POWER_ACCUM_WIDTH                    : natural := 64;
  constant ECM_DWELL_PLL_DELAY_WIDTH                      : natural := 16;

  constant ECM_TIMESTAMP_WIDTH                            : natural := 48;
  constant ECM_DDS_DATA_WIDTH                             : natural := 16;
  constant ECM_SYNTHESIZER_DATA_WIDTH                     : natural := 16;

  type ecm_tx_instruction_header_t is record
    valid               : std_logic;
    instruction_type    : unsigned(ECM_TX_INSTRUCTION_TYPE_WIDTH - 1 downto 0);

    output_valid        : std_logic;
    output_control      : unsigned(ECM_TX_OUTPUT_CONTROL_WIDTH - 1 downto 0);

    dds_valid           : std_logic;
    dds_control         : dds_control_setup_entry_t;
  end record;
  constant ECM_TX_INSTRUCTION_HEADER_PACKED_WIDTH : natural := 16;

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
    valid                       : std_logic;
    trigger_immediate_after_min : std_logic;
    tx_program_index            : unsigned(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
    duration_gate_min           : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
    duration_gate_max           : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  end record;
  constant ECM_CHANNEL_TX_PROGRAM_ENTRY_ALIGNED_WIDTH : natural := 8 + 8 + 16 + 2*16;

  type ecm_channel_tx_program_entry_array_t is array (natural range <>) of ecm_channel_tx_program_entry_t;

  type ecm_channel_control_entry_t is record
    enable                          : std_logic;
    trigger_mode                    : unsigned(ECM_CHANNEL_TRIGGER_MODE_WIDTH - 1 downto 0);
    trigger_duration_max_minus_one  : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
    trigger_threshold               : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
    trigger_hyst_shift              : unsigned(ECM_DRFM_SEGMENT_HYST_SHIFT_WIDTH - 1 downto 0);
    drfm_gain                       : std_logic;
    recording_address               : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
    program_entries                 : ecm_channel_tx_program_entry_array_t(ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES - 1 downto 0);
  end record;
  constant ECM_CHANNEL_CONTROL_ENTRY_ALIGNED_WIDTH : natural := 8 + 8 + 16 + 32 + 8 + 8 + 16 +
                                                                ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES * ECM_CHANNEL_TX_PROGRAM_ENTRY_ALIGNED_WIDTH;

  type ecm_channel_control_entry_array_t is array (natural range <>) of ecm_channel_control_entry_t;

  type ecm_dwell_entry_t is record
    valid                     : std_logic;
    global_counter_check      : std_logic;
    global_counter_dec        : std_logic;
    skip_pll_prelock_wait     : std_logic;
    skip_pll_lock_check       : std_logic;
    skip_pll_postlock_wait    : std_logic;
    force_full_duration       : std_logic; --TODO: remove
    repeat_count              : unsigned(ECM_DWELL_REPEAT_COUNT_WIDTH - 1 downto 0);
    fast_lock_profile         : unsigned(ECM_FAST_LOCK_PROFILE_INDEX_WIDTH - 1 downto 0);
    next_dwell_index          : unsigned(ECM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);

    pll_pre_lock_delay        : unsigned(ECM_DWELL_PLL_DELAY_WIDTH - 1 downto 0);
    pll_post_lock_delay       : unsigned(ECM_DWELL_PLL_DELAY_WIDTH - 1 downto 0);

    tag                       : unsigned(ECM_DWELL_TAG_WIDTH - 1 downto 0);
    frequency                 : unsigned(ECM_DWELL_FREQUENCY_WIDTH - 1 downto 0);

    measurement_duration      : unsigned(ECM_DWELL_DURATION_WIDTH - 1 downto 0);

    total_duration_max        : unsigned(ECM_DWELL_DURATION_WIDTH - 1 downto 0);
  end record;
  constant ECM_DWELL_ENTRY_ALIGNED_WIDTH : natural := 8 + 8 + 8 + 8 + 16*2 + 16 + 16 + 32*2;

  type ecm_dwell_program_entry_t is record
    enable                    : std_logic;
    initial_dwell_index       : unsigned(ECM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
    global_counter_init       : unsigned(ECM_DWELL_GLOBAL_COUNTER_WIDTH - 1 downto 0);
  end record;
  constant ECM_DWELL_PROGRAM_ENTRY_ALIGNED_WIDTH : natural := 8 + 8 + ECM_DWELL_GLOBAL_COUNTER_WIDTH;

  type ecm_hardware_control_entry_t is record
    reset                     : std_logic;
    enable_channelizer        : std_logic;
    enable_synthesizer        : std_logic;
  end record;

  type ecm_config_data_t is record
    valid                     : std_logic;
    first                     : std_logic;
    last                      : std_logic;
    data                      : std_logic_vector(31 downto 0);
    module_id                 : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0);
    message_type              : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0);
    address                   : unsigned(ECM_CONFIG_ADDRESS_WIDTH - 1 downto 0);
  end record;
  constant ECM_CONFIG_DATA_WIDTH : natural := 3 + 32 + ECM_MODULE_ID_WIDTH + ECM_MESSAGE_TYPE_WIDTH + ECM_CONFIG_ADDRESS_WIDTH;

  --type ecm_common_header_t is record
  --  magic_num                 : std_logic_vector(31 downto 0);
  --  sequence_num              : unsigned(31 downto 0);
  --  module_id                 : unsigned(ECM_MODULE_ID_WIDTH - 1 downto 0);
  --  message_type              : unsigned(ECM_MESSAGE_TYPE_WIDTH - 1 downto 0);
  --  address                   : unsigned(ECM_CONFIG_ADDRESS_WIDTH - 1 downto 0);
  --end record;
  constant ECM_COMMON_HEADER_WIDTH  : natural := 96;


  --type ecm_report_dwell_stats_t is record
  --  dwell_entry               : ecm_dwell_entry_t;
  --  dwell_sequence_num        : unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  --  measurement_duration      : unsigned(ECM_DWELL_DURATION_WIDTH - 1 downto 0);
  --  total_duration            : unsigned(ECM_DWELL_DURATION_WIDTH - 1 downto 0);
  --  ts_dwell_start            : unsigned(ECM_TIMESTAMP_WIDTH - 1 downto 0);
  --
  --  -- array of 128? bit entries: num_samples, accum, max
  --end record;

  --type ecm_report_drfm_channel_data_t record
  --  dwell_sequence_num        : unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  --  channel_index             : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  --  max_iq_bits               : unsigned(ECM_DRFM_DATA_WIDTH_WIDTH - 1 downto 0);
  --  segment_sequence_num      : unsigned(ECM_DRFM_SEGMENT_SEQUENCE_NUM_WIDTH - 1 downto 0);
  --  segment_timestamp         : unsigned(ECM_TIMESTAMP_WIDTH - 1 downto 0);
  --  segment_first_addr        : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  --  segment_last_addr         : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  --  slice_start               : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
  --  slice_length              : unsigned(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
  --
  --  iq_data : array of N 32-bit entries
  --end record;

  --type ecm_report_drfm_summary_t record
  --  dwell_sequence_num        : unsigned(ECM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  --
  --  channel entry array: readout flag, recorded flag
  --end record;

  type ecm_drfm_write_req_t is record
    valid               : std_logic;
    first               : std_logic;
    last                : std_logic;
    channel_index       : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
    address             : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
    data                : signed_array_t(1 downto 0)(ECM_DRFM_DATA_WIDTH - 1 downto 0);
  end record;

  type ecm_drfm_read_req_t is record
    valid               : std_logic;
    address             : unsigned(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
    channel_index       : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
    channel_last        : std_logic;
  end record;

  type ecm_output_control_t is record
    valid               : std_logic;
    channel_index       : unsigned(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
    control             : unsigned(ECM_TX_OUTPUT_CONTROL_WIDTH - 1 downto 0);
  end record;


  type ecm_channelizer_warnings_t is record
    demux_gap       : std_logic;
  end record;
  constant ECM_CHANNELIZER_WARNINGS_WIDTH : natural := 1;
  type ecm_channelizer_warnings_array_t is array (natural range <>) of ecm_channelizer_warnings_t; --TODO: remove array types?

  type ecm_channelizer_errors_t is record
    demux_overflow      : std_logic;
    filter_overflow     : std_logic;
    mux_overflow        : std_logic;
    mux_underflow       : std_logic;
    mux_collision       : std_logic;
    stretcher_overflow  : std_logic;
    stretcher_underflow : std_logic;
  end record;
  constant ECM_CHANNELIZER_ERRORS_WIDTH : natural := 7;
  type ecm_channelizer_errors_array_t is array (natural range <>) of ecm_channelizer_errors_t;

  type ecm_synthesizer_errors_t is record
    stretcher_overflow  : std_logic;
    stretcher_underflow : std_logic;
    filter_overflow     : std_logic;
    mux_input_overflow  : std_logic;
    mux_fifo_overflow   : std_logic;
    mux_fifo_underflow  : std_logic;
  end record;
  constant ECM_SYNTHESIZER_ERRORS_WIDTH : natural := 6;
  type ecm_synthesizer_errors_array_t is array (natural range <>) of ecm_synthesizer_errors_t;

  type ecm_dwell_stats_errors_t is record
    reporter_timeout  : std_logic;
    reporter_overflow : std_logic;
  end record;
  constant ECM_DWELL_STATS_ERRORS_WIDTH : natural := 2;
  type ecm_dwell_stats_errors_array_t is array (natural range <>) of ecm_dwell_stats_errors_t;

  type ecm_drfm_errors_t is record
    ext_read_overflow   : std_logic;
    int_read_overflow   : std_logic;
    invalid_read        : std_logic;
    reporter_timeout    : std_logic;
    reporter_overflow   : std_logic;
  end record;
  constant ECM_DRFM_ERRORS_WIDTH : natural := 5;
  type ecm_drfm_errors_array_t is array (natural range <>) of ecm_drfm_errors_t;

  type ecm_output_block_errors_t is record
    dds_drfm_sync_mismatch : std_logic;
  end record;
  constant ECM_OUTPUT_BLOCK_ERRORS_WIDTH : natural := 5;

  type ecm_status_reporter_errors_t is record
    reporter_timeout  : std_logic;
    reporter_overflow : std_logic;
  end record;
  constant ECM_STATUS_REPORTER_ERRORS_WIDTH : natural := 2;

  type ecm_status_flags_t is record
    channelizer_warnings  : ecm_channelizer_warnings_t;
    channelizer_errors    : ecm_channelizer_errors_t;
    synthesizer_errors    : ecm_synthesizer_errors_t;
    dwell_stats_errors    : ecm_dwell_stats_errors_t;
    drfm_errors           : ecm_drfm_errors_t;
    output_block_errors   : ecm_output_block_errors_t;
  end record;
  constant ECM_STATUS_FLAGS_WIDTH : natural := ECM_CHANNELIZER_WARNINGS_WIDTH +
                                               ECM_CHANNELIZER_ERRORS_WIDTH +
                                               ECM_SYNTHESIZER_ERRORS_WIDTH +
                                               ECM_DWELL_STATS_ERRORS_WIDTH +
                                               ECM_DRFM_ERRORS_WIDTH +
                                               ECM_OUTPUT_BLOCK_ERRORS_WIDTH;

  function unpack(v : std_logic_vector(ECM_CONFIG_DATA_WIDTH - 1 downto 0)) return ecm_config_data_t;
  function unpack(v : std_logic_vector(ECM_TX_INSTRUCTION_HEADER_PACKED_WIDTH - 1 downto 0)) return ecm_tx_instruction_header_t;
  function unpack(v : std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0)) return ecm_tx_instruction_playback_t;
  function unpack(v : std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0)) return ecm_tx_instruction_wait_t;
  function unpack(v : std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0)) return ecm_tx_instruction_jump_t;
  function unpack(v : std_logic_vector(ECM_DWELL_PROGRAM_ENTRY_ALIGNED_WIDTH - 1 downto 0)) return ecm_dwell_program_entry_t;
  function unpack(v : std_logic_vector(ECM_DWELL_ENTRY_ALIGNED_WIDTH - 1 downto 0)) return ecm_dwell_entry_t;
  function unpack(v : std_logic_vector(ECM_CHANNEL_TX_PROGRAM_ENTRY_ALIGNED_WIDTH - 1 downto 0)) return ecm_channel_tx_program_entry_t;
  function unpack(v : std_logic_vector(ECM_CHANNEL_CONTROL_ENTRY_ALIGNED_WIDTH - 1 downto 0)) return ecm_channel_control_entry_t;

  function pack(v : ecm_channelizer_warnings_t) return std_logic_vector;
  function pack(v : ecm_channelizer_errors_t) return std_logic_vector;
  function pack(v : ecm_synthesizer_errors_t) return std_logic_vector;
  function pack(v : ecm_dwell_stats_errors_t) return std_logic_vector;
  function pack(v : ecm_drfm_errors_t) return std_logic_vector;
  function pack(v : ecm_output_block_errors_t) return std_logic_vector;
  function pack(v : ecm_status_reporter_errors_t) return std_logic_vector;
  function pack(v : ecm_status_flags_t) return std_logic_vector;
  function pack(v : ecm_config_data_t) return std_logic_vector;
  function pack_aligned(v : ecm_dwell_entry_t) return std_logic_vector;

end package ecm_pkg;

package body ecm_pkg is


  function unpack(v : std_logic_vector(ECM_CONFIG_DATA_WIDTH - 1 downto 0)) return ecm_config_data_t is
    variable r : ecm_config_data_t;
  begin
    r.valid         := v(0);
    r.first         := v(1);
    r.last          := v(2);
    r.data          := v(34 downto 3);
    r.module_id     := unsigned(v(35 + ECM_MODULE_ID_WIDTH - 1 downto 35));
    r.message_type  := unsigned(v(35 + ECM_MODULE_ID_WIDTH + ECM_MESSAGE_TYPE_WIDTH - 1 downto 35 + ECM_MODULE_ID_WIDTH));
    r.address       := unsigned(v(35 + ECM_MODULE_ID_WIDTH + ECM_MESSAGE_TYPE_WIDTH + ECM_CONFIG_ADDRESS_WIDTH - 1 downto 35 + ECM_MODULE_ID_WIDTH + ECM_MESSAGE_TYPE_WIDTH));

    return r;
  end function;

  function unpack(v : std_logic_vector(ECM_TX_INSTRUCTION_HEADER_PACKED_WIDTH - 1 downto 0)) return ecm_tx_instruction_header_t is
    variable r : ecm_tx_instruction_header_t;
  begin
    r.valid             := v(3);
    r.instruction_type  := unsigned(v(2 downto 0));

    r.output_valid      := v(7);
    r.output_control    := unsigned(v(5 downto 4));

    r.dds_valid         := v(11);
    r.dds_control       := unpack(v(10 downto 8));
    return r;
  end function;

  function unpack(v : std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0)) return ecm_tx_instruction_playback_t is
    variable r : ecm_tx_instruction_playback_t;
  begin

    r.header            := unpack(v(15 downto 0));
    r.mode              := v(16);
    r.base_count        := unsigned(v(47 downto 32));
    r.rand_offset_mask  := unsigned(v(63 downto 48));

    return r;
  end function;

  function unpack(v : std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0)) return ecm_tx_instruction_wait_t is
    variable r : ecm_tx_instruction_wait_t;
  begin

    r.header            := unpack(v(15 downto 0));
    r.base_duration     := unsigned(v(35 downto 16));
    r.rand_offset_mask  := unsigned(v(59 downto 40));

    return r;
  end function;

  function unpack(v : std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0)) return ecm_tx_instruction_jump_t is
    variable r : ecm_tx_instruction_jump_t;
  begin

    r.header          := unpack(v(15 downto 0));
    r.dest_index      := unsigned(v(16 + ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 16));
    r.counter_check   := v(32);
    r.counter_value   := unsigned(v(55 downto 40));

    return r;
  end function;

  function unpack(v : std_logic_vector(ECM_DWELL_PROGRAM_ENTRY_ALIGNED_WIDTH - 1 downto 0)) return ecm_dwell_program_entry_t is
    variable r : ecm_dwell_program_entry_t;
  begin
    r.enable              := v(0);
    r.initial_dwell_index := unsigned(v(8 + ECM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 8));
    r.global_counter_init := unsigned(v(16 + ECM_DWELL_GLOBAL_COUNTER_WIDTH - 1 downto 16));
    return r;
  end function;

  function unpack(v : std_logic_vector(ECM_DWELL_ENTRY_ALIGNED_WIDTH - 1 downto 0)) return ecm_dwell_entry_t is
    variable r : ecm_dwell_entry_t;
  begin

    (r.force_full_duration, r.skip_pll_postlock_wait, r.skip_pll_lock_check,
     r.skip_pll_prelock_wait, r.global_counter_dec, r.global_counter_check, r.valid) := v(6 downto 0);

    r.repeat_count          := unsigned(v(8 + ECM_DWELL_REPEAT_COUNT_WIDTH - 1 downto 8));
    r.fast_lock_profile     := unsigned(v(16 + ECM_FAST_LOCK_PROFILE_INDEX_WIDTH - 1 downto 16));
    r.next_dwell_index      := unsigned(v(24 + ECM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 24));

    r.pll_pre_lock_delay    := unsigned(v(32 + ECM_DWELL_PLL_DELAY_WIDTH - 1 downto 32));
    r.pll_post_lock_delay   := unsigned(v(48 + ECM_DWELL_PLL_DELAY_WIDTH - 1 downto 48));

    r.tag                   := unsigned(v(64 + ECM_DWELL_TAG_WIDTH - 1 downto 64));
    r.frequency             := unsigned(v(80 + ECM_DWELL_FREQUENCY_WIDTH - 1 downto 80));

    r.measurement_duration  := unsigned(v(96 + ECM_DWELL_DURATION_WIDTH - 1 downto 96));
    r.total_duration_max    := unsigned(v(128 + ECM_DWELL_DURATION_WIDTH - 1 downto 128));

    return r;
  end function;

  function unpack(v : std_logic_vector(ECM_CHANNEL_TX_PROGRAM_ENTRY_ALIGNED_WIDTH - 1 downto 0)) return ecm_channel_tx_program_entry_t is
    variable r : ecm_channel_tx_program_entry_t;
  begin

    r.valid                       := v(0);
    r.trigger_immediate_after_min := v(8);
    r.tx_program_index            := unsigned(v(16 + ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 16));
    r.duration_gate_min           := unsigned(v(32 + ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 32));
    r.duration_gate_max           := unsigned(v(48 + ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 48));

    return r;
  end function;

  function unpack(v : std_logic_vector(ECM_CHANNEL_CONTROL_ENTRY_ALIGNED_WIDTH - 1 downto 0)) return ecm_channel_control_entry_t is
    variable r : ecm_channel_control_entry_t;
  begin
    r.enable                          := v(0);
    r.trigger_mode                    := unsigned(v(8 + ECM_CHANNEL_TRIGGER_MODE_WIDTH - 1 downto 8));
    r.trigger_duration_max_minus_one  := unsigned(v(16 + ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 16));

    r.trigger_threshold               := unsigned(v(32 + CHAN_POWER_WIDTH - 1 downto 32));
    r.trigger_hyst_shift              := unsigned(v(64 + ECM_DRFM_SEGMENT_HYST_SHIFT_WIDTH - 1 downto 64));
    r.drfm_gain                       := v(72);

    r.recording_address               := unsigned(v(80 + ECM_DRFM_ADDR_WIDTH - 1 downto 80));

    for i in 0 to (ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES - 1) loop
      r.program_entries(i)  := unpack(v(96 + ECM_CHANNEL_TX_PROGRAM_ENTRY_ALIGNED_WIDTH * (i+1) - 1 downto 96 + ECM_CHANNEL_TX_PROGRAM_ENTRY_ALIGNED_WIDTH*i));
    end loop;

    return r;
  end function;


  function pack(v : ecm_channelizer_warnings_t) return std_logic_vector is
    variable r : std_logic_vector(ECM_CHANNELIZER_WARNINGS_WIDTH - 1 downto 0);
  begin
    r(0) := v.demux_gap;
    return r;
  end function;

  function pack(v : ecm_channelizer_errors_t) return std_logic_vector is
    variable r : std_logic_vector(ECM_CHANNELIZER_ERRORS_WIDTH - 1 downto 0);
  begin
    r := (
          v.stretcher_underflow,
          v.stretcher_overflow,
          v.mux_collision,
          v.mux_underflow,
          v.mux_overflow,
          v.filter_overflow,
          v.demux_overflow
         );
    return r;
  end function;

  function pack(v : ecm_synthesizer_errors_t) return std_logic_vector is
    variable r : std_logic_vector(ECM_SYNTHESIZER_ERRORS_WIDTH - 1 downto 0);
  begin
    r := (
          v.mux_fifo_underflow,
          v.mux_fifo_overflow,
          v.mux_input_overflow,
          v.filter_overflow,
          v.stretcher_underflow,
          v.stretcher_overflow
         );
    return r;
  end function;

  function pack(v : ecm_dwell_stats_errors_t) return std_logic_vector is
    variable r : std_logic_vector(ECM_DWELL_STATS_ERRORS_WIDTH - 1 downto 0);
  begin
    r := (
          v.reporter_overflow,
          v.reporter_timeout
         );
    return r;
  end function;

  function pack(v : ecm_drfm_errors_t) return std_logic_vector is
    variable r : std_logic_vector(ECM_DRFM_ERRORS_WIDTH - 1 downto 0);
  begin
    r := (
          v.reporter_overflow,
          v.reporter_timeout,
          v.invalid_read,
          v.int_read_overflow,
          v.ext_read_overflow
         );
    return r;
  end function;

  function pack(v : ecm_output_block_errors_t) return std_logic_vector is
    variable r : std_logic_vector(ECM_OUTPUT_BLOCK_ERRORS_WIDTH - 1 downto 0);
  begin
    r(0) := v.dds_drfm_sync_mismatch;
    return r;
  end function;

  function pack(v : ecm_status_reporter_errors_t) return std_logic_vector is
    variable r : std_logic_vector(ECM_STATUS_REPORTER_ERRORS_WIDTH - 1 downto 0);
  begin
    r := (
          v.reporter_overflow,
          v.reporter_timeout
         );
    return r;
  end function;

  function pack(v : ecm_status_flags_t) return std_logic_vector is
    variable r : std_logic_vector(ECM_STATUS_FLAGS_WIDTH - 1 downto 0);
  begin
    r := (
          pack(v.output_block_errors),
          pack(v.drfm_errors),
          pack(v.dwell_stats_errors),
          pack(v.synthesizer_errors),
          pack(v.channelizer_errors),
          pack(v.channelizer_warnings)
         );
    return r;
  end function;

  function pack(v : ecm_config_data_t) return std_logic_vector is
    variable r : std_logic_vector(ECM_CONFIG_DATA_WIDTH - 1 downto 0);
  begin
    r := (std_logic_vector(v.address),
          std_logic_vector(v.message_type),
          std_logic_vector(v.module_id),
          v.data, v.last, v.first, v.valid);

    return r;
  end function;

  function pack_aligned(v : ecm_dwell_entry_t) return std_logic_vector is
    variable r        : std_logic_vector(ECM_DWELL_ENTRY_ALIGNED_WIDTH - 1 downto 0);
    variable v_flags  : std_logic_vector(7 downto 0);
  begin
    assert (ECM_DWELL_ENTRY_ALIGNED_WIDTH mod 32 = 0)
      report "ECM_DWELL_ENTRY_ALIGNED_WIDTH must be a multiple of 32."
      severity failure;

    v_flags := ('0', v.force_full_duration, v.skip_pll_postlock_wait, v.skip_pll_lock_check,
                v.skip_pll_prelock_wait, v.global_counter_dec, v.global_counter_check, v.valid);

    -- swapped by 32-bit word to match SV struct packing in TB
    r := (
            std_logic_vector(v.total_duration_max),

            std_logic_vector(v.measurement_duration),

            std_logic_vector(v.tag),
            std_logic_vector(v.frequency),

            std_logic_vector(v.pll_pre_lock_delay),
            std_logic_vector(v.pll_post_lock_delay),

            v_flags,
            std_logic_vector(resize_up(v.repeat_count, 8)),
            std_logic_vector(resize_up(v.fast_lock_profile, 8)),
            std_logic_vector(resize_up(v.next_dwell_index, 8))
         );

    return r;
  end function;

end package body ecm_pkg;
