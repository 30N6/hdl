`timescale 1ns/1ps

import math::*;

interface mag_tx_intf #(parameter DATA_WIDTH) (input logic Clk);
  logic                             valid = 0;
  logic signed [DATA_WIDTH - 1 : 0] data_i;
  logic signed [DATA_WIDTH - 1 : 0] data_q;

  task write(input logic signed [DATA_WIDTH - 1 : 0] d_i, logic signed [DATA_WIDTH - 1 : 0] d_q);
    data_i <= d_i;
    data_q <= d_q;
    valid  <= 1;
    @(posedge Clk);
    valid  <= 0;
    data_i <= 'x;
    data_q <= 'x;
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

module mag_approximation_tb;
  parameter time CLK_HALF_PERIOD = 4ns;
  parameter DATA_WIDTH = 14;

  typedef struct
  {
    logic [DATA_WIDTH - 1 : 0] data;
  } expect_t;

  logic Clk;
  logic Rst;

  mag_tx_intf #(.DATA_WIDTH(DATA_WIDTH)) tx_intf (.*);
  mag_rx_intf #(.DATA_WIDTH(DATA_WIDTH)) rx_intf (.*);

  expect_t expected_data [$];

  initial begin
    Clk = 0;
    forever begin
      #(CLK_HALF_PERIOD);
      Clk = ~Clk;
    end
  end

  initial begin
    Rst = 1;
    repeat(10) @(posedge Clk);
    Rst = 0;
  end

  mag_approximation
  #(
    .DATA_WIDTH(DATA_WIDTH),
    .LATENCY(1)
  )
  dut
  (
    .Clk          (Clk),

    .Input_valid  (tx_intf.valid),
    .Input_i      (tx_intf.data_i),
    .Input_q      (tx_intf.data_q),

    .Output_valid (rx_intf.valid),
    .Output_data  (rx_intf.data)
  );

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (!Rst);
  endtask

  initial begin
    automatic logic [DATA_WIDTH - 1 : 0] read_data;

    wait_for_reset();

    forever begin
      rx_intf.read(read_data);
      if ( read_data == expected_data[0].data ) begin
        //$display("%0t: data match - %X", $time, read_data);
      end else begin
        $error("%0t: error -- data mismatch: expected = %X  actual = %X", $time, expected_data[0].data, read_data);
      end
      expected_data.pop_front();
    end
  end

  final begin
    if ( expected_data.size() != 0 ) begin
      $error("Unexpected data remaining in queue:");
      while ( expected_data.size() != 0 ) begin
        $display("%X", expected_data[0].data);
        expected_data.pop_front();
      end
    end
  end

  function automatic int clamp_magnitude(int v, int bits);
    if (v > (2**bits - 1)) begin
      return 2**bits - 1;
    end else begin
      return v;
    end
  endfunction;

  function automatic int mag_approx_model(int i, int q);
    int i_abs = clamp_magnitude(math::iabs(i), DATA_WIDTH - 1);
    int q_abs = clamp_magnitude(math::iabs(q), DATA_WIDTH - 1);
    int v_min = math::imin(i_abs, q_abs);
    int v_max = math::imax(i_abs, q_abs);
    int r = v_max + (3 * v_min)/8;
    //$display("%0t: mag_approx_model: i=%0d q=%0d v_min=%0d v_max=%0d r=%0d", $time, i, q, v_min, v_max, r);
    return r;
  endfunction

  task automatic standard_tests();
    parameter NUM_TESTS = 20;

    for ( int i_test = 0; i_test < NUM_TESTS; i_test++ ) begin
      int max_write_delay = $urandom_range(5);
      int wait_cycles;

      $display("%0t: Running test %0d: max_write_delay = %0d", $time, i_test, max_write_delay);

      for ( int i_iteration = 0; i_iteration < 10000; i_iteration++ ) begin
        expect_t e;
        bit signed [DATA_WIDTH - 1 : 0] input_i = $urandom_range(2**DATA_WIDTH - 1, 0);
        bit signed [DATA_WIDTH - 1 : 0] input_q = $urandom_range(2**DATA_WIDTH - 1, 0);
        int approx_mag  = mag_approx_model(input_i, input_q);

        e.data = approx_mag;
        expected_data.push_back(e);

        tx_intf.write(input_i, input_q);
        repeat($urandom_range(max_write_delay)) @(posedge(Clk));
      end

      wait_cycles = 0;
      while ((expected_data.size() != 0) && (wait_cycles < 1e5)) begin
        @(posedge Clk);
        wait_cycles++;
      end
      assert (wait_cycles < 1e5) else $error("Timeout while waiting for expected queue to empty during standard test %0d.", i_test);
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
