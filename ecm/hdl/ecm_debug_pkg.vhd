library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library ecm_lib;
  use ecm_lib.ecm_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

package ecm_debug_pkg is

  type ecm_dwell_trigger_debug_t is record
    --r3_channel_control_program_entry_0  : std_logic_vector(ECM_CHANNEL_TX_PROGRAM_ENTRY_WIDTH - 1 downto 0);
    r3_channel_state_wr_en              : std_logic;
    r3_channel_state_wr_index           : std_logic_vector(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
    r3_channel_state_wr_data_state      : std_logic_vector(3 downto 0);
    r3_channel_state_wr_en_rec_len      : std_logic_vector(ECM_DRFM_SEGMENT_LENGTH_WIDTH - 1 downto 0);
    r3_drfm_write_req_valid             : std_logic;
    r3_drfm_write_req_first             : std_logic;
    r3_drfm_write_req_last              : std_logic;
    r3_drfm_write_req_trigger_accepted  : std_logic;
    r3_drfm_write_req_address           : std_logic_vector(ECM_DRFM_ADDR_WIDTH - 1 downto 0);
    r3_drfm_write_req_channel_index     : std_logic_vector(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
    r3_trigger_check_duration_min       : std_logic_vector(ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES - 1 downto 0);
    r3_trigger_check_duration_max       : std_logic_vector(ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES - 1 downto 0);
    r3_trigger_pending                  : std_logic;
  end record;

  constant ECM_DWELL_TRIGGER_DEBUG_WIDTH : natural := --ECM_CHANNEL_TX_PROGRAM_ENTRY_WIDTH +
                                                      1 + ECM_CHANNEL_INDEX_WIDTH + 4 +
                                                      ECM_DRFM_SEGMENT_LENGTH_WIDTH + 4 + ECM_DRFM_ADDR_WIDTH + ECM_CHANNEL_INDEX_WIDTH +
                                                      ECM_NUM_CHANNEL_TX_PROGRAM_ENTRIES * 2 + 1;

  type ecm_dwell_controller_debug_t is record
    s_state                         : std_logic_vector(3 downto 0);
    --w_channel_entry_valid           : std_logic;
    --w_channel_entry_index           : std_logic_vector(ECM_DWELL_CHANNEL_CONTROL_ENTRY_INDEX_WIDTH - 1 downto 0);
    --w_channel_entry_program_entry_0 : std_logic_vector(ECM_CHANNEL_TX_PROGRAM_ENTRY_WIDTH - 1 downto 0);
    w_tx_instruction_valid          : std_logic;
    w_tx_instruction_index          : std_logic_vector(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
    w_tx_instruction_data           : std_logic_vector(ECM_TX_INSTRUCTION_DATA_WIDTH - 1 downto 0);
    r_dwell_program_valid           : std_logic;
    r_dwell_program_tag             : std_logic_vector(ECM_DWELL_TAG_WIDTH - 1 downto 0);
    r_dwell_cycles                  : std_logic_vector(ECM_DWELL_DURATION_WIDTH - 1 downto 0);
    r_dwell_done_meas               : std_logic;
    r_dwell_done_total              : std_logic;
    r_dwell_meas_flush_done         : std_logic;
    r_report_received_drfm          : std_logic;
    r_report_received_stats         : std_logic;
    r_dwell_report_done_drfm        : std_logic;
    r_dwell_report_done_stats       : std_logic;
    r_dwell_active                  : std_logic;
    r_dwell_start_meas              : std_logic;
    r_dwell_active_meas             : std_logic;
    r_dwell_active_tx               : std_logic;
    r_dwell_report_wait             : std_logic;
    w_trigger_immediate_tx          : std_logic;
    w_trigger_pending               : std_logic;
    w_tx_program_req_valid          : std_logic;
    w_tx_program_req_channel        : std_logic_vector(ECM_CHANNEL_INDEX_WIDTH - 1 downto 0);
    w_tx_program_req_index          : std_logic_vector(ECM_TX_INSTRUCTION_INDEX_WIDTH - 1 downto 0);
    w_tx_programs_done              : std_logic;
  end record;

  constant ECM_DWELL_CONTROLLER_DEBUG_WIDTH : natural := 4 + -- 1 + ECM_DWELL_CHANNEL_CONTROL_ENTRY_INDEX_WIDTH + ECM_CHANNEL_TX_PROGRAM_ENTRY_WIDTH +
                                                         1 + ECM_TX_INSTRUCTION_INDEX_WIDTH + ECM_TX_INSTRUCTION_DATA_WIDTH + 1 +
                                                         ECM_DWELL_TAG_WIDTH + ECM_DWELL_DURATION_WIDTH + 15 + ECM_CHANNEL_INDEX_WIDTH +
                                                         ECM_TX_INSTRUCTION_INDEX_WIDTH + 1;

  function unpack(v : std_logic_vector(ECM_DWELL_TRIGGER_DEBUG_WIDTH - 1 downto 0)) return ecm_dwell_trigger_debug_t;
  function pack(v : ecm_dwell_trigger_debug_t) return std_logic_vector;
  function unpack(v : std_logic_vector(ECM_DWELL_CONTROLLER_DEBUG_WIDTH - 1 downto 0)) return ecm_dwell_controller_debug_t;
  function pack(v : ecm_dwell_controller_debug_t) return std_logic_vector;

end package ecm_debug_pkg;

package body ecm_debug_pkg is


  function unpack(v : std_logic_vector(ECM_DWELL_TRIGGER_DEBUG_WIDTH - 1 downto 0)) return ecm_dwell_trigger_debug_t is
    variable r : ecm_dwell_trigger_debug_t;
  begin
    (
      --r.r3_channel_control_program_entry_0  ,
      r.r3_channel_state_wr_en              ,
      r.r3_channel_state_wr_index           ,
      r.r3_channel_state_wr_data_state      ,
      r.r3_channel_state_wr_en_rec_len      ,
      r.r3_drfm_write_req_valid             ,
      r.r3_drfm_write_req_first             ,
      r.r3_drfm_write_req_last              ,
      r.r3_drfm_write_req_trigger_accepted  ,
      r.r3_drfm_write_req_address           ,
      r.r3_drfm_write_req_channel_index     ,
      r.r3_trigger_check_duration_min       ,
      r.r3_trigger_check_duration_max       ,
      r.r3_trigger_pending
    ) := v;

    return r;
  end function;

  function unpack(v : std_logic_vector(ECM_DWELL_CONTROLLER_DEBUG_WIDTH - 1 downto 0)) return ecm_dwell_controller_debug_t is
    variable r : ecm_dwell_controller_debug_t;
  begin
    (
      r.s_state                         ,
      --r.w_channel_entry_valid           ,
      --r.w_channel_entry_index           ,
      --r.w_channel_entry_program_entry_0 ,
      r.w_tx_instruction_valid          ,
      r.w_tx_instruction_index          ,
      r.w_tx_instruction_data           ,
      r.r_dwell_program_valid           ,
      r.r_dwell_program_tag             ,
      r.r_dwell_cycles                  ,
      r.r_dwell_done_meas               ,
      r.r_dwell_done_total              ,
      r.r_dwell_meas_flush_done         ,
      r.r_report_received_drfm          ,
      r.r_report_received_stats         ,
      r.r_dwell_report_done_drfm        ,
      r.r_dwell_report_done_stats       ,
      r.r_dwell_active                  ,
      r.r_dwell_start_meas              ,
      r.r_dwell_active_meas             ,
      r.r_dwell_active_tx               ,
      r.r_dwell_report_wait             ,
      r.w_trigger_immediate_tx          ,
      r.w_trigger_pending               ,
      r.w_tx_program_req_valid          ,
      r.w_tx_program_req_channel        ,
      r.w_tx_program_req_index          ,
      r.w_tx_programs_done
    ) := v;

    return r;
  end function;

  function pack(v : ecm_dwell_trigger_debug_t) return std_logic_vector is
    variable r : std_logic_vector(ECM_DWELL_TRIGGER_DEBUG_WIDTH - 1 downto 0);
  begin

    r := (
            --v.r3_channel_control_program_entry_0  ,
            v.r3_channel_state_wr_en              ,
            v.r3_channel_state_wr_index           ,
            v.r3_channel_state_wr_data_state      ,
            v.r3_channel_state_wr_en_rec_len      ,
            v.r3_drfm_write_req_valid             ,
            v.r3_drfm_write_req_first             ,
            v.r3_drfm_write_req_last              ,
            v.r3_drfm_write_req_trigger_accepted  ,
            v.r3_drfm_write_req_address           ,
            v.r3_drfm_write_req_channel_index     ,
            v.r3_trigger_check_duration_min       ,
            v.r3_trigger_check_duration_max       ,
            v.r3_trigger_pending
          );
    return r;
  end function;

  function pack(v : ecm_dwell_controller_debug_t) return std_logic_vector is
    variable r : std_logic_vector(ECM_DWELL_CONTROLLER_DEBUG_WIDTH - 1 downto 0);
  begin

    r := (
            v.s_state                         ,
            --v.w_channel_entry_valid           ,
            --v.w_channel_entry_index           ,
            --v.w_channel_entry_program_entry_0 ,
            v.w_tx_instruction_valid          ,
            v.w_tx_instruction_index          ,
            v.w_tx_instruction_data           ,
            v.r_dwell_program_valid           ,
            v.r_dwell_program_tag             ,
            v.r_dwell_cycles                  ,
            v.r_dwell_done_meas               ,
            v.r_dwell_done_total              ,
            v.r_dwell_meas_flush_done         ,
            v.r_report_received_drfm          ,
            v.r_report_received_stats         ,
            v.r_dwell_report_done_drfm        ,
            v.r_dwell_report_done_stats       ,
            v.r_dwell_active                  ,
            v.r_dwell_start_meas              ,
            v.r_dwell_active_meas             ,
            v.r_dwell_active_tx               ,
            v.r_dwell_report_wait             ,
            v.w_trigger_immediate_tx          ,
            v.w_trigger_pending               ,
            v.w_tx_program_req_valid          ,
            v.w_tx_program_req_channel        ,
            v.w_tx_program_req_index          ,
            v.w_tx_programs_done
          );
    return r;
  end function;

end package body ecm_debug_pkg;
