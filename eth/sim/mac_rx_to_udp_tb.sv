`timescale 1ns/1ps

import eth_pkg::*;

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

module mac_rx_to_udp_tb;
  parameter time CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH        = 8;

  typedef struct
  {
    logic [AXI_DATA_WIDTH - 1 : 0] data [$];
  } expect_t;

  typedef struct
  {
    logic [AXI_DATA_WIDTH - 1 : 0] data [$];
    logic                          error [$];
    int post_packet_delay;
  } tx_data_t;

  logic Clk;
  logic Rst;

  gmii_tx_intf                                    tx_intf (.*);
  axi_rx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  rx_intf (.*);

  expect_t    expected_data[$];

  int   num_received = 0;
  logic r_udp_rx_ready;
  logic w_udp_rx_valid;

  logic [15:0] r_filter_port;

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

  mac_rx_to_udp #(.INPUT_BUFFER_DATA_DEPTH(4096), .INPUT_BUFFER_FRAME_DEPTH(64)) dut
  (
    .Clk              (Clk),
    .Rst              (Rst),

    .Udp_filter_port  (r_filter_port),

    .Mac_valid        (tx_intf.valid),
    .Mac_data         (tx_intf.data),
    .Mac_error        (tx_intf.error),
    .Mac_accepted     (tx_intf.accepted),

    .Udp_data         (rx_intf.data),
    .Udp_valid        (w_udp_rx_valid),
    .Udp_last         (rx_intf.last),
    .Udp_ready        (r_udp_rx_ready)
  );

  assign rx_intf.valid = w_udp_rx_valid && r_udp_rx_ready;

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

  function automatic bit randomize_tx_data(logic [15:0] filter_port, output tx_data_t d);
    int r;
    bit accepted = 1;
    logic [15:0] eth_type;
    logic [7:0] ip_ver_ihl;
    logic [7:0] ip_proto;
    logic [15:0] udp_dest_port;
    logic [15:0] udp_len;
    bit error;

    if ($urandom_range(99) < 5) begin
      eth_type = $urandom;
    end else begin
      eth_type = eth_type_ip;
    end

    if ($urandom_range(99) < 5) begin
      ip_ver_ihl = $urandom;
    end else begin
      ip_ver_ihl = eth_ip_ver_ihl;
    end

    if ($urandom_range(99) < 5) begin
      ip_proto = $urandom;
    end else begin
      ip_proto = eth_ip_proto_udp;
    end

    if ($urandom_range(99) < 5) begin
      udp_dest_port = $urandom;
    end else begin
      udp_dest_port = filter_port;
    end

    if ($urandom_range(99) < 5) begin
      udp_len = 0;
    end else begin
      udp_len = $urandom_range(eth_udp_max_payload_length, 0);
    end

    error = ($urandom_range(99) < 5);

    accepted = (eth_type == eth_type_ip) && (ip_ver_ihl == eth_ip_ver_ihl) && (ip_proto == eth_ip_proto_udp) &&
               (udp_dest_port == filter_port) && (udp_len > 0) && !error;

    $display("randomize_tx_data: accepted=%0d ip_ver_ihl=%02X", accepted, ip_ver_ihl);

    r = $urandom_range(7,0);
    for (int i = 0; i < r; i++) begin
      d.data.push_back(eth_preamble_byte);
    end
    d.data.push_back(eth_sfd_byte);

    for (int i = 0; i < 2*eth_mac_length; i++) begin
      d.data.push_back($urandom);
    end
    for (int i = 0; i < 2; i++) begin
      d.data.push_back(eth_type[i*8 +: 8]);
    end

    d.data.push_back(ip_ver_ihl);
    for (int i = 0; i < 8; i++) begin
      d.data.push_back($urandom);
    end
    d.data.push_back(ip_proto);
    for (int i = 0; i < (eth_ipv4_header_length - 10); i++) begin
      d.data.push_back($urandom);
    end

    for (int i = 0; i < 2; i++) begin
      d.data.push_back($urandom);
    end
    for (int i = 0; i < 2; i++) begin
      d.data.push_back(udp_dest_port[(1 - i)*8 +: 8]);
    end
    for (int i = 0; i < 2; i++) begin
      d.data.push_back(udp_len[(1 - i)*8 +: 8]);
    end
    for (int i = 0; i < 2; i++) begin
      d.data.push_back($urandom);
    end

    for (int i = 0; i < udp_len; i++) begin
      d.data.push_back($urandom);
    end

    //random padding
    r = $urandom_range(8, 0);
    for (int i = 0; i < r; i++) begin
      d.data.push_back($urandom);
    end

    //fcs
    for (int i = 0; i < 4; i++) begin
      d.data.push_back($urandom);
    end

    for (int i = 0; i < d.data.size(); i++) begin
      d.error.push_back(0);
    end
    if (error) begin
      d.error[$urandom_range(d.error.size() - 1, 0)] = 1;
    end

    return accepted;
  endfunction

  function automatic expect_t get_expected_data(tx_data_t d);
    expect_t e;
    logic [15:0] udp_length;
    int frame_start_index = 0;
    int data_start_index = 0;

    while(d.data[frame_start_index] != eth_sfd_byte) begin
      frame_start_index++;
    end
    frame_start_index++;

    data_start_index = frame_start_index + eth_mac_header_length + eth_ipv4_header_length + eth_udp_header_length;

    udp_length = {d.data[frame_start_index + eth_mac_header_length + eth_ipv4_header_length + 4],
                  d.data[frame_start_index + eth_mac_header_length + eth_ipv4_header_length + 5]};

    e.data.delete();
    for (int i = 0; i < udp_length; i++) begin
      e.data.push_back(d.data[data_start_index + i]);
    end

    $display("tx_data_len=%0d frame_start=%0d data_start=%0d udp_len=%0d", d.data.size(), frame_start_index, data_start_index, udp_length);

    return e;
  endfunction

  task automatic standard_test();
    parameter NUM_TESTS = 20;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int max_write_delay = $urandom_range(12, 4);
      int num_packets = $urandom_range(200, 100);
      tx_data_t tx_data;
      expect_t e;

      $display("%0t: Test started - max_write_delay=%0d", $time, max_write_delay);

      r_filter_port = $urandom;

      for (int i = 0; i < num_packets; i++) begin
        int r = $urandom_range(99);
        int packet_len;
        bit accepted;

        if (r < 25) begin
          packet_len = $urandom_range(45, 1);
        end else begin
          packet_len = $urandom_range(1500, 1);
        end

        accepted = randomize_tx_data(r_filter_port, tx_data);

        tx_data.post_packet_delay = $urandom_range(max_write_delay);

        $display("%0t: writing data: %p", $time, tx_data.data);
        tx_intf.write(tx_data.data, tx_data.error);
        repeat(3) @(posedge Clk);
        accepted &= tx_intf.accepted;

        if (accepted) begin
          e = get_expected_data(tx_data);
          $display("%0t: expecting: %p", $time, e);
          expected_data.push_back(e);
        end
      end

      begin
        int wait_cycles = 0;
        while (1) begin
          if (((expected_data.size() == 0)) || (wait_cycles > 1e6)) begin
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
