library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

package esm_pkg is

  constant ESM_CONTROL_MAGIC_NUM                        : std_logic_vector(31 downto 0) := "45534D43";
  constant ESM_REPORT_MAGIC_NUM                         : std_logic_vector(31 downto 0) := "45534D52";

  constant ESM_MODULE_ID_WIDTH                          : natural := 2;
  constant ESM_MESSAGE_TYPE_WIDTH                       : natural := 8;

  constant ESM_MODULE_ID_CONTROL                        : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0) := "00";
  constant ESM_MODULE_ID_DWELL                          : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0) := "01";
  constant ESM_MODULE_ID_PDW                            : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0) := "10";

  constant ESM_CONTROL_MESSAGE_TYPE_ENABLE              : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"00";
  constant ESM_CONTROL_MESSAGE_TYPE_DWELL_ENTRY         : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"01";
  constant ESM_CONTROL_MESSAGE_TYPE_DWELL_PROGRAM       : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"02";
  constant ESM_CONTROL_MESSAGE_TYPE_PDW_SETUP           : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"03";  --TODO: unused?

  constant ESM_REPORT_MESSAGE_TYPE_DWELL_COMPLETE_INFO  : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"10";
  constant ESM_REPORT_MESSAGE_TYPE_DWELL_COMPLETE_STATS : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"10";
  constant ESM_REPORT_MESSAGE_TYPE_PDW                  : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"20";

  constant ESM_NUM_CHANNELS_NARROW                      : natural := 64;
  constant ESM_NUM_CHANNELS_WIDE                        : natural := 8;
  constant ESM_CHANNEL_INDEX_WIDTH                      : natural := clog2(ESM_NUM_CHANNELS_WIDE);

  constant ESM_NUM_FAST_LOCK_PROFILES                   : natural := 8;
  constant ESM_FAST_LOCK_PROFILE_INDEX_WIDTH            : natural := clog2(ESM_NUM_FAST_LOCK_PROFILES);
  constant ESM_NUM_DWELL_ENTRIES                        : natural := 32;
  constant ESM_DWELL_ENTRY_INDEX_WIDTH                  : natural := clog2(ESM_NUM_DWELL_ENTRIES);
  constant ESM_NUM_DWELL_INSTRUCTIONS                   : natural := 32;
  constant ESM_DWELL_INSTRUCTION_INDEX_WIDTH            : natural := clog2(ESM_NUM_DWELL_INSTRUCTIONS);

  type esm_common_header_t is record
    magic_num                 : std_logic_vector(31 downto 0);
    sequence_num              : unsigned(31 downto 0);
    module_id                 : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0);
    message_type              : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0);
  end record;

  type esm_message_enable_t is record
    header                    : esm_common_header_t;
    reset                     : std_logic;
    enable_channelizer        : std_logic_vector(1 downto 0);
    enable_pdw                : std_logic_vector(1 downto 0);
  end record;

  type esm_dwell_metadata_t is record
    tag                       : unsigned(15 downto 0);
    frequency                 : unsigned(15 downto 0);
    duration                  : unsigned(31 downto 0);
    gain                      : unsigned(7 downto 0);
    fast_lock_profile         : unsigned(ESM_FAST_LOCK_PROFILE_INDEX_WIDTH - 1 downto 0);
    threshold_narrow          : unsigned(15 downto 0);
    threshold_wide            : unsigned(15 downto 0);
    channel_mask_narrow       : std_logic_vector(ESM_NUM_CHANNELS_NARROW - 1 downto 0);
    channel_mask_wide         : std_logic_vector(ESM_NUM_CHANNELS_WIDE - 1 downto 0);
  end record;

  type esm_message_dwell_entry_t is record
    header                    : esm_common_header_t;
    entry_valid               : std_logic;
    entry_data                : esm_dwell_metadata_t;
    entry_index               : unsigned(ESM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
  end record;

  type esm_dwell_instruction_t is record
    valid                     : std_logic;
    global_counter_check      : std_logic;
    global_counter_dec        : std_logic;
    repeat_count              : unsigned(3 downto 0);
    entry_index               : unsigned(ESM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
    next_instruction_index    : unsigned(ESM_DWELL_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
  end record;

  type esm_dwell_instruction_array_t is array (natural range <>) of esm_dwell_instruction_t;

  type esm_message_dwell_program_t is record
    header                    : esm_common_header_t;
    enable_program            : std_logic;
    enable_delayed_start      : std_logic;
    global_counter_init       : unsigned(31 downto 0);
    delayed_start_time        : unsigned(63 downto 0);
    instructions              : esm_dwell_instruction_array_t(ESM_NUM_DWELL_INSTRUCTIONS - 1 downto 0);
  end record;

  type esm_message_dwell_complete_info_t is record
    header                    : esm_common_header_t;
    dwell_sequence_num        : unsigned(31 downto 0);
    metadata                  : esm_dwell_metadata_t;

    num_samples               : unsigned(31 downto 0);
    ts_dwell_start            : unsigned(63 downto 0);
    ts_pll_locked             : unsigned(63 downto 0);
    ts_dwell_end              : unsigned(63 downto 0);
  end record;

  type esm_message_dwell_complete_stats_t is record
    header                    : esm_common_header_t;
    dwell_sequence_num        : unsigned(31 downto 0);
    metadata                  : esm_dwell_metadata_t;

    channel_start_index       : unsigned(ESM_CHANNEL_INDEX_WIDTH - 1 downto 0);
    channel_amplitude         : unsigned_array_t(ESM_NUM_CHANNELS_WIDE/2 - 1 downto 0)(31 downto 0);
  end record;

  type esm_message_pdw_t is record
    header                    : esm_common_header_t;
    pdw_sequence_num          : unsigned(31 downto 0);
    dwell_sequence_num        : unsigned(31 downto 0);
    dwell_metadata            : esm_dwell_metadata_t;
    pulse_channel             : unsigned(ESM_CHANNEL_INDEX_WIDTH - 1 downto 0);
    pulse_threshold           : unsigned(31 downto 0);
    pulse_amplitude           : unsigned(31 downto 0);
    pulse_duration            : unsigned(31 downto 0);  --TODO: early termination flag?
    pulse_frequency           : unsigned(31 downto 0);  --TODO: IFM module
    pulse_start_time          : unsigned(63 downto 0);
    raw_samples               : std_logic_vector_array_t(40 downto 0)(31 downto 0); --TODO: increase to max
  end record;

  type esm_config_data_t is record
    valid                     : std_logic;
    first                     : std_logic;
    last                      : std_logic;
    data                      : std_logic_vector(31 downto 0);
    module_id                 : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0);
    message_type              : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0);
  end record;

end package esm_pkg;

package body esm_pkg is

end package body esm_pkg;
