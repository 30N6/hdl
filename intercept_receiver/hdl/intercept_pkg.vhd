library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

package intercept_pkg is

  constant INTERCEPT_MAX_WORDS_PER_PACKET_SMALL                 : natural := 128;
  constant INTERCEPT_MAX_WORDS_PER_PACKET_LARGE                 : natural := 360;
  constant INTERCEPT_CONTROL_MAGIC_NUM                          : std_logic_vector(31 downto 0) := x"494E5443";
  constant INTERCEPT_REPORT_MAGIC_NUM                           : std_logic_vector(31 downto 0) := x"494E5452";

  constant INTERCEPT_MODULE_ID_WIDTH                            : natural := 8;
  constant INTERCEPT_MESSAGE_TYPE_WIDTH                         : natural := 8;

  constant INTERCEPT_MODULE_ID_CONTROL                          : unsigned(INTERCEPT_MODULE_ID_WIDTH - 1 downto 0) := x"00";
  constant INTERCEPT_MODULE_ID_DWELL_CONTROLLER                 : unsigned(INTERCEPT_MODULE_ID_WIDTH - 1 downto 0) := x"01";
  constant INTERCEPT_MODULE_ID_DWELL_STATS                      : unsigned(INTERCEPT_MODULE_ID_WIDTH - 1 downto 0) := x"02";
  constant INTERCEPT_MODULE_ID_STATUS                           : unsigned(INTERCEPT_MODULE_ID_WIDTH - 1 downto 0) := x"07";

  constant INTERCEPT_CONTROL_MESSAGE_TYPE_ENABLE                : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"00";
  constant INTERCEPT_CONTROL_MESSAGE_TYPE_DWELL_ENTRY           : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"01";
  constant INTERCEPT_CONTROL_MESSAGE_TYPE_DWELL_PROGRAM         : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"02";
  constant INTERCEPT_CONTROL_MESSAGE_TYPE_DWELL_CHANNEL_CONTROL : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"03";

  constant INTERCEPT_REPORT_MESSAGE_TYPE_DWELL_STATS            : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"10";
  constant INTERCEPT_REPORT_MESSAGE_TYPE_STREAM                 : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"20";
  constant INTERCEPT_REPORT_MESSAGE_TYPE_STATUS                 : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"30";

  constant INTERCEPT_CONFIG_ADDRESS_WIDTH                       : natural := 16;

  constant INTERCEPT_NUM_CHANNELS                               : natural := 512;
  constant INTERCEPT_CHANNEL_INDEX_WIDTH                        : natural := clog2(INTERCEPT_NUM_CHANNELS);

  constant INTERCEPT_NUM_FAST_LOCK_PROFILES                     : natural := 8;
  constant INTERCEPT_FAST_LOCK_PROFILE_INDEX_WIDTH              : natural := clog2(INTERCEPT_NUM_FAST_LOCK_PROFILES);
  constant INTERCEPT_NUM_DWELL_ENTRIES                          : natural := 32;
  constant INTERCEPT_DWELL_ENTRY_INDEX_WIDTH                    : natural := clog2(INTERCEPT_NUM_DWELL_ENTRIES);
  constant INTERCEPT_NUM_CHANNEL_CONTROL_ENTRIES                : natural := INTERCEPT_NUM_CHANNELS * INTERCEPT_NUM_DWELL_ENTRIES;
  constant INTERCEPT_DWELL_CHANNEL_CONTROL_ENTRY_INDEX_WIDTH    : natural := clog2(INTERCEPT_NUM_CHANNEL_CONTROL_ENTRIES);

  constant INTERCEPT_DWELL_DURATION_WIDTH                       : natural := 32;
  constant INTERCEPT_DWELL_SEQUENCE_NUM_WIDTH                   : natural := 32;
  constant INTERCEPT_TIMESTAMP_WIDTH                            : natural := 48;
  constant INTERCEPT_MIN_DURATION_WIDTH                         : natural := 16;


  --type intercept_common_header_t is record
  --  magic_num                 : std_logic_vector(31 downto 0);
  --  sequence_num              : unsigned(31 downto 0);
  --  module_id                 : unsigned(INTERCEPT_MODULE_ID_WIDTH - 1 downto 0);
  --  message_type              : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0);
  --  address                   : unsigned(INTERCEPT_CONFIG_ADDRESS_WIDTH - 1 downto 0);
  --end record;
  constant INTERCEPT_COMMON_HEADER_WIDTH  : natural := 96;

  --type intercept_message_enable_t is record
  --  header                    : esm_common_header_t;
  --  reset                     : std_logic;
  --  enable_channelizer        : std_logic;
  --  enable_stream             : std_logic;
  --  enable_status             : std_logic;
  --end record;

--TODO: dwell
--  type esm_dwell_entry_t is record
--    tag                       : unsigned(15 downto 0);
--    frequency                 : unsigned(15 downto 0);
--    duration                  : unsigned(ESM_DWELL_DURATION_WIDTH - 1 downto 0);
--    gain                      : unsigned(6 downto 0);
--    fast_lock_profile         : unsigned(ESM_FAST_LOCK_PROFILE_INDEX_WIDTH - 1 downto 0);
--    threshold_shift_narrow    : unsigned(ESM_THRESHOLD_SHIFT_WIDTH - 1 downto 0);
--    threshold_shift_wide      : unsigned(ESM_THRESHOLD_SHIFT_WIDTH - 1 downto 0);
--    channel_mask_narrow       : std_logic_vector(ESM_NUM_CHANNELS_NARROW - 1 downto 0);
--    channel_mask_wide         : std_logic_vector(ESM_NUM_CHANNELS_WIDE - 1 downto 0);
--    min_pulse_duration        : unsigned(ESM_MIN_DURATION_WIDTH - 1 downto 0);
--  end record;
--
--  type esm_dwell_entry_array_t is array (natural range <>) of esm_dwell_entry_t;
--
--  constant ESM_DWELL_ENTRY_PACKED_WIDTH : natural := 224;
--  --type esm_dwell_entry_packed_t is record
--  --  tag                       : unsigned(15 downto 0);
--  --  frequency                 : unsigned(15 downto 0);
--  --  duration                  : unsigned(31 downto 0);
--  --  gain                      : unsigned(7 downto 0);
--  --  fast_lock_profile         : unsigned(7 downto 0);
--  --  padding0                  : std_logic_vector(15 downto 0);
--  --  threshold_shift_narrow    : unsigned(4 downto 0);
--  --  padding_t0                : std_logic_vector(2 downto 0);
--  --  threshold_shift_wide      : unsigned(4 downto 0);
--  --  padding_t1                : std_logic_vector(2 downto 0);
--  --  padding1                  : std_logic_vector(15 downto 0);
--  --  channel_mask_narrow       : std_logic_vector(63 downto 0);
--  --  channel_mask_wide         : std_logic_vector(7 downto 0);
--  --  padding1                  : std_logic_vector(7 downto 0);
--  --  min_pulse_duration        : unsigned(15 downto 0);
--  --end record;
--
--  type esm_dwell_instruction_t is record
--    valid                     : std_logic;
--    global_counter_check      : std_logic;
--    global_counter_dec        : std_logic;
--    skip_pll_prelock_wait     : std_logic;
--    skip_pll_lock_check       : std_logic;
--    skip_pll_postlock_wait    : std_logic;
--    repeat_count              : unsigned(3 downto 0);
--    entry_index               : unsigned(ESM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
--    next_instruction_index    : unsigned(ESM_DWELL_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
--  end record;
--
--  constant ESM_DWELL_INSTRUCTION_PACKED_WIDTH : natural := 32;
--  --type esm_dwell_instruction_packed_t is record
--  --  flags                     : std_logic_vector(7 downto 0);
--  --  repeat_count              : unsigned(7 downto 0);
--  --  entry_index               : unsigned(7 downto 0);
--  --  next_instruction_index    : unsigned(7 downto 0);
--  --end record;
--
--  type esm_dwell_instruction_array_t is array (natural range <>) of esm_dwell_instruction_t;
--
--  type esm_dwell_program_t is record
--    --header                    : esm_common_header_t;
--    enable_program            : std_logic;
--    enable_delayed_start      : std_logic;
--    global_counter_init       : unsigned(31 downto 0);
--    delayed_start_time        : unsigned(63 downto 0);
--    instructions              : esm_dwell_instruction_array_t(ESM_NUM_DWELL_INSTRUCTIONS - 1 downto 0);
--  end record;
--
--  type esm_dwell_program_header_t is record
--    enable_program            : std_logic;
--    enable_delayed_start      : std_logic;
--    global_counter_init       : unsigned(31 downto 0);
--    delayed_start_time        : unsigned(63 downto 0);
--  end record;
--
--  constant ESM_DWELL_PROGRAM_HEADER_PACKED_WIDTH : natural := 128;
--  --type esm_dwell_program_header_packed_t is record
--  --  --header                    : esm_common_header_t;
--  --  enable_program            : std_logic_vector(7 downto 0);
--  --  enable_delayed_start      : std_logic_vector(7 downto 0);
--  --  padding                   : std_logic_vector(15 downto 0);
--  --  global_counter_init       : unsigned(31 downto 0);
--  --  delayed_start_time        : unsigned(63 downto 0);
--  --  --instructions              : esm_dwell_instruction_array_packed_t(ESM_NUM_DWELL_INSTRUCTIONS - 1 downto 0);
--  --end record;
--
--  --TODO: add reporting?
--  --type esm_message_dwell_complete_info_t is record
--  --  header                    : esm_common_header_t;
--  --  dwell_sequence_num        : unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
--  --  metadata                  : esm_dwell_entry_t;
--  --
--  --  num_samples               : unsigned(31 downto 0);
--  --  ts_dwell_start            : unsigned(63 downto 0);
--  --  ts_dwell_end              : unsigned(63 downto 0);
--  --end record;
--  --
--  --type esm_message_dwell_complete_stats_t is record
--  --  header                    : esm_common_header_t;
--  --  dwell_sequence_num        : unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
--  --  metadata                  : esm_dwell_entry_t;
--  --  duration_actual           : unsigned(31 downto 0);
--  --  num_samples               : unsigned(31 downto 0);
--  --  ts_dwell_start            : unsigned(63 downto 0);
--  --  ts_dwell_end              : unsigned(63 downto 0);
--  --
--  --  -- array of 128 bit entries: index, accum, max
--  --end record;
--  --

  type intercept_config_data_t is record
    valid                     : std_logic;
    first                     : std_logic;
    last                      : std_logic;
    data                      : std_logic_vector(31 downto 0);
    module_id                 : unsigned(INTERCEPT_MODULE_ID_WIDTH - 1 downto 0);
    message_type              : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0);
    address                   : unsigned(INTERCEPT_CONFIG_ADDRESS_WIDTH - 1 downto 0);
  end record;
  constant INTERCEPT_CONFIG_DATA_WIDTH : natural := 3 + 32 + INTERCEPT_MODULE_ID_WIDTH + INTERCEPT_MESSAGE_TYPE_WIDTH + INTERCEPT_CONFIG_ADDRESS_WIDTH;

  type intercept_channelizer_warnings_t is record
    demux_gap       : std_logic;
  end record;

  constant INTERCEPT_CHANNELIZER_WARNINGS_WIDTH : natural := 1;

  type intercept_channelizer_errors_t is record
    demux_overflow  : std_logic;
    filter_overflow : std_logic;
    mux_overflow    : std_logic;
    mux_underflow   : std_logic;
    mux_collision   : std_logic;
  end record;

  constant INTERCEPT_CHANNELIZER_ERRORS_WIDTH : natural := 5;

  type intercept_dwell_stats_errors_t is record
    reporter_timeout  : std_logic;
    reporter_overflow : std_logic;
  end record;

  constant INTERCEPT_DWELL_STATS_ERRORS_WIDTH : natural := 2;

  type intercept_stream_encoder_errors_t is record
    reporter_timeout  : std_logic;
    reporter_overflow : std_logic;
  end record;

  constant INTERCEPT_STREAM_ENCODER_ERRORS_WIDTH : natural := 2;

  type intercept_status_reporter_errors_t is record
    reporter_timeout  : std_logic;
    reporter_overflow : std_logic;
  end record;

  constant INTERCEPT_STATUS_REPORTER_ERRORS_WIDTH : natural := 2;

  type intercept_path_status_flags_t is record
    channelizer_warnings  : intercept_channelizer_warnings_t;
    channelizer_errors    : intercept_channelizer_errors_t;
    stream_encoder_errors : intercept_stream_encoder_errors_t;
    dwell_stats_errors    : intercept_dwell_stats_errors_t;
  end record;

  constant INTERCEPT_PATH_STATUS_FLAGS_WIDTH : natural := INTERCEPT_CHANNELIZER_WARNINGS_WIDTH +
                                                          INTERCEPT_CHANNELIZER_ERRORS_WIDTH +
                                                          INTERCEPT_STREAM_ENCODER_ERRORS_WIDTH +
                                                          INTERCEPT_DWELL_STATS_ERRORS_WIDTH;

  --function unpack(v : std_logic_vector) return esm_dwell_entry_t;
  --function unpack(v : std_logic_vector) return esm_dwell_program_header_t;
  --function unpack(v : std_logic_vector) return esm_dwell_instruction_t;
  function unpack(v : std_logic_vector) return intercept_config_data_t;

  function pack(v : intercept_channelizer_warnings_t) return std_logic_vector;
  function pack(v : intercept_channelizer_errors_t) return std_logic_vector;
  function pack(v : intercept_dwell_stats_errors_t) return std_logic_vector;
  function pack(v : intercept_stream_encoder_errors_t) return std_logic_vector;
  function pack(v : intercept_status_reporter_errors_t) return std_logic_vector;
  function pack(v : intercept_path_status_flags_t) return std_logic_vector;
  function pack(v : intercept_config_data_t) return std_logic_vector;

end package intercept_pkg;

package body intercept_pkg is

--  function unpack(v : std_logic_vector) return esm_dwell_entry_t is
--    variable vm : std_logic_vector(v'length - 1 downto 0);
--    variable r : esm_dwell_entry_t;
--  begin
--    assert (v'length = ESM_DWELL_ENTRY_PACKED_WIDTH)
--      report "Unexpected length"
--      severity failure;
--
--    vm := v;
--
--    r.tag                     := unsigned(vm(15 downto 0));
--    r.frequency               := unsigned(vm(31 downto 16));
--    r.duration                := unsigned(vm(63 downto 32));
--    r.gain                    := unsigned(vm(70 downto 64));
--    r.fast_lock_profile       := unsigned(vm(74 downto 72));
--    --padding
--    r.threshold_shift_narrow  := unsigned(vm(100 downto 96));
--    r.threshold_shift_wide    := unsigned(vm(108 downto 104));
--    --padding
--    r.channel_mask_narrow     := vm(191 downto 128);
--    r.channel_mask_wide       := vm(199 downto 192);
--    --padding
--    r.min_pulse_duration      := unsigned(vm(223 downto 208));
--    return r;
--  end function;
--
--  function unpack(v : std_logic_vector) return esm_dwell_program_header_t is
--    variable r : esm_dwell_program_header_t;
--  begin
--    assert (v'length = ESM_DWELL_PROGRAM_HEADER_PACKED_WIDTH)
--      report "Unexpected length"
--      severity failure;
--
--    r.enable_program        := v(0);
--    r.enable_delayed_start  := v(8);
--    r.global_counter_init   := unsigned(v(63 downto 32));
--    r.delayed_start_time    := unsigned(v(127 downto 64));
--    return r;
--  end function;
--
--  function unpack(v : std_logic_vector) return esm_dwell_instruction_t is
--    variable r : esm_dwell_instruction_t;
--  begin
--    assert (v'length = ESM_DWELL_INSTRUCTION_PACKED_WIDTH)
--      report "Unexpected length"
--      severity failure;
--
--    r.valid                   := v(0);
--    r.global_counter_check    := v(1);
--    r.global_counter_dec      := v(2);
--    r.skip_pll_prelock_wait   := v(3);
--    r.skip_pll_lock_check     := v(4);
--    r.skip_pll_postlock_wait  := v(5);
--    r.repeat_count            := unsigned(v(11 downto 8));
--    r.entry_index             := unsigned(v(23 downto 16));
--    r.next_instruction_index  := unsigned(v(28 downto 24));
--    return r;
--  end function;

  function unpack(v : std_logic_vector) return intercept_config_data_t is
    variable r : intercept_config_data_t;
  begin
    assert (v'length = INTERCEPT_CONFIG_DATA_WIDTH)
      report "Invalid length."
      severity failure;

    r.valid         := v(0);
    r.first         := v(1);
    r.last          := v(2);
    r.data          := v(34 downto 3);
    r.module_id     := unsigned(v(35 + INTERCEPT_MODULE_ID_WIDTH - 1 downto 35));
    r.message_type  := unsigned(v(35 + INTERCEPT_MODULE_ID_WIDTH + INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 35 + INTERCEPT_MODULE_ID_WIDTH));
    r.address       := unsigned(v(35 + INTERCEPT_MODULE_ID_WIDTH + INTERCEPT_MESSAGE_TYPE_WIDTH + INTERCEPT_CONFIG_ADDRESS_WIDTH - 1 downto 35 + INTERCEPT_MODULE_ID_WIDTH + INTERCEPT_MESSAGE_TYPE_WIDTH));

    return r;
  end function;

  function pack(v : intercept_channelizer_warnings_t) return std_logic_vector is
    variable r : std_logic_vector(INTERCEPT_CHANNELIZER_WARNINGS_WIDTH - 1 downto 0);
  begin
    r(0) := v.demux_gap;
    return r;
  end function;

  function pack(v : intercept_channelizer_errors_t) return std_logic_vector is
    variable r : std_logic_vector(INTERCEPT_CHANNELIZER_ERRORS_WIDTH - 1 downto 0);
  begin
    r := (
          v.mux_collision,
          v.mux_underflow,
          v.mux_overflow,
          v.filter_overflow,
          v.demux_overflow
         );
    return r;
  end function;

  function pack(v : intercept_dwell_stats_errors_t) return std_logic_vector is
    variable r : std_logic_vector(INTERCEPT_DWELL_STATS_ERRORS_WIDTH - 1 downto 0);
  begin
    r := (
          v.reporter_overflow,
          v.reporter_timeout
         );
    return r;
  end function;

  function pack(v : intercept_stream_encoder_errors_t) return std_logic_vector is
    variable r : std_logic_vector(INTERCEPT_STREAM_ENCODER_ERRORS_WIDTH - 1 downto 0);
  begin
    r := (
          v.reporter_overflow,
          v.reporter_timeout
         );
    return r;
  end function;

  function pack(v : intercept_status_reporter_errors_t) return std_logic_vector is
    variable r : std_logic_vector(INTERCEPT_STATUS_REPORTER_ERRORS_WIDTH - 1 downto 0);
  begin
    r := (
          v.reporter_overflow,
          v.reporter_timeout
         );
    return r;
  end function;

  function pack(v : intercept_path_status_flags_t) return std_logic_vector is
    variable r : std_logic_vector(INTERCEPT_PATH_STATUS_FLAGS_WIDTH - 1 downto 0);
  begin
    r := (
          pack(v.dwell_stats_errors),
          pack(v.stream_encoder_errors),
          pack(v.channelizer_errors),
          pack(v.channelizer_warnings)
         );
    return r;
  end function;

  function pack(v : intercept_config_data_t) return std_logic_vector is
    variable r : std_logic_vector(INTERCEPT_CONFIG_DATA_WIDTH - 1 downto 0);
  begin
    r := (std_logic_vector(v.address),
          std_logic_vector(v.message_type),
          std_logic_vector(v.module_id),
          v.data, v.last, v.first, v.valid);

    return r;
  end function;

end package body intercept_pkg;
