`timescale 1ns/1ps

import math::*;
import dsp_pkg::*;

/*
typedef struct {
  int                                         channel_index;
  dds_control_setup_entry_t                   setup;
  int                                         control_type;
  bit [DDS_CONTROL_ENTRY_PACKED_WIDTH - 1:0]  control_data;

  int data_i;
  int data_q;
} control_transaction_t;
*/
interface control_intf (input logic Clk);
  dds_control_t data;

  task write(input dds_control_t tx);
    data                <= tx;
    data.valid          <= 1;
    @(posedge Clk);
    data.valid          <= 0;
    data.channel_index  <= 'x;
    data.setup_data     <= {default: 'x};
    data.control_type   <= 'x;
    data.control_data   <= 'x;
  endtask
endinterface

module channelized_dds_tb;
  parameter time CLK_HALF_PERIOD    = 4ns;
  parameter NUM_CHANNELS            = 16;
  parameter CHANNEL_INDEX_WIDTH     = $clog2(NUM_CHANNELS);
  parameter OUTPUT_DATA_WIDTH       = 12;

  logic Clk;
  logic Rst;

  control_intf                              ctrl_intf (.*);

  logic [CHANNEL_INDEX_WIDTH - 1 : 0]       r_channel_index = 0;
  channelizer_control_t                     r_sync_input;

  channelizer_control_t                     w_output_ctrl;
  logic signed [OUTPUT_DATA_WIDTH - 1 : 0]  w_output_data [1 : 0];
  logic [OUTPUT_DATA_WIDTH - 1 : 0]         r_output_i [NUM_CHANNELS - 1 : 0];
  logic [OUTPUT_DATA_WIDTH - 1 : 0]         r_output_q [NUM_CHANNELS - 1 : 0];

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

  always_ff @(posedge Clk) begin
    if ($urandom_range(99) < 50) begin
      r_sync_input.valid      <= 1;
      r_sync_input.last       <= r_channel_index == (NUM_CHANNELS - 1);
      r_sync_input.data_index <= r_channel_index;
      r_channel_index         <= r_channel_index + 1;
    end else begin
      r_sync_input.valid      <= 0;
      r_sync_input.last       <= 'x;
      r_sync_input.data_index <= 'x;
    end
  end

  channelized_dds #(.OUTPUT_DATA_WIDTH(OUTPUT_DATA_WIDTH), .NUM_CHANNELS(NUM_CHANNELS), .CHANNEL_INDEX_WIDTH(CHANNEL_INDEX_WIDTH), .LATENCY(7)) dut
  (
    .Clk          (Clk),
    .Rst          (Rst),

    .Control_data (ctrl_intf.data),

    .Sync_data    (r_sync_input),

    .Output_ctrl  (w_output_ctrl),
    .Output_data  (w_output_data)
  );

  always_ff @(posedge Clk) begin
    if (w_output_ctrl.valid) begin
      r_output_i[w_output_ctrl.data_index] <= w_output_data[0];
      r_output_q[w_output_ctrl.data_index] <= w_output_data[1];
    end

    /*if (synthesizer_tb.gen_dut.synth_16.i_synthesizer.i_mux.Input_valid) begin
      $display("%0d %07X", synthesizer_tb.gen_dut.synth_16.i_synthesizer.i_mux.Input_channel, synthesizer_tb.gen_dut.synth_16.i_synthesizer.i_mux.Input_i);
    end*/
  end

  function automatic bit [dds_control_lfsr_entry_packed_width - 1 : 0] pack_dds_control_lfsr_entry(int lfsr_phase_inc);
    bit [dds_control_lfsr_entry_packed_width - 1 : 0] r = '0;
    r[15:0] = lfsr_phase_inc;
    return r;
  endfunction

  function automatic bit [dds_control_sin_sweep_entry_packed_width - 1 : 0] pack_dds_control_sin_sweep_entry(int sweep_phase_inc_start, int sweep_phase_inc_stop, int sweep_phase_inc_step);
    bit [dds_control_sin_sweep_entry_packed_width - 1 : 0] r = '0;
    r[15:0]   = signed'(sweep_phase_inc_start);
    r[31:16]  = signed'(sweep_phase_inc_stop);
    r[47:32]  = signed'(sweep_phase_inc_step);
    return r;
  endfunction

  function automatic bit [dds_control_sin_step_entry_packed_width - 1 : 0] pack_dds_control_sin_step_entry(int step_phase_inc_min, int step_phase_inc_rand_offset_mask, int step_period_minus_one);
    bit [dds_control_sin_step_entry_packed_width - 1 : 0] r = '0;
    r[15:0]   = signed'(step_phase_inc_min);
    r[31:16]  = step_phase_inc_rand_offset_mask;
    r[47:32]  = step_period_minus_one;
    return r;
  endfunction

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
    repeat(5) @(posedge Clk);
  endtask

  task automatic standard_tests();
    dds_control_t ctrl;
    dds_control_t transactions [$];
    $display("%0t: Standard test started", $time);

    for (int i = 0; i < NUM_CHANNELS; i++) begin
      transactions.push_back({channel_index: i, setup_data:{0, 0}, control_type:dds_control_type_none, default:'0});
    end

    transactions.push_back({channel_index: 0, setup_data:{0, 2}, control_type:dds_control_type_sin_sweep, control_data:pack_dds_control_sin_sweep_entry(-32767, 32767, 10), default:'0});
    transactions.push_back({channel_index: 1, setup_data:{0, 2}, control_type:dds_control_type_sin_sweep, control_data:pack_dds_control_sin_sweep_entry(-32767, 32767, 100), default:'0});
    transactions.push_back({channel_index: 2, setup_data:{0, 2}, control_type:dds_control_type_sin_sweep, control_data:pack_dds_control_sin_sweep_entry(-32767, 32767, 1000), default:'0});

    transactions.push_back({channel_index: 1, setup_data:{0, 2}, control_type:dds_control_type_sin_sweep, control_data:pack_dds_control_sin_sweep_entry(-32767, 32767, 100), default:'0});


    for (int i = 0; i < transactions.size(); i++) begin
      ctrl = transactions[i];
      ctrl_intf.write(ctrl);
      //repeat($urandom_range(1)) @(posedge Clk);
    end

    /*while (tx_queue.size() > 0) begin
      tx = tx_queue.pop_front();
      tx_intf.write(tx);
      //repeat () @(posedge Clk);
    end*/

    repeat(500000) @(posedge Clk);

    $display("%0t: Standard test finished", $time);

    Rst = 1;
    repeat(500) @(posedge Clk);
    Rst = 0;
  endtask

  initial
  begin
    wait_for_reset();
    standard_tests();
    $finish;
  end

endmodule
