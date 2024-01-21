`timescale 1ns/1ps

import math::*;
import dsp_pkg::*;

typedef struct {
  int data_i;
  int data_q;
  int index;
} pfb_32_transaction_t;

interface pfb_32_intf #(parameter DATA_WIDTH) (input logic Clk);
  logic                             valid = 0;
  logic [4:0]                       index;
  logic signed [DATA_WIDTH - 1 : 0] data_i;
  logic signed [DATA_WIDTH - 1 : 0] data_q;

  task write(input pfb_32_transaction_t tx);
    data_i  <= tx.data_i;
    data_q  <= tx.data_q;
    index   <= tx.index;
    valid   <= 1;
    @(posedge Clk);
    data_i  <= 'x;
    data_q  <= 'x;
    valid   <= 0;
    @(posedge Clk);
  endtask

  task read(output pfb_32_transaction_t rx);
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

module pfb_32_filter_tb;
  parameter time CLK_HALF_PERIOD  = 4ns;
  parameter INPUT_DATA_WIDTH      = 12;
  parameter OUTPUT_DATA_WIDTH     = 12 + $clog2(12);

  typedef struct
  {
    pfb_32_transaction_t data;
  } expect_t;

  logic Clk;
  logic Rst;

  pfb_32_intf #(.DATA_WIDTH(INPUT_DATA_WIDTH))  tx_intf (.*);
  pfb_32_intf #(.DATA_WIDTH(OUTPUT_DATA_WIDTH)) rx_intf (.*);
  expect_t                                      expected_data [$];
  int                                           num_received = 0;
  int                                           num_matched = 0;
  logic                                         w_error;

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

  pfb_32_filter #(
    .INPUT_DATA_WIDTH   (INPUT_DATA_WIDTH),
    .OUTPUT_DATA_WIDTH  (OUTPUT_DATA_WIDTH)
  )
  dut
  (
    .Clk            (Clk),
    .Rst            (Rst),

    .Input_valid    (tx_intf.valid),
    .Input_index    (tx_intf.index),
    .Input_i        (tx_intf.data_i),
    .Input_q        (tx_intf.data_q),

    .Output_valid   (rx_intf.valid),
    .Output_index   (rx_intf.index),
    .Output_i       (rx_intf.data_i),
    .Output_q       (rx_intf.data_q),

    .Error_input_overflow (w_error)
  );

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

  function automatic bit compare_data(pfb_32_transaction_t r, pfb_32_transaction_t e);
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
    automatic pfb_32_transaction_t read_data;

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

  function automatic int process_filter_sample(pfb_32_transaction_t d);
    pfb_32_transaction_t r;
    return r;
    /*parameter ACCUM_WIDTH = INPUT_WIDTH + $clog2(WINDOW_LENGTH);
    logic [ACCUM_WIDTH - 1:0] accum;

    for(int i = WINDOW_LENGTH-1; i > 0; i--) begin
      filter_data[i] = filter_data[i - 1];
    end
    filter_data[0] = d;

    accum = 0;
    for (int i = 0; i < WINDOW_LENGTH; i++) begin
      accum += filter_data[i];
    end

    //$display("%0t: process_filter_sample: d=%0d post_accum=%0d ret=%0d", $time, d, accum, accum[ACCUM_WIDTH - 1 : ACCUM_WIDTH - OUTPUT_WIDTH]);

    return accum[ACCUM_WIDTH - 1 : ACCUM_WIDTH - OUTPUT_WIDTH];*/
  endfunction

  task automatic standard_tests();
    parameter NUM_TESTS = 20;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int wait_cycles;
      bit [4:0] channel_index = 31;

      repeat(10) @(posedge Clk);
      $display("%0t: Standard test started", $time);

      for (int i_iteration = 0; i_iteration < 10000; i_iteration++) begin
        expect_t e;
        pfb_32_transaction_t tx;
        pfb_32_transaction_t rx;

        tx.data_i = $urandom_range(2**INPUT_DATA_WIDTH - 1, 0);
        tx.data_q = $urandom_range(2**INPUT_DATA_WIDTH - 1, 0);
        tx.index  = channel_index;
        channel_index--;

        rx = process_filter_sample(tx);
        e.data = rx;
        expected_data.push_back(e);

        tx_intf.write(tx);
        repeat($urandom_range(max_write_delay)) @(posedge(Clk));
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
