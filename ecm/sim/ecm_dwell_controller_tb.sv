`timescale 1ns/1ps

import math::*;
import ecm_pkg::*;
import dsp_pkg::*;

typedef struct {
  int data_i;
  int data_q;
  int index;
  int wait_cycles;
} channelizer_transaction_t;

interface channelizer_tx_intf #(parameter DATA_WIDTH) (input logic Clk);
  channelizer_control_t             ctrl;
  logic signed [DATA_WIDTH - 1 : 0] data [1:0];
  logic [chan_power_width - 1 : 0]  power;

  task clear();
    ctrl.valid      <= 0;
    ctrl.last       <= 'x;
    ctrl.data_index <= 'x;
    data[0]         <= 'x;
    data[1]         <= 'x;
  endtask

  task write(input channelizer_transaction_t tx);
    ctrl.valid      <= 1;
    ctrl.last       <= (tx.index == (ecm_num_channels - 1));
    ctrl.data_index <= tx.index;
    data[0]         <= tx.data_i;
    data[1]         <= tx.data_q;
    @(posedge Clk);
    clear();
    repeat(tx.wait_cycles) @(posedge Clk);
  endtask
endinterface

typedef struct {
  ecm_dwell_entry_t                             data;
  logic [ecm_dwell_sequence_num_width - 1 : 0]  seq_num;
  logic                                         active;
  logic                                         active_meas;
  logic                                         active_tx;
  logic                                         done;
} dwell_state_t;

interface dwell_rx_intf (input logic Clk);
  ecm_dwell_entry_t                             data;
  logic [ecm_dwell_sequence_num_width - 1 : 0]  seq_num;
  logic                                         active;
  logic                                         active_meas;
  logic                                         active_tx;
  logic                                         done;

  task read(output dwell_state_t d);
    logic r_active, r_active_meas, r_active_tx, r_done;
    logic v;

    do begin
      r_active      = active;
      r_active_meas = active_meas;
      r_active_tx   = active_tx;
      r_done        = done;

      @(posedge Clk);

      d.data        = data;
      d.seq_num     = seq_num;
      d.active      = active;
      d.active_meas = active_meas;
      d.active_tx   = active_tx;
      d.done        = done;

      v = (active !== r_active) || (active_meas !== r_active_meas) || (active_tx !== r_active_tx) || (done !== r_done);
    end while (v !== 1);
  endtask
endinterface

interface ecm_drfm_write_req_intf (input logic Clk);
  ecm_drfm_write_req_t  data;

  task read(output ecm_drfm_write_req_t d);
    do begin
      d <= data;
      @(posedge Clk);
    end while (d.valid !== 1);
  endtask
endinterface

interface ecm_drfm_read_req_intf (input logic Clk);
  ecm_drfm_read_req_t  data;

  task read(output ecm_drfm_read_req_t d);
    do begin
      d <= data;
      @(posedge Clk);
    end while (d.valid !== 1);
  endtask
endinterface

interface axi_tx_intf #(parameter AXI_DATA_WIDTH) (input logic Clk);
  logic                           valid = 0;
  logic                           last;
  logic [AXI_DATA_WIDTH - 1 : 0]  data;
  logic                           ready;

  task write(input bit [AXI_DATA_WIDTH - 1 : 0] d []);
    for (int i = 0; i < d.size(); i++) begin
      valid <= 1;
      data  <= d[i];
      last  <= (i == (d.size() - 1));

      do begin
        @(posedge Clk);
      end while (!ready);

      valid <= 0;
      data  <= 'x;
      last  <= 'x;
    end
  endtask
endinterface

module ecm_dwell_controller_tb;
  parameter time CLK_HALF_PERIOD      = 2ns;
  parameter time AXI_CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH            = 32;
  parameter CHANNELIZER_DATA_WIDTH    = 20;
  parameter SYNC_TO_DRFM_READ_LATENCY = 6;

  typedef struct
  {
    ecm_dwell_entry_t data;
  } expect_t;

  logic Clk_axi;
  logic Clk;
  logic Rst;

  axi_tx_intf             #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))      cfg_tx_intf   (.Clk(Clk_axi));
  channelizer_tx_intf     #(.DATA_WIDTH(CHANNELIZER_DATA_WIDTH))  chan_intf     (.*);
  ecm_drfm_write_req_intf                                         drfm_wr_intf  (.*);
  ecm_drfm_read_req_intf                                          drfm_rd_intf  (.*);
  dwell_rx_intf                                                   dwell_intf    (.*);

  logic                 w_rst_out;
  logic                 w_enable_chan;
  logic                 w_enable_synth;
  logic                 w_enable_status;
  ecm_config_data_t     w_module_config;
  logic                 w_dwell_active;
  logic                 w_dwell_active_meas;
  logic                 w_dwell_active_tx;
  logic                 w_dwell_done;
  ecm_dwell_entry_t     w_dwell_data;
  logic [31:0]          w_dwell_seq_num;
  logic                 r_dwell_report_done_drfm;
  logic                 r_dwell_report_done_stats;

  logic [3:0]           w_ad9361_control;
  logic [3:0]           r_ad9361_control;
  logic [7:0]           w_ad9361_status;

  channelizer_control_t r_sync_data;

  bit [31:0]            config_seq_num = 0;
  ecm_dwell_entry_t     dwell_entry_mem [ecm_num_dwell_entries - 1 : 0];

  expect_t              expected_data [$];
  int                   num_received = 0;

  initial begin
    Clk_axi = 0;
    forever begin
      #(AXI_CLK_HALF_PERIOD);
      Clk_axi = ~Clk_axi;
    end
  end

  initial begin
    Clk = 0;
    forever begin
      #(CLK_HALF_PERIOD);
      Clk = ~Clk;
    end
  end

  initial begin
    Rst = 1;
    repeat(100) @(posedge Clk);
    Rst = 0;
  end

  ecm_config #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH)) cfg
  (
    .Clk_x4         (Clk),

    .S_axis_clk     (Clk_axi),
    .S_axis_resetn  (!Rst),
    .S_axis_ready   (cfg_tx_intf.ready),
    .S_axis_valid   (cfg_tx_intf.valid),
    .S_axis_data    (cfg_tx_intf.data),
    .S_axis_last    (cfg_tx_intf.last),

    .Rst_out        (w_rst_out),
    .Enable_status  (w_enable_status),
    .Enable_chan    (w_enable_chan),
    .Enable_synth   (w_enable_synth),

    .Module_config  (w_module_config)
  );

  ecm_dwell_controller #(.SYNC_TO_DRFM_READ_LATENCY(SYNC_TO_DRFM_READ_LATENCY), .CHANNELIZER_DATA_WIDTH(CHANNELIZER_DATA_WIDTH)) dut
  (
    .Clk                      (Clk),
    .Rst                      (Rst),

    .Module_config            (w_module_config),

    .Ad9361_control           (w_ad9361_control),
    .Ad9361_status            (w_ad9361_status),

    .Channelizer_ctrl         (chan_intf.ctrl),
    .Channelizer_data         (chan_intf.data),
    .Channelizer_pwr          (chan_intf.power),

    .Sync_data                (r_sync_data),

    .Dwell_active             (w_dwell_active),
    .Dwell_active_measurement (w_dwell_active_meas),
    .Dwell_active_transmit    (w_dwell_active_tx),
    .Dwell_done               (w_dwell_done),
    .Dwell_data               (w_dwell_data),
    .Dwell_sequence_num       (w_dwell_seq_num),
    .Dwell_report_done_drfm   (r_dwell_report_done_drfm),
    .Dwell_report_done_stats  (r_dwell_report_done_stats),

    .Drfm_write_req           (drfm_wr_intf.data),
    .Drfm_read_req            (drfm_rd_intf.data),
    .Dds_control              (), //(dds_intf.data),    //TODO
    .Output_control           () //(output_intf.data), //TODO
  );

  assign dwell_intf.data         = w_dwell_data;
  assign dwell_intf.seq_num      = w_dwell_seq_num;
  assign dwell_intf.active       = w_dwell_active;
  assign dwell_intf.active_meas  = w_dwell_active_meas;
  assign dwell_intf.active_tx    = w_dwell_active_tx;
  assign dwell_intf.done         = w_dwell_done;

  //TODO: combined rx interface - allow checking of wr->rd sequence; for reads, capture the dds and output control states

  always_ff @(posedge Clk) begin
    r_ad9361_control <= w_ad9361_control;
  end

  initial begin
    w_ad9361_status <= 0;

    while (1) begin
      if (w_ad9361_control != r_ad9361_control) begin
        w_ad9361_status <= '0;
        repeat ($urandom_range(10, 5)) @(posedge Clk);
        w_ad9361_status <= '1;
      end
      @(posedge Clk);
    end
  end

  initial begin
    automatic logic [ecm_channel_index_width - 1 : 0] channel_index = 0;
    @(posedge Clk);

    forever begin
      r_sync_data.valid       <= 1;
      r_sync_data.last        <= (channel_index == (ecm_num_channels - 1));
      r_sync_data.data_index  <= channel_index;
      @(posedge Clk);
      r_sync_data.valid       <= 0;
      r_sync_data.last        <= 'x;
      r_sync_data.data_index  <= 'x;
      @(posedge Clk);
    end
  end

  initial begin
    r_dwell_report_done_drfm  <= 0;
    r_dwell_report_done_stats <= 0;
    @(posedge Clk);

    forever begin
      while (!w_dwell_active) begin
        @(posedge Clk);
      end
      while (!w_dwell_done) begin
        @(posedge Clk);
      end

      fork
        begin
          repeat ($urandom_range(256, 128)) @(posedge Clk);
          r_dwell_report_done_drfm <= 1;
          @(posedge Clk);
          r_dwell_report_done_drfm <= 0;
          @(posedge Clk);
        end

        begin
          repeat ($urandom_range(256, 128)) @(posedge Clk);
          r_dwell_report_done_stats <= 1;
          @(posedge Clk);
          r_dwell_report_done_stats <= 0;
          @(posedge Clk);
        end
      join

      while (w_dwell_active) begin
        @(posedge Clk);
      end
    end
  end


  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
  endtask

  task automatic write_config(bit [31:0] config_data []);
    @(posedge Clk_axi)
    cfg_tx_intf.write(config_data);
    repeat(10) @(posedge Clk_axi);
  endtask

  task automatic send_initial_config();
    bit [31:0] config_data [][] = '{{ecm_control_magic_num, config_seq_num++, 32'h00000000, 32'hDEADBEEF, 32'h01000000, 32'hDEADBEEF},
                                    {ecm_control_magic_num, config_seq_num++, 32'h00000000, 32'hDEADBEEF, 32'h00010100, 32'hDEADBEEF}};
    foreach (config_data[i]) begin
      write_config(config_data[i]);
    end
  endtask

  //TODO: assert control and dds state is off at the end of each dwell

  typedef struct {
    int                                             inst_start_addr;
    ecm_tx_instruction_header_t                     inst_headers  [$];
    logic [ecm_tx_instruction_data_width - 1 : 0]   inst_raw_data [$];
  } tx_instructions_t;

  function automatic logic [ecm_tx_instruction_header_packed_width - 1 : 0] pack_ecm_tx_instruction_header(ecm_tx_instruction_header_t header);
    logic [ecm_tx_instruction_header_packed_width - 1 : 0] r = '0;

    r[2:0]  = header.instruction_type;
    r[3]    = header.valid;

    r[5:4]  = header.output_control;
    r[7]    = header.output_valid;

    r[8]    = header.dds_control.dds_sin_phase_inc_select;
    r[10:9] = header.dds_control.dds_output_select;
    r[11]   = header.dds_valid;

    return r;
  endfunction

  function automatic logic [ecm_tx_instruction_data_width - 1 : 0] randomize_instruction_from_header(ecm_tx_instruction_header_t header);
    logic [ecm_tx_instruction_data_width - 1 : 0] r = '0;

    r[ecm_tx_instruction_header_packed_width - 1 : 0] = pack_ecm_tx_instruction_header(header);

    if (header.instruction_type == ecm_tx_instruction_type_nop) begin
      //no fields to pack
    end else if (header.instruction_type == ecm_tx_instruction_type_dds_setup_bpsk) begin
      r[31:16] = $urandom;
    end else if (header.instruction_type == ecm_tx_instruction_type_dds_setup_cw_sweep) begin
      r[31:16] = $urandom;
      r[47:32] = $urandom;
      r[63:48] = $urandom;
    end else if (header.instruction_type == ecm_tx_instruction_type_dds_setup_cw_step) begin
      r[31:16] = $urandom;
      r[47:32] = $urandom;
      r[63:48] = $urandom;
    end else begin
      $error("unsupported instruction type for randomization: %0d", header.instruction_type);
    end
    return r;
  endfunction

  function automatic ecm_tx_instruction_header_t randomize_instruction_header(int instruction_type);
    ecm_tx_instruction_header_t header;

    header.valid                                = 1;
    header.instruction_type                     = instruction_type;
    header.output_valid                         = $urandom;
    header.output_control                       = $urandom;
    header.dds_valid                            = $urandom;
    header.dds_control.dds_sin_phase_inc_select = $urandom;
    header.dds_control.dds_output_select        = $urandom;

    return header;
  endfunction


  function automatic tx_instructions_t randomize_tx_program_instructions(int start_addr, int max_length);
    tx_instructions_t                             result;
    ecm_tx_instruction_header_t                   header;
    logic [ecm_tx_instruction_data_width - 1 : 0] raw_data;
    /*ecm_tx_instruction_dds_setup_bpsk_t           inst_setup_dds_bpsk;
    ecm_tx_instruction_dds_setup_cw_sweep_t       inst_setup_dds_sweep;
    ecm_tx_instruction_dds_setup_cw_step_t        inst_setup_dds_step;*/
    ecm_tx_instruction_playback_t                 inst_setup_playback;
    ecm_tx_instruction_wait_t                     inst_setup_wait;
    ecm_tx_instruction_jump_t                     inst_setup_jump;

    int r;
    int num_top_level_blocks = $urandom_range(4, 1);
    int jump_counter_total = 0;

    result.inst_start_addr = start_addr;

    for (int i_top_level_block = 0; i_top_level_block < num_top_level_blocks; i_top_level_block++) begin
      int block_start_addr  = result.inst_start_addr + inst_headers.size();
      int block_setup_len   = $urandom_range(8, 1);

      for (int i_block_setup = 0; i_block_setup < block_setup_len; i_block_setup++) begin
        header = randomize_instruction_header($urandom_range(ecm_tx_instruction_type_dds_setup_cw_step, ecm_tx_instruction_type_nop));
        raw_data = randomize_instruction_from_header(header);

        result.inst_headers.push_back(header);
        result.inst_raw_data.push_back(raw_data);
      end

      r = $urandom_range(99);
      if (r < 10) begin
        header = randomize_instruction_header(ecm_tx_instruction_type_nop);
        raw_data = '0;
        raw_data[15:0] = pack_ecm_tx_instruction_header(header);
      end else if (r < 70) begin
        header                              = randomize_instruction_header(ecm_tx_instruction_type_wait);

        inst_setup_wait.header              = header;
        inst_setup_wait.base_duration       = $urandom_range(1000, 100);
        if ($urandom_range(99) < 50) begin
          inst_setup_wait.rand_offset_mask  = 255;
        end else begin
          inst_setup_wait.rand_offset_mask  = 0;
        end

        raw_data = '0;
        raw_data[15:0]  = pack_ecm_tx_instruction_header(header);
        raw_data[35:16] = inst_setup_wait.base_duration;
        raw_data[59:40] = inst_setup_wait.rand_offset_mask;
      end else begin
        header = randomize_instruction_header(ecm_tx_instruction_type_playback);

        inst_setup_playback.header = header;
        inst_setup_playback.mode = $urandom;
        if (inst_setup_playback.mode == 0) begin
          inst_setup_playback.base_count = $urandom_range(10, 1);
          if ($urandom_range(99) < 50) begin
            inst_setup_playback.rand_offset_mask = $urandom_range(7);
          end else begin
            inst_setup_playback.rand_offset_mask = 0;
          end
        end else begin
          inst_setup_playback.base_count = $urandom_range(4000, 500);
          if ($urandom_range(99) < 50) begin
            inst_setup_playback.rand_offset_mask = $urandom_range(1023);
          end else begin
            inst_setup_playback.rand_offset_mask = 0;
          end
        end

        raw_data = '0;
        raw_data[15:0]  = pack_ecm_tx_instruction_header(header);
        raw_data[31:16] = inst_setup_playback.base_count;
        raw_data[47:32] = inst_setup_playback.rand_offset_mask;
      end
      result.inst_headers.push_back(header);
      result.inst_raw_data.push_back(raw_data);

      if ($urandom_range(50) < 80) begin
        header = randomize_instruction_header(ecm_tx_instruction_type_jump);
        inst_setup_jump.header = header;
        inst_setup_jump.dest_index = block_start_addr;
        inst_setup_jump.counter_check = 1;
        inst_setup_jump.counter_value = jump_counter_total + $urandom_range(5, 1);
        jump_counter_total = inst_setup_jump.counter_value;

        raw_data = '0;
        raw_data[15:0]  = pack_ecm_tx_instruction_header(header);
        raw_data[31:16] = inst_setup_jump.dest_index;
        raw_data[32]    = inst_setup_jump.counter_check;
        raw_data[55:40] = inst_setup_jump.counter_value;

        result.inst_headers.push_back(header);
        result.inst_raw_data.push_back(raw_data);
      end
    end

    while (result.inst_headers.size() > (max_length - 1)) begin
      void'(result.inst_headers.pop_back());
      void'(result.inst_raw_data.pop_back());
    end

    header.valid = 0;
    raw_data[15:0]  = pack_ecm_tx_instruction_header(header);
    result.inst_headers.push_back(header);
    result.inst_raw_data.push_back(raw_data);

    return result;
  endfunction


/*
  task automatic send_dwell_entry(esm_message_dwell_entry_t entry);
    bit [esm_message_dwell_entry_packed_width - 1 : 0] packed_entry = '0;
    bit [31:0] config_data [] = new[4 + esm_message_dwell_entry_packed_width/32];

    $display("%0t: send_dwell_entry[%0d] = %p", $time, entry.entry_index, entry.entry_data);

    packed_entry[7   :   0] = entry.entry_index;
    packed_entry[63  :  32] = 32'hDEADBEEF;

    packed_entry[79  :  64] = entry.entry_data.tag;
    packed_entry[95  :  80] = entry.entry_data.frequency;
    packed_entry[127 :  96] = entry.entry_data.duration;
    packed_entry[135 : 128] = entry.entry_data.gain;
    packed_entry[143 : 136] = entry.entry_data.fast_lock_profile;
    packed_entry[167 : 160] = entry.entry_data.threshold_shift_narrow;
    packed_entry[175 : 168] = entry.entry_data.threshold_shift_wide;
    packed_entry[255 : 192] = entry.entry_data.channel_mask_narrow;
    packed_entry[263 : 256] = entry.entry_data.channel_mask_wide;
    packed_entry[287 : 272] = entry.entry_data.min_pulse_duration;

    config_data[0] = esm_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {esm_module_id_dwell_controller, esm_control_message_type_dwell_entry, 16'h0000};
    config_data[3] = 32'hDEADBEEF;

    for (int i = 0; i < (esm_message_dwell_entry_packed_width/32); i++) begin
      config_data[4 + i] = packed_entry[i*32 +: 32];
    end

    write_config(config_data);
  endtask

  function automatic bit [31:0] pack_dwell_instruction(esm_dwell_instruction_t instruction);
    bit [31:0] r = '0;

    r[0]      = instruction.valid;
    r[1]      = instruction.global_counter_check;
    r[2]      = instruction.global_counter_dec;
    r[3]      = instruction.skip_pll_prelock_wait;
    r[4]      = instruction.skip_pll_lock_check;
    r[5]      = instruction.skip_pll_postlock_wait;
    r[15:8]   = instruction.repeat_count;
    r[23:16]  = instruction.entry_index;
    r[31:24]  = instruction.next_instruction_index;

    return r;
  endfunction

  task automatic send_dwell_program(esm_message_dwell_program_t dwell_program);
    bit [esm_message_dwell_program_header_packed_width - 1 : 0] packed_header = '0;
    bit [31:0] config_data [] = new[4 + esm_message_dwell_program_header_packed_width/32 + esm_num_dwell_instructions];

    $display("%0t: send_dwell_program = %p", $time, dwell_program);

    packed_header[7:0]    = dwell_program.enable_program;
    packed_header[15:8]   = dwell_program.enable_delayed_start;
    packed_header[63:32]  = dwell_program.global_counter_init;
    packed_header[127:64] = dwell_program.delayed_start_time;

    config_data[0] = esm_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {esm_module_id_dwell_controller, esm_control_message_type_dwell_program, 16'h0000};
    config_data[3] = 32'hDEADBEEF;

    for (int i = 0; i < (esm_message_dwell_program_header_packed_width/32); i++) begin
      config_data[4 + i] = packed_header[i*32 +: 32];
    end

    for (int i = 0; i < esm_num_dwell_instructions; i++) begin
      config_data[4 + (esm_message_dwell_program_header_packed_width/32) + i] = pack_dwell_instruction(dwell_program.instructions[i]);
    end

    write_config(config_data);
  endtask

  function automatic bit compare_data(esm_dwell_metadata_t a, esm_dwell_metadata_t b);
    if(a.tag                    !== b.tag)                    return 0;
    if(a.frequency              !== b.frequency)              return 0;
    if(a.duration               !== b.duration)               return 0;
    if(a.gain                   !== b.gain)                   return 0;
    if(a.fast_lock_profile      !== b.fast_lock_profile)      return 0;
    if(a.threshold_shift_narrow !== b.threshold_shift_narrow) return 0;
    if(a.threshold_shift_wide   !== b.threshold_shift_wide)   return 0;
    if(a.channel_mask_narrow    !== b.channel_mask_narrow)    return 0;
    if(a.channel_mask_wide      !== b.channel_mask_wide)      return 0;
    if(a.min_pulse_duration     !== b.min_pulse_duration)     return 0;
    return 1;
  endfunction

  initial begin
    automatic esm_dwell_metadata_t read_data;

    wait_for_reset();

    forever begin
      rx_intf.read(read_data);
      if (compare_data(read_data, expected_data[0].data)) begin
        $display("%0t: data match (remaining=%0d) - %p", $time, expected_data.size(), read_data);
      end else begin
        $error("%0t: error -- data mismatch: expected = %p  actual = %p", $time, expected_data[0].data, read_data);
      end
      num_received++;
      void'(expected_data.pop_front());
    end
  end

  final begin
    if ( expected_data.size() != 0 ) begin
      $error("Unexpected data remaining in queue:");
      while ( expected_data.size() != 0 ) begin
        $display("%p", expected_data[0].data);
        void'(expected_data.pop_front());
      end
    end
  end

  function automatic void randomize_instructions(inout esm_message_dwell_program_t dwell_program, bit global_counter_enable);
    int random_order = $urandom_range(99) < 50;
    int loop = ($urandom_range(99) < 50) && global_counter_enable;
    int num_instructions = $urandom_range(10, esm_num_dwell_instructions - 1);
    int indices [$];

    for (int i = 1; i < num_instructions; i++) begin
      indices.push_back(i);
    end
    indices.shuffle();
    indices.push_front(0);

    for (int i = 0; i < esm_num_dwell_instructions; i++) begin
      dwell_program.instructions[i].valid = 0;
    end

    //$display("%0t: randomize_instructions: global_counter_enable=%0d", $time, global_counter_enable);

    for (int i = 0; i < num_instructions; i++) begin
      int idx = random_order ? indices[i] : i;

      dwell_program.instructions[idx].valid = 1;
      dwell_program.instructions[idx].global_counter_check    = global_counter_enable;
      dwell_program.instructions[idx].global_counter_dec      = global_counter_enable;
      dwell_program.instructions[idx].skip_pll_prelock_wait   = $urandom_range(1);
      dwell_program.instructions[idx].skip_pll_lock_check     = $urandom_range(1);
      dwell_program.instructions[idx].skip_pll_postlock_wait  = $urandom_range(1);
      dwell_program.instructions[idx].repeat_count            = $urandom_range(4);
      dwell_program.instructions[idx].entry_index             = $urandom_range(esm_num_dwell_entries - 1);

      if (i == (num_instructions - 1)) begin
        if (loop) begin
          dwell_program.instructions[idx].next_instruction_index = 0;
        end else begin
          dwell_program.instructions[idx].next_instruction_index = esm_num_dwell_instructions - 1;
        end
      end else begin
        if (random_order) begin
          dwell_program.instructions[idx].next_instruction_index = indices[i + 1];
        end else begin
          dwell_program.instructions[idx].next_instruction_index = idx + 1;
        end
      end
      //$display("%0t: randomize_instructions[%0d]: idx=%0d inst=%p", $time, i, idx, dwell_program.instructions[idx]);
    end
  endfunction

  function automatic void expect_dwell_program(esm_message_dwell_program_t dwell_program);
    int global_counter = dwell_program.global_counter_init;
    int inst_index = 0;
    bit done = 0;

    while (1) begin
      esm_dwell_instruction_t inst = dwell_program.instructions[inst_index];
      expect_t e;

      //$display("%0t: expect_dwell_program - initial: inst[%0d]=%p", $time, inst_index, inst);

      if (!inst.valid) begin
        break;
      end

      for (int i = 0; i < inst.repeat_count + 1; i++) begin
        if (inst.global_counter_check && (global_counter <= 0)) begin
          done = 1;
          break;
        end

        //$display("%0t: expecting dwell: inst_index=%0d  entry_index=%0d  next_instruction_index=%0d  global_counter=%0d", $time, inst_index, inst.entry_index, inst.next_instruction_index, global_counter);
        e.data = dwell_entry_mem[inst.entry_index];
        $display("%0t: expecting dwell: inst_index=%0d  dwell_entry=%p", $time, inst_index, e.data);

        expected_data.push_back(e);
        if (inst.global_counter_dec) begin
          global_counter--;
        end
      end

      if (done) begin
        break;
      end

      inst_index = inst.next_instruction_index;
      //$display("%0t: expect_dwell_program - final: inst_index=%0d", $time, inst_index);
    end
  endfunction
*/
  task automatic standard_tests();
    parameter NUM_TESTS = 20;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int wait_cycles;

      send_initial_config();

      for (int i_dwell = 0; i_dwell < ecm_num_dwell_entries; i_dwell++) begin
      /*
        esm_message_dwell_entry_t entry;
        entry.entry_index                       = i_dwell;
        entry.entry_data.tag                    = $urandom;
        entry.entry_data.frequency              = $urandom;
        entry.entry_data.duration               = $urandom_range(1000);
        entry.entry_data.gain                   = $urandom;
        entry.entry_data.fast_lock_profile      = $urandom;
        entry.entry_data.threshold_shift_narrow = $urandom;
        entry.entry_data.threshold_shift_wide   = $urandom;
        entry.entry_data.channel_mask_narrow    = $urandom;
        entry.entry_data.channel_mask_wide      = $urandom;
        entry.entry_data.min_pulse_duration     = $urandom;

        send_dwell_entry(entry);
        dwell_entry_mem[i_dwell] = entry.entry_data;
      end

      for (int i_rep = 0; i_rep < 10; i_rep++) begin
        int global_counter_init   = $urandom_range(500);
        bit global_counter_enable = $urandom;
        int delayed_start_time    = $urandom_range(5000);
        int delayed_start_enable  = $urandom;

        esm_message_dwell_program_t dwell_program;
        dwell_program.enable_program        = 1;
        dwell_program.enable_delayed_start  = delayed_start_enable;
        dwell_program.global_counter_init   = global_counter_init;
        dwell_program.delayed_start_time    = delayed_start_time;

        randomize_instructions(dwell_program, global_counter_enable);
        //$display("dwell_program: %p", dwell_program);
        //for (int i = 0; i < esm_num_dwell_instructions; i++) begin
        //  $display("  inst[%0d] = %p", i, dwell_program.instructions[i]);
        //end

        expect_dwell_program(dwell_program);

        send_dwell_program(dwell_program);

        //repeat(300000) @(posedge Clk);
*/

        wait_cycles = 0;
        while ((expected_data.size() != 0) && (wait_cycles < 6e5)) begin
          @(posedge Clk);
          wait_cycles++;
        end
        assert (wait_cycles < 6e5) else $error("Timeout while waiting for expected queue to empty during standard test");

        foreach (expected_data[i]) begin
          $display("%0t: end of rep: expected_data[%0d]=%p", $time, i, expected_data[i]);
        end
      end

      $display("%0t: Standard test finished: num_received = %0d", $time, num_received);

      Rst = 1;
      repeat(100) @(posedge Clk);
      Rst = 0;
    end
  endtask

  initial
  begin
    wait_for_reset();
    standard_tests();

    $finish;
  end

endmodule
