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

  task read(output channelizer_transaction_t rx);
    logic v;
    do begin
      rx.data_i <= data[0];
      rx.data_q <= data[1];
      rx.index  <= index;
      v         <= valid;
      @(posedge Clk);
    end while (v !== 1);
  endtask
endinterface

module channelizer_tb;
  parameter time CLK_HALF_PERIOD  = 4ns;
  parameter NUM_CHANNELS          = 32;
  parameter CHANNEL_INDEX_WIDTH   = $clog2(NUM_CHANNELS);
  parameter NUM_COEFS_PER_CHANNEL = (NUM_CHANNELS > 8) ? 12 : 8;
  parameter INPUT_DATA_WIDTH      = 16;
  parameter OUTPUT_DATA_WIDTH     = 16 + $clog2(NUM_COEFS_PER_CHANNEL) + $clog2(NUM_CHANNELS);

  typedef struct
  {
    channelizer_transaction_t data;
  } expect_t;

  logic Clk;
  logic Rst;

  channelizer_intf #(.DATA_WIDTH(INPUT_DATA_WIDTH),   .INDEX_WIDTH(CHANNEL_INDEX_WIDTH))  tx_intf (.*);
  channelizer_intf #(.DATA_WIDTH(OUTPUT_DATA_WIDTH),  .INDEX_WIDTH(CHANNEL_INDEX_WIDTH))  rx_intf (.*);

  expect_t                                expected_data [$];
  int                                     num_received = 0;
  int                                     num_matched = 0;
  logic                                   w_error;

  channelizer_control_t                   w_chan_output_control;
  logic signed [OUTPUT_DATA_WIDTH - 1:0]  w_chan_output_iq [1:0];
  channelizer_control_t                   w_fft_output_control;
  logic signed [OUTPUT_DATA_WIDTH - 1:0]  w_fft_output_iq [1:0];

  logic [OUTPUT_DATA_WIDTH - 1:0]         r_chan_output_i [NUM_CHANNELS - 1:0];
  logic [OUTPUT_DATA_WIDTH - 1:0]         r_chan_output_q [NUM_CHANNELS - 1:0];
  logic [OUTPUT_DATA_WIDTH - 1:0]         r_fft_output_i [NUM_CHANNELS - 1:0];
  logic [OUTPUT_DATA_WIDTH - 1:0]         r_fft_output_q [NUM_CHANNELS - 1:0];

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
    if (NUM_CHANNELS == 64) begin
      channelizer_64 #(.INPUT_DATA_WIDTH(INPUT_DATA_WIDTH), .OUTPUT_DATA_WIDTH(OUTPUT_DATA_WIDTH)) dut64
      (
        .Clk                  (Clk),
        .Rst                  (Rst),

        .Input_valid          (tx_intf.valid),
        .Input_data           (tx_intf.data),

        .Output_chan_control  (w_chan_output_control),
        .Output_chan_data     (w_chan_output_iq),

        .Output_fft_control   (w_fft_output_control),
        .Output_fft_data      (w_fft_output_iq),

        .Error_overflow       (w_error)
      );
    end else if (NUM_CHANNELS == 32) begin
      channelizer_32 #(.INPUT_DATA_WIDTH(INPUT_DATA_WIDTH), .OUTPUT_DATA_WIDTH(OUTPUT_DATA_WIDTH)) dut32
      (
        .Clk                  (Clk),
        .Rst                  (Rst),

        .Input_valid          (tx_intf.valid),
        .Input_data           (tx_intf.data),

        .Output_chan_control  (w_chan_output_control),
        .Output_chan_data     (w_chan_output_iq),

        .Output_fft_control   (w_fft_output_control),
        .Output_fft_data      (w_fft_output_iq),

        .Error_overflow       (w_error)
      );
    end else if (NUM_CHANNELS == 8) begin
      channelizer_8 #(.INPUT_DATA_WIDTH(INPUT_DATA_WIDTH), .OUTPUT_DATA_WIDTH(OUTPUT_DATA_WIDTH)) dut8
      (
        .Clk                  (Clk),
        .Rst                  (Rst),

        .Input_valid          (tx_intf.valid),
        .Input_data           (tx_intf.data),

        .Output_chan_control  (w_chan_output_control),
        .Output_chan_data     (w_chan_output_iq),

        .Output_fft_control   (w_fft_output_control),
        .Output_fft_data      (w_fft_output_iq),

        .Error_overflow       (w_error)
      );
    end
  endgenerate

  //assign rx_intf.valid  = w_output_valid;
  //assign rx_intf.data   = w_chan_output_iq;
  //assign rx_intf.index  = w_output_index;

  always_ff @(posedge Clk) begin
    if (w_chan_output_control.valid) begin
      r_chan_output_i[w_chan_output_control.data_index] <= w_chan_output_iq[0];
      r_chan_output_q[w_chan_output_control.data_index] <= w_chan_output_iq[1];
    end

    if (w_fft_output_control.valid) begin
      r_fft_output_i[w_fft_output_control.data_index] <= w_fft_output_iq[0];
      r_fft_output_q[w_fft_output_control.data_index] <= w_fft_output_iq[1];
    end
  end

  always_ff @(posedge Clk) begin
    if (!Rst) begin
      if (w_error) begin
        $error("%0t: overflow error", $time);
      end
    end
  end

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
  endtask

  initial begin
    automatic channelizer_transaction_t read_data;

    wait_for_reset();

    forever begin
      rx_intf.read(read_data);
      num_received++;
    end
  end

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
    $display("%0t: Standard test finished: num_received = %0d num_matched=%0d", $time, num_received, num_matched);

    Rst = 1;
    repeat(500) @(posedge Clk);
    Rst = 0;
  endtask

  initial
  begin
    wait_for_reset();

    if (NUM_CHANNELS == 64) begin
      standard_tests("./test_data/channelizer_test_data_2024_01_23_64.txt");
    end else if (NUM_CHANNELS == 32) begin
      standard_tests("./test_data/channelizer_test_data_2024_01_23_32.txt");
    end else if (NUM_CHANNELS == 8) begin
      standard_tests("./test_data/channelizer_test_data_2024_01_23_8.txt");
    end
    $finish;
  end

endmodule
