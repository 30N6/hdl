`timescale 1ns/1ps

interface gmii_tx_intf (input logic Clk);
  logic       valid = 0;
  logic       last;
  logic [7:0] data;
  logic       ready;

  task write(input logic [7:0] d []);
    for (int i = 0; i < d.size(); i++) begin
      /*if ($urandom_range(99) < 10) begin
        @(posedge Clk);
      end*/
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

module gmii_arb_tb;
  parameter time CLK_HALF_PERIOD  = 5ns;
  parameter NUM_INPUTS = 2;
  parameter INTERFRAME_GAP = 12;

  typedef struct
  {
    logic [7:0] data [$];
  } expect_t;

  typedef struct
  {
    logic [7:0] data [$];
    int   post_packet_delay;
  } tx_data_t;

  logic Clk;
  logic Rst;

  gmii_tx_intf  tx_intf [NUM_INPUTS - 1 : 0] (.*);
  gmii_rx_intf  rx_intf (.*);

  tx_data_t   tx_queue      [NUM_INPUTS - 1:0][$];
  expect_t    expected_data [NUM_INPUTS - 1:0][$];

  int num_received = 0;

  logic [7 : 0]               w_input_data [NUM_INPUTS - 1 : 0];
  logic [NUM_INPUTS - 1 : 0]  w_input_valid;
  logic [NUM_INPUTS - 1 : 0]  w_input_last;
  logic [NUM_INPUTS - 1 : 0]  w_input_ready;

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

  gmii_arb #(.NUM_INPUTS(NUM_INPUTS), .INTERFRAME_GAP(INTERFRAME_GAP)) dut
  (
    .Clk          (Clk),
    .Rst          (Rst),

    .Input_data   (w_input_data),
    .Input_valid  (w_input_valid),
    .Input_last   (w_input_last),
    .Input_ready  (w_input_ready),

    .Output_data  (rx_intf.data),
    .Output_valid (rx_intf.valid),
    .Output_last  (rx_intf.last)
  );

  genvar i_input;
  generate
    for (i_input = 0; i_input < NUM_INPUTS; i_input++) begin
      assign tx_intf[i_input].ready = w_input_ready[i_input];
      assign w_input_valid[i_input] = tx_intf[i_input].valid;
      assign w_input_data[i_input]  = tx_intf[i_input].data;
      assign w_input_last[i_input]  = tx_intf[i_input].last;
    end
  endgenerate

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
      int input_index;
      rx_intf.read(read_data);

      input_index = read_data[0];
      assert (input_index < NUM_INPUTS) else $error("Invalid input_index");

      if (data_match(read_data, expected_data[input_index][0].data)) begin
        //$display("%0t: data match - %p", $time, read_data);
      end else begin
        $error("%0t: error -- data mismatch on input_index=%0d: expected = %p  actual = %p", $time, input_index, expected_data[input_index][0].data, read_data);
      end
      void'(expected_data[input_index].pop_front());

      num_received++;
    end
  end

  final begin
    for (int i_input = 0; i_input < NUM_INPUTS; i_input++) begin
      if ( expected_data[i_input].size() != 0 ) begin
        $error("Unexpected data remaining in queue %0d:", i_input);
        while ( expected_data[i_input].size() != 0 ) begin
          $display("%p", expected_data[i_input][0].data);
          void'(expected_data[i_input].pop_front());
        end
      end
    end
  end

  generate
    for (i_input = 0; i_input < NUM_INPUTS; i_input++) begin
      initial begin
        while (1) begin
          @(posedge Clk);
          if (tx_queue[i_input].size() > 0) begin
            tx_intf[i_input].write(tx_queue[i_input][0].data);
            repeat(tx_queue[i_input][0].post_packet_delay) @(posedge Clk);
            void'(tx_queue[i_input].pop_front());
          end
        end
      end
    end
  endgenerate

  task automatic standard_test();
    parameter NUM_TESTS = 200;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int max_write_delay = $urandom_range(5);
      tx_data_t tx_data;
      expect_t e;
      int r;

      $display("%0t: Test started - max_write_delay=%0d", $time, max_write_delay);

      for (int i_input = 0; i_input < NUM_INPUTS; i_input++) begin
        r = $urandom_range(200, 20);
        for (int i = 0; i < r; i++) begin
          tx_data.post_packet_delay = $urandom_range(max_write_delay);
          tx_data.data.delete();
          tx_data.data.push_back(i_input);
          repeat($urandom_range(10)) tx_data.data.push_back($urandom);
          tx_queue[i_input].push_back(tx_data);
          e.data = tx_data.data;
          expected_data[i_input].push_back(e);
        end
      end

      begin
        int wait_cycles = 0;
        while (1) begin
          bit queues_empty = 1;
          for (int i_input = 0; i_input < NUM_INPUTS; i_input++) begin
            queues_empty &= (expected_data[i_input].size() == 0) && (tx_queue[i_input].size() == 0);
          end

          if (queues_empty || (wait_cycles > 1e5)) begin
            break;
          end

          @(posedge Clk);
          wait_cycles++;
        end
        assert (wait_cycles < 1e5) else $error("Timeout while waiting for expected queue to empty during test.");
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
