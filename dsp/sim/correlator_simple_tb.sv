`timescale 1ns/1ps

import math::*;

interface mag_tx_intf #(parameter DATA_WIDTH) (input logic Clk);
  logic                       valid;
  logic [DATA_WIDTH - 1 : 0]  data;

  task write(input logic [DATA_WIDTH - 1 : 0] d);
    data  <= d;
    valid <= 1;
    @(posedge Clk);
    data  <= 'x;
    valid <= 0;
  endtask
endinterface

interface mag_rx_intf #(parameter DATA_WIDTH) (input logic Clk);
  logic                       valid;
  logic [DATA_WIDTH - 1 : 0]  data;

  task read(output logic [DATA_WIDTH - 1 : 0] d);
    logic v;
    do begin
      d <= data;
      v <= valid;
      @(posedge Clk);
    end while (v !== 1);
  endtask
endinterface

module correlator_simple_tb;
  parameter time CLK_HALF_PERIOD = 4ns;
  parameter INPUT_WIDTH = 14;
  parameter OUTPUT_WIDTH = 16;
  parameter WINDOW_LENGTH = 64;
  parameter logic [0 : WINDOW_LENGTH - 1] CORRELATION_DATA = 64'b1111000011110000000000000000111100001111000000000000000000000000;

  typedef struct
  {
    logic [OUTPUT_WIDTH - 1 : 0] data;
  } expect_t;

  logic Clk;
  logic Rst;

  mag_tx_intf #(.DATA_WIDTH(INPUT_WIDTH)) tx_intf (.*);
  mag_rx_intf #(.DATA_WIDTH(OUTPUT_WIDTH)) rx_intf (.*);

  expect_t                      expected_data [$];
  logic [INPUT_WIDTH - 1:0]     filter_data [WINDOW_LENGTH - 1:0];
  int                           num_received = 0;

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

  correlator_simple
  #(
    .CORRELATION_LENGTH (WINDOW_LENGTH),
    .CORRELATION_DATA   (CORRELATION_DATA),
    .LATENCY            (WINDOW_LENGTH + 1),
    .INPUT_WIDTH        (INPUT_WIDTH),
    .OUTPUT_WIDTH       (OUTPUT_WIDTH)
  )
  dut
  (
    .Clk          (Clk),
    .Rst          (Rst),

    .Input_valid  (tx_intf.valid),
    .Input_data   (tx_intf.data),

    .Output_valid (rx_intf.valid),
    .Output_data  (rx_intf.data)
  );

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
  endtask

  initial begin
    automatic logic [OUTPUT_WIDTH - 1 : 0] read_data;

    wait_for_reset();

    forever begin
      rx_intf.read(read_data);
      if ( read_data == expected_data[0].data ) begin
        //$display("%0t: data match - %X", $time, read_data);
      end else begin
        $error("%0t: error -- data mismatch: expected = %X  actual = %X", $time, expected_data[0].data, read_data);
      end
      num_received++;
      void'(expected_data.pop_front());
    end
  end

  final begin
    if ( expected_data.size() != 0 ) begin
      $error("Unexpected data remaining in queue:");
      while ( expected_data.size() != 0 ) begin
        $display("%X", expected_data[0].data);
        void'(expected_data.pop_front());
      end
    end
  end

  function automatic int process_correlator_sample(int d);
    parameter ACCUM_WIDTH = INPUT_WIDTH + $clog2(WINDOW_LENGTH);
    logic [ACCUM_WIDTH - 1:0] accum;

    for(int i = WINDOW_LENGTH-1; i > 0; i--) begin
      filter_data[i] = filter_data[i - 1];
    end
    filter_data[0] = d;

    accum = 0;
    for (int i = 0; i < WINDOW_LENGTH; i++) begin
      accum += filter_data[i] * CORRELATION_DATA[WINDOW_LENGTH - i - 1];
    end

    //$display("%0t: process_correlator_sample: d=%0d post_accum=%0d ret=%0d", $time, d, accum, accum[ACCUM_WIDTH - 1 : ACCUM_WIDTH - OUTPUT_WIDTH]);

    return accum[ACCUM_WIDTH - 1 : ACCUM_WIDTH - OUTPUT_WIDTH];
  endfunction

  task automatic standard_tests();
    parameter NUM_TESTS = 20;

    for ( int i_test = 0; i_test < NUM_TESTS; i_test++ ) begin
      int max_write_delay = $urandom_range(5);
      int wait_cycles;

      repeat(10) @(posedge Clk);

      for (int i = 0; i < WINDOW_LENGTH; i++) begin
        filter_data[i] = 0;
      end

      $display("%0t: Test %0d started: max_write_delay = %0d", $time, i_test, max_write_delay);

      for ( int i_iteration = 0; i_iteration < 10000; i_iteration++ ) begin
        expect_t e;
        bit [INPUT_WIDTH - 1 : 0] input_mag = $urandom_range(2**INPUT_WIDTH - 1, 0);

        int filtered_mag = process_correlator_sample(input_mag);

        e.data = filtered_mag;
        expected_data.push_back(e);

        tx_intf.write(input_mag);
        repeat($urandom_range(max_write_delay)) @(posedge(Clk));
      end

      wait_cycles = 0;
      while ((expected_data.size() != 0) && (wait_cycles < 1e5)) begin
        @(posedge Clk);
        wait_cycles++;
      end
      assert (wait_cycles < 1e5) else $error("Timeout while waiting for expected queue to empty during standard test %0d.", i_test);

      $display("%0t: Test %0d finished: num_received = %0d", $time, i_test, num_received);

      Rst = 1;
      repeat(100) @(posedge Clk);
      Rst = 0;
    end
  endtask

  initial
  begin
    wait_for_reset();
    standard_tests();
    repeat(100) @(posedge Clk);
    $finish;
  end

endmodule
