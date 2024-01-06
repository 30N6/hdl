`timescale 1ns/1ps

import math::*;
import adsb_pkg::*;

interface adc_tx_intf (input logic Clk);
  logic                             valid = 0;
  logic signed [15 : 0] data_i;
  logic signed [15 : 0] data_q;

  task write(input logic signed [15 : 0] d_i, logic signed [15 : 0] d_q);
    data_i <= d_i;
    data_q <= d_q;
    valid  <= 1;
    @(posedge Clk);
    valid  <= 0;
    data_i <= 'x;
    data_q <= 'x;
  endtask
endinterface

interface axi_tx_intf #(parameter AXI_DATA_WIDTH) (input logic Clk);
  logic                           valid = 0;
  logic                           last;
  logic [AXI_DATA_WIDTH - 1 : 0]  data;
  logic                           ready;

  task write(input logic [AXI_DATA_WIDTH - 1 : 0] d []);
    for (int i = 0; i < d.size(); i++) begin
      valid <= 1;
      data  <= d[i];
      last  <= (i == (d.size() - 1));

      do begin
        @(posedge Clk);
      end while (ready);

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

module adsb_demodulator_tb;
  parameter time DATA_CLK_HALF_PERIOD = 8ns;
  parameter time AXI_CLK_HALF_PERIOD  = 5ns;
  parameter IQ_WIDTH                  = 14;
  parameter AXI_DATA_WIDTH            = 32;

  typedef struct
  {
    logic [AXI_DATA_WIDTH - 1 : 0] data [$];
  } expect_t;

  logic Clk, Axi_clk;
  logic Rst, Axi_rst;

  adc_tx_intf                               adc_tx_intf (.Clk(Clk));
  axi_tx_intf #(.DATA_WIDTH(INPUT_WIDTH))   cfg_tx_intf (.Clk(Axi_clk));
  axi_rx_intf #(.DATA_WIDTH(OUTPUT_WIDTH))  rpt_rx_intf (.Clk(Axi_clk));

  expect_t                      expected_data [$];
  logic [INPUT_WIDTH - 1:0]     filter_data [WINDOW_LENGTH - 1:0];
  int                           num_received = 0;

  logic r_axi_rx_ready;
  logic w_axi_rx_valid;

  initial begin
    Clk = 0;
    forever begin
      #(DATA_CLK_HALF_PERIOD);
      Clk = ~Clk;
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
    Rst = 1;
    @(posedge Clk);
    Rst = 0;
  end

  initial begin
    Axi_rst = 1;
    @(posedge Axi_clk);
    Axi_rst = 0;
  end

  always_ff @(posedge Axi_clk) begin
    r_axi_rx_ready <= $urandom_range(99) < 80;
  end

  adsb_demodulator
  #(
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .IQ_WIDTH       (IQ_WIDTH)
  )
  dut
  (
    .Data_clk       (Clk),
    .Data_rst       (Rst),

    .Adc_valid      (adc_tx_intf.valid),
    .Adc_data_i     (adc_tx_intf.data_i),
    .Adc_data_q     (adc_tx_intf.data_q),

    .S_axis_clk     (Axi_clk),
    .S_axis_resetn  (!Axi_rst),
    .S_axis_ready   (cfg_tx_intf.ready),
    .S_axis_valid   (cfg_tx_intf.valid),
    .S_axis_data    (cfg_tx_intf.data),
    .S_axis_last    (cfg_tx_intf.last),

    .M_axis_clk     (Axi_clk),
    .M_axis_resetn  (!Axi_rst),
    .M_axis_ready   (r_axi_rx_ready),
    .M_axis_valid   (w_axi_rx_valid),
    .M_axis_data    (rpt_rx_intf.data),
    .M_axis_last    (rpt_rx_intf.last)
  );

  assign rpt_rx_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
  endtask

  task automatic write_config();
    bit [ADSB_CONFIG_WIDTH - 1 : 0] config_data [] = {64'h00000001AD5B0101, 64'h00000100AD5B0101};

    for (int i = 0; i < config_data.size(); i++) begin
      logic [AXI_DATA_WIDTH - 1 : 0] axi_data [$];
      for (int j = 0; j < ($size(config_data[i]) / AXI_DATA_WIDTH); j++) begin
        axi_data.push_back(config_data[AXI_DATA_WIDTH*j +: AXI_DATA_WIDTH]);
      end
      cfg_tx_intf.write(axi_data);
      repeat(200) @(posedge Axi_clk);
    end
  endtask

  function automatic bit data_match(logic [AXI_DATA_WIDTH - 1 : 0] a [$], logic [AXI_DATA_WIDTH - 1 : 0] b []);
    if (a.size() != b.size()) begin
      $display("%0t: size mismatch: a=%0d b=%0d", $time, a.size(), b.size());
      return 0;
    end

    for (int i = 0; i < a.size(); i++) begin
      if (a[i] !== b[i]) begin
        $display("%0t: data mismatch: a[%0d]=%0X b[%0d]=%0X", $time, i, a[i], i, b[i]);
        return 0;
      end
    end

    return 1;
  endfunction

  initial begin
    automatic logic [AXI_DATA_WIDTH - 1 : 0] read_data [$];

    wait_for_reset();

    forever begin
      rx_intf.read(read_data);
      if (data_match(read_data, expected_data[0].data)) begin
        //$display("%0t: data match - %X", $time, read_data);
      end else begin
        $error("%0t: error -- data mismatch: expected = %p  actual = %p", $time, expected_data[0].data, read_data);
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
        bit signed [DATA_WIDTH - 1 : 0] input_i = $urandom_range(2**IQ_WIDTH - 1, 0);
        bit signed [DATA_WIDTH - 1 : 0] input_q = $urandom_range(2**IQ_WIDTH - 1, 0);

        //e.data = filtered_mag;
        //expected_data.push_back(e);

        tx_intf.write(input_i, input_q);
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
    write_config();
    standard_tests();
    repeat(100) @(posedge Clk);
    $finish;
  end

endmodule
