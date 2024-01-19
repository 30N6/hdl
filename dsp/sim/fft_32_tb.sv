`timescale 1ns/1ps

import math::*;

typedef struct {
  int data_i;
  int data_q;
  int index;
  bit last;
  int delay;
} fft_32_transfer_t;

interface fft_32_tx_intf #(parameter DATA_WIDTH) (input logic Clk);
  logic                             valid = 0;
  logic signed [DATA_WIDTH - 1 : 0] data_i;
  logic signed [DATA_WIDTH - 1 : 0] data_q;
  logic [4 : 0]                     index;
  logic                             last;

  task write(input fft_32_transfer_t tx);
    data_i  <= tx.data_i;
    data_q  <= tx.data_q;
    index   <= tx.index;
    last    <= tx.last;
    valid   <= 1;
    @(posedge Clk);
    data_i  <= 'x;
    data_q  <= 'x;
    index   <= 'x;
    last    <= 'x;
    valid   <= 0;
    repeat (tx.delay) @(posedge Clk);
  endtask
endinterface

interface fft_32_rx_intf #(parameter DATA_WIDTH) (input logic Clk);
  logic                             valid;
  logic signed [DATA_WIDTH - 1 : 0] data_i;
  logic signed [DATA_WIDTH - 1 : 0] data_q;
  logic [4 : 0]                     index;
  logic                             last;

  task read(output fft_32_transfer_t d);
    logic v;
    do begin
      d.data_i  <= data_i;
      d.data_q  <= data_q;
      d.index   <= index;
      d.last    <= last;
      v         <= valid;
      @(posedge Clk);
    end while (v !== 1);
  endtask
endinterface

module fft_32_tb;
  parameter time CLK_HALF_PERIOD = 4ns;
  parameter INPUT_WIDTH = 16;
  parameter OUTPUT_WIDTH = INPUT_WIDTH + 5;

  typedef struct
  {
    fft_32_transfer_t data;
    int frame_index;
  } expect_t;

  logic Clk;
  logic Rst;

  fft_32_tx_intf #(.DATA_WIDTH(INPUT_WIDTH))  tx_intf (.*);
  fft_32_rx_intf #(.DATA_WIDTH(OUTPUT_WIDTH)) rx_intf (.*);
  expect_t                                    expected_data [$];
  int                                         num_received = 0;

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

  logic w_error;

  fft_32 #(
    .INPUT_DATA_WIDTH  (INPUT_WIDTH),
    .OUTPUT_DATA_WIDTH (OUTPUT_WIDTH),
    .IFFT_MODE         (0)
  )
  dut
  (
    .Clk                   (Clk),
    .Rst                   (Rst),

    .Input_valid           (tx_intf.valid),
    .Input_i               (tx_intf.data_i),
    .Input_q               (tx_intf.data_q),
    .Input_index           (tx_intf.index),
    .Input_last            (tx_intf.last),

    .Output_valid          (rx_intf.valid),
    .Output_i              (rx_intf.data_i),
    .Output_q              (rx_intf.data_q),
    .Output_index          (rx_intf.index),
    .Output_last           (rx_intf.last),

    .Error_input_overflow  (w_error)
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

  function automatic bit compare_fft_data(fft_32_transfer_t a, fft_32_transfer_t b);
    int d_i = a.data_i - b.data_i;
    int d_q = a.data_q - b.data_q;
    real diff = $sqrt($pow($itor(d_i), 2.0) + $pow($itor(d_q), 2.0));
    real threshold = 0.0001 * (2**OUTPUT_WIDTH - 1);
    //$display("a=%p b=%p d_i=%0d d_q=%0d diff=%f threshold=%f", a, b, d_i, d_q, diff, threshold);

    if (diff < threshold) begin
      return 1;
    end else begin
      return 0;
    end
  endfunction

  initial begin
    automatic fft_32_transfer_t read_data;

    wait_for_reset();

    forever begin
      rx_intf.read(read_data);
      if (compare_fft_data(read_data, expected_data[0].data)) begin
        //$display("%0t: data match - frame=%0d - %p", $time, expected_data[0].frame_index, read_data);
      end else begin
        $error("%0t: error -- data mismatch: frame=%0d   expected = %p  actual = %p", $time, expected_data[0].frame_index, expected_data[0].data, read_data);
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
    int max_frame_delay = 64;
    int min_frame_delay = 32;
    int max_sample_delay = $urandom_range(5);
    int wait_cycles;
    fft_32_transfer_t tx_queue[$];
    fft_32_transfer_t rx_queue[$];
    fft_32_transfer_t transfer_data;
    int d_i, d_q;
    int frame_index;
    int current_max_sample_delay = 0;

    int fd_test_in  = $fopen("./test_data/fft_test_data_2024_01_16_in.txt", "r");
    int fd_test_out = $fopen("./test_data/fft_test_data_2024_01_16_out.txt", "r");

    repeat(10) @(posedge Clk);
    $display("%0t: Standard test started: max_frame_delay=%0d min_frame_delay=%0d max_sample_delay=%0d", $time, max_frame_delay, min_frame_delay, max_sample_delay);

    while ($fscanf(fd_test_in, "%d %d %d %d %d", frame_index, transfer_data.index, transfer_data.last, d_i, d_q) == 5) begin
      //$display("input_transfer: frame=%0d index=%0d last=%0d d_i=%0d", frame_index, transfer_data.index, transfer_data.last, d_i, d_q);
      transfer_data.data_i = d_i;
      transfer_data.data_q = d_q;
      tx_queue.push_back(transfer_data);
    end
    $fclose(fd_test_in);

    while ($fscanf(fd_test_out, "%d %d %d %d %d", frame_index, transfer_data.index, transfer_data.last, d_i, d_q) == 5) begin
      expect_t e;
      transfer_data.data_i = d_i;
      transfer_data.data_q = d_q;
      e.data = transfer_data;
      e.frame_index = frame_index;
      expected_data.push_back(e);
    end
    $fclose(fd_test_out);

    $display("%0t: TX queue size = %0d", $time, tx_queue.size());

    while (tx_queue.size() > 0) begin
      transfer_data = tx_queue.pop_front();
      tx_intf.write(transfer_data);
      if (transfer_data.last) begin
        int frame_delay = ($urandom_range(99) < 20) ? min_frame_delay : $urandom_range(max_frame_delay, min_frame_delay);
        repeat (frame_delay) @(posedge Clk);
        current_max_sample_delay = ($urandom_range(99) < 20) ? 0 : $urandom_range(max_sample_delay);        
      end else begin
        repeat (current_max_sample_delay) @(posedge Clk);
      end
    end

    wait_cycles = 0;
    while ((expected_data.size() != 0) && (wait_cycles < 1e5)) begin
      @(posedge Clk);
      wait_cycles++;
    end
    assert (wait_cycles < 1e5) else $error("Timeout while waiting for expected queue to empty during standard test");

    $display("%0t: Standard test finished: num_received = %0d", $time, num_received);

    Rst = 1;
    repeat(100) @(posedge Clk);
    Rst = 0;
  endtask

  initial
  begin
    wait_for_reset();
    standard_tests();
    repeat(100) @(posedge Clk);
    $finish;
  end

endmodule
