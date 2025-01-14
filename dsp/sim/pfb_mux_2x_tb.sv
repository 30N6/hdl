`timescale 1ns/1ps

import math::*;
import dsp_pkg::*;

typedef struct {
  int data_i;
  int data_q;
  int index;
  bit last;
} pfb_transaction_tx_t;

typedef struct {
  int data_i;
  int data_q;
} pfb_transaction_rx_t;

interface pfb_tx_intf #(parameter DATA_WIDTH, parameter CHANNEL_INDEX_WIDTH) (input logic Clk);
  logic                               valid;
  logic                               last;
  logic [CHANNEL_INDEX_WIDTH - 1 : 0] index;
  logic signed [DATA_WIDTH - 1 : 0]   data_i;
  logic signed [DATA_WIDTH - 1 : 0]   data_q;

  task clear();
    valid <= 0;
  endtask

  task write(input pfb_transaction_tx_t tx);
    data_i  <= tx.data_i;
    data_q  <= tx.data_q;
    index   <= tx.index;
    last    <= tx.last;
    valid   <= 1;
    @(posedge Clk);
    valid   <= 0;
    data_i  <= 'x;
    data_q  <= 'x;
    index   <= 'x;
    last    <= 'x;
    @(posedge Clk);
  endtask
endinterface

interface pfb_rx_intf #(parameter DATA_WIDTH) (input logic Clk);
  logic                             valid = 0;
  logic signed [DATA_WIDTH - 1 : 0] data_i;
  logic signed [DATA_WIDTH - 1 : 0] data_q;

  task read(output pfb_transaction_rx_t rx);
    logic v;
    do begin
      rx.data_i <= data_i;
      rx.data_q <= data_q;
      v         <= valid;
      @(posedge Clk);
    end while (v !== 1);
  endtask
endinterface

module pfb_mux_2x_tb;
  parameter time CLK_HALF_PERIOD  = 4ns;
  parameter INPUT_WIDTH           = 16;
  parameter OUTPUT_WIDTH          = INPUT_WIDTH + 1;
  parameter NUM_CHANNELS          = 16;
  parameter CHANNEL_INDEX_WIDTH   = $clog2(NUM_CHANNELS);

  typedef struct
  {
    pfb_transaction_rx_t data;
  } expect_t;

  logic Clk;
  logic Rst;

  pfb_tx_intf #(.DATA_WIDTH(INPUT_WIDTH), .CHANNEL_INDEX_WIDTH(CHANNEL_INDEX_WIDTH))  tx_intf (.*);
  pfb_rx_intf #(.DATA_WIDTH(OUTPUT_WIDTH))                                            rx_intf (.*);
  expect_t                                                                            expected_data [$];
  int                                                                                 num_received = 0;
  int                                                                                 num_matched = 0;

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

  pfb_mux_2x #(
    .NUM_CHANNELS         (NUM_CHANNELS),
    .CHANNEL_INDEX_WIDTH  (CHANNEL_INDEX_WIDTH),
    .INPUT_WIDTH          (INPUT_WIDTH)
  )
  dut
  (
    .Clk                  (Clk),
    .Rst                  (Rst),

    .Input_valid          (tx_intf.valid),
    .Input_channel        (tx_intf.index),
    .Input_last           (tx_intf.last),
    .Input_i              (tx_intf.data_i),
    .Input_q              (tx_intf.data_q),

    .Output_valid         (rx_intf.valid),
    .Output_i             (rx_intf.data_i),
    .Output_q             (rx_intf.data_q),

    .Error_input_overflow (),
    .Error_fifo_overflow  (),
    .Error_fifo_underflow ()
  );

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
  endtask

  function automatic bit compare_data(pfb_transaction_rx_t r, pfb_transaction_rx_t e);
    if (e.data_i !== r.data_i) begin
      return 0;
    end
    if (e.data_q !== r.data_q) begin
      return 0;
    end
    return 1;
  endfunction

  initial begin
    automatic pfb_transaction_rx_t read_data;

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
    parameter NUM_TESTS = 1;
    parameter NUM_FRAMES = 4096;
    pfb_transaction_tx_t tx_data[] = new[NUM_FRAMES*NUM_CHANNELS];
    pfb_transaction_rx_t framed_data [NUM_CHANNELS][NUM_FRAMES];
    pfb_transaction_rx_t framed_data_d [NUM_CHANNELS][NUM_FRAMES + 1];
    pfb_transaction_rx_t summed_data [NUM_CHANNELS][NUM_FRAMES];

    for (int i = 0; i < NUM_CHANNELS; i++) begin
      framed_data_d[i][0] = {default: 0};
    end

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int wait_cycles;
      int channel_index = 0;

      repeat(10) @(posedge Clk);
      $display("%0t: Standard test started", $time);

      for (int i_sample = 0; i_sample < tx_data.size(); i_sample++) begin
        bit [INPUT_WIDTH - 1 : 0] data_i = $urandom_range(2**INPUT_WIDTH - 1, 0);
        bit [INPUT_WIDTH - 1 : 0] data_q = $urandom_range(2**INPUT_WIDTH - 1, 0);

        tx_data[i_sample].data_i  = signed'(data_i);
        tx_data[i_sample].data_q  = signed'(data_q);
        tx_data[i_sample].index   = i_sample % NUM_CHANNELS;
        tx_data[i_sample].last    = i_sample % NUM_CHANNELS == (NUM_CHANNELS - 1);
        //$display("tx_data[%0d] = %p", i_sample, tx_data[i_sample]);
      end

      for (int i_output = 0; i_output < tx_data.size(); i_output++) begin
        int frame_index = i_output / NUM_CHANNELS;
        int channel_index = i_output % NUM_CHANNELS;
        framed_data[channel_index][frame_index].data_i = tx_data[i_output].data_i;
        framed_data[channel_index][frame_index].data_q = tx_data[i_output].data_q;
        framed_data_d[channel_index][frame_index + 1] = framed_data[channel_index][frame_index];
      end

      for (int i_frame = 0; i_frame < NUM_FRAMES; i_frame++) begin
        for (int i_channel = 0; i_channel < NUM_CHANNELS/2; i_channel++) begin
          summed_data[i_channel][i_frame].data_i = framed_data_d[i_channel][i_frame].data_i + framed_data[i_channel + NUM_CHANNELS/2][i_frame].data_i;
          summed_data[i_channel][i_frame].data_q = framed_data_d[i_channel][i_frame].data_q + framed_data[i_channel + NUM_CHANNELS/2][i_frame].data_q;
        end
      end

      for (int i_frame = 0; i_frame < NUM_FRAMES; i_frame++) begin
        for (int i_channel = (NUM_CHANNELS/2 - 1); i_channel >= 0; i_channel--) begin
          expect_t e;
          e.data = summed_data[i_channel][i_frame];
          expected_data.push_back(e);
        end
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
    tx_intf.clear();
    wait_for_reset();
    standard_tests();
    $finish;
  end

endmodule
