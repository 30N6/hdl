`timescale 1ns/1ps

import math::*;
import dsp_pkg::*;

typedef struct {
  int data_i;
  int data_q;
  int index;
} channelizer_transaction_t;

interface channelizer_intf #(parameter DATA_WIDTH, parameter INDEX_WIDTH) (input logic Clk);
  logic                             valid = 0;
  logic [INDEX_WIDTH - 1 : 0]       index;
  logic signed [DATA_WIDTH - 1 : 0] data [1:0];

  task write(input channelizer_transaction_t tx);
    data[0] <= tx.data_i;
    data[1] <= tx.data_q;
    valid   <= 1;
    @(posedge Clk);
    data[0] <= 0;
    data[1] <= 0;
    valid   <= 0;
    repeat(3) @(posedge Clk);
  endtask
endinterface

module synthesizer_tb;
  parameter time CLK_HALF_PERIOD        = 4ns;
  parameter NUM_CHANNELS                = 16;
  parameter CHANNEL_INDEX_WIDTH         = $clog2(NUM_CHANNELS);
  parameter NUM_COEFS_PER_CHANNEL_CHAN  = 8;
  parameter NUM_COEFS_PER_CHANNEL_SYNTH = 6;
  parameter INPUT_DATA_WIDTH            = 12;
  parameter CHAN_OUTPUT_DATA_WIDTH      = INPUT_DATA_WIDTH + $clog2(NUM_COEFS_PER_CHANNEL_CHAN) + $clog2(NUM_CHANNELS);
  parameter SYNTH_OUTPUT_DATA_WIDTH     = CHAN_OUTPUT_DATA_WIDTH + $clog2(NUM_CHANNELS) + $clog2(NUM_COEFS_PER_CHANNEL_SYNTH) + 1;

  typedef struct
  {
    channelizer_transaction_t data;
  } expect_t;

  logic Clk;
  logic Rst;

  channelizer_intf #(.DATA_WIDTH(INPUT_DATA_WIDTH), .INDEX_WIDTH(CHANNEL_INDEX_WIDTH))  tx_intf (.*);

  expect_t                                expected_data [$];
  logic                                   w_warning_demux_gap;
  logic                                   w_error_chan_demux_overflow;
  logic                                   w_error_chan_filter_overflow;
  logic                                   w_error_chan_mux_overflow;
  logic                                   w_error_chan_mux_underflow;
  logic                                   w_error_chan_mux_collision;
  logic                                   w_error_synth_stretcher_overflow;
  logic                                   w_error_synth_stretcher_underflow;
  logic                                   w_error_synth_filter_overflow;
  logic                                   w_error_synth_mux_input_overflow;
  logic                                   w_error_synth_mux_fifo_overflow;
  logic                                   w_error_synth_mux_fifo_underflow;

  channelizer_control_t                           w_chan_output_control;
  logic signed [CHAN_OUTPUT_DATA_WIDTH - 1 : 0]   w_chan_output_iq [1 : 0];
  synthesizer_control_t                           w_synth_input_control;

  logic                                           w_synth_output_valid;
  logic signed [SYNTH_OUTPUT_DATA_WIDTH - 1 : 0]  w_synth_output_iq [1 : 0];

  logic [CHAN_OUTPUT_DATA_WIDTH - 1 : 0]          r_chan_output_i [NUM_CHANNELS - 1 : 0];
  logic [CHAN_OUTPUT_DATA_WIDTH - 1 : 0]          r_chan_output_q [NUM_CHANNELS - 1 : 0];
  logic [SYNTH_OUTPUT_DATA_WIDTH - 1 : 0]         r_synth_output_i;
  logic [SYNTH_OUTPUT_DATA_WIDTH - 1 : 0]         r_synth_output_q;

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

  generate
    if (NUM_CHANNELS == 16) begin : gen_dut
      channelizer_16 #(.INPUT_DATA_WIDTH(INPUT_DATA_WIDTH), .OUTPUT_DATA_WIDTH(CHAN_OUTPUT_DATA_WIDTH), .BASEBANDING_ENABLE(0)) chan_16
      (
        .Clk                    (Clk),
        .Rst                    (Rst),

        .Input_valid            (tx_intf.valid),
        .Input_data             (tx_intf.data),

        .Output_chan_ctrl       (w_chan_output_control),
        .Output_chan_data       (w_chan_output_iq),
        .Output_chan_pwr        (),

        .Output_fft_ctrl        (),
        .Output_fft_data        (),

        .Warning_demux_gap      (w_warning_demux_gap),
        .Error_demux_overflow   (w_error_chan_demux_overflow),
        .Error_filter_overflow  (w_error_chan_filter_overflow),
        .Error_mux_overflow     (w_error_chan_mux_overflow),
        .Error_mux_underflow    (w_error_chan_mux_underflow),
        .Error_mux_collision    (w_error_chan_mux_collision)
      );

      assign w_synth_input_control.valid                = w_chan_output_control.valid;
      assign w_synth_input_control.last                 = w_chan_output_control.last;
      assign w_synth_input_control.data_index           = w_chan_output_control.data_index;
      assign w_synth_input_control.transmit_active      = 1'b1;
      assign w_synth_input_control.active_channel_count = 5'd1;

      synthesizer_16 #(.INPUT_DATA_WIDTH(CHAN_OUTPUT_DATA_WIDTH), .OUTPUT_DATA_WIDTH(SYNTH_OUTPUT_DATA_WIDTH)) synth_16
      (
        .Clk                       (Clk),
        .Rst                       (Rst),

        .Input_ctrl                (w_synth_input_control),
        .Input_data                (w_chan_output_iq),

        .Output_valid              (w_synth_output_valid),
        .Output_data               (w_synth_output_iq),

        .Error_stretcher_overflow  (w_error_synth_stretcher_overflow),
        .Error_stretcher_underflow (w_error_synth_stretcher_underflow),
        .Error_filter_overflow     (w_error_synth_filter_overflow),
        .Error_mux_input_overflow  (w_error_synth_mux_input_overflow),
        .Error_mux_fifo_overflow   (w_error_synth_mux_fifo_overflow),
        .Error_mux_fifo_underflow  (w_error_synth_mux_fifo_underflow)
      );
    end
  endgenerate

  always_ff @(posedge Clk) begin
    if (w_chan_output_control.valid) begin
      r_chan_output_i[w_chan_output_control.data_index] <= w_chan_output_iq[0];
      r_chan_output_q[w_chan_output_control.data_index] <= w_chan_output_iq[1];
    end

    /*if (synthesizer_tb.gen_dut.synth_16.i_synthesizer.i_mux.Input_valid) begin
      $display("%0d %07X", synthesizer_tb.gen_dut.synth_16.i_synthesizer.i_mux.Input_channel, synthesizer_tb.gen_dut.synth_16.i_synthesizer.i_mux.Input_i);
    end*/

    if (w_synth_output_valid) begin
      r_synth_output_i <= w_synth_output_iq[0];
      r_synth_output_q <= w_synth_output_iq[1];
    end
  end

  always_ff @(posedge Clk) begin
    if (!Rst) begin
      if (w_warning_demux_gap) begin
        $warning("%0t: demux gap warning", $time);
      end

      if (w_error_chan_demux_overflow) begin
        $error("%0t: demux overflow error", $time);
      end
      if (w_error_chan_filter_overflow) begin
        $error("%0t: filter overflow error", $time);
      end
      if (w_error_chan_mux_overflow) begin
        $error("%0t: mux overflow error", $time);
      end
      if (w_error_chan_mux_underflow) begin
        $error("%0t: mux underflow error", $time);
      end
      if (w_error_chan_mux_collision) begin
        $error("%0t: mux collision error", $time);
      end

      if (w_error_synth_stretcher_overflow) begin
        $error("%0t: synth stretcher overflow error", $time);
      end
      if (w_error_synth_stretcher_underflow) begin
        $error("%0t: synth stretcher overflow error", $time);
      end
      if (w_error_synth_filter_overflow) begin
        $error("%0t: synth filter overflow error", $time);
      end
      if (w_error_synth_mux_input_overflow) begin
        $error("%0t: synth mux input overflow error", $time);
      end
      if (w_error_synth_mux_fifo_overflow) begin
        $error("%0t: synth mux fifo overflow error", $time);
      end
      if (w_error_synth_mux_fifo_underflow) begin
        $error("%0t: synth mux fifo underflow error", $time);
      end
    end
  end

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
  endtask

  task automatic standard_tests(string filename);
    int fd_test_in  = $fopen(filename, "r");
    channelizer_transaction_t tx;
    channelizer_transaction_t tx_queue[$];
    int d_i, d_q;

    $display("%0t: Standard test started: %s", $time, filename);

    while ($fscanf(fd_test_in, "%d %d", d_i, d_q) == 2) begin
      tx.data_i  = d_i;
      tx.data_q  = d_q;
      tx_queue.push_back(tx);
    end
    $fclose(fd_test_in);

    while (tx_queue.size() > 0) begin
      tx = tx_queue.pop_front();
      tx_intf.write(tx);
      //repeat () @(posedge Clk);
    end

    $display("%p %p", r_chan_output_i, r_chan_output_q);
    $display("%0t: Standard test finished", $time);

    Rst = 1;
    repeat(500) @(posedge Clk);
    Rst = 0;
  endtask

  initial
  begin
    wait_for_reset();

    if (NUM_CHANNELS == 16) begin
      standard_tests("./test_data/channelizer_test_data_2025_01_08_16.txt");
    end else begin
      $error("unsupported channel count");
    end
    $finish;
  end

endmodule
