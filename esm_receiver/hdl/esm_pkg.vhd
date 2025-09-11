library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

package esm_pkg is

  constant ESM_MAX_WORDS_PER_PACKET                     : natural := 128;
  constant ESM_CONTROL_MAGIC_NUM                        : std_logic_vector(31 downto 0) := x"45534D43";
  constant ESM_REPORT_MAGIC_NUM                         : std_logic_vector(31 downto 0) := x"45534D52";

  constant ESM_MODULE_ID_WIDTH                          : natural := 8;
  constant ESM_MESSAGE_TYPE_WIDTH                       : natural := 8;

  constant ESM_MODULE_ID_CONTROL                        : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0) := x"00";
  constant ESM_MODULE_ID_DWELL_CONTROLLER               : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0) := x"01";
  constant ESM_MODULE_ID_DWELL_STATS_NARROW             : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0) := x"02";
  constant ESM_MODULE_ID_DWELL_STATS_WIDE               : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0) := x"03";
  constant ESM_MODULE_ID_PDW_NARROW                     : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0) := x"04";
  constant ESM_MODULE_ID_PDW_WIDE                       : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0) := x"05";
  constant ESM_MODULE_ID_STATUS                         : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0) := x"06";

  constant ESM_CONTROL_MESSAGE_TYPE_ENABLE              : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"00";
  constant ESM_CONTROL_MESSAGE_TYPE_DWELL_ENTRY         : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"01";
  constant ESM_CONTROL_MESSAGE_TYPE_DWELL_PROGRAM       : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"02";
  constant ESM_CONTROL_MESSAGE_TYPE_PDW_SETUP           : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"03";  --TODO: unused?

  constant ESM_REPORT_MESSAGE_TYPE_DWELL_COMPLETE_INFO  : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"10"; --TODO: unused?
  constant ESM_REPORT_MESSAGE_TYPE_DWELL_STATS          : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"11";
  constant ESM_REPORT_MESSAGE_TYPE_PDW_PULSE            : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"20";
  constant ESM_REPORT_MESSAGE_TYPE_PDW_SUMMARY          : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"21";
  constant ESM_REPORT_MESSAGE_TYPE_STATUS               : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"30";

  constant ESM_CONFIG_ADDRESS_WIDTH                     : natural := 16;

  constant ESM_NUM_CHANNELS_NARROW                      : natural := 64;
  constant ESM_NUM_CHANNELS_WIDE                        : natural := 8;
  constant ESM_CHANNEL_INDEX_WIDTH                      : natural := clog2(ESM_NUM_CHANNELS_NARROW);

  constant ESM_NUM_FAST_LOCK_PROFILES                   : natural := 8;
  constant ESM_FAST_LOCK_PROFILE_INDEX_WIDTH            : natural := clog2(ESM_NUM_FAST_LOCK_PROFILES);
  constant ESM_NUM_DWELL_ENTRIES                        : natural := 256;
  constant ESM_DWELL_ENTRY_INDEX_WIDTH                  : natural := clog2(ESM_NUM_DWELL_ENTRIES);
  constant ESM_NUM_DWELL_INSTRUCTIONS                   : natural := 32;
  constant ESM_DWELL_INSTRUCTION_INDEX_WIDTH            : natural := clog2(ESM_NUM_DWELL_INSTRUCTIONS);

  constant ESM_DWELL_DURATION_WIDTH                     : natural := 32;
  constant ESM_DWELL_SEQUENCE_NUM_WIDTH                 : natural := 32;
  constant ESM_TIMESTAMP_WIDTH                          : natural := 48;
  constant ESM_THRESHOLD_SHIFT_WIDTH                    : natural := 5;
  constant ESM_MIN_DURATION_WIDTH                       : natural := 16;
  constant ESM_PDW_SEQUENCE_NUM_WIDTH                   : natural := 32;
  constant ESM_PDW_POWER_ACCUM_WIDTH                    : natural := 48;
  constant ESM_PDW_CYCLE_COUNT_WIDTH                    : natural := 32;
  constant ESM_PDW_IFM_WIDTH                            : natural := 16;
  constant ESM_PDW_SAMPLE_BUFFER_FRAME_DEPTH            : natural := 64;
  constant ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH      : natural := clog2(ESM_PDW_SAMPLE_BUFFER_FRAME_DEPTH);
  constant ESM_PDW_SAMPLE_BUFFER_SAMPLE_DEPTH           : natural := 128;
  constant ESM_PDW_SAMPLE_BUFFER_SAMPLE_INDEX_WIDTH     : natural := clog2(ESM_PDW_SAMPLE_BUFFER_SAMPLE_DEPTH);
  constant ESM_PDW_BUFFERED_SAMPLES_PER_FRAME           : natural := 112;
  constant ESM_PDW_BUFFERED_IQ_DELAY_SAMPLES            : natural := 8;

  --type esm_common_header_t is record
  --  magic_num                 : std_logic_vector(31 downto 0);
  --  sequence_num              : unsigned(31 downto 0);
  --  module_id                 : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0);
  --  message_type              : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0);
  --  address                   : unsigned(ESM_CONFIG_ADDRESS_WIDTH - 1 downto 0);
  --end record;
  constant ESM_COMMON_HEADER_WIDTH  : natural := 96;

  --type esm_message_enable_t is record
  --  header                    : esm_common_header_t;
  --  reset                     : std_logic;
  --  enable_channelizer        : std_logic_vector(1 downto 0);
  --  enable_pdw                : std_logic_vector(1 downto 0);
  --end record;

  type esm_dwell_entry_t is record
    tag                       : unsigned(15 downto 0);
    frequency                 : unsigned(15 downto 0);
    duration                  : unsigned(ESM_DWELL_DURATION_WIDTH - 1 downto 0);
    gain                      : unsigned(6 downto 0);
    fast_lock_profile         : unsigned(ESM_FAST_LOCK_PROFILE_INDEX_WIDTH - 1 downto 0);
    threshold_shift_narrow    : unsigned(ESM_THRESHOLD_SHIFT_WIDTH - 1 downto 0);
    threshold_shift_wide      : unsigned(ESM_THRESHOLD_SHIFT_WIDTH - 1 downto 0);
    channel_mask_narrow       : std_logic_vector(ESM_NUM_CHANNELS_NARROW - 1 downto 0);
    channel_mask_wide         : std_logic_vector(ESM_NUM_CHANNELS_WIDE - 1 downto 0);
    min_pulse_duration        : unsigned(ESM_MIN_DURATION_WIDTH - 1 downto 0);
  end record;

  type esm_dwell_entry_array_t is array (natural range <>) of esm_dwell_entry_t;

  constant ESM_DWELL_ENTRY_PACKED_WIDTH : natural := 224;
  --type esm_dwell_entry_packed_t is record
  --  tag                       : unsigned(15 downto 0);
  --  frequency                 : unsigned(15 downto 0);
  --  duration                  : unsigned(31 downto 0);
  --  gain                      : unsigned(7 downto 0);
  --  fast_lock_profile         : unsigned(7 downto 0);
  --  padding0                  : std_logic_vector(15 downto 0);
  --  threshold_shift_narrow    : unsigned(4 downto 0);
  --  padding_t0                : std_logic_vector(2 downto 0);
  --  threshold_shift_wide      : unsigned(4 downto 0);
  --  padding_t1                : std_logic_vector(2 downto 0);
  --  padding1                  : std_logic_vector(15 downto 0);
  --  channel_mask_narrow       : std_logic_vector(63 downto 0);
  --  channel_mask_wide         : std_logic_vector(7 downto 0);
  --  padding1                  : std_logic_vector(7 downto 0);
  --  min_pulse_duration        : unsigned(15 downto 0);
  --end record;

  type esm_dwell_instruction_t is record
    valid                     : std_logic;
    global_counter_check      : std_logic;
    global_counter_dec        : std_logic;
    skip_pll_prelock_wait     : std_logic;
    skip_pll_lock_check       : std_logic;
    skip_pll_postlock_wait    : std_logic;
    repeat_count              : unsigned(3 downto 0);
    entry_index               : unsigned(ESM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
    next_instruction_index    : unsigned(ESM_DWELL_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
  end record;

  constant ESM_DWELL_INSTRUCTION_PACKED_WIDTH : natural := 32;
  --type esm_dwell_instruction_packed_t is record
  --  flags                     : std_logic_vector(7 downto 0);
  --  repeat_count              : unsigned(7 downto 0);
  --  entry_index               : unsigned(7 downto 0);
  --  next_instruction_index    : unsigned(7 downto 0);
  --end record;

  type esm_dwell_instruction_array_t is array (natural range <>) of esm_dwell_instruction_t;

  type esm_dwell_program_t is record
    --header                    : esm_common_header_t;
    enable_program            : std_logic;
    enable_delayed_start      : std_logic;
    global_counter_init       : unsigned(31 downto 0);
    delayed_start_time        : unsigned(63 downto 0);
    instructions              : esm_dwell_instruction_array_t(ESM_NUM_DWELL_INSTRUCTIONS - 1 downto 0);
  end record;

  type esm_dwell_program_header_t is record
    enable_program            : std_logic;
    enable_delayed_start      : std_logic;
    global_counter_init       : unsigned(31 downto 0);
    delayed_start_time        : unsigned(63 downto 0);
  end record;

  constant ESM_DWELL_PROGRAM_HEADER_PACKED_WIDTH : natural := 128;
  --type esm_dwell_program_header_packed_t is record
  --  --header                    : esm_common_header_t;
  --  enable_program            : std_logic_vector(7 downto 0);
  --  enable_delayed_start      : std_logic_vector(7 downto 0);
  --  padding                   : std_logic_vector(15 downto 0);
  --  global_counter_init       : unsigned(31 downto 0);
  --  delayed_start_time        : unsigned(63 downto 0);
  --  --instructions              : esm_dwell_instruction_array_packed_t(ESM_NUM_DWELL_INSTRUCTIONS - 1 downto 0);
  --end record;

  --TODO: add reporting?
  --type esm_message_dwell_complete_info_t is record
  --  header                    : esm_common_header_t;
  --  dwell_sequence_num        : unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  --  metadata                  : esm_dwell_entry_t;
  --
  --  num_samples               : unsigned(31 downto 0);
  --  ts_dwell_start            : unsigned(63 downto 0);
  --  ts_dwell_end              : unsigned(63 downto 0);
  --end record;
  --
  --type esm_message_dwell_complete_stats_t is record
  --  header                    : esm_common_header_t;
  --  dwell_sequence_num        : unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  --  metadata                  : esm_dwell_entry_t;
  --  duration_actual           : unsigned(31 downto 0);
  --  num_samples               : unsigned(31 downto 0);
  --  ts_dwell_start            : unsigned(63 downto 0);
  --  ts_dwell_end              : unsigned(63 downto 0);
  --
  --  -- array of 128 bit entries: index, accum, max
  --end record;
  --
  --type esm_message_pdw_t is record
  --  header                    : esm_common_header_t;
  --  dwell_sequence_num        : unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  --  pdw_sequence_num          : unsigned(31 downto 0);
  --  pulse_channel             : unsigned(ESM_CHANNEL_INDEX_WIDTH - 1 downto 0);
  --  pulse_threshold           : unsigned(31 downto 0);
  --  pulse_power_accum         : unsigned(63 downto 0);
  --  pulse_duration            : unsigned(31 downto 0);  --TODO: early termination flag?
  --  pulse_frequency           : unsigned(31 downto 0);  --TODO: IFM module
  --  pulse_start_time          : unsigned(63 downto 0);  --TODO: end time instead?
  --  raw_samples               : std_logic_vector_array_t(40 downto 0)(31 downto 0); --TODO: increase to max
  --end record;

  type esm_pdw_sample_buffer_req_t is record
    frame_index   : unsigned(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
    frame_read    : std_logic;
    frame_drop    : std_logic;
  end record;

  type esm_pdw_sample_buffer_ack_t is record
    sample_index  : unsigned(ESM_PDW_SAMPLE_BUFFER_SAMPLE_INDEX_WIDTH - 1 downto 0);
    sample_last   : std_logic;
    sample_valid  : std_logic;
  end record;

  type esm_pdw_fifo_data_t is record
    sequence_num                : unsigned(ESM_PDW_SEQUENCE_NUM_WIDTH - 1 downto 0);
    channel                     : unsigned(ESM_CHANNEL_INDEX_WIDTH - 1 downto 0);
    power_threshold             : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
    power_accum                 : unsigned(ESM_PDW_POWER_ACCUM_WIDTH - 1 downto 0);
    duration                    : unsigned(ESM_PDW_CYCLE_COUNT_WIDTH - 1 downto 0);
    frequency                   : unsigned(ESM_PDW_IFM_WIDTH - 1 downto 0);
    pulse_start_time            : unsigned(ESM_TIMESTAMP_WIDTH - 1 downto 0);
    buffered_frame_index        : unsigned(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
    buffered_frame_valid        : std_logic;
  end record;
  constant ESM_PDW_FIFO_DATA_WIDTH : natural :=  ESM_PDW_SEQUENCE_NUM_WIDTH + ESM_CHANNEL_INDEX_WIDTH + CHAN_POWER_WIDTH + ESM_PDW_POWER_ACCUM_WIDTH +
                                                 ESM_PDW_CYCLE_COUNT_WIDTH + ESM_PDW_IFM_WIDTH + ESM_TIMESTAMP_WIDTH + ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH +
                                                 1;

  type esm_config_data_t is record
    valid                     : std_logic;
    first                     : std_logic;
    last                      : std_logic;
    data                      : std_logic_vector(31 downto 0);
    module_id                 : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0);
    message_type              : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0);
    address                   : unsigned(ESM_CONFIG_ADDRESS_WIDTH - 1 downto 0);
  end record;
  constant ESM_CONFIG_DATA_WIDTH : natural := 3 + 32 + ESM_MODULE_ID_WIDTH + ESM_MESSAGE_TYPE_WIDTH + ESM_CONFIG_ADDRESS_WIDTH;

  type esm_channelizer_warnings_t is record
    demux_gap       : std_logic;
  end record;

  type esm_channelizer_warnings_array_t is array (natural range <>) of esm_channelizer_warnings_t;

  constant ESM_CHANNELIZER_WARNINGS_WIDTH : natural := 1;

  type esm_channelizer_errors_t is record
    demux_overflow  : std_logic;
    filter_overflow : std_logic;
    mux_overflow    : std_logic;
    mux_underflow   : std_logic;
    mux_collision   : std_logic;
  end record;

  constant ESM_CHANNELIZER_ERRORS_WIDTH : natural := 5;

  type esm_channelizer_errors_array_t is array (natural range <>) of esm_channelizer_errors_t;

  type esm_dwell_stats_errors_t is record
    reporter_timeout  : std_logic;
    reporter_overflow : std_logic;
  end record;

  constant ESM_DWELL_STATS_ERRORS_WIDTH : natural := 2;

  type esm_dwell_stats_errors_array_t is array (natural range <>) of esm_dwell_stats_errors_t;

  type esm_pdw_encoder_errors_t is record
    pdw_fifo_busy           : std_logic;
    pdw_fifo_overflow       : std_logic;
    pdw_fifo_underflow      : std_logic;
    sample_buffer_busy      : std_logic;
    sample_buffer_underflow : std_logic;
    sample_buffer_overflow  : std_logic;
    reporter_timeout        : std_logic;
    reporter_overflow       : std_logic;
  end record;

  constant ESM_PDW_ENCODER_ERRORS_WIDTH : natural := 8;

  type esm_pdw_encoder_errors_array_t is array (natural range <>) of esm_pdw_encoder_errors_t;

  type esm_status_reporter_errors_t is record
    reporter_timeout  : std_logic;
    reporter_overflow : std_logic;
  end record;

  constant ESM_STATUS_REPORTER_ERRORS_WIDTH : natural := 2;

  type esm_path_status_flags_t is record
    channelizer_warnings  : esm_channelizer_warnings_t;
    channelizer_errors    : esm_channelizer_errors_t;
    dwell_stats_errors    : esm_dwell_stats_errors_t;
    pdw_encoder_errors    : esm_pdw_encoder_errors_t;
  end record;

  constant ESM_PATH_STATUS_FLAGS_WIDTH : natural := ESM_CHANNELIZER_WARNINGS_WIDTH +
                                                    ESM_CHANNELIZER_ERRORS_WIDTH +
                                                    ESM_DWELL_STATS_ERRORS_WIDTH +
                                                    ESM_PDW_ENCODER_ERRORS_WIDTH;

  type esm_path_status_flags_array_t is array (natural range <>) of esm_path_status_flags_t;

  function unpack(v : std_logic_vector) return esm_dwell_entry_t;
  function unpack(v : std_logic_vector) return esm_dwell_program_header_t;
  function unpack(v : std_logic_vector) return esm_dwell_instruction_t;
  function unpack(v : std_logic_vector) return esm_pdw_fifo_data_t;
  function unpack(v : std_logic_vector) return esm_config_data_t;

  function pack(v : esm_pdw_fifo_data_t) return std_logic_vector;
  function pack(v : esm_channelizer_warnings_t) return std_logic_vector;
  function pack(v : esm_channelizer_errors_t) return std_logic_vector;
  function pack(v : esm_dwell_stats_errors_t) return std_logic_vector;
  function pack(v : esm_pdw_encoder_errors_t) return std_logic_vector;
  function pack(v : esm_status_reporter_errors_t) return std_logic_vector;
  function pack(v : esm_path_status_flags_t) return std_logic_vector;
  function pack(v : esm_config_data_t) return std_logic_vector;

end package esm_pkg;

package body esm_pkg is

  function unpack(v : std_logic_vector) return esm_dwell_entry_t is
    variable vm : std_logic_vector(v'length - 1 downto 0);
    variable r : esm_dwell_entry_t;
  begin
    assert (v'length = ESM_DWELL_ENTRY_PACKED_WIDTH)
      report "Unexpected length"
      severity failure;

    vm := v;

    r.tag                     := unsigned(vm(15 downto 0));
    r.frequency               := unsigned(vm(31 downto 16));
    r.duration                := unsigned(vm(63 downto 32));
    r.gain                    := unsigned(vm(70 downto 64));
    r.fast_lock_profile       := unsigned(vm(74 downto 72));
    --padding
    r.threshold_shift_narrow  := unsigned(vm(100 downto 96));
    r.threshold_shift_wide    := unsigned(vm(108 downto 104));
    --padding
    r.channel_mask_narrow     := vm(191 downto 128);
    r.channel_mask_wide       := vm(199 downto 192);
    --padding
    r.min_pulse_duration      := unsigned(vm(223 downto 208));
    return r;
  end function;

  function unpack(v : std_logic_vector) return esm_dwell_program_header_t is
    variable r : esm_dwell_program_header_t;
  begin
    assert (v'length = ESM_DWELL_PROGRAM_HEADER_PACKED_WIDTH)
      report "Unexpected length"
      severity failure;

    r.enable_program        := v(0);
    r.enable_delayed_start  := v(8);
    r.global_counter_init   := unsigned(v(63 downto 32));
    r.delayed_start_time    := unsigned(v(127 downto 64));
    return r;
  end function;

  function unpack(v : std_logic_vector) return esm_dwell_instruction_t is
    variable r : esm_dwell_instruction_t;
  begin
    assert (v'length = ESM_DWELL_INSTRUCTION_PACKED_WIDTH)
      report "Unexpected length"
      severity failure;

    r.valid                   := v(0);
    r.global_counter_check    := v(1);
    r.global_counter_dec      := v(2);
    r.skip_pll_prelock_wait   := v(3);
    r.skip_pll_lock_check     := v(4);
    r.skip_pll_postlock_wait  := v(5);
    r.repeat_count            := unsigned(v(11 downto 8));
    r.entry_index             := unsigned(v(23 downto 16));
    r.next_instruction_index  := unsigned(v(28 downto 24));
    return r;
  end function;

  function unpack(v : std_logic_vector) return esm_pdw_fifo_data_t is
    variable r : esm_pdw_fifo_data_t;
  begin
    assert (v'length = ESM_PDW_FIFO_DATA_WIDTH)
      report "Invalid length."
      severity failure;

    --TODO: use new style
    r.sequence_num          := unsigned(v(31 downto 0));
    r.channel               := unsigned(v(37 downto 32));
    r.power_threshold       := unsigned(v(69 downto 38));
    r.power_accum           := unsigned(v(117 downto 70));
    r.duration              := unsigned(v(149 downto 118));
    r.frequency             := unsigned(v(165 downto 150));
    r.pulse_start_time      := unsigned(v(213 downto 166));
    r.buffered_frame_index  := unsigned(v(219 downto 214));
    r.buffered_frame_valid  := v(220);
    return r;
  end function;

  function unpack(v : std_logic_vector) return esm_config_data_t is
    variable r : esm_config_data_t;
  begin
    assert (v'length = ESM_CONFIG_DATA_WIDTH)
      report "Invalid length."
      severity failure;

    r.valid         := v(0);
    r.first         := v(1);
    r.last          := v(2);
    r.data          := v(34 downto 3);
    r.module_id     := unsigned(v(35 + ESM_MODULE_ID_WIDTH - 1 downto 35));
    r.message_type  := unsigned(v(35 + ESM_MODULE_ID_WIDTH + ESM_MESSAGE_TYPE_WIDTH - 1 downto 35 + ESM_MODULE_ID_WIDTH));
    r.address       := unsigned(v(35 + ESM_MODULE_ID_WIDTH + ESM_MESSAGE_TYPE_WIDTH + ESM_CONFIG_ADDRESS_WIDTH - 1 downto 35 + ESM_MODULE_ID_WIDTH + ESM_MESSAGE_TYPE_WIDTH));

    return r;
  end function;


  function pack(v : esm_pdw_fifo_data_t) return std_logic_vector is
    variable r : std_logic_vector(ESM_PDW_FIFO_DATA_WIDTH - 1 downto 0);
  begin
    --TODO: use new style
    r(31 downto 0)    := std_logic_vector(v.sequence_num);
    r(37 downto 32)   := std_logic_vector(v.channel);
    r(69 downto 38)   := std_logic_vector(v.power_threshold);
    r(117 downto 70)  := std_logic_vector(v.power_accum);
    r(149 downto 118) := std_logic_vector(v.duration);
    r(165 downto 150) := std_logic_vector(v.frequency);
    r(213 downto 166) := std_logic_vector(v.pulse_start_time);
    r(219 downto 214) := std_logic_vector(v.buffered_frame_index);
    r(220)            := v.buffered_frame_valid;

    return r;
  end function;

  function pack(v : esm_channelizer_warnings_t) return std_logic_vector is
    variable r : std_logic_vector(ESM_CHANNELIZER_WARNINGS_WIDTH - 1 downto 0);
  begin
    r(0) := v.demux_gap;
    return r;
  end function;

  function pack(v : esm_channelizer_errors_t) return std_logic_vector is
    variable r : std_logic_vector(ESM_CHANNELIZER_ERRORS_WIDTH - 1 downto 0);
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

  function pack(v : esm_dwell_stats_errors_t) return std_logic_vector is
    variable r : std_logic_vector(ESM_DWELL_STATS_ERRORS_WIDTH - 1 downto 0);
  begin
    r := (
          v.reporter_overflow,
          v.reporter_timeout
         );
    return r;
  end function;

  function pack(v : esm_pdw_encoder_errors_t) return std_logic_vector is
    variable r : std_logic_vector(ESM_PDW_ENCODER_ERRORS_WIDTH - 1 downto 0);
  begin
    r := (
          v.reporter_overflow,
          v.reporter_timeout,
          v.sample_buffer_overflow,
          v.sample_buffer_underflow,
          v.sample_buffer_busy,
          v.pdw_fifo_underflow,
          v.pdw_fifo_overflow,
          v.pdw_fifo_busy
         );
    return r;
  end function;

  function pack(v : esm_status_reporter_errors_t) return std_logic_vector is
    variable r : std_logic_vector(ESM_STATUS_REPORTER_ERRORS_WIDTH - 1 downto 0);
  begin
    r := (
          v.reporter_overflow,
          v.reporter_timeout
         );
    return r;
  end function;

  function pack(v : esm_path_status_flags_t) return std_logic_vector is
    variable r : std_logic_vector(ESM_PATH_STATUS_FLAGS_WIDTH - 1 downto 0);
  begin
    r := (
          pack(v.pdw_encoder_errors),
          pack(v.dwell_stats_errors),
          pack(v.channelizer_errors),
          pack(v.channelizer_warnings)
         );
    return r;
  end function;

  function pack(v : esm_config_data_t) return std_logic_vector is
    variable r : std_logic_vector(ESM_CONFIG_DATA_WIDTH - 1 downto 0);
  begin
    r := (std_logic_vector(v.address),
          std_logic_vector(v.message_type),
          std_logic_vector(v.module_id),
          v.data, v.last, v.first, v.valid);

    --TODO: cleanup
    --r(0)             := v.valid;
    --r(1)             := v.first;
    --r(2)             := v.last;
    --r(34 downto 3)   := v.data;
    --r(35 + ESM_MODULE_ID_WIDTH - 1 downto 35)                                                 := std_logic_vector(v.module_id);
    --r(35 + ESM_MODULE_ID_WIDTH + ESM_MESSAGE_TYPE_WIDTH - 1 downto 35 + ESM_MODULE_ID_WIDTH)  := std_logic_vector(v.message_type);

    return r;
  end function;


end package body esm_pkg;