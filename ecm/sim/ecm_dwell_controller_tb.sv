`timescale 1ns/1ps

import math::*;
import ecm_pkg::*;
import dsp_pkg::*;

typedef struct {
  int data_i;
  int data_q;
  int data_p;
  int index;
  int wait_cycles;
} channelizer_transaction_t;

typedef struct {
  int data_i [ecm_num_channels - 1 : 0];
  int data_q [ecm_num_channels - 1 : 0];
  int unsigned data_p [ecm_num_channels - 1 : 0];
} channelizer_frame_t;
typedef channelizer_frame_t channelizer_frame_queue_t [$];

interface channelizer_tx_intf #(parameter DATA_WIDTH) (input logic Clk);
  channelizer_control_t             ctrl;
  logic signed [DATA_WIDTH - 1 : 0] data [1:0];
  logic [chan_power_width - 1 : 0]  power;
  logic                             active;

  task clear();
    active <= 0;
    clear_partial();
  endtask

  task clear_partial();
    ctrl.valid      <= 0;
    ctrl.last       <= 'x;
    ctrl.data_index <= 'x;
    data[0]         <= 'x;
    data[1]         <= 'x;
    power           <= 'x;
  endtask

  task write_single(input channelizer_transaction_t tx);
    active          <= 1;
    ctrl.valid      <= 1;
    ctrl.last       <= (tx.index == (ecm_num_channels - 1));
    ctrl.data_index <= tx.index;
    data[0]         <= tx.data_i;
    data[1]         <= tx.data_q;
    power           <= tx.data_p;
    @(posedge Clk);
    clear();
    repeat(tx.wait_cycles) @(posedge Clk);
  endtask

  task write_queue(input channelizer_frame_queue_t tx);
    automatic int channel_order [$];
    for (int i = 0; i < ecm_num_channels; i++) begin
      channel_order.push_back(i);
    end
    channel_order.shuffle();
    $display("write_queue: channel_order=%p", channel_order);

    clear_partial();
    active <= 1;

    for (int i_frame = 0; i_frame < tx.size(); i_frame++) begin
      for (int i_channel = 0; i_channel < ecm_num_channels; i_channel++) begin
        automatic int channel_index = channel_order[i_channel];
        ctrl.valid      <= 1;
        ctrl.last       <= (channel_index == (ecm_num_channels - 1));
        ctrl.data_index <= channel_index;
        data[0]         <= tx[i_frame].data_i[channel_index];
        data[1]         <= tx[i_frame].data_q[channel_index];
        power           <= tx[i_frame].data_p[channel_index];
        @(posedge Clk);
        clear_partial();
        @(posedge Clk);
      end
    end
    active <= 0;
    @(posedge Clk);

  endtask
endinterface

interface dwell_rx_intf (input logic Clk);
  ecm_dwell_entry_t                               data;
  logic [ecm_dwell_sequence_num_width - 1 : 0]    seq_num;
  logic [ecm_dwell_global_counter_width - 1 : 0]  global_counter;
  logic                                           active;

  task read(output ecm_dwell_entry_t dwell_entry, output int dwell_seq_num, output int dwell_global_counter);
    logic r_active;

    do begin
      r_active      <= active;
      @(posedge Clk);
      dwell_entry   <= data;
      dwell_seq_num <= seq_num;
      dwell_global_counter <= global_counter;
    end while ((active === 0) || (r_active === 1));
  endtask
endinterface

interface ecm_drfm_recording_intf (input logic Clk);
  ecm_drfm_write_req_t  data;
  int                   dwell_seq_num;

  task read(output ecm_drfm_write_req_t d, output int dwell_seq);
    do begin
      d         <= data;
      dwell_seq <= dwell_seq_num;
      @(posedge Clk);
    end while (d.valid !== 1);
  endtask
endinterface

interface ecm_tx_execution_intf (input logic Clk);
  ecm_drfm_read_req_t   drfm_read_req;
  dds_control_t         dds_control;
  ecm_output_control_t  output_control;
  logic                 dwell_active_tx;
  int                   dwell_seq_num;

  task read(output ecm_drfm_read_req_t drfm, output dds_control_t dds, output ecm_output_control_t oc, output logic active_tx, output int dwell_seq);
    do begin
      drfm      <= drfm_read_req;
      dds       <= dds_control;
      oc        <= output_control;
      active_tx <= dwell_active_tx;
      dwell_seq <= dwell_seq_num;
      @(posedge Clk);
    end while ((drfm.read_valid !== 1) && (dds.valid !== 1) && (oc.valid !== 1));
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
  parameter SYNC_TO_DRFM_READ_LATENCY = 7;

  typedef struct
  {
    int dwell_seq_num;
    int dwell_global_counter;
    ecm_dwell_entry_t dwell_entry;
  } expect_dwell_t;

  typedef struct {
    int                   dwell_seq_num;
    int                   recording_length;
    ecm_drfm_write_req_t  write_data;

    logic signed [ecm_drfm_data_width - 1 : 0] packed_wr_i;
    logic signed [ecm_drfm_data_width - 1 : 0] packed_wr_q;
  } expect_drfm_t;

  typedef struct {
    int                   unique_id;
    int                   dwell_seq_num;
    bit                   dwell_active_tx;
    int                   instruction_index;

    ecm_drfm_read_req_t   drfm_read_req;
    dds_control_t         dds_control;
    ecm_output_control_t  output_control;
  } expect_exec_t;

  logic Clk_axi;
  logic Clk;
  logic Rst;

  axi_tx_intf             #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))      cfg_tx_intf   (.Clk(Clk_axi));
  channelizer_tx_intf     #(.DATA_WIDTH(CHANNELIZER_DATA_WIDTH))  chan_intf     (.*);
  ecm_drfm_recording_intf                                         drfm_intf     (.*);
  ecm_tx_execution_intf                                           exec_intf     (.*);
  dwell_rx_intf                                                   dwell_intf    (.*);

  channelizer_control_t                           r_chan_ctrl;
  logic signed [CHANNELIZER_DATA_WIDTH - 1 : 0]   r_chan_data [1:0];
  logic [chan_power_width - 1 : 0]                r_chan_power;
  logic                                           r_chan_intf_active;
  logic                                           r_chan_valid = 0;
  int                                             r_chan_index = 0;

  logic                     w_rst_out;
  logic                     w_enable_chan;
  logic                     w_enable_synth;
  logic                     w_enable_status;
  ecm_config_data_t         w_module_config;
  logic                     w_dwell_active;
  logic                     w_dwell_active_meas;
  logic                     w_dwell_active_tx;
  logic                     w_dwell_done;
  ecm_dwell_entry_t         w_dwell_data;
  logic [31:0]              w_dwell_seq_num;
  logic [15:0]              w_dwell_global_counter;
  logic [15:0]              w_dwell_program_tag;
  logic                     r_dwell_report_done_drfm;
  logic                     r_dwell_report_done_stats;
  logic                     r_dwell_active_meas;
  logic                     r_dwell_active_tx;

  logic [3:0]               w_ad9361_control;
  logic [3:0]               r_ad9361_control;
  logic [7:0]               w_ad9361_status;

  logic                     w_error_program_fifo_overflow;
  logic                     w_error_program_fifo_underflow;

  channelizer_control_t     r_sync_data = '{default: '0};

  bit [31:0]                config_seq_num = 0;
  ecm_dwell_entry_t         dwell_entry_mem [ecm_num_dwell_entries - 1 : 0];

  expect_dwell_t            expected_data_dwell [$];
  int                       num_received_dwell = 0;

  expect_drfm_t             expected_data_drfm [ecm_num_channels - 1 : 0] [$];
  int                       num_received_drfm = 0;

  expect_exec_t             expected_data_exec [ecm_num_channels - 1 : 0] [$];
  int                       num_received_exec = 0;
  int                       num_dropped_exec = 0;

  channelizer_frame_queue_t dwell_channelizer_tx_data [int];

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
    .Clk                          (Clk),
    .Rst                          (Rst),

    .Module_config                (w_module_config),

    .Ad9361_control               (w_ad9361_control),
    .Ad9361_status                (w_ad9361_status),

    .Channelizer_ctrl             (r_chan_ctrl), //(chan_intf.ctrl),
    .Channelizer_data             (r_chan_data), //(chan_intf.data),
    .Channelizer_pwr              (r_chan_power), //(chan_intf.power),

    .Sync_data                    (r_sync_data),

    .Dwell_active                 (w_dwell_active),
    .Dwell_active_measurement     (w_dwell_active_meas),
    .Dwell_active_transmit        (w_dwell_active_tx),
    .Dwell_done                   (w_dwell_done),
    .Dwell_data                   (w_dwell_data),
    .Dwell_sequence_num           (w_dwell_seq_num),
    .Dwell_global_counter         (w_dwell_global_counter),
    .Dwell_program_tag            (w_dwell_program_tag),
    .Dwell_report_done_drfm       (r_dwell_report_done_drfm),
    .Dwell_report_done_stats      (r_dwell_report_done_stats),

    .Drfm_write_req               (drfm_intf.data),
    .Drfm_read_req                (exec_intf.drfm_read_req),
    .Dds_control                  (exec_intf.dds_control),
    .Output_control               (exec_intf.output_control),

    .Error_program_fifo_overflow  (w_error_program_fifo_overflow),
    .Error_program_fifo_underflow (w_error_program_fifo_underflow)
  );

  assign dwell_intf.data            = w_dwell_data;
  assign dwell_intf.seq_num         = w_dwell_seq_num;
  assign dwell_intf.global_counter  = w_dwell_global_counter;
  assign dwell_intf.active          = w_dwell_active;

  assign drfm_intf.dwell_seq_num    = w_dwell_seq_num;
  assign exec_intf.dwell_seq_num    = w_dwell_seq_num;
  assign exec_intf.dwell_active_tx  = r_dwell_active_tx;  //match hardware timing

  always_ff @(posedge Clk) begin
    if (!Rst) begin
      if (w_error_program_fifo_overflow)  $error("fifo overflow");
      if (w_error_program_fifo_underflow) $error("fifo underflow");
    end
  end

  always_ff @(posedge Clk) begin
    r_ad9361_control    <= w_ad9361_control;
    r_dwell_active_meas <= w_dwell_active_meas;
    r_dwell_active_tx   <= w_dwell_active_tx;
  end

  initial begin
    w_ad9361_status <= 0;

    while (1) begin
      if (w_ad9361_control !== r_ad9361_control) begin
        w_ad9361_status <= '0;
        repeat ($urandom_range(10, 5)) @(posedge Clk);
        w_ad9361_status <= '1;
      end
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

  always_ff @(posedge Clk) begin
    if (chan_intf.active) begin
      r_chan_ctrl             <= chan_intf.ctrl;
      r_chan_data             <= chan_intf.data;
      r_chan_power            <= chan_intf.power;
    end else if (ecm_dwell_controller_tb.dut.s_state == 9) begin //S_DWELL_FLUSH_MEAS
      r_chan_valid <= !r_chan_valid;
      if (r_chan_valid) begin
        r_chan_index <= ((r_chan_index + 1) % ecm_num_channels);
      end
      r_chan_ctrl.valid       <= r_chan_valid;
      r_chan_ctrl.last        <= r_chan_index == (ecm_num_channels - 1);
      r_chan_ctrl.data_index  <= r_chan_index;
      r_chan_data             <= '{default: 'x};
      r_chan_power            <= $urandom;
    end else begin
      r_chan_ctrl.valid       <= 0;
      r_chan_ctrl.last        <= 'x;
      r_chan_power            <= 'x;
    end
  end

  always_ff @(posedge Clk) begin
    if (!r_sync_data.valid) begin
      r_sync_data.valid       <= 1;
      r_sync_data.last        <= ((r_sync_data.data_index + 1) % ecm_num_channels) == (ecm_num_channels - 1);
      r_sync_data.data_index  <= ((r_sync_data.data_index + 1) % ecm_num_channels);
    end else begin
      r_sync_data.valid       <= 0;
      r_sync_data.last        <= 'x;
    end
  end

  initial begin
    wait_for_reset();
    @(posedge Clk);

    forever begin
      if (w_dwell_active_meas && !r_dwell_active_meas) begin
        if (dwell_channelizer_tx_data.exists(w_dwell_seq_num)) begin
          $display("%0t: dwell_seq_num=%0d - sending channelizer data", $time, w_dwell_seq_num);
          chan_intf.write_queue(dwell_channelizer_tx_data[w_dwell_seq_num]);
          $display("%0t: dwell_seq_num=%0d - channelizer data sent", $time, w_dwell_seq_num);
        end
      end

      @(posedge Clk);
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

  typedef struct {
    int                                             inst_start_addr;
    ecm_tx_instruction_header_t                     inst_headers  [$];
    logic [ecm_tx_instruction_data_width - 1 : 0]   inst_raw_data [$];
  } tx_instructions_t;

  typedef struct {
    int                           dwell_index;
    int                           channel_index;
    ecm_channel_control_entry_t   entry;
  } channel_entry_t;

  typedef struct {
    int               dwell_index;
    ecm_dwell_entry_t entry;
  } dwell_data_t;

  typedef tx_instructions_t tx_instructions_queue_t [$];
  typedef channel_entry_t   channel_entry_queue_t [$];
  typedef dwell_data_t      dwell_data_queue_t [$];


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

  function automatic tx_instructions_t randomize_tx_program_instructions(int start_addr, int max_length, int channel_mem_depth, int max_playback_length);
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
      int block_start_addr  = result.inst_start_addr + result.inst_headers.size();
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
          inst_setup_playback.base_count = $urandom_range((max_playback_length / channel_mem_depth) + 1, 1);
          inst_setup_playback.rand_offset_mask = 0; //simplify verification

          /*if ($urandom_range(99) < 50) begin
            inst_setup_playback.rand_offset_mask = $urandom_range(7);
          end else begin
            inst_setup_playback.rand_offset_mask = 0;
          end*/
        end else begin
          inst_setup_playback.base_count = $urandom_range(max_playback_length, 0.1*max_playback_length);
          inst_setup_playback.rand_offset_mask = 0; //simplify verification
          /*if ($urandom_range(99) < 50) begin
            inst_setup_playback.rand_offset_mask = $urandom_range(1023);
          end else begin
            inst_setup_playback.rand_offset_mask = 0;
          end*/
        end

        raw_data = '0;
        raw_data[15:0]  = pack_ecm_tx_instruction_header(header);
        raw_data[16]    = inst_setup_playback.mode;
        raw_data[47:32] = inst_setup_playback.base_count;
        raw_data[63:48] = inst_setup_playback.rand_offset_mask;
        $display("inst_setup_playback=%p  raw_data=%016X", inst_setup_playback, raw_data);
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

  function automatic tx_instructions_queue_t randomize_tx_programs(int num_programs, int channel_mem_depth, int max_playback_length);
    tx_instructions_queue_t r;

    for (int i = 0; i < num_programs; i++) begin
      r.push_back(randomize_tx_program_instructions(i * 32, 32, channel_mem_depth, max_playback_length));
    end

    return r;
  endfunction

  task automatic send_tx_program(tx_instructions_t data);
    $display("%0t: sending tx program: addr=%0X", $time, data.inst_start_addr);
    for (int i_inst = 0; i_inst < data.inst_raw_data.size(); i_inst++) begin
      bit [31:0] config_data [] = new[4 + ecm_tx_instruction_data_width/32];
      bit [15:0] address = data.inst_start_addr + i_inst;

      config_data[0] = ecm_control_magic_num;
      config_data[1] = config_seq_num++;
      config_data[2] = {ecm_module_id_dwell_controller, ecm_control_message_type_dwell_tx_instruction, address};
      config_data[3] = 32'hDEADBEEF;

      $display("    instruction[%0d]=%016X -- header=%p", i_inst, data.inst_raw_data[i_inst], data.inst_headers[i_inst]);

      for (int i = 0; i < (ecm_tx_instruction_data_width/32); i++) begin
        config_data[4 + i] = data.inst_raw_data[i_inst][i*32 +: 32];
      end

      write_config(config_data);
    end
  endtask

  function automatic channel_entry_queue_t randomize_channel_entries(dwell_data_queue_t dwell_entries, tx_instructions_queue_t tx_programs, int channel_mem_depth, bit enable_immediate);
    channel_entry_queue_t r;

    for (int i_dwell = 0; i_dwell < dwell_entries.size(); i_dwell++) begin
      int max_trigger_duration = (dwell_entries[i_dwell].entry.measurement_duration / (2*ecm_num_channels)) * 0.75;
      max_trigger_duration = (max_trigger_duration > channel_mem_depth) ? channel_mem_depth : max_trigger_duration;

      for (int i_channel = 0; i_channel < ecm_num_channels; i_channel++) begin
        ecm_channel_control_entry_t d;
        int thresh_bits;

        d.enable        = ($urandom_range(99) < 90);
        d.trigger_mode  = $urandom_range(ecm_channel_trigger_mode_threshold_trigger, ecm_channel_trigger_mode_none); //$urandom_range(ecm_channel_trigger_mode_force_trigger, ecm_channel_trigger_mode_none);

        if ($urandom_range(99) < 50) begin
          d.trigger_duration_max_minus_one  = max_trigger_duration - 1;
        end else begin
          d.trigger_duration_max_minus_one  = $urandom_range(max_trigger_duration - 1, max_trigger_duration * 0.5);
        end

        $display("randomize_channel_entries: dwell_index=%0d channel_index=%0d -- measurement_duration=%0d  max_trigger_duration=%0d  entry.trigger_duration_max_minus_one=%0d  channel_mem_depth=%0d",
          i_dwell, i_channel, dwell_entries[i_dwell].entry.measurement_duration, max_trigger_duration, d.trigger_duration_max_minus_one, channel_mem_depth);

        thresh_bits = $urandom_range(30, 16);

        d.trigger_threshold   = $urandom_range(2**thresh_bits - 1, 2**(thresh_bits - 1));
        d.trigger_hyst_shift  = $urandom_range(3, 1);
        d.drfm_gain           = 0; //TODO: test
        d.recording_address   = i_channel * (ecm_drfm_mem_depth / ecm_num_channels);

        for (int i_program_entry = 0; i_program_entry < ecm_num_channel_tx_program_entries; i_program_entry++) begin
          int tx_program_index = $urandom_range(tx_programs.size() - 1, 0);

          d.program_entries[i_program_entry].valid                        = ($urandom_range(99) < 75);
          d.program_entries[i_program_entry].trigger_immediate_after_min  = enable_immediate ? $urandom : 0;
          d.program_entries[i_program_entry].tx_instruction_index         = tx_programs[tx_program_index].inst_start_addr;

          if ($urandom_range(99) < 50) begin
            d.program_entries[i_program_entry].duration_gate_min_minus_one  = max_trigger_duration - 1;
            d.program_entries[i_program_entry].duration_gate_max_minus_one  = max_trigger_duration - 1;
          end else begin
            d.program_entries[i_program_entry].duration_gate_min_minus_one  = $urandom_range(500, 10);
            d.program_entries[i_program_entry].duration_gate_max_minus_one  = $urandom_range(d.trigger_duration_max_minus_one, d.program_entries[i_program_entry].duration_gate_min_minus_one);
          end
        end

        r.push_back('{dwell_index: i_dwell, channel_index: i_channel, entry:d});
      end
    end

    return r;
  endfunction

  function automatic bit [ecm_channel_tx_program_entry_aligned_width - 1 : 0] pack_ecm_channel_tx_program_entry(ecm_channel_tx_program_entry_t data);
    bit [ecm_channel_tx_program_entry_aligned_width - 1 : 0] r;

    r[0]      = data.valid;
    r[8]      = data.trigger_immediate_after_min;
    r[31:16]  = data.tx_instruction_index;
    r[47:32]  = data.duration_gate_min_minus_one;
    r[63:48]  = data.duration_gate_max_minus_one;

    return r;
  endfunction

  task automatic send_channel_entry(channel_entry_t data);
    bit [ecm_channel_control_entry_aligned_width - 1 : 0] packed_entry = '0;
    bit [31:0] config_data [] = new[4 + ecm_channel_control_entry_aligned_width/32];
    bit [15:0] address = data.dwell_index * ecm_num_channels + data.channel_index;

    $display("%0t: send_channel_entry[%0d][%0d] = %p", $time, data.dwell_index, data.channel_index, data.entry);

    packed_entry[0]         = data.entry.enable;
    packed_entry[15:8]      = data.entry.trigger_mode;
    packed_entry[31:16]     = data.entry.trigger_duration_max_minus_one;
    packed_entry[63:32]     = data.entry.trigger_threshold;
    packed_entry[71:64]     = data.entry.trigger_hyst_shift;
    packed_entry[79:72]     = data.entry.drfm_gain;
    packed_entry[95:80]     = data.entry.recording_address;

    for (int i_program_entry = 0; i_program_entry < ecm_num_channel_tx_program_entries; i_program_entry++) begin
      bit [ecm_channel_tx_program_entry_aligned_width - 1 : 0] p = pack_ecm_channel_tx_program_entry(data.entry.program_entries[i_program_entry]);
      //$display("  program[%0d]=%016X %p", i_program_entry, p, data.entry.program_entries[i_program_entry]);
      packed_entry[(96 + ecm_channel_tx_program_entry_aligned_width*i_program_entry) +: ecm_channel_tx_program_entry_aligned_width]  = p;
    end

    config_data[0] = ecm_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {ecm_module_id_dwell_controller, ecm_control_message_type_dwell_channel_control, address};
    config_data[3] = 32'hDEADBEEF;

    for (int i = 0; i < (ecm_channel_control_entry_aligned_width/32); i++) begin
      config_data[4 + i] = packed_entry[i*32 +: 32];
      //$display(" config_data[%0d]=%08X", 4+i, config_data[4+i]);
    end

    write_config(config_data);
  endtask

  function automatic ecm_dwell_entry_t randomize_dwell_entry();
    ecm_dwell_entry_t r;

    r.valid                   = 1;
    r.global_counter_check    = 0;  //TODO: verify
    r.global_counter_dec      = 0;
    r.skip_pll_prelock_wait   = $urandom;
    r.skip_pll_lock_check     = 0;
    r.skip_pll_postlock_wait  = 0;
    r.repeat_count            = ($urandom_range(99) < 50) ? $urandom_range(2, 0) : 0;
    r.fast_lock_profile       = $urandom;
    r.next_dwell_index        = $urandom;
    r.pll_pre_lock_delay      = $urandom_range(500, 100);
    r.pll_post_lock_delay     = $urandom_range(500, 100);
    r.tag                     = $urandom;
    r.frequency               = $urandom;
    r.measurement_duration    = $urandom_range(5000*ecm_num_channels, 100*ecm_num_channels);
    r.total_duration_max      = r.measurement_duration + $urandom_range(5000*ecm_num_channels, 1000*ecm_num_channels);

    return r;
  endfunction

  function automatic dwell_data_queue_t randomize_dwell_entries(int num_dwells);
    dwell_data_queue_t r;

    for (int i = 0; i < num_dwells; i++) begin
      dwell_data_t d;

      d.dwell_index = i;
      d.entry = randomize_dwell_entry();
      d.entry.global_counter_check  = 1;
      d.entry.global_counter_dec    = 1;
      d.entry.next_dwell_index      = i + 1;
      r.push_back(d);
    end

    r.push_back('{entry: '{valid: 0, default:'x}, dwell_index: num_dwells});

    return r;
  endfunction

  task automatic send_dwell_entry(dwell_data_t data);
    bit [ecm_dwell_entry_aligned_width - 1 : 0] packed_entry = '0;
    bit [31:0] config_data [] = new[4 + ecm_dwell_entry_aligned_width/32];
    bit [15:0] address = data.dwell_index;

    $display("%0t: send_dwell_entry[%0d] = %p", $time, data.dwell_index, data.entry);

    packed_entry[0]         = data.entry.valid;
    packed_entry[1]         = data.entry.global_counter_check;
    packed_entry[2]         = data.entry.global_counter_dec;
    packed_entry[3]         = data.entry.skip_pll_prelock_wait;
    packed_entry[4]         = data.entry.skip_pll_lock_check;
    packed_entry[5]         = data.entry.skip_pll_postlock_wait;

    packed_entry[15:8]      = data.entry.repeat_count;
    packed_entry[23:16]     = data.entry.fast_lock_profile;
    packed_entry[31:24]     = data.entry.next_dwell_index;
    packed_entry[47:32]     = data.entry.pll_pre_lock_delay;
    packed_entry[63:48]     = data.entry.pll_post_lock_delay;
    packed_entry[79:64]     = data.entry.tag;
    packed_entry[95:80]     = data.entry.frequency;
    packed_entry[127:96]    = data.entry.measurement_duration;
    packed_entry[159:128]   = data.entry.total_duration_max;

    config_data[0] = ecm_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {ecm_module_id_dwell_controller, ecm_control_message_type_dwell_entry, address};
    config_data[3] = 32'hDEADBEEF;

    for (int i = 0; i < (ecm_dwell_entry_aligned_width/32); i++) begin
      config_data[4 + i] = packed_entry[i*32 +: 32];
    end

    write_config(config_data);
  endtask

  task automatic send_dwell_program(ecm_dwell_program_entry_t data);
    bit [ecm_dwell_program_entry_aligned_width + 16 - 1 : 0] packed_entry = '0; //16 bits of padding -- TODO: add software assert for min size
    bit [31:0] config_data [] = new[4 + $size(packed_entry)/32];

    $display("%0t: send_dwell_program = %p", $time, data);

    packed_entry[0]     = data.enable;
    packed_entry[15:8]  = data.initial_dwell_index;
    packed_entry[31:16] = data.global_counter_init;
    packed_entry[47:32] = data.tag;

    config_data[0] = ecm_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {ecm_module_id_dwell_controller, ecm_control_message_type_dwell_program, 16'h0000};
    config_data[3] = 32'hDEADBEEF;

    for (int i = 0; i < (ecm_dwell_program_entry_aligned_width/32); i++) begin
      config_data[4 + i] = packed_entry[i*32 +: 32];
    end

    write_config(config_data);
  endtask

  function automatic void generate_channelizer_data(ecm_dwell_program_entry_t dwell_program, dwell_data_queue_t dwell_entries, channel_entry_queue_t channel_entries, int initial_seq_num);
    ecm_dwell_entry_t             dwell_mem [ecm_num_dwell_entries - 1 : 0] = '{default: '{default:'0}};
    ecm_channel_control_entry_t   channel_mem [ecm_num_dwell_entries - 1 : 0][ecm_num_channels - 1 : 0] = '{default: '{default: '{default:'0}}};
    int                           dwell_index = dwell_program.initial_dwell_index;
    int                           global_counter = dwell_program.global_counter_init;
    int                           repeat_count = 0;
    int                           num_dwells = 0;
    int                           dwell_seq_num = initial_seq_num;
    int                           dwell_channelizer_data[int][ecm_num_channels - 1:0];

    if (!dwell_program.enable) begin
      return;
    end

    $display("%p", dwell_entries);

    $display("generate_channelizer_data: dwell_program started - dwell_seq_num=%0d dwell_index=%0d global_counter=%0d", dwell_seq_num, dwell_index, global_counter);

    for (int i = 0; i < dwell_entries.size(); i++) begin
      dwell_data_t d = dwell_entries[i];
      dwell_mem[d.dwell_index] = d.entry;
    end
    for (int i = 0; i < channel_entries.size(); i++) begin
      channel_entry_t d = channel_entries[i];
      channel_mem[d.dwell_index][d.channel_index] = d.entry;
    end

    forever begin
      ecm_dwell_entry_t dwell_entry = dwell_mem[dwell_index];
      channelizer_frame_queue_t dwell_frame_queue;
      int num_dwell_frames = dwell_entry.measurement_duration / (2*ecm_num_channels);

      $display("generate_channelizer_data: [start] dwell_seq_num=%0d dwell_index=%0d - duration=%0d num_dwell_frames=%0d", dwell_seq_num, dwell_index, dwell_entry.measurement_duration, num_dwell_frames);

      if (!dwell_entry.valid || (dwell_entry.global_counter_check && (global_counter == 0))) begin
        $display("generate_channelizer_data: [exit]: dwell_seq_num=%0d valid=%0d counter_check=%0d counter_value=%0d", dwell_seq_num, dwell_entry.valid, dwell_entry.global_counter_check, global_counter);
        break;
      end

      for (int i = 0; i < num_dwell_frames; i++) begin
        channelizer_frame_t d = '{default: 0};
        dwell_frame_queue.push_back(d);
      end

      $display("generate_channelizer_data: [generate] dwell_seq_num=%0d  index=%0d  repeat_count=%0d  global_counter=%0d", dwell_seq_num, dwell_index, repeat_count, global_counter);

      for (int i_channel = 0; i_channel < ecm_num_channels; i_channel++) begin
        ecm_channel_control_entry_t chan_entry = channel_mem[dwell_index][i_channel];
        if (!chan_entry.enable || (chan_entry.trigger_mode == ecm_channel_trigger_mode_none) || (chan_entry.trigger_mode == ecm_channel_trigger_mode_force_trigger)) begin
          //channel disabled or no/forced trigger - data doesn't matter
          foreach(dwell_frame_queue[i]) begin
            dwell_frame_queue[i].data_i[i_channel] = $urandom;
            dwell_frame_queue[i].data_q[i_channel] = $urandom;
            dwell_frame_queue[i].data_p[i_channel] = $urandom;
          end

          $display("generate_channelizer_data: [channel] disabled/none/forced:      dwell_seq_num=%0d channel_index=%0d", dwell_seq_num, i_channel);
        end else begin //threshold trigger
          int threshold_new   = chan_entry.trigger_threshold;
          int threshold_cont  = chan_entry.trigger_threshold >> chan_entry.trigger_hyst_shift;
          $display("generate_channelizer_data: [channel] threshold_trigger:         dwell_seq_num=%0d channel_index=%0d   thresh_new=%0d thresh_cont=%0d", dwell_seq_num, i_channel, threshold_new, threshold_cont);

          foreach(dwell_frame_queue[i]) begin
            dwell_frame_queue[i].data_i[i_channel] = $urandom;
            dwell_frame_queue[i].data_q[i_channel] = $urandom;
            dwell_frame_queue[i].data_p[i_channel] = $urandom_range(threshold_cont - 1, 0);
          end

          if ($urandom_range(99) < 75) begin
            int pulse_duration;
            int start_index;
            int end_index;

            if ($urandom_range(99) < 25) begin
              pulse_duration = chan_entry.trigger_duration_max_minus_one + 1;
            end else begin
              pulse_duration = $urandom_range(chan_entry.trigger_duration_max_minus_one + 1, 1);
            end

            start_index = $urandom_range(dwell_frame_queue.size() * 0.75 - pulse_duration * 1.1, 0);
            start_index = (start_index < 0) ? 0 : start_index;
            end_index = start_index;

            for (int i = 0; i < dwell_frame_queue.size(); i++) begin
              if ((i >= start_index) && ((i - start_index) < pulse_duration)) begin
                int p;
                if (i == start_index) begin
                  if ($urandom_range(99) < 50) begin
                    p = threshold_new;
                  end else begin
                    p = $urandom_range(2**chan_power_width - 1, threshold_new);
                  end
                end else begin
                  int r = $urandom_range(99);
                  if (r < 10) begin
                    p = threshold_cont;
                  end else if (r < 50) begin
                    p = $urandom_range(threshold_new - 1, threshold_cont);
                  end else begin
                    p = $urandom_range(2**chan_power_width - 1, threshold_cont);
                  end
                end
                end_index = i;
                dwell_frame_queue[i].data_p[i_channel] = p;
              end
            end

            $display("generate_channelizer_data: [channel] threshold_trigger pulse:   dwell_seq_num=%0d channel_index=%0d  start_index=%0d end_index=%0d (total_length=%0d)", dwell_seq_num, i_channel, start_index, end_index, dwell_frame_queue.size());
          end

        end
      end

      $display("generate_channelizer_data: adding queue (size=%0d) for seq=%0d", dwell_frame_queue.size(), dwell_seq_num);
      dwell_channelizer_tx_data[dwell_seq_num] = dwell_frame_queue;

      dwell_seq_num++;

      if (dwell_entry.global_counter_dec) begin
        global_counter--;
      end

      if (repeat_count == dwell_entry.repeat_count) begin
        dwell_index = dwell_entry.next_dwell_index;
        repeat_count = 0;
      end else begin
        repeat_count++;
      end

      if (num_dwells > 500) begin
        $error("too many dwells - infinite loop?");
        break;
      end
      num_dwells++;
    end

  endfunction


  function automatic void generate_expected_events(ecm_dwell_program_entry_t dwell_program, dwell_data_queue_t dwell_entries, channel_entry_queue_t channel_entries, tx_instructions_queue_t tx_programs, int initial_dwell_seq_num);
    ecm_dwell_entry_t                             dwell_mem [ecm_num_dwell_entries - 1 : 0] = '{default: '{default:'0}};
    ecm_channel_control_entry_t                   channel_mem [ecm_num_dwell_entries - 1 : 0][ecm_num_channels - 1 : 0] = '{default: '{default: '{default:'0}}};
    ecm_tx_instruction_header_t                   instruction_mem_header [ecm_num_tx_instructions - 1 : 0] = '{default: '{default: '0}};
    logic [ecm_tx_instruction_data_width - 1 : 0] instruction_mem_raw [ecm_num_tx_instructions - 1 : 0] = '{default: '0};

    int dwell_seq_num = initial_dwell_seq_num;
    int dwell_index = dwell_program.initial_dwell_index;
    int global_counter = dwell_program.global_counter_init;
    int repeat_count = 0;
    int num_dwells = 0;
    longint expect_id = 0;

    bit verbose = 0;

    if (!dwell_program.enable) begin
      return;
    end

    for (int i = 0; i < dwell_entries.size(); i++) begin
      dwell_data_t d = dwell_entries[i];
      dwell_mem[d.dwell_index] = d.entry;
    end
    for (int i = 0; i < channel_entries.size(); i++) begin
      channel_entry_t d = channel_entries[i];
      channel_mem[d.dwell_index][d.channel_index] = d.entry;
    end
    for (int i = 0; i < tx_programs.size(); i++) begin
      tx_instructions_t pgm = tx_programs[i];
      for (int j = 0; j < pgm.inst_headers.size(); j++) begin
        int addr = pgm.inst_start_addr + j;
        instruction_mem_header[addr] = pgm.inst_headers[j];
        instruction_mem_raw[addr] = pgm.inst_raw_data[j];
      end
    end

    forever begin
      ecm_dwell_entry_t dwell_entry = dwell_mem[dwell_index];
      channelizer_frame_queue_t dwell_frame_queue = dwell_channelizer_tx_data[dwell_seq_num];
      bit [ecm_num_channels - 1 : 0] trigger_active = '0;
      int trigger_instruction_index [ecm_num_channels - 1 : 0] = '{default: 0};
      int trigger_length [ecm_num_channels - 1 : 0] = '{default: 0};

      if (!dwell_entry.valid || (dwell_entry.global_counter_check && (global_counter == 0))) begin
        break;
      end

      expected_data_dwell.push_back('{dwell_entry: dwell_entry, dwell_seq_num: dwell_seq_num, dwell_global_counter: global_counter});

      for (int i_channel = 0; i_channel < ecm_num_channels; i_channel++) begin
        ecm_channel_control_entry_t chan_entry = channel_mem[dwell_index][i_channel];
        int drfm_gain_offset  = chan_entry.drfm_gain ? 0 : (CHANNELIZER_DATA_WIDTH - ecm_drfm_data_width);
        int threshold_new     = chan_entry.trigger_threshold;
        int threshold_cont    = chan_entry.trigger_threshold >> chan_entry.trigger_hyst_shift;
        int recording_length  = 0;

        if (!chan_entry.enable || (chan_entry.trigger_mode == ecm_channel_trigger_mode_none)) begin
          continue;
        end

        if (chan_entry.trigger_mode == ecm_channel_trigger_mode_force_trigger) begin
          for (int i = 0; (i < dwell_frame_queue.size()) && (i <= chan_entry.trigger_duration_max_minus_one); i++) begin
            expect_drfm_t e;
            e.write_data.valid          = 1;
            e.write_data.first          = (i == 0);
            e.write_data.last           = (i == (dwell_frame_queue.size() - 1)) || (i == chan_entry.trigger_duration_max_minus_one);
            e.write_data.channel_index  = i_channel;
            e.write_data.address        = chan_entry.recording_address + i;
            e.dwell_seq_num             = dwell_seq_num;
            e.recording_length          = recording_length;

            for (int j = 0; j < ecm_drfm_data_width; j++) begin
              e.write_data.data[0][j] = dwell_frame_queue[i].data_i[i_channel][drfm_gain_offset + j];
              e.write_data.data[1][j] = dwell_frame_queue[i].data_q[i_channel][drfm_gain_offset + j];
              e.packed_wr_i[j]        = dwell_frame_queue[i].data_i[i_channel][drfm_gain_offset + j];
              e.packed_wr_q[j]        = dwell_frame_queue[i].data_q[i_channel][drfm_gain_offset + j];
            end

            expected_data_drfm[i_channel].push_back(e);
            recording_length++;

            if (i == 0) begin
              $display("generate_expected_events: forced_trigger[%0d][%0d]: index=%0d  data_i=%0d data_q=%0d (start)", dwell_seq_num, i_channel, i, e.packed_wr_i, e.packed_wr_q);
            end else if ((i >= dwell_frame_queue.size()) || (i > chan_entry.trigger_duration_max_minus_one)) begin
              $display("generate_expected_events: forced_trigger[%0d][%0d]: index=%0d  data_i=%0d data_q=%0d conditions: %0d %0d(stop)", dwell_seq_num, i_channel, i, e.packed_wr_i, e.packed_wr_q,
                (i < dwell_frame_queue.size()), (i <= chan_entry.trigger_duration_max_minus_one));
            end
          end
        end else begin //ecm_channel_trigger_mode_threshold_trigger
          bit pulse_active = 0;
          bit pulse_last = 0;
          int pulse_addr = 0;

          for (int i = 0; i < dwell_frame_queue.size(); i++) begin
            expect_drfm_t e;

            if (pulse_active) begin
              pulse_last = (i == (dwell_frame_queue.size() - 1)) || (pulse_addr == chan_entry.trigger_duration_max_minus_one) || (dwell_frame_queue[i].data_p[i_channel] < threshold_cont);

              //TODO: immediate start

              e.write_data.valid          = 1;
              e.write_data.first          = 0;
              e.write_data.last           = pulse_last;
              e.write_data.channel_index  = i_channel;
              e.write_data.address        = chan_entry.recording_address + pulse_addr;
              e.dwell_seq_num             = dwell_seq_num;
              e.recording_length          = recording_length;

              for (int j = 0; j < ecm_drfm_data_width; j++) begin
                e.write_data.data[0][j] = dwell_frame_queue[i].data_i[i_channel][drfm_gain_offset + j];
                e.write_data.data[1][j] = dwell_frame_queue[i].data_q[i_channel][drfm_gain_offset + j];
                e.packed_wr_i[j]        = dwell_frame_queue[i].data_i[i_channel][drfm_gain_offset + j];
                e.packed_wr_q[j]        = dwell_frame_queue[i].data_q[i_channel][drfm_gain_offset + j];
              end

              expected_data_drfm[i_channel].push_back(e);
              recording_length++;
              pulse_active = !pulse_last;
              pulse_addr++;

              if (pulse_last) begin
                $display("generate_expected_events: threshold_trigger[%0d][%0d]: index=%0d  data_i=%0d data_q=%0d data_p=%0d - threshold_cont=%0d - %0d %0d %0d (stop)",
                  dwell_seq_num, i_channel, i, e.packed_wr_i, e.packed_wr_q, dwell_frame_queue[i].data_p[i_channel], threshold_cont,
                  (i == (dwell_frame_queue.size() - 1)), (pulse_addr == chan_entry.trigger_duration_max_minus_one), (dwell_frame_queue[i].data_p[i_channel] < threshold_cont));
              end

            end else if (dwell_frame_queue[i].data_p[i_channel] >= threshold_new) begin
              e.write_data.valid          = 1;
              e.write_data.first          = 1;
              e.write_data.last           = 0;
              e.write_data.channel_index  = i_channel;
              e.write_data.address        = chan_entry.recording_address + pulse_addr;
              e.dwell_seq_num             = dwell_seq_num;

              for (int j = 0; j < ecm_drfm_data_width; j++) begin
                e.write_data.data[0][j] = dwell_frame_queue[i].data_i[i_channel][drfm_gain_offset + j];
                e.write_data.data[1][j] = dwell_frame_queue[i].data_q[i_channel][drfm_gain_offset + j];
                e.packed_wr_i[j]        = dwell_frame_queue[i].data_i[i_channel][drfm_gain_offset + j];
                e.packed_wr_q[j]        = dwell_frame_queue[i].data_q[i_channel][drfm_gain_offset + j];
              end

              expected_data_drfm[i_channel].push_back(e);
              recording_length++;
              pulse_addr = 1;
              pulse_active = 1;

              $display("generate_expected_events: threshold_trigger[%0d][%0d]: index=%0d  data_i=%0d data_q=%0d data_p=%0d - threshold_new=%0d (start)",
                dwell_seq_num, i_channel, i, e.packed_wr_i, e.packed_wr_q, dwell_frame_queue[i].data_p[i_channel], threshold_new);
            end
          end
          //dwell_frame_queue[i].data_p[i_channel] = p;
        end

        if (recording_length > 0) begin
          $display("generate_expected_events: dwell_seq_num[%0d] channel[%0d] recording_length=%0d trigger_mode=%0d", dwell_seq_num, i_channel, recording_length, chan_entry.trigger_mode);

          if (chan_entry.trigger_mode == ecm_channel_trigger_mode_force_trigger) begin
            if (chan_entry.program_entries[0].valid) begin
              trigger_active[i_channel]             = 1;
              trigger_instruction_index[i_channel]  = chan_entry.program_entries[0].tx_instruction_index;
              trigger_length[i_channel]             = recording_length;
              $display("generate_expected_events: channel[%0d] forced trigger: index=%0d", i_channel, trigger_instruction_index[i_channel]);
            end
          end else begin //ecm_channel_trigger_mode_threshold_trigger
            for (int i = 0; i < ecm_num_channel_tx_program_entries; i++) begin
              bit min_check = ((recording_length - 1) >= chan_entry.program_entries[i].duration_gate_min_minus_one);
              bit max_check = ((recording_length - 1) <= chan_entry.program_entries[i].duration_gate_max_minus_one) || chan_entry.program_entries[i].trigger_immediate_after_min;

              if (!chan_entry.program_entries[i].valid) begin
                continue;
              end

              if (min_check && max_check) begin
                trigger_active[i_channel]             = 1;
                trigger_instruction_index[i_channel]  = chan_entry.program_entries[i].tx_instruction_index;
                trigger_length[i_channel]             = recording_length;
                $display("generate_expected_events: dwell_seq_num[%0d] channel[%0d] threshold trigger: program=%0d inst_index=%0d -- immediate=%0d", dwell_seq_num, i_channel, i, trigger_instruction_index[i_channel], chan_entry.program_entries[i].trigger_immediate_after_min);
                break;
              end
            end
          end
        end

      end

      for (int i_channel = 0; i_channel < ecm_num_channels; i_channel++) begin
        ecm_channel_control_entry_t chan_entry = channel_mem[dwell_index][i_channel];
        int instruction_index = trigger_instruction_index[i_channel];
        int loop_count = 0;
        dds_control_t dds_control;
        ecm_output_control_t output_control;
        ecm_drfm_read_req_t drfm_read_req;
        ecm_drfm_read_req_t playback_queue [$];

        if (!trigger_active[i_channel]) begin
          continue;
        end

        dds_control.channel_index = i_channel;
        output_control.channel_index = i_channel;

        forever begin
          ecm_tx_instruction_header_t header = instruction_mem_header[instruction_index];
          logic [ecm_tx_instruction_data_width - 1 : 0] inst_raw = instruction_mem_raw[instruction_index];
          expect_exec_t e;

          if (!header.valid) begin
            $display("  [stop] instruction_index=%0d", instruction_index);
            e.unique_id       = expect_id++;
            e.dwell_active_tx = 0;
            e.dwell_seq_num   = dwell_seq_num;
            e.dds_control     = '{default: 0, valid: 1, channel_index: i_channel};
            e.output_control  = '{default: 0, valid: 1, channel_index: i_channel};
            e.drfm_read_req   = '{default: 0};
            expected_data_exec[i_channel].push_back(e);
            $display("expected_data_exec[%0d] : [stop] push %p", i_channel, e);
            break;
          end

          e.instruction_index = instruction_index;

          dds_control.valid = header.dds_valid;
          dds_control.setup_data = header.dds_control;
          dds_control.control_data = inst_raw[63:16];
          dds_control.control_type = dds_control_type_none;

          output_control.valid = header.output_valid;
          output_control.control = header.output_control;

          $display("generate_expected_events: execution: dwell_seq_num=%0d channel=%0d instruction_index=%0d type=%0d header=%p", dwell_seq_num, i_channel, instruction_index, header.instruction_type, header);

          if (header.instruction_type == ecm_tx_instruction_type_nop) begin
            instruction_index = instruction_index + 1;

          end else if (header.instruction_type == ecm_tx_instruction_type_dds_setup_bpsk) begin
            dds_control.control_type = dds_control_type_lfsr;
            instruction_index = instruction_index + 1;

          end else if (header.instruction_type == ecm_tx_instruction_type_dds_setup_cw_sweep) begin
            dds_control.control_type = dds_control_type_sin_sweep;
            instruction_index = instruction_index + 1;

          end else if (header.instruction_type == ecm_tx_instruction_type_dds_setup_cw_step) begin
            dds_control.control_type = dds_control_type_sin_step;
            instruction_index = instruction_index + 1;

          end else if (header.instruction_type == ecm_tx_instruction_type_playback) begin
            ecm_tx_instruction_playback_t inst_playback = '{default: '0, mode: inst_raw[16], base_count: inst_raw[47:32], rand_offset_mask: inst_raw[63:48]};
            assert (inst_playback.rand_offset_mask == 0) else $error("rand_offset_mask expected to be 0.");

            if (inst_playback.mode == 0) begin //number of segments
              for (int i = 0; i < inst_playback.base_count; i++) begin
                for (int j = 0; j < trigger_length[i_channel]; j++) begin
                  drfm_read_req.read_valid = 1;
                  drfm_read_req.sync_valid = 1;
                  drfm_read_req.address = chan_entry.recording_address + j;
                  drfm_read_req.channel_index = i_channel;
                  drfm_read_req.channel_last = (i_channel == (ecm_num_channels - 1));
                  playback_queue.push_back(drfm_read_req);
                end
              end
            end else begin //number of samples
              for (int i = 0; i < inst_playback.base_count; i++) begin
                drfm_read_req.read_valid = 1;
                drfm_read_req.sync_valid = 1;
                drfm_read_req.address = chan_entry.recording_address + (i % trigger_length[i_channel]);
                drfm_read_req.channel_index = i_channel;
                drfm_read_req.channel_last = (i_channel == (ecm_num_channels - 1));
                playback_queue.push_back(drfm_read_req);
              end
            end
            instruction_index = instruction_index + 1;

          end else if (header.instruction_type == ecm_tx_instruction_type_wait) begin
            instruction_index = instruction_index + 1;

          end else if (header.instruction_type == ecm_tx_instruction_type_jump) begin
            ecm_tx_instruction_jump_t inst_jump = '{default: '0, dest_index: inst_raw[31:16], counter_check: inst_raw[32], counter_value: inst_raw[55:40]};

            $display("   jump: %p", inst_jump);

            if (!inst_jump.counter_check || (loop_count != inst_jump.counter_value)) begin
              instruction_index = inst_jump.dest_index;
            end else begin
              instruction_index = instruction_index + 1;
            end
            $display("   jump: next_instruction_index=%0d match=%0d", instruction_index, loop_count == inst_jump.counter_value);
            loop_count++;
          end

          if (dds_control.valid || output_control.valid) begin
            e.unique_id       = expect_id++;
            e.dwell_active_tx = 1;
            e.dwell_seq_num   = dwell_seq_num;
            e.dds_control     = dds_control;
            e.output_control  = output_control;
            e.drfm_read_req   = '{default: 0};
            if (verbose) begin
              $display("expected_data_exec[%0d] : push %p", i_channel, e);
            end
            expected_data_exec[i_channel].push_back(e);
          end

          while (playback_queue.size() > 0) begin
            e.unique_id             = expect_id++;
            e.dwell_active_tx       = 1;
            e.dwell_seq_num         = dwell_seq_num;
            e.dds_control.valid     = 0;
            e.output_control.valid  = 0;
            e.drfm_read_req         = playback_queue.pop_front();
            expected_data_exec[i_channel].push_back(e);
            if (verbose) begin
              $display("expected_data_exec[%0d] : push %p", i_channel, e);
            end
          end

        end
      end

      dwell_seq_num++;

      if (dwell_entry.global_counter_dec) begin
        global_counter--;
      end

      if (repeat_count == dwell_entry.repeat_count) begin
        dwell_index = dwell_entry.next_dwell_index;
        repeat_count = 0;
      end else begin
        repeat_count++;
      end

      if (num_dwells > 500) begin
        $error("too many dwells - infinite loop?");
        break;
      end
      num_dwells++;
    end

  endfunction

  function automatic bit compare_data_dwell(expect_dwell_t a, expect_dwell_t b);
    if (a.dwell_seq_num !== b.dwell_seq_num) begin
      $display("dwell_seq_num mismatch: %p %p", a.dwell_seq_num, b.dwell_seq_num);
      return 0;
    end
    if (a.dwell_global_counter !== b.dwell_global_counter) begin
      $display("dwell_global_counter mismatch: %p %p", a.dwell_global_counter, b.dwell_global_counter);
      return 0;
    end
    if (a.dwell_entry !== b.dwell_entry) begin
      $display("dwell_entry mismatch: %p %p", a.dwell_entry, b.dwell_entry);
      return 0;
    end

    return 1;
  endfunction

  initial begin
    automatic ecm_dwell_entry_t dwell_entry;
    automatic int dwell_seq_num;
    automatic int dwell_global_counter;
    automatic expect_dwell_t dwell_rx;

    wait_for_reset();

    forever begin
      dwell_intf.read(dwell_entry, dwell_seq_num, dwell_global_counter);
      dwell_rx.dwell_seq_num        = dwell_seq_num;
      dwell_rx.dwell_global_counter = dwell_global_counter;
      dwell_rx.dwell_entry          = dwell_entry;

      if (compare_data_dwell(dwell_rx, expected_data_dwell[0])) begin
        $display("%0t: dwell data match (remaining=%0d) - data=%p", $time, expected_data_dwell.size(), dwell_rx);
      end else begin
        $error("%0t: error -- dwell data mismatch: expected=%p  actual=%p", $time, expected_data_dwell[0], dwell_rx);
      end
      num_received_dwell++;
      void'(expected_data_dwell.pop_front());
    end
  end

  final begin
    if ( expected_data_dwell.size() != 0 ) begin
      $error("Unexpected data remaining in dwell queue:  size=%0d", expected_data_dwell.size());
      /*while ( expected_data_dwell.size() != 0 ) begin
        $display("%p", expected_data_dwell[0]);
        void'(expected_data_dwell.pop_front());
      end*/
    end
  end

  function automatic bit compare_data_drfm(expect_drfm_t a, expect_drfm_t b);
    if (a.dwell_seq_num !== b.dwell_seq_num) begin
      $display("dwell_seq_num mismatch: %p %p", a.dwell_seq_num, b.dwell_seq_num);
      return 0;
    end

    if (a.write_data !== b.write_data) begin
      $display("write_data mismatch: %p %p", a.write_data, b.write_data);
      return 0;
    end

    return 1;
  endfunction

  initial begin
    automatic ecm_drfm_write_req_t d;
    automatic int dwell_seq_num;
    automatic expect_drfm_t drfm_rx;

    wait_for_reset();

    forever begin
      drfm_intf.read(d, dwell_seq_num);
      drfm_rx.dwell_seq_num = dwell_seq_num;
      drfm_rx.write_data = d;

      if (compare_data_drfm(drfm_rx, expected_data_drfm[d.channel_index][0])) begin
        //$display("%0t: drfm data match (remaining=%0d) - channel=%0d data=%p", $time, expected_data_drfm[d.channel_index].size(), d.channel_index, drfm_rx);
      end else begin
        $error("%0t: error -- drfm data mismatch: channel=%0d  expected=%p  actual=%p", $time, d.channel_index, expected_data_drfm[d.channel_index][0], drfm_rx);
      end
      num_received_drfm++;
      void'(expected_data_drfm[d.channel_index].pop_front());
    end
  end

  final begin
    for (int i = 0; i < ecm_num_channels; i++) begin
      if ( expected_data_drfm[i].size() != 0 ) begin
        $error("Unexpected data remaining in drfm queue[%0d]:  size=%0d", i, expected_data_drfm[i].size());
        /*while ( expected_data_drfm[i].size() != 0 ) begin
          $display("%p", expected_data_drfm[i][0]);
          void'(expected_data_drfm[i].pop_front());
        end*/
      end
    end
  end

  function automatic bit compare_data_exec(expect_exec_t a, expect_exec_t b);

    if (a.dwell_seq_num !== b.dwell_seq_num) begin
      $display("dwell_seq_num mismatch: %p %p", a.dwell_seq_num, b.dwell_seq_num);
      return 0;
    end

    if (a.dds_control.valid && a.output_control.valid && a.drfm_read_req.read_valid && !a.dwell_active_tx) begin
      //$display("compare_data_exec: [end of dwell] skipping drfm_read_req check");
    end else begin
      if (a.drfm_read_req.read_valid || b.drfm_read_req.read_valid) begin
        if (a.drfm_read_req !== b.drfm_read_req) begin
          $display("drfm_read_req mismatch: %p %p", a.drfm_read_req, b.drfm_read_req);
          return 0;
        end
      end
    end

    if (a.dds_control.valid || b.dds_control.valid) begin
      if (a.dds_control.valid !== b.dds_control.valid) begin
        $display("dds_control mismatch: %p %p", a.dds_control, b.dds_control);
        return 0;
      end
      if (a.dds_control.channel_index !== b.dds_control.channel_index) begin
        $display("dds_control mismatch: %p %p", a.dds_control, b.dds_control);
        return 0;
      end
      if (a.dds_control.setup_data !== b.dds_control.setup_data) begin
        $display("dds_control mismatch: %p %p", a.dds_control, b.dds_control);
        return 0;
      end
      if (a.dds_control.control_type !== b.dds_control.control_type) begin
        $display("dds_control mismatch: %p %p", a.dds_control, b.dds_control);
        return 0;
      end
      if ((a.dds_control.control_type !== dds_control_type_none) && (a.dds_control.control_data !== b.dds_control.control_data)) begin
        $display("dds_control mismatch: %p %p", a.dds_control, b.dds_control);
        return 0;
      end
    end

    if (a.output_control.valid || b.output_control.valid) begin
      if (a.output_control !== b.output_control) begin
        $display("output_control mismatch: %p %p", a.output_control, b.output_control);
        return 0;
      end
    end

    return 1;
  endfunction

  initial begin
    automatic ecm_drfm_read_req_t drfm;
    automatic dds_control_t dds;
    automatic ecm_output_control_t oc;
    automatic int dwell_seq_num;
    automatic logic dwell_active_tx;
    automatic expect_exec_t rx;

    wait_for_reset();

    forever begin
      automatic int channel_index = -1;
      exec_intf.read(drfm, dds, oc, dwell_active_tx, dwell_seq_num);
      rx.drfm_read_req = drfm;
      rx.dds_control = dds;
      rx.output_control = oc;
      rx.dwell_seq_num = dwell_seq_num;
      rx.dwell_active_tx = dwell_active_tx;

      if (drfm.read_valid) begin
        channel_index = drfm.channel_index;
      end else if (dds.valid) begin
        channel_index = dds.channel_index;
      end else if (oc.valid) begin
        channel_index = oc.channel_index;
      end

      assert ((!drfm.read_valid || (channel_index == drfm.channel_index)) && (!dds.valid || (channel_index == dds.channel_index)) && (!oc.valid || (channel_index == oc.channel_index))) else $error("channel mismatch");

      // end of dwell -- drop any expected transactions that will be cut off
      if (!rx.dwell_active_tx) begin
        automatic int dropped = 0;
        assert (rx.dds_control.valid && (rx.dds_control.setup_data.dds_output_select == 0) && (rx.dds_control.control_type == 0)) else $error("unexpected end of dwell dds data");
        assert (rx.output_control.valid && (rx.output_control.control == 0)) else $error("unexpected end of dwell output control data");

        while((expected_data_exec[channel_index].size() > 0) && expected_data_exec[channel_index][0].dwell_active_tx && (expected_data_exec[channel_index][0].dwell_seq_num == rx.dwell_seq_num)) begin
          void'(expected_data_exec[channel_index].pop_front());
          num_dropped_exec++;
          dropped++;
        end

        $display("%0t: [end of dwell] dropped %0d expected exec transactions", $time, dropped);
      end

      if (compare_data_exec(rx, expected_data_exec[channel_index][0])) begin
        //$display("%0t: exec data match (remaining=%0d) - channel=%0d unique_id=%0d inst_index=%0d  data=%p", $time, expected_data_exec[channel_index].size(), channel_index,
        //  expected_data_exec[channel_index][0].unique_id, expected_data_exec[channel_index][0].instruction_index, rx);
      end else begin
        $error("%0t: error -- exec data mismatch: channel=%0d  expected=%p  actual=%p", $time, channel_index, expected_data_exec[channel_index][0], rx);
      end
      num_received_exec++;
      void'(expected_data_exec[channel_index].pop_front());
    end
  end

  final begin
    for (int i = 0; i < ecm_num_channels; i++) begin
      if ( expected_data_exec[i].size() != 0 ) begin
        $error("Unexpected data remaining in exec queue[%0d]: size=%0d", i, expected_data_exec[i].size());
        /*while ( expected_data_exec[i].size() != 0 ) begin
          $display("%p", expected_data_exec[i][0]);
          void'(expected_data_exec[i].pop_front());
        end*/
      end
    end
  end

/*
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

    send_initial_config();

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int wait_cycles;
      int num_programs = $urandom_range(16, 4);
      int num_dwells = $urandom_range(16, 4);
      int channel_mem_depth = $urandom_range(300, 100);
      int max_playback_length = $urandom_range(3, 1) * channel_mem_depth;
      bit enable_immediate_trigger = 0; //TODO: test
      int dwell_seq_num = 0;
      tx_instructions_queue_t   tx_programs;
      dwell_data_queue_t        dwell_entries;
      channel_entry_queue_t     channel_entries;
      ecm_dwell_program_entry_t dwell_program;

      $display("\n\n\n**** test[%0d]: num_programs=%0d  num_dwells=%0d  channel_mem_depth=%0d max_playback_length=%0d ****\n\n\n", i_test, num_programs, num_dwells, channel_mem_depth, max_playback_length);

      tx_programs     = randomize_tx_programs(num_programs, channel_mem_depth, max_playback_length);
      dwell_entries   = randomize_dwell_entries(num_dwells);
      channel_entries = randomize_channel_entries(dwell_entries, tx_programs, channel_mem_depth, enable_immediate_trigger);

      dwell_program.enable              = 1;
      dwell_program.initial_dwell_index = $urandom_range(2, 0);
      dwell_program.global_counter_init = num_dwells - dwell_program.initial_dwell_index + 1;
      dwell_program.tag                 = $urandom;

      generate_channelizer_data(dwell_program, dwell_entries, channel_entries, dwell_seq_num);
      generate_expected_events(dwell_program, dwell_entries, channel_entries, tx_programs, dwell_seq_num);

      for (int i_program = 0; i_program < tx_programs.size(); i_program++) begin
        send_tx_program(tx_programs[i_program]);
      end

      for (int i_channel_entry = 0; i_channel_entry < channel_entries.size(); i_channel_entry++) begin
        send_channel_entry(channel_entries[i_channel_entry]);
      end

      for (int i_dwell = 0; i_dwell < dwell_entries.size(); i_dwell++) begin
        send_dwell_entry(dwell_entries[i_dwell]);
      end

      send_dwell_program(dwell_program);

      //generate_expected_dwell_events(dwell_program, dwell_entries

      for (int i_rep = 0; i_rep < 10; i_rep++) begin
        bit done = 1;
        repeat (500000) @(posedge Clk);
        for (int i_channel = 0; i_channel < ecm_num_channels; i_channel++) begin
          if ((expected_data_drfm[i_channel].size() != 0) || (expected_data_exec[i_channel].size() != 0)) begin
            done = 0;
          end
        end
        if (done) begin
          break;
        end
      end

      for (int i_channel = 0; i_channel < ecm_num_channels; i_channel++) begin
        if ((expected_data_drfm[i_channel].size() != 0) || (expected_data_exec[i_channel].size() != 0)) begin
          $display("%0t: end of rep: expected_data_drfm[%0d]=%0d", $time, i_channel, expected_data_drfm[i_channel].size());
          $display("%0t: end of rep: expected_data_exec[%0d]=%0d", $time, i_channel, expected_data_exec[i_channel].size());

          /*foreach (expected_data_drfm[i]) begin
            $display("%0t: end of rep: expected_data_drfm[%0d]=%p", $time, i, expected_data_drfm[i]);
          end
          foreach (expected_data_exec[i]) begin
            $display("%0t: end of rep: expected_data_exec[%0d]=%p", $time, i, expected_data_exec[i]);
          end*/
        end
      end

      $display("%0t: Standard test finished: num_received_dwell=%0d  num_received_drfm=%0d num_received_exec=%0d num_dropped_exec=%0d", $time, num_received_dwell, num_received_drfm, num_received_exec, num_dropped_exec);

      Rst = 1;
      repeat(100) @(posedge Clk);
      Rst = 0;
      repeat(100) @(posedge Clk);
    end
  endtask

  initial
  begin
    chan_intf.clear();
    wait_for_reset();
    repeat(100) @(posedge Clk);
    standard_tests();

    $finish;
  end

endmodule
