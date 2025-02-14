`timescale 1ns/1ps

import math::*;
import ecm_pkg::*;

typedef struct {
  int data_i;
  int data_q;
} adc_transaction_t;

interface adc_tx_intf #(parameter ADC_WIDTH) (input logic Clk);
  logic                             valid = 0;
  logic signed [ADC_WIDTH - 1 : 0]  data_i;
  logic signed [ADC_WIDTH - 1 : 0]  data_q;

  task write(input adc_transaction_t tx);
    data_i  <= tx.data_i;
    data_q  <= tx.data_q;
    valid   <= 1;
    @(posedge Clk);
    data_i  <= 0;
    data_q  <= 0;
    valid   <= 0;
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

interface axi_rx_intf #(parameter AXI_DATA_WIDTH) (input logic Clk);
  logic                           valid;
  logic                           last;
  logic [AXI_DATA_WIDTH - 1 : 0]  data;

  task read(output logic [AXI_DATA_WIDTH - 1 : 0] d [$]);
    automatic bit done = 0;
    d.delete();

    do begin
      if (valid) begin
        d.push_back(data);
        done = last;
      end
      @(posedge Clk);
    end while(!done);
  endtask
endinterface

module ecm_top_tb;
  parameter time ADC_CLK_HALF_PERIOD  = 8ns;
  parameter time AXI_CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH            = 32;
  parameter ADC_WIDTH                 = 16;
  parameter IQ_WIDTH                  = 12;

  logic Adc_clk;
  logic Adc_clk_x4;
  logic Adc_rst;
  logic Axi_clk;
  logic Axi_rstn;

  adc_tx_intf #(.ADC_WIDTH(ADC_WIDTH))            tx_intf     (.Clk(Adc_clk));
  axi_tx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  cfg_tx_intf (.Clk(Axi_clk));
  axi_rx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  rpt_rx_intf (.Clk(Axi_clk));

  logic [3:0]                                     w_ad9361_control;
  logic [3:0]                                     r_ad9361_control;
  logic [7:0]                                     w_ad9361_status;
  logic                                           r_axi_rx_ready;
  logic                                           w_axi_rx_valid;

  bit [31:0]                                      config_seq_num = 0;
  //esm_dwell_metadata_t                            dwell_entry_mem [esm_num_dwell_entries - 1 : 0];

  initial begin
    Adc_clk = 0;
    forever begin
      #(ADC_CLK_HALF_PERIOD);
      Adc_clk = ~Adc_clk;
    end
  end

  initial begin
    Adc_clk_x4 = 0;
    forever begin
      #(ADC_CLK_HALF_PERIOD/4);
      Adc_clk_x4 = ~Adc_clk_x4;
    end
  end

  initial begin
    Axi_clk = 0;
    forever begin
      #(AXI_CLK_HALF_PERIOD);
      Axi_clk = ~Axi_clk;
    end
  end

  initial begin
    Adc_rst = 1;
    repeat(100) @(posedge Adc_clk);
    Adc_rst = 0;
  end

  initial begin
    Axi_rstn = 0;
    repeat(10) @(posedge Axi_clk);
    Axi_rstn = 1;
  end

  ecm_top #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH), .ADC_WIDTH(ADC_WIDTH), .DAC_WIDTH(ADC_WIDTH), .IQ_WIDTH(IQ_WIDTH)) dut
  (
    .Adc_clk        (Adc_clk),
    .Adc_clk_x4     (Adc_clk_x4),
    .Adc_rst        (Adc_rst),

    .Ad9361_control (w_ad9361_control),
    .Ad9361_status  (w_ad9361_status),

    .Adc_valid      (tx_intf.valid),
    .Adc_data_i     (tx_intf.data_i),
    .Adc_data_q     (tx_intf.data_q),

    .Dac_data_i     (),
    .Dac_data_q     (),

    .S_axis_clk     (Axi_clk),
    .S_axis_resetn  (Axi_rstn),
    .S_axis_ready   (cfg_tx_intf.ready),
    .S_axis_valid   (cfg_tx_intf.valid),
    .S_axis_data    (cfg_tx_intf.data),
    .S_axis_last    (cfg_tx_intf.last),

    .M_axis_clk     (Axi_clk),
    .M_axis_resetn  (Axi_rstn),
    .M_axis_ready   (r_axi_rx_ready),
    .M_axis_valid   (w_axi_rx_valid),
    .M_axis_data    (rpt_rx_intf.data),
    .M_axis_last    (rpt_rx_intf.last)
  );

  always_ff @(posedge Axi_clk) begin
    r_axi_rx_ready <= $urandom_range(99) < 80;
  end

  assign rpt_rx_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

  always_ff @(posedge Adc_clk) begin
    r_ad9361_control <= w_ad9361_control;
  end

  initial begin
    w_ad9361_status <= '1;
    /*w_ad9361_status <= 0;
    while (1) begin
      if (w_ad9361_control != r_ad9361_control) begin
        w_ad9361_status <= '0;
        repeat ($urandom_range(10, 5)) @(posedge Adc_clk);
        w_ad9361_status <= '1;
      end
      @(posedge Adc_clk);
    end*/
  end

  initial begin
    while (1) begin
      tx_intf.write('{data_i: $urandom, data_q: $urandom});
    end
  end

  task automatic wait_for_reset();
    do begin
      @(posedge Adc_clk);
    end while (Adc_rst);
  endtask

  task automatic write_config(bit [31:0] config_data []);
    @(posedge Axi_clk)
    cfg_tx_intf.write(config_data);
    repeat(10) @(posedge Axi_clk);
  endtask

  task automatic send_initial_config();
    bit [31:0] config_data [][] = '{{ecm_control_magic_num, config_seq_num++, 32'h00000000, 32'hDEADBEEF, 32'h01000000, 32'hDEADBEEF},
                                    {ecm_control_magic_num, config_seq_num++, 32'h00000000, 32'hDEADBEEF, 32'h00010101, 32'hDEADBEEF}};
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

        d.enable                          = ($urandom_range(99) < 90);
        d.trigger_mode                    = ecm_channel_trigger_mode_force_trigger; //$urandom_range(ecm_channel_trigger_mode_threshold_trigger, ecm_channel_trigger_mode_none); //$urandom_range(ecm_channel_trigger_mode_force_trigger, ecm_channel_trigger_mode_none);
        d.trigger_duration_max_minus_one  = 1024;

        d.trigger_threshold   = $urandom_range(200, 100);
        d.trigger_hyst_shift  = $urandom_range(3, 1);
        d.drfm_gain           = 0; //TODO: test
        d.recording_address   = i_channel * (ecm_drfm_mem_depth / ecm_num_channels);

        for (int i_program_entry = 0; i_program_entry < ecm_num_channel_tx_program_entries; i_program_entry++) begin
          int tx_program_index = $urandom_range(tx_programs.size() - 1, 0);

          d.program_entries[i_program_entry].valid                          = ($urandom_range(99) < 75);
          d.program_entries[i_program_entry].trigger_immediate_after_min    = enable_immediate;
          d.program_entries[i_program_entry].tx_instruction_index           = tx_programs[tx_program_index].inst_start_addr;
          d.program_entries[i_program_entry].duration_gate_min_minus_one    = 100;
          d.program_entries[i_program_entry].duration_gate_max_minus_one    = 4095;
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
    r.global_counter_check    = 1;
    r.global_counter_dec      = 1;
    r.skip_pll_prelock_wait   = 0;
    r.skip_pll_lock_check     = 0;
    r.skip_pll_postlock_wait  = 0;
    r.repeat_count            = 0;
    r.fast_lock_profile       = $urandom;
    r.next_dwell_index        = $urandom;
    r.pll_pre_lock_delay      = $urandom_range(500, 100);
    r.pll_post_lock_delay     = $urandom_range(500, 100);
    r.tag                     = $urandom;
    r.frequency               = $urandom;
    r.measurement_duration    = $urandom_range(1000, 500);
    r.total_duration_max      = r.measurement_duration + $urandom_range(5000, 2000);
    r.min_trigger_duration    = $urandom_range(100);

    return r;
  endfunction

  function automatic dwell_data_queue_t randomize_dwell_entries(int num_dwells);
    dwell_data_queue_t r;

    for (int i = 0; i < num_dwells; i++) begin
      dwell_data_t d;

      d.dwell_index = i;
      d.entry = randomize_dwell_entry();
      d.entry.next_dwell_index = i + 1;
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
    packed_entry[175:160]   = data.entry.min_trigger_duration;

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

  task automatic standard_tests();
    parameter NUM_TESTS = 20;

    send_initial_config();

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
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
      dwell_program.initial_dwell_index = 0;
      dwell_program.global_counter_init = num_dwells - dwell_program.initial_dwell_index + 1;
      dwell_program.tag                 = $urandom;

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

      repeat(1e5) @(posedge Adc_clk);

      Adc_rst = 1;
      repeat(100) @(posedge Adc_clk);
      Adc_rst = 0;
      repeat(100) @(posedge Adc_clk);
    end

  endtask

  initial
  begin
    wait_for_reset();
    standard_tests();

    $finish;
  end

endmodule
