library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;

library esm_lib;
  use esm_lib.esm_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

package esm_debug_pkg is

  type esm_pdw_sample_processor_debug_t is record
    w_buffer_empty                      : std_logic;
    w_buffer_full                       : std_logic;
    w_buffer_next_index                 : std_logic_vector(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
    w_buffer_next_start                 : std_logic;
    w_buffer_wr_en                      : std_logic;
    w_pending_fifo_wr_en                : std_logic;
    w_pending_fifo_full                 : std_logic;
    w_pending_fifo_rd_en                : std_logic;
    w_pending_fifo_empty                : std_logic;
    w_fifo_full                         : std_logic;
    r_fifo_wr_en                        : std_logic;
    r_fifo_wr_data_channel              : std_logic_vector(ESM_CHANNEL_INDEX_WIDTH - 1 downto 0);
    w_fifo_empty                        : std_logic;

    r2_context_state                    : std_logic_vector(1 downto 0);
    r2_context_pulse_seq_num            : std_logic_vector(ESM_PDW_SEQUENCE_NUM_WIDTH - 1 downto 0);
    r2_context_power_accum_a            : std_logic_vector(ESM_PDW_POWER_ACCUM_WIDTH - 16 - 1 downto 0);
    r2_context_duration                 : std_logic_vector(ESM_PDW_CYCLE_COUNT_WIDTH - 1 downto 0);
    r2_context_recording_skipped        : std_logic;
    r2_context_recording_active         : std_logic;
    r2_context_recording_frame_index    : std_logic_vector(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
    r2_context_recording_sample_index   : std_logic_vector(ESM_PDW_SAMPLE_BUFFER_SAMPLE_INDEX_WIDTH - 1 downto 0);
    r2_context_recording_sample_padding : std_logic_vector(3 downto 0);

    r2_input_ctrl_valid                 : std_logic;
    r2_input_ctrl_last                  : std_logic;
    r2_input_ctrl_index                 : std_logic_vector(5 downto 0);
    r2_input_i                          : std_logic_vector(15 downto 0);
    r2_input_q                          : std_logic_vector(15 downto 0);
    r2_input_power                      : std_logic_vector(CHAN_POWER_WIDTH - 1 downto 0);
    r2_new_detect                       : std_logic;
    r2_continued_detect                 : std_logic;
  end record;

  constant ESM_PDW_SAMPLE_PROCESSOR_DEBUG_WIDTH : natural := 17 + ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH + ESM_CHANNEL_INDEX_WIDTH + 2 +
                                                             ESM_PDW_SEQUENCE_NUM_WIDTH + (ESM_PDW_POWER_ACCUM_WIDTH - 16) +
                                                             ESM_PDW_CYCLE_COUNT_WIDTH + ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH +
                                                             ESM_PDW_SAMPLE_BUFFER_SAMPLE_INDEX_WIDTH + 4 +
                                                             6 + 16 + 16 + CHAN_POWER_WIDTH;

  type esm_pdw_encoder_debug_t is record
    r_timestamp                     : std_logic_vector(ESM_TIMESTAMP_WIDTH - 1 downto 0);
    s_state                         : std_logic_vector(2 downto 0);
    r_dwell_active                  : std_logic;
    r_dwell_data_tag                : std_logic_vector(15 downto 0);
    w_pdw_ready                     : std_logic;
    w_pdw_valid                     : std_logic;

    w_pdw_data_sequence_num         : std_logic_vector(ESM_PDW_SEQUENCE_NUM_WIDTH - 1 downto 0);
    w_pdw_data_channel              : std_logic_vector(ESM_CHANNEL_INDEX_WIDTH - 1 downto 0);
    w_pdw_data_power_accum          : std_logic_vector(ESM_PDW_POWER_ACCUM_WIDTH - 1 downto 0);
    w_pdw_data_duration             : std_logic_vector(ESM_PDW_CYCLE_COUNT_WIDTH - 1 downto 0);
    w_pdw_data_buffered_frame_index : std_logic_vector(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
    w_pdw_data_buffered_frame_valid : std_logic;

    w_frame_req_index               : std_logic_vector(ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH - 1 downto 0);
    w_frame_req_read                : std_logic;
    w_frame_req_drop                : std_logic;

    w_frame_ack_index               : std_logic_vector(ESM_PDW_SAMPLE_BUFFER_SAMPLE_INDEX_WIDTH - 1 downto 0);
    w_frame_ack_valid               : std_logic;
    w_frame_ack_last                : std_logic;

    w_frame_data_i                  : std_logic_vector(15 downto 0);
    w_frame_data_q                  : std_logic_vector(15 downto 0);
    w_dwell_active                  : std_logic;
    w_dwell_done                    : std_logic;
    w_report_ack                    : std_logic;
    w_pdw_fifo_busy                 : std_logic;
    w_pdw_fifo_overflow             : std_logic;
    w_pdw_fifo_underflow            : std_logic;
    w_sample_buffer_busy            : std_logic;
    w_sample_buffer_underflow       : std_logic;
    w_sample_buffer_overflow        : std_logic;
    w_reporter_timeout              : std_logic;
    w_reporter_overflow             : std_logic;
  end record;

  constant ESM_PDW_ENCODER_DEBUG_WIDTH : natural := 19 + ESM_TIMESTAMP_WIDTH + 3 + 16 +
                                                    ESM_PDW_SEQUENCE_NUM_WIDTH + ESM_CHANNEL_INDEX_WIDTH + ESM_PDW_POWER_ACCUM_WIDTH + ESM_PDW_CYCLE_COUNT_WIDTH + ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH +
                                                    ESM_PDW_SAMPLE_BUFFER_FRAME_INDEX_WIDTH + ESM_PDW_SAMPLE_BUFFER_SAMPLE_INDEX_WIDTH + 16 + 16;

  function unpack(v : std_logic_vector) return esm_pdw_sample_processor_debug_t;
  function pack(v : esm_pdw_sample_processor_debug_t) return std_logic_vector;
  function unpack(v : std_logic_vector) return esm_pdw_encoder_debug_t;
  function pack(v : esm_pdw_encoder_debug_t) return std_logic_vector;

end package esm_debug_pkg;

package body esm_debug_pkg is


  function unpack(v : std_logic_vector) return esm_pdw_sample_processor_debug_t is
    variable r : esm_pdw_sample_processor_debug_t;
  begin
    assert (v'length = ESM_PDW_SAMPLE_PROCESSOR_DEBUG_WIDTH)
      report "unexpected length"
      severity failure;

    (
      r.w_buffer_empty                      ,
      r.w_buffer_full                       ,
      r.w_buffer_next_index                 ,
      r.w_buffer_next_start                 ,
      r.w_buffer_wr_en                      ,
      r.w_pending_fifo_wr_en                ,
      r.w_pending_fifo_full                 ,
      r.w_pending_fifo_rd_en                ,
      r.w_pending_fifo_empty                ,
      r.w_fifo_full                         ,
      r.r_fifo_wr_en                        ,
      r.r_fifo_wr_data_channel              ,
      r.w_fifo_empty                        ,
      r.r2_context_state                    ,
      r.r2_context_pulse_seq_num            ,
      r.r2_context_power_accum_a            ,
      r.r2_context_duration                 ,
      r.r2_context_recording_skipped        ,
      r.r2_context_recording_active         ,
      r.r2_context_recording_frame_index    ,
      r.r2_context_recording_sample_index   ,
      r.r2_context_recording_sample_padding ,
      r.r2_input_ctrl_valid                 ,
      r.r2_input_ctrl_last                  ,
      r.r2_input_ctrl_index                 ,
      r.r2_input_i                          ,
      r.r2_input_q                          ,
      r.r2_input_power                      ,
      r.r2_new_detect                       ,
      r.r2_continued_detect
    ) := v;

    return r;
  end function;

  function unpack(v : std_logic_vector) return esm_pdw_encoder_debug_t is
    variable r : esm_pdw_encoder_debug_t;
  begin
    assert (v'length = ESM_PDW_ENCODER_DEBUG_WIDTH)
      report "unexpected length"
      severity failure;

    (
      r.r_timestamp                     ,
      r.s_state                         ,
      r.r_dwell_active                  ,
      r.r_dwell_data_tag                ,
      r.w_pdw_ready                     ,
      r.w_pdw_valid                     ,
      r.w_pdw_data_sequence_num         ,
      r.w_pdw_data_channel              ,
      r.w_pdw_data_power_accum          ,
      r.w_pdw_data_duration             ,
      r.w_pdw_data_buffered_frame_index ,
      r.w_pdw_data_buffered_frame_valid ,
      r.w_frame_req_index               ,
      r.w_frame_req_read                ,
      r.w_frame_req_drop                ,
      r.w_frame_ack_index               ,
      r.w_frame_ack_valid               ,
      r.w_frame_ack_last                ,
      r.w_frame_data_i                  ,
      r.w_frame_data_q                  ,
      r.w_dwell_active                  ,
      r.w_dwell_done                    ,
      r.w_report_ack                    ,
      r.w_pdw_fifo_busy                 ,
      r.w_pdw_fifo_overflow             ,
      r.w_pdw_fifo_underflow            ,
      r.w_sample_buffer_busy            ,
      r.w_sample_buffer_underflow       ,
      r.w_sample_buffer_overflow        ,
      r.w_reporter_timeout              ,
      r.w_reporter_overflow
    ) := v;

    return r;
  end function;

  function pack(v : esm_pdw_sample_processor_debug_t) return std_logic_vector is
    variable r : std_logic_vector(ESM_PDW_SAMPLE_PROCESSOR_DEBUG_WIDTH - 1 downto 0);
  begin

    r := (
            v.w_buffer_empty                      ,
            v.w_buffer_full                       ,
            v.w_buffer_next_index                 ,
            v.w_buffer_next_start                 ,
            v.w_buffer_wr_en                      ,
            v.w_pending_fifo_wr_en                ,
            v.w_pending_fifo_full                 ,
            v.w_pending_fifo_rd_en                ,
            v.w_pending_fifo_empty                ,
            v.w_fifo_full                         ,
            v.r_fifo_wr_en                        ,
            v.r_fifo_wr_data_channel              ,
            v.w_fifo_empty                        ,
            v.r2_context_state                    ,
            v.r2_context_pulse_seq_num            ,
            v.r2_context_power_accum_a            ,
            v.r2_context_duration                 ,
            v.r2_context_recording_skipped        ,
            v.r2_context_recording_active         ,
            v.r2_context_recording_frame_index    ,
            v.r2_context_recording_sample_index   ,
            v.r2_context_recording_sample_padding ,
            v.r2_input_ctrl_valid                 ,
            v.r2_input_ctrl_last                  ,
            v.r2_input_ctrl_index                 ,
            v.r2_input_i                          ,
            v.r2_input_q                          ,
            v.r2_input_power                      ,
            v.r2_new_detect                       ,
            v.r2_continued_detect
          );
    return r;
  end function;

  function pack(v : esm_pdw_encoder_debug_t) return std_logic_vector is
    variable r : std_logic_vector(ESM_PDW_ENCODER_DEBUG_WIDTH - 1 downto 0);
  begin

    r := (
            v.r_timestamp                     ,
            v.s_state                         ,
            v.r_dwell_active                  ,
            v.r_dwell_data_tag                ,
            v.w_pdw_ready                     ,
            v.w_pdw_valid                     ,
            v.w_pdw_data_sequence_num         ,
            v.w_pdw_data_channel              ,
            v.w_pdw_data_power_accum          ,
            v.w_pdw_data_duration             ,
            v.w_pdw_data_buffered_frame_index ,
            v.w_pdw_data_buffered_frame_valid ,
            v.w_frame_req_index               ,
            v.w_frame_req_read                ,
            v.w_frame_req_drop                ,
            v.w_frame_ack_index               ,
            v.w_frame_ack_valid               ,
            v.w_frame_ack_last                ,
            v.w_frame_data_i                  ,
            v.w_frame_data_q                  ,
            v.w_dwell_active                  ,
            v.w_dwell_done                    ,
            v.w_report_ack                    ,
            v.w_pdw_fifo_busy                 ,
            v.w_pdw_fifo_overflow             ,
            v.w_pdw_fifo_underflow            ,
            v.w_sample_buffer_busy            ,
            v.w_sample_buffer_underflow       ,
            v.w_sample_buffer_overflow        ,
            v.w_reporter_timeout              ,
            v.w_reporter_overflow
          );
    return r;
  end function;

end package body esm_debug_pkg;
