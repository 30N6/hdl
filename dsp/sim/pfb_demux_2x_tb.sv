`timescale 1ns/1ps

import math::*;
import dsp_pkg::*;

typedef struct {
  int data_i;
  int data_q;
  int index;
  int original_sample_index;
  int original_frame_index;
} pfb_transaction_t;

interface pfb_tx_intf #(parameter DATA_WIDTH) (input logic Clk);
  logic                             valid = 0;
  logic signed [DATA_WIDTH - 1 : 0] data_i;
  logic signed [DATA_WIDTH - 1 : 0] data_q;

  task write(input pfb_transaction_t tx);
    data_i  <= tx.data_i;
    data_q  <= tx.data_q;
    valid   <= 1;
    @(posedge Clk);
    data_i  <= 'x;
    data_q  <= 'x;
    valid   <= 0;
    repeat(3) @(posedge Clk);
  endtask
endinterface

interface pfb_rx_intf #(parameter DATA_WIDTH) (input logic Clk);
  logic                             valid;
  logic [4:0]                       index;
  logic signed [DATA_WIDTH - 1 : 0] data_i;
  logic signed [DATA_WIDTH - 1 : 0] data_q;

  task read(output pfb_transaction_t rx);
    logic v;
    do begin
      rx.data_i <= data_i;
      rx.data_q <= data_q;
      rx.index  <= index;
      v         <= valid;
      @(posedge Clk);
    end while (v !== 1);
  endtask
endinterface

module pfb_demux_2x_tb;
  parameter time CLK_HALF_PERIOD = 4ns;
  parameter DATA_WIDTH = 16;
  parameter CHANNEL_COUNT = 32;
  parameter CHANNEL_INDEX_WIDTH = $clog2(CHANNEL_COUNT);

  typedef struct
  {
    pfb_transaction_t data;
  } expect_t;

  logic Clk;
  logic Rst;

  pfb_tx_intf #(.DATA_WIDTH(DATA_WIDTH))  tx_intf (.*);
  pfb_rx_intf #(.DATA_WIDTH(DATA_WIDTH))  rx_intf (.*);
  expect_t                                expected_data [$];
  int                                     num_received = 0;
  int                                     num_matched = 0;

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

  pfb_demux_2x #(
    .CHANNEL_COUNT        (CHANNEL_COUNT),
    .CHANNEL_INDEX_WIDTH  (CHANNEL_INDEX_WIDTH),
    .DATA_WIDTH           (DATA_WIDTH)
  )
  dut
  (
    .Clk            (Clk),
    .Rst            (Rst),

    .Input_valid    (tx_intf.valid),
    .Input_i        (tx_intf.data_i),
    .Input_q        (tx_intf.data_q),

    .Output_valid   (rx_intf.valid),
    .Output_channel (rx_intf.index),
    .Output_i       (rx_intf.data_i),
    .Output_q       (rx_intf.data_q)
  );

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
  endtask

  function automatic bit compare_data(pfb_transaction_t r, pfb_transaction_t e);
    if (e.index !== r.index) begin
      return 0;
    end
    if (e.data_i !== r.data_i) begin
      return 0;
    end
    if (e.data_q !== r.data_q) begin
      return 0;
    end
    return 1;
  endfunction

  initial begin
    automatic pfb_transaction_t read_data;

    wait_for_reset();

    forever begin
      rx_intf.read(read_data);
      if (expected_data.size() == 0) begin
        //skipping
      end else if (compare_data(read_data, expected_data[0].data)) begin
        num_matched++;
        //$display("%0t: data match - %p", $time, expected_data[0].data);
      end else begin
        $error("%0t: error -- data mismatch: expected = %p  actual = %p - remaining=%0d", $time, expected_data[0].data, read_data, expected_data.size());
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

  task automatic standard_tests();
    parameter NUM_TESTS = 20;
    pfb_transaction_t tx_data[] = new[256*32];
    int output_sample_index [32][512];

    for (int i_channel = 0; i_channel < 32; i_channel++) begin
      for (int i_frame = 0; i_frame < 513; i_frame++) begin
        int channel_o = (31 - i_channel);
        output_sample_index[i_channel][i_frame] = channel_o + 16*i_frame;
      end
    end

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int wait_cycles;
      bit [4:0] channel_index = 31;

      repeat(10) @(posedge Clk);
      $display("%0t: Standard test started", $time);

      for (int i_sample = 0; i_sample < tx_data.size(); i_sample++) begin
        int output_channel;
        bit [DATA_WIDTH - 1 : 0] data_i = $urandom_range(2**DATA_WIDTH - 1, 0);
        bit [DATA_WIDTH - 1 : 0] data_q = $urandom_range(2**DATA_WIDTH - 1, 0);

        tx_data[i_sample].data_i = signed'(data_i);
        tx_data[i_sample].data_q = signed'(data_q);
        //$display("tx_data[%0d] = %p", i_sample, tx_data[i_sample]);
      end

      for (int i_output = 0; i_output < tx_data.size() * 2 - 32; i_output++) begin
        expect_t e;
        int output_channel  = (31 - i_output % 32);
        int output_frame    = i_output / 32;
        int output_sample   = output_sample_index[output_channel][output_frame];

        e.data                        = tx_data[output_sample];
        e.data.index                  = output_channel;
        e.data.original_sample_index  = output_sample;
        e.data.original_frame_index   = output_frame;
        expected_data.push_back(e);
      end

      foreach(tx_data[i]) begin
        tx_intf.write(tx_data[i]);
      end

      wait_cycles = 0;
      while ((expected_data.size() != 0) && (wait_cycles < 1e5)) begin
        @(posedge Clk);
        wait_cycles++;
      end
      assert (wait_cycles < 1e5) else $error("Timeout while waiting for expected queue to empty during standard test");

      $display("%0t: Standard test finished: num_received = %0d num_matched=%0d", $time, num_received, num_matched);

      Rst = 1;
      repeat(500) @(posedge Clk);
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
