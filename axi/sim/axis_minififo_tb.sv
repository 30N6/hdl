`timescale 1ns/1ps

interface axi_tx_intf #(parameter AXI_DATA_WIDTH) (input logic Clk);
  logic                           valid = 0;
  logic                           last;
  logic [AXI_DATA_WIDTH - 1 : 0]  data;
  logic                           ready;

  task write(input logic [AXI_DATA_WIDTH - 1 : 0] d []);
    for (int i = 0; i < d.size(); i++) begin
      if ($urandom_range(99) < 10) begin
        @(posedge Clk);
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

module axis_minififo_tb;
  parameter time CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH        = 32;

  typedef struct
  {
    logic [AXI_DATA_WIDTH - 1 : 0] data [$];
  } expect_t;

  typedef struct
  {
    logic [AXI_DATA_WIDTH - 1 : 0] data [$];
    int post_packet_delay;
  } tx_data_t;

  logic Clk;
  logic Rst;

  axi_tx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  slave_tx_intf   (.*);
  axi_rx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  master_rx_intf  (.*);

  tx_data_t   tx_queue[$];
  expect_t    expected_data[$];

  int   num_received = 0;
  logic r_axi_rx_ready;
  logic w_axi_rx_valid;

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
    r_axi_rx_ready <= $urandom_range(99) < 80;
  end

  axis_minififo #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH)) dut
  (
    .Clk          (Clk),
    .Rst          (Rst),

    .S_axis_ready (slave_tx_intf.ready),
    .S_axis_valid (slave_tx_intf.valid),
    .S_axis_data  (slave_tx_intf.data),
    .S_axis_last  (slave_tx_intf.last),

    .M_axis_ready (r_axi_rx_ready),
    .M_axis_valid (w_axi_rx_valid),
    .M_axis_data  (master_rx_intf.data),
    .M_axis_last  (master_rx_intf.last)
  );

  assign master_rx_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
  endtask

  function automatic bit data_match(logic [AXI_DATA_WIDTH - 1 : 0] a [$], logic [AXI_DATA_WIDTH - 1 : 0] b []);
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
    automatic logic [AXI_DATA_WIDTH - 1 : 0] read_data [$];

    wait_for_reset();

    forever begin
      master_rx_intf.read(read_data);

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
        slave_tx_intf.write(tx_queue[0].data);
        repeat(tx_queue[0].post_packet_delay) @(posedge Clk);
        void'(tx_queue.pop_front());
      end
    end
  end

  task automatic standard_test();
    parameter NUM_TESTS = 200;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int max_write_delay = $urandom_range(5);
      tx_data_t tx_data;
      expect_t e;
      int r;

      $display("%0t: Test started - max_write_delay=%0d", $time, max_write_delay);

      r = $urandom_range(200, 20);
      for (int i = 0; i < r; i++) begin
        tx_data.post_packet_delay = $urandom_range(max_write_delay);
        tx_data.data.delete();
        repeat($urandom_range(100, 1)) tx_data.data.push_back($urandom);
        tx_queue.push_back(tx_data);
        $display("expecting: %p", tx_data);
        e.data = tx_data.data;
        expected_data.push_back(e);
      end

      begin
        int wait_cycles = 0;
        while (1) begin
          if ((expected_data.size() == 0) || (wait_cycles > 1e5)) begin
            break;
          end

          @(posedge Clk);
          wait_cycles++;
        end
        assert (wait_cycles < 1e5) else $error("Timeout while waiting for expected queue to empty during test.");
      end

      $display("%0t: Test finished: num_received = %0d", $time, num_received);
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
