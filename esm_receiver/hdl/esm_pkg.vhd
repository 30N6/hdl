library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

package esm_pkg is

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

  constant ESM_CONTROL_MESSAGE_TYPE_ENABLE              : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"00";
  constant ESM_CONTROL_MESSAGE_TYPE_DWELL_ENTRY         : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"01";
  constant ESM_CONTROL_MESSAGE_TYPE_DWELL_PROGRAM       : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"02";
  constant ESM_CONTROL_MESSAGE_TYPE_PDW_SETUP           : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"03";  --TODO: unused?

  constant ESM_REPORT_MESSAGE_TYPE_DWELL_COMPLETE_INFO  : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"10"; --TODO: unused?
  constant ESM_REPORT_MESSAGE_TYPE_DWELL_STATS          : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"11";
  constant ESM_REPORT_MESSAGE_TYPE_PDW_PULSE            : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"20";
  constant ESM_REPORT_MESSAGE_TYPE_PDW_SUMMARY          : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"21";

  constant ESM_NUM_CHANNELS_NARROW                      : natural := 64;
  constant ESM_NUM_CHANNELS_WIDE                        : natural := 8;
  constant ESM_CHANNEL_INDEX_WIDTH                      : natural := clog2(ESM_NUM_CHANNELS_NARROW);

  constant ESM_NUM_FAST_LOCK_PROFILES                   : natural := 8;
  constant ESM_FAST_LOCK_PROFILE_INDEX_WIDTH            : natural := clog2(ESM_NUM_FAST_LOCK_PROFILES);
  constant ESM_NUM_DWELL_ENTRIES                        : natural := 32;
  constant ESM_DWELL_ENTRY_INDEX_WIDTH                  : natural := clog2(ESM_NUM_DWELL_ENTRIES);
  constant ESM_NUM_DWELL_INSTRUCTIONS                   : natural := 32;
  constant ESM_DWELL_INSTRUCTION_INDEX_WIDTH            : natural := clog2(ESM_NUM_DWELL_INSTRUCTIONS);

  constant ESM_DWELL_DURATION_WIDTH                     : natural := 32;
  constant ESM_DWELL_SEQUENCE_NUM_WIDTH                 : natural := 32;
  constant ESM_TIMESTAMP_WIDTH                          : natural := 48;
  constant ESM_THRESHOLD_WIDTH                          : natural := 32;
  constant ESM_PDW_SEQUENCE_NUM_WIDTH                   : natural := 32;
  constant ESM_PDW_POWER_ACCUM_WIDTH                    : natural := 48;
  constant ESM_PDW_CYCLE_COUNT_WIDTH                    : natural := 32;
  constant ESM_PDW_IFM_WIDTH                            : natural := 16;
  constant ESM_PDW_SAMPLE_BUFFER_FRAME_DEPTH            : natural := 16;
  constant ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH      : natural := clog2(ESM_PDW_SAMPLE_BUFFER_FRAME_DEPTH);
  constant ESM_PDW_SAMPLE_BUFFER_SAMPLE_DEPTH           : natural := 64;
  constant ESM_PDW_SAMPLE_BUFFER_SAMPLE_INDEX_WIDTH     : natural := clog2(ESM_PDW_SAMPLE_BUFFER_SAMPLE_DEPTH);

  --type esm_common_header_t is record
  --  magic_num                 : std_logic_vector(31 downto 0);
  --  sequence_num              : unsigned(31 downto 0);
  --  module_id                 : unsigned(ESM_MODULE_ID_WIDTH - 1 downto 0);
  --  message_type              : unsigned(ESM_MESSAGE_TYPE_WIDTH - 1 downto 0);
  --end record;

  --type esm_message_enable_t is record
  --  header                    : esm_common_header_t;
  --  reset                     : std_logic;
  --  enable_channelizer        : std_logic_vector(1 downto 0);
  --  enable_pdw                : std_logic_vector(1 downto 0);
  --end record;

  type esm_dwell_metadata_t is record
    tag                       : unsigned(15 downto 0);
    frequency                 : unsigned(15 downto 0);
    duration                  : unsigned(ESM_DWELL_DURATION_WIDTH - 1 downto 0);
    gain                      : unsigned(6 downto 0);
    fast_lock_profile         : unsigned(ESM_FAST_LOCK_PROFILE_INDEX_WIDTH - 1 downto 0);
    threshold_narrow          : unsigned(ESM_THRESHOLD_WIDTH - 1 downto 0);
    threshold_wide            : unsigned(ESM_THRESHOLD_WIDTH - 1 downto 0);
    channel_mask_narrow       : std_logic_vector(ESM_NUM_CHANNELS_NARROW - 1 downto 0);
    channel_mask_wide         : std_logic_vector(ESM_NUM_CHANNELS_WIDE - 1 downto 0);
  end record;

  type esm_dwell_metadata_array_t is array (natural range <>) of esm_dwell_metadata_t;

  constant ESM_DWELL_METADATA_PACKED_WIDTH : natural := 256;
  --type esm_dwell_metadata_packed_t is record
  --  tag                       : unsigned(15 downto 0);
  --  frequency                 : unsigned(15 downto 0);
  --  duration                  : unsigned(31 downto 0);
  --  gain                      : unsigned(7 downto 0);
  --  fast_lock_profile         : unsigned(7 downto 0);
  --  padding0                  : std_logic_vector(15 downto 0);
  --  threshold_narrow          : unsigned(31 downto 0);
  --  threshold_wide            : unsigned(31 downto 0);
  --  channel_mask_narrow       : std_logic_vector(63 downto 0);
  --  channel_mask_wide         : std_logic_vector(7 downto 0);
  --  padding1                  : std_logic_vector(23 downto 0);
  --end record;

  type esm_message_dwell_entry_t is record
    entry_index               : unsigned(ESM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
    entry_data                : esm_dwell_metadata_t;
  end record;

  constant ESM_MESSAGE_DWELL_ENTRY_PACKED_WIDTH : natural := 32 + ESM_DWELL_METADATA_PACKED_WIDTH;
  --type esm_message_dwell_entry_packed_t is record
  --  entry_index               : unsigned(7 downto 0);
  --  padding                   : std_logic_vector(23 downto 0);
  --  entry_data                : esm_dwell_metadata_packed_t;
  --end record;

  type esm_dwell_instruction_t is record
    valid                     : std_logic;
    global_counter_check      : std_logic;
    global_counter_dec        : std_logic;
    repeat_count              : unsigned(3 downto 0);
    entry_index               : unsigned(ESM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0);
    next_instruction_index    : unsigned(ESM_DWELL_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
  end record;

  constant ESM_DWELL_INSTRUCTION_PACKED_WIDTH : natural := 32;
  --type esm_message_dwell_instruction_packed_t is record
  --  flags                     : std_logic_vector(7 downto 0);
  --  repeat_count              : unsigned(7 downto 0);
  --  entry_index               : unsigned(7 downto 0);
  --  next_instruction_index    : unsigned(7 downto 0);
  --end record;

  type esm_dwell_instruction_array_t is array (natural range <>) of esm_dwell_instruction_t;

  type esm_message_dwell_program_t is record
    --header                    : esm_common_header_t;
    enable_program            : std_logic;
    enable_delayed_start      : std_logic;
    global_counter_init       : unsigned(31 downto 0);
    delayed_start_time        : unsigned(63 downto 0);
    instructions              : esm_dwell_instruction_array_t(ESM_NUM_DWELL_INSTRUCTIONS - 1 downto 0);
  end record;

  type esm_message_dwell_program_header_t is record
    enable_program            : std_logic;
    enable_delayed_start      : std_logic;
    global_counter_init       : unsigned(31 downto 0);
    delayed_start_time        : unsigned(63 downto 0);
  end record;

  constant ESM_MESSAGE_DWELL_PROGRAM_HEADER_PACKED_WIDTH : natural := 128;
  --type esm_message_dwell_program_header_packed_t is record
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
  --  metadata                  : esm_dwell_metadata_t;
  --
  --  num_samples               : unsigned(31 downto 0);
  --  ts_dwell_start            : unsigned(63 downto 0);
  --  ts_dwell_end              : unsigned(63 downto 0);
  --end record;
  --
  --type esm_message_dwell_complete_stats_t is record
  --  header                    : esm_common_header_t;
  --  dwell_sequence_num        : unsigned(ESM_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
  --  metadata                  : esm_dwell_metadata_t;
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
  end record;

  function unpack(v : std_logic_vector) return esm_dwell_metadata_t;
  function unpack(v : std_logic_vector) return esm_message_dwell_entry_t;
  function unpack(v : std_logic_vector) return esm_message_dwell_program_header_t;
  function unpack(v : std_logic_vector) return esm_dwell_instruction_t;
  function unpack(v : std_logic_vector) return esm_pdw_fifo_data_t;
  function pack(v : esm_pdw_fifo_data_t) return std_logic_vector;

end package esm_pkg;

package body esm_pkg is

  function unpack(v : std_logic_vector) return esm_dwell_metadata_t is
    variable vm : std_logic_vector(v'length - 1 downto 0);
    variable r : esm_dwell_metadata_t;
  begin
    assert (v'length = ESM_DWELL_METADATA_PACKED_WIDTH)
      report "Unexpected length"
      severity failure;

    vm := v;

    r.tag                 := unsigned(vm(15 downto 0));
    r.frequency           := unsigned(vm(31 downto 16));
    r.duration            := unsigned(vm(63 downto 32));
    r.gain                := unsigned(vm(70 downto 64));
    r.fast_lock_profile   := unsigned(vm(74 downto 72));
    --padding
    r.threshold_narrow    := unsigned(vm(127 downto 96));
    r.threshold_wide      := unsigned(vm(159 downto 128));
    r.channel_mask_narrow := vm(223 downto 160);
    r.channel_mask_wide   := vm(231 downto 224);
    return r;
  end function;

  function unpack(v : std_logic_vector) return esm_message_dwell_entry_t is
    variable r : esm_message_dwell_entry_t;
  begin
    assert (v'length = ESM_MESSAGE_DWELL_ENTRY_PACKED_WIDTH)
      report "Unexpected length: " & integer'image(v'length)
      severity failure;

    r.entry_index   := unsigned(v(ESM_DWELL_ENTRY_INDEX_WIDTH - 1 downto 0));
    r.entry_data    := unpack(v(32 + ESM_DWELL_METADATA_PACKED_WIDTH - 1 downto 32));
    return r;
  end function;

  function unpack(v : std_logic_vector) return esm_message_dwell_program_header_t is
    variable r : esm_message_dwell_program_header_t;
  begin
    assert (v'length = ESM_MESSAGE_DWELL_PROGRAM_HEADER_PACKED_WIDTH)
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
    r.repeat_count            := unsigned(v(11 downto 8));
    r.entry_index             := unsigned(v(20 downto 16));
    r.next_instruction_index  := unsigned(v(28 downto 24));
    return r;
  end function;

  function unpack(v : std_logic_vector) return esm_pdw_fifo_data_t is
    variable r : esm_pdw_fifo_data_t;
  begin
    assert (v'length = ESM_PDW_FIFO_DATA_WIDTH)
      report "Invalid length."
      severity failure;

    r.sequence_num          := unsigned(v(31 downto 0));
    r.channel               := unsigned(v(37 downto 32));
    r.power_threshold       := unsigned(v(69 downto 38));
    r.power_accum           := unsigned(v(117 downto 70));
    r.duration              := unsigned(v(149 downto 118));
    r.frequency             := unsigned(v(165 downto 150));
    r.pulse_start_time      := unsigned(v(213 downto 166));
    r.buffered_frame_index  := unsigned(v(217 downto 214));
    r.buffered_frame_valid  := v(218);
    return r;
  end function;

  function pack(v : esm_pdw_fifo_data_t) return std_logic_vector is
    variable r : std_logic_vector(ESM_PDW_FIFO_DATA_WIDTH - 1 downto 0);
  begin

    r(31 downto 0)    := std_logic_vector(v.sequence_num);
    r(37 downto 32)   := std_logic_vector(v.channel);
    r(69 downto 38)   := std_logic_vector(v.power_threshold);
    r(117 downto 70)  := std_logic_vector(v.power_accum);
    r(149 downto 118) := std_logic_vector(v.duration);
    r(165 downto 150) := std_logic_vector(v.frequency);
    r(213 downto 166) := std_logic_vector(v.pulse_start_time);
    r(217 downto 214) := std_logic_vector(v.buffered_frame_index);
    r(218)            := v.buffered_frame_valid;

    return r;
  end function;


end package body esm_pkg;