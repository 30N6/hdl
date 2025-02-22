`timescale 1ns/1ps

interface gmii_tx_intf (input logic Clk);
  logic       valid = 0;
  logic       error;
  logic [7:0] data;
  logic       accepted;

  task write(input logic [7:0] d [], input logic e []);
    for (int i = 0; i < d.size(); i++) begin
      valid <= 1;
      data  <= d[i];
      error <= e[i];
      @(posedge Clk);
      valid <= 0;
      data  <= 'x;
      error <= 'x;
    end
  endtask
endinterface

interface gmii_rx_intf (input logic Clk);
  logic       valid;
  logic       last;
  logic [7:0] data;

  task read(output logic [7:0] d [$]);
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

module gmii_buffer_tb;
  parameter time CLK_HALF_PERIOD  = 5ns;
  parameter DATA_DEPTH  = 4096;
  parameter FRAME_DEPTH = 64;

  typedef struct
  {
    logic [7:0] data [$];
  } expect_t;

  typedef struct
  {
    logic [7:0] data [$];
    logic error [$];
    int   post_packet_delay;
  } tx_data_t;

  logic Clk;
  logic Rst;

  gmii_tx_intf  tx_intf (.*);
  gmii_rx_intf  rx_intf (.*);

  expect_t    expected_data[$];

  int   num_received = 0;
  logic r_rx_ready;
  logic w_rx_valid;
  int   ready_prob = 80;

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
    r_rx_ready <= $urandom_range(99) < ready_prob;
  end

  gmii_buffer #(.DATA_DEPTH(DATA_DEPTH), .FRAME_DEPTH(FRAME_DEPTH)) dut
  (
    .Clk            (Clk),
    .Rst            (Rst),

    .Input_data     (tx_intf.data),
    .Input_valid    (tx_intf.valid),
    .Input_error    (tx_intf.error),
    .Input_accepted (tx_intf.accepted),

    .Output_data    (rx_intf.data),
    .Output_valid   (w_rx_valid),
    .Output_last    (rx_intf.last),
    .Output_ready   (r_rx_ready)
  );

  assign rx_intf.valid = w_rx_valid && r_rx_ready;

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

  task automatic standard_test();
    parameter NUM_TESTS = 200;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      tx_data_t tx_data;
      expect_t e;
      int num_packets = $urandom_range(200, 20);
      int max_packet_size = $urandom_range(1500, 200);
      int r = $urandom_range(99);

      if (r < 10) begin
        ready_prob = 10;
      end else begin
        ready_prob = 80;
      end

      $display("%0t: Test started - ready_prob=%0d", $time, ready_prob);

      for (int i = 0; i < num_packets; i++) begin
        int len;
        int error = $urandom_range(99) < 5;
        logic input_accepted;

        r = $urandom_range(99);
        if (r < 80) begin
          len = $urandom_range(10, 1);
        end else begin
          len = $urandom_range(max_packet_size, 10);
        end

        r = $urandom_range(99);
        if (r < 80) begin
          tx_data.post_packet_delay = $urandom_range(5);
        end else begin
          tx_data.post_packet_delay = $urandom_range(200, 100);
        end

        tx_data.data.delete();
        tx_data.error.delete();

        for (int j = 0; j < len; j++) begin
          tx_data.data.push_back($urandom);
          tx_data.error.push_back(0);
        end

        if (error) begin
          int error_index;
          r = $urandom_range(99);
          if (r < 10) begin
            error_index = 0;
          end else if (r < 20) begin
            error_index = len - 1;
          end else begin
            error_index = $urandom_range(len - 1);
          end
          tx_data.error[error_index] = 1;
        end

        $display("%0t: writing data: %p", $time, tx_data.data);
        tx_intf.write(tx_data.data, tx_data.error);
        repeat(3) @(posedge Clk);
        input_accepted = tx_intf.accepted;

        if (!error && input_accepted) begin
          $display("%0t: expecting: %p", $time, tx_data);
          e.data = tx_data.data;
          expected_data.push_back(e);
        end else begin
          $display("%0t: input rejected: error=%0d accepted=%0d", $time, error, input_accepted);
        end

        repeat(tx_data.post_packet_delay) @(posedge Clk);
      end

      begin
        int wait_cycles = 0;
        while (1) begin
          if ((expected_data.size() == 0) || (wait_cycles > 1e6)) begin
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
