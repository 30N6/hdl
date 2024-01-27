library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

package esm_pkg is

  constant ESM_CONTROL_MAGIC_NUM                        : std_logic_vector(31 downto 0) := "45534D43";
  constant ESM_REPORT_MAGIC_NUM                         : std_logic_vector(31 downto 0) := "45534D52";

  constant ESM_CONTROL_MESSAGE_TYPE_ENABLE              : unsigned(7 downto 0) := x"00";
  constant ESM_CONTROL_MESSAGE_TYPE_DWELL_REQUEST       : unsigned(7 downto 0) := x"01";
  constant ESM_CONTROL_MESSAGE_TYPE_PDW_SETUP           : unsigned(7 downto 0) := x"02";  --TODO: unused?

  constant ESM_REPORT_MESSAGE_TYPE_DWELL_COMPLETE_INFO  : unsigned(7 downto 0) := x"10";
  constant ESM_REPORT_MESSAGE_TYPE_DWELL_COMPLETE_STATS : unsigned(7 downto 0) := x"10";
  constant ESM_REPORT_MESSAGE_TYPE_PDW                  : unsigned(7 downto 0) := x"20";

  constant ESM_MAX_NUM_CHANNELS                   : natural := 64;
  constant ESM_NUM_FAST_LOCK_PROFILES             : natural := 8;

  type esm_common_header_t is record
    magic_num     : std_logic_vector(31 downto 0);
    message_type  : unsigned(7 downto 0);
    module_id     : unsigned(7 downto 0);
    padding_0     : std_logic_vector(15 downto 0);
    sequence_num  : unsigned(31 downto 0);
    padding_1     : std_logic_vector(31 downto 0);
  end record;

  type esm_message_enable_t is record
    header                    : esm_common_header_t;
    reset                     : std_logic;
    enable_channelizer_wide   : std_logic;
    enable_channelizer_narrow : std_logic;
    enable_pdw_wide           : std_logic;
    enable_pdw_narrow         : std_logic;
  end record;

  type esm_dwell_metadata_t is record
    tag           : unsigned(31 downto 0);
    frequency     : unsigned(15 downto 0);
    gain          : unsigned(7 downto 0);
    padding       : unsigned(7 downto 0);
  end record;

  type esm_dwell_request_entry_t is record
    valid         : std_logic;
    metadata      : esm_dwell_metadata_t;
    threshold     : unsigned(31 downto 0);
    duration      : unsigned(31 downto 0);
    channel_mask  : std_logic_vector(ESM_MAX_NUM_CHANNELS - 1 downto 0);
  end record;

  type esm_dwell_request_entry_array_t is array (natural range <>) of esm_dwell_request_entry_t;

  type esm_message_dwell_request_t is record
    header        : esm_common_header_t;
    dwell_entries : esm_dwell_request_entry_array_t(ESM_NUM_FAST_LOCK_PROFILES - 1 downto 0);
  end record;

  type esm_message_dwell_complete_info_t is record
    header              : esm_common_header_t;
    dwell_sequence_num  : unsigned(31 downto 0);
    metadata            : esm_dwell_metadata_t;

    channel_mask        : std_logic_vector(ESM_MAX_NUM_CHANNELS - 1 downto 0);
    num_samples         : unsigned(31 downto 0);
    ts_start_dwell      : unsigned(63 downto 0);
    ts_pll_locked       : unsigned(63 downto 0);
    ts_dwell_end        : unsigned(63 downto 0);
  end record;

  type esm_message_dwell_complete_stats_t is record
    header              : esm_common_header_t;
    dwell_sequence_num  : unsigned(31 downto 0);
    metadata            : esm_dwell_metadata_t;

    channel_amplitude   : unsigned_array_t(ESM_MAX_NUM_CHANNELS/2 - 1 downto 0)(31 downto 0);
    channel_start_index : unsigned(7 downto 0);
  end record;

  type esm_message_pdw_t is record
    header              : esm_common_header_t;
    pdw_sequence_num    : unsigned(31 downto 0);
    dwell_sequence_num  : unsigned(31 downto 0);
    dwell_metadata      : esm_dwell_metadata_t;
    threshold           : unsigned(31 downto 0);
    pulse_amplitude     : unsigned(31 downto 0);
    pulse_duration      : unsigned(31 downto 0);  --TODO: early termination flag?
    pulse_frequency     : unsigned(31 downto 0);
    ts_start            : unsigned(63 downto 0);

    raw_samples         : std_logic_vector_array_t(49 downto 0)(31 downto 0);
  end record;

end package esm_pkg;

package body esm_pkg is

end package body esm_pkg;
