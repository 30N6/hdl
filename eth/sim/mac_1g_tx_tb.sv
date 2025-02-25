`timescale 1ns/1ps

import eth_pkg::*;

interface header_tx_intf (input logic Clk);
  logic                                     wr_en = 0;
  logic [31:0]                              wr_data;
  logic [eth_tx_header_addr_width - 1 : 0]  wr_addr;

  task write(input logic [7:0] d [$]);
    automatic logic [31:0] w [] = new[(d.size() + 3)/4];

    for (int i = 0; i < d.size(); i++) begin
      automatic int i_word = i / 4;
      automatic int i_byte = i % 4;
      w[i_word][i_byte * 8 +: 8] = d[i];
    end

    for (int i = 0; i < w.size(); i++) begin
      wr_en     <= 1;
      wr_data   <= w[i];
      wr_addr   <= i;
      @(posedge Clk);
    end

    wr_en     <= 0;
    wr_data   <= 'x;
    wr_addr   <= 'x;
  endtask
endinterface

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

module mac_1g_tx_tb;
  parameter time CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH        = 8;

  typedef struct
  {
    logic [AXI_DATA_WIDTH - 1 : 0] data [$];
  } expect_t;

  typedef struct
  {
    logic [AXI_DATA_WIDTH - 1 : 0] data [$];
    int post_packet_delay;
  } tx_data_t;

  typedef struct {
    logic [7:0] data [$];
  } header_data_t;

  logic Clk;
  logic Rst;

  header_tx_intf                                  header_intf (.*);
  axi_tx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  tx_intf (.*);
  axi_rx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  rx_intf (.*);

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

  mac_1g_tx dut
  (
    .Clk            (Clk),
    .Rst            (Rst),

    .Header_wr_en   (header_intf.wr_en),
    .Header_wr_addr (header_intf.wr_addr),
    .Header_wr_data (header_intf.wr_data),

    .Payload_ready  (tx_intf.ready),
    .Payload_valid  (tx_intf.valid),
    .Payload_data   (tx_intf.data),
    .Payload_last   (tx_intf.last),

    .Mac_data       (rx_intf.data),
    .Mac_valid      (w_axi_rx_valid),
    .Mac_last       (rx_intf.last),
    .Mac_ready      (r_axi_rx_ready)
  );

  assign rx_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

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


  function automatic logic [31:0] get_fcs(logic [7:0] data [$]);
    logic [31:0] crc = '1;

    for (int i = 0; i < data.size(); i++) begin
      crc[7:0] ^= data[i];

      for (int k = 0; k < 8; k++) begin
        crc = (crc & 1) ? ((crc >> 1) ^ 32'hEDB88320) : (crc >> 1);
      end
    end

    return crc ^ 32'hFFFFFFFF;
  endfunction

  function automatic expect_t get_expected_data(header_data_t header_data, tx_data_t tx_data);
    expect_t e;
    int padding_bytes = (eth_min_frame_size - eth_fcs_length) - (2*eth_mac_length + eth_type_length + tx_data.data.size());
    logic [31:0] fcs = '1;
    logic [7:0] fcs_data [$];

    for (int i = 0; i < eth_preamble_length; i++) begin
      e.data.push_back(eth_preamble_byte);
    end
    e.data.push_back(eth_sfd_byte);

    for (int i = 0; i < eth_mac_length; i++) begin
      e.data.push_back(header_data.data[i]);
      fcs_data.push_back(header_data.data[i]);
    end

    for (int i = 0; i < eth_mac_length; i++) begin
      e.data.push_back(header_data.data[i+eth_mac_length]);
      fcs_data.push_back(header_data.data[i+eth_mac_length]);
    end

    for (int i = 0; i < eth_type_length; i++) begin
      e.data.push_back(header_data.data[i+2*eth_mac_length]);
      fcs_data.push_back(header_data.data[i+2*eth_mac_length]);
    end

    for (int i = 0; i < tx_data.data.size(); i++) begin
      e.data.push_back(tx_data.data[i]);
      fcs_data.push_back(tx_data.data[i]);
    end

    for (int i = 0; i < padding_bytes; i++) begin
      e.data.push_back(0);
      fcs_data.push_back(0);
    end

    fcs = get_fcs(fcs_data);
    $display("%0t: get_fcs: %08X", $time, fcs);

    for (int i = 0; i < eth_fcs_length; i++) begin
      e.data.push_back(fcs[i*8+:8]);
    end

    return e;
  endfunction

  function automatic header_data_t randomize_header();
    header_data_t r;
    logic [15:0] ip_partial_checksum;

    for (int i = 0; i < eth_mac_header_length; i++) begin
      r.data.push_back($urandom);
    end

    r.data.push_back(8'h45);      // ver, IHL

    r.data.push_back(0);          // DSCP, ECN
    r.data.push_back(0);          // total length [0]
    r.data.push_back(0);          // total length [1]

    r.data.push_back($urandom);   // ID [0]
    r.data.push_back($urandom);   // ID [1]

    r.data.push_back(8'h40);      // flags - don't fragment
    r.data.push_back($urandom);   // fragment offset

    r.data.push_back(64);         //TTL
    r.data.push_back(17);         // protocol = Udp_data
    r.data.push_back($urandom);   // header checksum [0]
    r.data.push_back($urandom);   // header checksum [1]

    // source, dest addr
    for (int i = 0; i < 8; i++) begin
      r.data.push_back($urandom);
    end

    // source, dest port
    for (int i = 0; i < 4; i++) begin
      r.data.push_back($urandom);
    end

    r.data.push_back($urandom);   // UDP length [0]
    r.data.push_back($urandom);   // UDP length [1]
    r.data.push_back($urandom);   // UDP checksum [0]
    r.data.push_back($urandom);   // UDP checksum [1]

    assert (r.data.size() == eth_tx_header_byte_length) else $error("invalid size: %0d, expected %0d", r.data.size(), eth_tx_header_byte_length);

    return r;
  endfunction

  task automatic standard_test();
    parameter NUM_TESTS = 200;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int max_write_delay = $urandom_range(5);
      int num_packets = $urandom_range(200, 100);
      header_data_t header_data;
      tx_data_t tx_data;
      expect_t e;

      $display("%0t: Test started - max_write_delay=%0d", $time, max_write_delay);
      header_data = randomize_header();
      header_intf.write(header_data.data);

      for (int i = 0; i < num_packets; i++) begin
        int r = $urandom_range(99);
        int packet_len;

        if (r < 25) begin
          packet_len = $urandom_range(45, 1);
        end else begin
          packet_len = $urandom_range(1500, 1);
        end

        tx_data.post_packet_delay = $urandom_range(max_write_delay);
        tx_data.data.delete();
        repeat(packet_len) tx_data.data.push_back($urandom);
        tx_queue.push_back(tx_data);
        $display("%0t: expecting: %p", $time, tx_data);

        e = get_expected_data(header_data, tx_data);
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
