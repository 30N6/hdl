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
  constant INTERCEPT_MODULE_ID_STREAM_ENCODER                   : unsigned(INTERCEPT_MODULE_ID_WIDTH - 1 downto 0) := x"03";
  constant INTERCEPT_MODULE_ID_STATUS                           : unsigned(INTERCEPT_MODULE_ID_WIDTH - 1 downto 0) := x"07";

  constant INTERCEPT_CONTROL_MESSAGE_TYPE_ENABLE                  : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"00";
  constant INTERCEPT_CONTROL_MESSAGE_TYPE_DWELL_CONTROLLER_CONFIG : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"01";
  constant INTERCEPT_CONTROL_MESSAGE_TYPE_CHANNEL_CONFIG          : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"02";
  constant INTERCEPT_CONTROL_MESSAGE_TYPE_STREAM_CONFIG           : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"03";

  constant INTERCEPT_REPORT_MESSAGE_TYPE_DWELL_STATS            : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"10";
  constant INTERCEPT_REPORT_MESSAGE_TYPE_STREAM                 : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"20";
  constant INTERCEPT_REPORT_MESSAGE_TYPE_STATUS                 : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0) := x"30";

  constant INTERCEPT_CONFIG_ADDRESS_WIDTH                       : natural := 16;

  constant INTERCEPT_NUM_CHANNELS                               : natural := 512;
  constant INTERCEPT_CHANNEL_INDEX_WIDTH                        : natural := clog2(INTERCEPT_NUM_CHANNELS);

  constant INTERCEPT_NUM_STREAMS                                : natural := 16;
  constant INTERCEPT_STREAM_INDEX_WIDTH                         : natural := clog2(INTERCEPT_NUM_STREAMS);

  constant INTERCEPT_TAG_WIDTH                                  : natural := 16;
  constant INTERCEPT_DWELL_DURATION_MAX_FRAMES                  : natural := 65535;
  constant INTERCEPT_DWELL_DURATION_MIN_FRAMES                  : natural := 16;
  constant INTERCEPT_DWELL_DURATION_WIDTH                       : natural := clog2(INTERCEPT_DWELL_DURATION_MAX_FRAMES);
  constant INTERCEPT_DWELL_SEQUENCE_NUM_WIDTH                   : natural := 32;
  constant INTERCEPT_DWELL_FREQUENCY_WIDTH                      : natural := 32;
  constant INTERCEPT_TIMESTAMP_WIDTH                            : natural := 48;

  constant INTERCEPT_STREAM_COAST_DURATION_WIDTH                : natural := 24;
  constant INTERCEPT_STREAM_INTEGRATION_TIME_WIDTH              : natural := 16;
  constant INTERCEPT_STREAM_POWER_ACCUM_WIDTH                   : natural := CHAN_POWER_WIDTH + INTERCEPT_STREAM_INTEGRATION_TIME_WIDTH;
  constant INTERCEPT_STREAM_SAMPLE_INDEX_WIDTH                  : natural := 32;

  constant INTERCEPT_STREAM_TRIGGER_TYPE_NORMAL                 : natural := 0;
  constant INTERCEPT_STREAM_TRIGGER_TYPE_COAST                  : natural := 1;
  constant INTERCEPT_STREAM_TRIGGER_TYPE_FORCED                 : natural := 2;
  constant INTERCEPT_STREAM_TRIGGER_TYPE_LAST                   : natural := 3;
  constant INTERCEPT_STREAM_TRIGGER_TYPE_WIDTH                  : natural := clog2(INTERCEPT_STREAM_TRIGGER_TYPE_LAST + 1);

  type intercept_common_header_t is record
    magic_num                 : std_logic_vector(31 downto 0);
    sequence_num              : unsigned(31 downto 0);
    module_id                 : unsigned(INTERCEPT_MODULE_ID_WIDTH - 1 downto 0);
    message_type              : unsigned(INTERCEPT_MESSAGE_TYPE_WIDTH - 1 downto 0);
    address                   : unsigned(INTERCEPT_CONFIG_ADDRESS_WIDTH - 1 downto 0);
    padding                   : std_logic_vector(31 downto 0);
  end record;
  constant INTERCEPT_COMMON_HEADER_WIDTH  : natural := 128;

  --type intercept_message_enable_t is record
  --  header                    : intercept_common_header_t;
  --  reset                     : std_logic;
  --  enable_channelizer        : std_logic;
  --  enable_stream             : std_logic;
  --  enable_status             : std_logic;
  --end record;

  type intercept_message_dwell_controller_control_t is record
    enable                      : std_logic;
    dwell_tag                   : unsigned(INTERCEPT_TAG_WIDTH - 1 downto 0);
    dwell_frequency             : unsigned(INTERCEPT_DWELL_FREQUENCY_WIDTH - 1 downto 0);
    window_duration             : unsigned(INTERCEPT_DWELL_DURATION_WIDTH - 1 downto 0);
  end record;

  type intercept_message_dwell_controller_control_aligned_t is record
    enable                      : std_logic_vector(7 downto 0);
    padding0                    : std_logic_vector(7 downto 0);
    dwell_tag                   : std_logic_vector(15 downto 0);
    dwell_frequency             : std_logic_vector(31 downto 0);
    window_duration             : std_logic_vector(31 downto 0);
  end record;
  constant INTERCEPT_MESSAGE_DWELL_CONTROLLER_CONTROL_ALIGNED_WIDTH : natural := 96;

 --config address is the channel index
  type intercept_message_stream_encoder_channel_control_t is record
    enable                      : std_logic;
    force_trigger               : std_logic;
    force_stream                : unsigned(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0);
    stream_encoder_tag          : unsigned(INTERCEPT_TAG_WIDTH - 1 downto 0);
    threshold_start             : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
    threshold_continue          : unsigned(CHAN_POWER_WIDTH - 1 downto 0);
    coast_cycles                : unsigned(INTERCEPT_STREAM_COAST_DURATION_WIDTH - 1 downto 0);
    integration_cycles          : unsigned(INTERCEPT_STREAM_INTEGRATION_TIME_WIDTH - 1 downto 0); --TODO: implement
  end record;
  type intercept_message_stream_encoder_channel_control_array_t is array (natural range <>) of intercept_message_stream_encoder_channel_control_t;

  type intercept_message_stream_encoder_channel_control_aligned_t is record
    enable                      : std_logic_vector(7 downto 0);
    force_trigger               : std_logic_vector(7 downto 0);
    force_stream                : std_logic_vector(7 downto 0);
    padding0                    : std_logic_vector(7 downto 0);
    stream_encoder_tag          : std_logic_vector(15 downto 0);
    padding1                    : std_logic_vector(15 downto 0);
    threshold_start             : std_logic_vector(31 downto 0);
    threshold_continue          : std_logic_vector(31 downto 0);
    coast_cycles                : std_logic_vector(31 downto 0);
    integration_cycles          : std_logic_vector(31 downto 0);
  end record;
  constant INTERCEPT_MESSAGE_STREAM_ENCODER_CHANNEL_CONTROL_ALIGNED_WIDTH : natural := 192;

 --config address is the stream index
  type intercept_message_stream_encoder_stream_control_t is record
    enable                      : std_logic;
    stream_encoder_tag          : unsigned(INTERCEPT_TAG_WIDTH - 1 downto 0);
  end record;
  type intercept_message_stream_encoder_stream_control_array_t is array (natural range <>) of intercept_message_stream_encoder_stream_control_t;

  type intercept_message_stream_encoder_stream_control_aligned_t is record
    enable                      : std_logic_vector(7 downto 0);
    padding0                    : std_logic_vector(7 downto 0);
    stream_encoder_tag          : std_logic_vector(15 downto 0);
  end record;
  constant INTERCEPT_MESSAGE_STREAM_ENCODER_STREAM_CONTROL_ALIGNED_WIDTH : natural := 32;

  type intercept_dwell_data_t is record
    sequence_num                : unsigned(INTERCEPT_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
    frequency                   : unsigned(INTERCEPT_DWELL_FREQUENCY_WIDTH - 1 downto 0);
    tag                         : unsigned(INTERCEPT_TAG_WIDTH - 1 downto 0);
    window_duration             : unsigned(INTERCEPT_DWELL_DURATION_WIDTH - 1 downto 0);
  end record;
  constant INTERCEPT_DWELL_DATA_WIDTH : natural := INTERCEPT_DWELL_SEQUENCE_NUM_WIDTH + INTERCEPT_DWELL_FREQUENCY_WIDTH + INTERCEPT_TAG_WIDTH + INTERCEPT_DWELL_DURATION_WIDTH;

  type intercept_message_dwell_stats_report_t is record
    header                      : intercept_common_header_t;  -- 128
    dwell_data                  : intercept_dwell_data_t;     -- 96
    window_sequence_num         : unsigned(INTERCEPT_DWELL_SEQUENCE_NUM_WIDTH - 1 downto 0);
    window_timestamp            : unsigned(63 downto 0);

    -- array of 128 bit entries: index, accum, max
  end record;

  type intercept_stream_sample_t is record
    trigger_type                : unsigned(INTERCEPT_STREAM_TRIGGER_TYPE_WIDTH - 1 downto 0);
    stream_index                : unsigned(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0);
    channel_index               : unsigned(INTERCEPT_CHANNEL_INDEX_WIDTH - 1 downto 0);
    sample_index                : unsigned(INTERCEPT_STREAM_SAMPLE_INDEX_WIDTH - 1 downto 0);
    data_i                      : signed(25 downto 0);
    data_q                      : signed(25 downto 0);
  end record;
  constant INTERCEPT_STREAM_SAMPLE_WIDTH : natural := INTERCEPT_STREAM_TRIGGER_TYPE_WIDTH + INTERCEPT_STREAM_INDEX_WIDTH + INTERCEPT_CHANNEL_INDEX_WIDTH + 2*26;

  type intercept_stream_sample_aligned_t is record
    trigger_type                : unsigned(7 downto 0);
    stream_index                : unsigned(7 downto 0);
    channel_index               : unsigned(15 downto 0);
    sample_index                : unsigned(31 downto 0);
    data_i                      : signed(31 downto 0);
    data_q                      : signed(31 downto 0);
  end record;
  constant INTERCEPT_STREAM_SAMPLE_ALIGNED_WIDTH : natural := 128;

  type intercept_message_stream_report_t is record
    header                      : intercept_common_header_t;    -- 128
    dwell_data                  : intercept_dwell_data_t;       -- 96
    padding1                    : std_logic_vector(31 downto 0);
    timestamp                   : unsigned(63 downto 0);

    -- array of intercept_stream_sample_aligned_t: stream index, channel index, sample index, trigger type, IQ
  end record;

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
    reporter_busy     : std_logic;
    reporter_timeout  : std_logic;
    reporter_overflow : std_logic;
  end record;

  constant INTERCEPT_DWELL_STATS_ERRORS_WIDTH : natural := 3;

  type intercept_stream_encoder_errors_t is record
    fifo_overflow     : std_logic;
    fifo_underflow    : std_logic;
    reporter_timeout  : std_logic;
    reporter_overflow : std_logic;
  end record;

  constant INTERCEPT_STREAM_ENCODER_ERRORS_WIDTH : natural := 4;

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
  function unpack(v : std_logic_vector(INTERCEPT_DWELL_DATA_WIDTH - 1 downto 0)) return intercept_dwell_data_t;
  function unpack(v : std_logic_vector(INTERCEPT_STREAM_SAMPLE_WIDTH - 1 downto 0)) return intercept_stream_sample_t;
  function unpack(v : std_logic_vector(INTERCEPT_CONFIG_DATA_WIDTH - 1 downto 0)) return intercept_config_data_t;
  function unpack_aligned(v : std_logic_vector(INTERCEPT_MESSAGE_DWELL_CONTROLLER_CONTROL_ALIGNED_WIDTH - 1 downto 0)) return intercept_message_dwell_controller_control_t;
  function unpack_aligned(v : std_logic_vector(INTERCEPT_MESSAGE_STREAM_ENCODER_CHANNEL_CONTROL_ALIGNED_WIDTH - 1 downto 0)) return intercept_message_stream_encoder_channel_control_t;
  function unpack_aligned(v : std_logic_vector(INTERCEPT_MESSAGE_STREAM_ENCODER_STREAM_CONTROL_ALIGNED_WIDTH - 1 downto 0)) return intercept_message_stream_encoder_stream_control_t;

  function pack(v : intercept_dwell_data_t) return std_logic_vector;
  function pack(v : intercept_stream_sample_t) return std_logic_vector;
  function pack(v : intercept_stream_sample_aligned_t) return std_logic_vector;
  function pack(v : intercept_channelizer_warnings_t) return std_logic_vector;
  function pack(v : intercept_channelizer_errors_t) return std_logic_vector;
  function pack(v : intercept_dwell_stats_errors_t) return std_logic_vector;
  function pack(v : intercept_stream_encoder_errors_t) return std_logic_vector;
  function pack(v : intercept_status_reporter_errors_t) return std_logic_vector;
  function pack(v : intercept_path_status_flags_t) return std_logic_vector;
  function pack(v : intercept_config_data_t) return std_logic_vector;

end package intercept_pkg;

package body intercept_pkg is

  function unpack(v : std_logic_vector(INTERCEPT_DWELL_DATA_WIDTH - 1 downto 0)) return intercept_dwell_data_t is
    variable r : intercept_dwell_data_t;
  begin
    (r.window_duration, r.tag, r.frequency, r.sequence_num) := unsigned(v);
    return r;
  end function;

  function unpack(v : std_logic_vector(INTERCEPT_STREAM_SAMPLE_WIDTH - 1 downto 0)) return intercept_stream_sample_t is
    variable r : intercept_stream_sample_t;
    variable v_data_i : unsigned(r.data_i'range);
    variable v_data_q : unsigned(r.data_q'range);
  begin
    (v_data_q, v_data_i, r.sample_index, r.channel_index, r.stream_index, r.trigger_type) := unsigned(v);
    r.data_i := signed(v_data_i);
    r.data_q := signed(v_data_q);
    return r;
  end function;

  function unpack(v : std_logic_vector(INTERCEPT_CONFIG_DATA_WIDTH - 1 downto 0)) return intercept_config_data_t is
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

  function unpack_aligned(v : std_logic_vector(INTERCEPT_MESSAGE_DWELL_CONTROLLER_CONTROL_ALIGNED_WIDTH - 1 downto 0)) return intercept_message_dwell_controller_control_t is
    variable p : intercept_message_dwell_controller_control_aligned_t;
    variable r : intercept_message_dwell_controller_control_t;
  begin
    (p.window_duration, p.dwell_frequency, p.dwell_tag, p.padding0, p.enable) := v;

    r.enable          := p.enable(0);
    r.dwell_tag       := unsigned(p.dwell_tag);
    r.dwell_frequency := unsigned(p.dwell_frequency);
    r.window_duration := unsigned(p.window_duration(INTERCEPT_DWELL_DURATION_WIDTH - 1 downto 0));
    return r;
  end function;

  function unpack_aligned(v : std_logic_vector(INTERCEPT_MESSAGE_STREAM_ENCODER_CHANNEL_CONTROL_ALIGNED_WIDTH - 1 downto 0)) return intercept_message_stream_encoder_channel_control_t is
    variable p : intercept_message_stream_encoder_channel_control_aligned_t;
    variable r : intercept_message_stream_encoder_channel_control_t;
  begin
    (p.integration_cycles, p.coast_cycles, p.threshold_continue, p.threshold_start, p.padding1, p.stream_encoder_tag, p.padding0, p.force_stream, p.force_trigger, p.enable) := v;

    r.enable              := p.enable(0);
    r.force_trigger       := p.force_trigger(0);
    r.force_stream        := unsigned(p.force_stream(INTERCEPT_STREAM_INDEX_WIDTH - 1 downto 0));
    r.stream_encoder_tag  := unsigned(p.stream_encoder_tag);
    r.threshold_start     := unsigned(p.threshold_start);
    r.threshold_continue  := unsigned(p.threshold_continue);
    r.coast_cycles        := unsigned(p.coast_cycles(INTERCEPT_STREAM_COAST_DURATION_WIDTH - 1 downto 0));
    r.integration_cycles  := unsigned(p.integration_cycles(INTERCEPT_STREAM_INTEGRATION_TIME_WIDTH - 1 downto 0));
    return r;
  end function;

  function unpack_aligned(v : std_logic_vector(INTERCEPT_MESSAGE_STREAM_ENCODER_STREAM_CONTROL_ALIGNED_WIDTH - 1 downto 0)) return intercept_message_stream_encoder_stream_control_t is
    variable p : intercept_message_stream_encoder_stream_control_aligned_t;
    variable r : intercept_message_stream_encoder_stream_control_t;
  begin
    (p.stream_encoder_tag, p.padding0, p.enable) := v;

    r.enable              := p.enable(0);
    r.stream_encoder_tag  := unsigned(p.stream_encoder_tag);

    return r;
  end function;

  function pack(v : intercept_dwell_data_t) return std_logic_vector is
    variable r : std_logic_vector(INTERCEPT_DWELL_DATA_WIDTH - 1 downto 0);
  begin
    r := (std_logic_vector(v.window_duration), std_logic_vector(v.tag), std_logic_vector(v.frequency), std_logic_vector(v.sequence_num));
    return r;
  end function;

  function pack(v : intercept_stream_sample_t) return std_logic_vector is
    variable r : std_logic_vector(INTERCEPT_STREAM_SAMPLE_WIDTH - 1 downto 0);
  begin
    r := (std_logic_vector(v.data_q), std_logic_vector(v.data_i), std_logic_vector(v.sample_index), std_logic_vector(v.channel_index),
          std_logic_vector(v.stream_index), std_logic_vector(v.trigger_type));
    return r;
  end function;

  function pack(v : intercept_stream_sample_aligned_t) return std_logic_vector is
    variable r : std_logic_vector(INTERCEPT_STREAM_SAMPLE_ALIGNED_WIDTH - 1 downto 0);
  begin
    r := (std_logic_vector(v.data_q), std_logic_vector(v.data_i), std_logic_vector(v.sample_index), std_logic_vector(v.channel_index),
          std_logic_vector(v.stream_index), std_logic_vector(v.trigger_type));
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
          v.reporter_timeout,
          v.reporter_busy
         );
    return r;
  end function;

  function pack(v : intercept_stream_encoder_errors_t) return std_logic_vector is
    variable r : std_logic_vector(INTERCEPT_STREAM_ENCODER_ERRORS_WIDTH - 1 downto 0);
  begin
    r := (
          v.reporter_overflow,
          v.reporter_timeout,
          v.fifo_underflow,
          v.fifo_overflow
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
