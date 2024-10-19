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

module axis_mux_tb;
  parameter time CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH        = 32;
  parameter NUM_CHANNELS          = 4;

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

  axi_tx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  slave_tx_intf   [NUM_CHANNELS - 1 : 0] (.*);
  axi_rx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  master_rx_intf  (.*);

  tx_data_t   tx_queue      [NUM_CHANNELS - 1 : 0][$];
  expect_t    expected_data [NUM_CHANNELS - 1 : 0][$];

  logic [NUM_CHANNELS - 1 : 0]    w_s_axis_ready;
  logic [NUM_CHANNELS - 1 : 0]    w_s_axis_valid;
  logic [AXI_DATA_WIDTH - 1 : 0]  w_s_axis_data [NUM_CHANNELS - 1 : 0];
  logic [NUM_CHANNELS - 1 : 0]    w_s_axis_last;
  int                             num_received = 0;
  logic                           r_axi_rx_ready;
  logic                           w_axi_rx_valid;

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

  axis_mux #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH), .NUM_INPUTS(NUM_CHANNELS)) dut
  (
    .Clk          (Clk),
    .Rst          (Rst),

    .S_axis_ready (w_s_axis_ready),
    .S_axis_valid (w_s_axis_valid),
    .S_axis_data  (w_s_axis_data),
    .S_axis_last  (w_s_axis_last),

    .M_axis_ready (r_axi_rx_ready),
    .M_axis_valid (w_axi_rx_valid),
    .M_axis_data  (master_rx_intf.data),
    .M_axis_last  (master_rx_intf.last)
  );

  genvar i_slave;
  generate
    for (i_slave = 0; i_slave < NUM_CHANNELS; i_slave++) begin
      assign slave_tx_intf[i_slave].ready = w_s_axis_ready[i_slave];
      assign w_s_axis_valid[i_slave]      = slave_tx_intf[i_slave].valid;
      assign w_s_axis_data[i_slave]       = slave_tx_intf[i_slave].data;
      assign w_s_axis_last[i_slave]       = slave_tx_intf[i_slave].last;
    end
  endgenerate

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
      int channel;
      master_rx_intf.read(read_data);

      channel = read_data[0];
      assert (channel < NUM_CHANNELS) else $error("Invalid channel index");

      if (data_match(read_data, expected_data[channel][0].data)) begin
        //$display("%0t: data match - %p", $time, read_data);
      end else begin
        $error("%0t: error -- data mismatch on channel=%0d: expected = %p  actual = %p", $time, channel, expected_data[channel][0].data, read_data);
      end
      void'(expected_data[channel].pop_front());

      num_received++;
    end
  end

  final begin
    for (int i_channel = 0; i_channel < NUM_CHANNELS; i_channel++) begin
      if ( expected_data[i_channel].size() != 0 ) begin
        $error("Unexpected data remaining in queue %0d:", i_channel);
        while ( expected_data[i_channel].size() != 0 ) begin
          $display("%p", expected_data[i_channel][0].data);
          void'(expected_data[i_channel].pop_front());
        end
      end
    end
  end

  generate
    for (i_slave = 0; i_slave < NUM_CHANNELS; i_slave++) begin
      initial begin
        while (1) begin
          @(posedge Clk);
          if (tx_queue[i_slave].size() > 0) begin
            slave_tx_intf[i_slave].write(tx_queue[i_slave][0].data);
            repeat(tx_queue[i_slave][0].post_packet_delay) @(posedge Clk);
            void'(tx_queue[i_slave].pop_front());
          end
        end
      end
    end
  endgenerate

  task automatic standard_test();
    parameter NUM_TESTS = 20;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int max_write_delay = $urandom_range(5);
      tx_data_t tx_data;
      expect_t e;
      int r;

      $display("%0t: Test started - max_write_delay=%0d", $time, max_write_delay);

      for (int i_channel = 0; i_channel < NUM_CHANNELS; i_channel++) begin
        r = $urandom_range(200, 20);
        for (int i = 0; i < r; i++) begin
          tx_data.post_packet_delay = $urandom_range(max_write_delay);
          tx_data.data.delete();
          tx_data.data.push_back(i_channel);
          repeat($urandom_range(10)) tx_data.data.push_back($urandom);
          tx_queue[i_channel].push_back(tx_data);
          e.data = tx_data.data;
          expected_data[i_channel].push_back(e);
        end
      end

      begin
        int wait_cycles = 0;
        while (1) begin
          bit expected_empty = 1;
          for (int i_channel = 0; i_channel < NUM_CHANNELS; i_channel++) begin
            expected_empty &= (expected_data[i_channel].size() == 0);
          end

          if (expected_empty || (wait_cycles > 1e5)) begin
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
