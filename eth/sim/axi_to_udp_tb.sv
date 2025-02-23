`timescale 1ns/1ps

import eth_pkg::*;

interface axi_tx_intf #(parameter AXI_DATA_WIDTH) (input logic Clk);
  logic                           valid = 0;
  logic                           last;
  logic [AXI_DATA_WIDTH - 1 : 0]  data;
  logic                           ready;

  task write(input logic [AXI_DATA_WIDTH - 1 : 0] d []);
    for (int i = 0; i < d.size(); i++) begin
      if ($urandom_range(99) < 10) begin
        repeat($urandom_range(10, 1)) @(posedge Clk);
      end
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

interface udp_rx_intf (input logic Clk);
  logic                                 valid;
  logic                                 last;
  logic [7:0]                           data;
  logic [eth_udp_length_width - 1 : 0]  length;

  task read(output logic [7:0] d [$]);
    automatic bit done = 0;
    automatic bit first = 1;
    automatic int len = 0;
    d.delete();

    do begin
      if (valid) begin
        d.push_back(data);
        done = last;
        if (first) begin
          len = length;
          first = 0;
        end
      end
      @(posedge Clk);
    end while(!done);

    assert (len == d.size()) else $error("length mismatch");
  endtask
endinterface

module axi_to_udp_tb;
  parameter time CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH        = 32;
  parameter DATA_FIFO_DEPTH       = 4096;
  parameter FRAME_FIFO_DEPTH      = 64;

  typedef struct
  {
    logic [7:0] data [$];
  } expect_t;

  typedef struct
  {
    logic [AXI_DATA_WIDTH - 1 : 0] data [$];
    int post_packet_delay;
  } tx_data_t;

  logic Clk;
  logic Rst;

  axi_tx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  tx_intf (.*);
  udp_rx_intf                                     rx_intf (.*);

  tx_data_t   tx_queue[$];
  expect_t    expected_data[$];

  int   num_received = 0;
  logic r_udp_rx_ready;
  logic w_udp_rx_valid;

  initial begin
    Clk = 0;
    forever begin
      #(CLK_HALF_PERIOD);
      Clk = ~Clk;
    end
  end

  initial begin
    Rst = 1;
    @(posedge Clk);
    Rst = 0;
  end

  always_ff @(posedge Clk) begin
    r_udp_rx_ready <= $urandom_range(99) < 80;
  end

  axi_to_udp #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH), .DATA_FIFO_DEPTH(DATA_FIFO_DEPTH), .FRAME_FIFO_DEPTH(FRAME_FIFO_DEPTH)) dut
  (
    .Clk          (Clk),
    .Rst          (Rst),

    .S_axis_valid (tx_intf.valid),
    .S_axis_data  (tx_intf.data),
    .S_axis_last  (tx_intf.last),
    .S_axis_ready (tx_intf.ready),

    .Udp_length   (rx_intf.length),
    .Udp_data     (rx_intf.data),
    .Udp_valid    (w_udp_rx_valid),
    .Udp_last     (rx_intf.last),
    .Udp_ready    (r_udp_rx_ready)
  );

  assign rx_intf.valid = w_udp_rx_valid && r_udp_rx_ready;

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
  endtask

  function automatic bit data_match(logic [7:0] a [$], logic [7:0] b []);
    if (a.size() != b.size()) begin
      $display("%0t: size mismatch: a=%0d b=%0d", $time, a.size(), b.size());
      return 0;
    end

    for (int i = 0; i < a.size(); i++) begin
      if (a[i] !== b[i]) begin
        $display("%0t: data mismatch [%0d]: %X %X", $time, i, a[i], b[i]);
        return 0;
      end
    end

    return 1;
  endfunction

  initial begin
    automatic logic [7:0] read_data [$];

    wait_for_reset();

    forever begin
      rx_intf.read(read_data);

      if (data_match(read_data, expected_data[0].data)) begin
        $display("%0t: data match - %p", $time, read_data);
      end else begin
        $error("%0t: error -- data mismatch: expected = %p  actual = %p", $time, expected_data[0].data, read_data);
      end
      void'(expected_data.pop_front());

      num_received++;
    end
  end

  final begin
    if ( expected_data.size() != 0 ) begin
      $error("Unexpected data remaining in queue");
      while ( expected_data.size() != 0 ) begin
        $display("%p", expected_data[0].data);
        void'(expected_data.pop_front());
      end
    end
  end

  initial begin
    while (1) begin
      @(posedge Clk);
      if (tx_queue.size() > 0) begin
        $display("%0t: writing: %p", $time, tx_queue[0].data);
        tx_intf.write(tx_queue[0].data);
        repeat(tx_queue[0].post_packet_delay) @(posedge Clk);
        void'(tx_queue.pop_front());
      end
    end
  end

  function automatic expect_t get_expected_data(tx_data_t tx_data);
    expect_t e;

    for (int i = 0; i < tx_data.data.size(); i++) begin
      for (int j = 0; j < AXI_DATA_WIDTH/8; j++) begin
        e.data.push_back(tx_data.data[i][j*8 +: 8]);
      end
    end

    return e;
  endfunction

  task automatic standard_test();
    parameter NUM_TESTS = 20;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int max_write_delay = $urandom_range(5);
      int num_packets = $urandom_range(200, 100);
      tx_data_t tx_data;
      expect_t e;

      $display("%0t: Test started - max_write_delay=%0d", $time, max_write_delay);

      for (int i = 0; i < num_packets; i++) begin
        int r = $urandom_range(99);
        int packet_len;

        if (r < 25) begin
          packet_len = $urandom_range(10, 1);
        end else begin
          packet_len = $urandom_range(300, 1);
        end

        tx_data.post_packet_delay = $urandom_range(max_write_delay);
        tx_data.data.delete();
        repeat(packet_len) tx_data.data.push_back($urandom);
        tx_queue.push_back(tx_data);
        $display("%0t: expecting: %p", $time, tx_data);

        e = get_expected_data(tx_data);
        expected_data.push_back(e);
      end

      begin
        int wait_cycles = 0;
        while (1) begin
          if (((tx_queue.size() == 0) && (expected_data.size() == 0)) || (wait_cycles > 1e6)) begin
            break;
          end

          @(posedge Clk);
          wait_cycles++;
        end
        assert (wait_cycles < 1e6) else $error("Timeout while waiting for expected queue to empty during test.");
      end

      $display("%0t: Test finished: num_received = %0d", $time, num_received);
      Rst = 1;
      repeat(10) @(posedge Clk);
      Rst = 0;
      repeat(10) @(posedge Clk);
    end
  endtask

  initial
  begin
    wait_for_reset();
    repeat(10) @(posedge Clk);
    standard_test();
    $finish;
  end

endmodule
