`timescale 1ns/1ps

import eth_pkg::*;

interface header_tx_intf (input logic Clk);
  logic                                         wr_en = 0;
  logic [31:0]                                  wr_data;
  logic [eth_ip_udp_header_addr_width - 1 : 0]  wr_addr;

  task write(input logic [31:0] d []);
    for (int i = 0; i < d.size(); i++) begin
      wr_en     <= 1;
      wr_data   <= d[i];
      wr_addr   <= i;
      @(posedge Clk);
    end

    wr_en     <= 0;
    wr_data   <= 'x;
    wr_addr   <= 'x;

  endtask
endinterface

interface udp_tx_intf (input logic Clk);
  logic                                 valid = 0;
  logic                                 last;
  logic [7:0]                           data;
  logic [eth_udp_length_width - 1 : 0]  length;
  logic                                 ready;

  task write(input logic [7:0] d []);
    automatic bit length_sent = 0;

    for (int i = 0; i < d.size(); i++) begin
      if ($urandom_range(99) < 10) begin
        @(posedge Clk);
      end
      valid <= 1;
      data  <= d[i];
      last  <= (i == (d.size() - 1));
      if (!length_sent) begin
        length <= d.size();
        length_sent = 1;
      end else begin
        length <= 'x;
      end

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

module udp_tx_tb;
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
    logic [31:0] data [];
  } header_data_t;

  logic Clk;
  logic Rst;

  header_tx_intf                                  header_intf (.*);
  udp_tx_intf                                     tx_intf (.*);
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

  udp_tx dut
  (
    .Clk                (Clk),
    .Rst                (Rst),

    .Header_wr_en       (header_intf.wr_en),
    .Header_wr_addr     (header_intf.wr_addr),
    .Header_wr_data     (header_intf.wr_data),

    .Udp_length         (tx_intf.length),
    .Udp_data           (tx_intf.data),
    .Udp_valid          (tx_intf.valid),
    .Udp_last           (tx_intf.last),
    .Udp_ready          (tx_intf.ready),

    .Mac_payload_data   (rx_intf.data),
    .Mac_payload_valid  (w_axi_rx_valid),
    .Mac_payload_last   (rx_intf.last),
    .Mac_payload_ready  (r_axi_rx_ready)
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

  function automatic logic [15:0] get_ip_checksum(logic [31:0] header []);
    logic [31:0] ip_checksum;

    ip_checksum = 0;
    for (int i = 0; i < 5; i++) begin
      for (int j = 0; j < 2; j++) begin
        logic [15:0] raw_word = header[i][16*j +: 16];
        logic [15:0] swapped_word = {raw_word[7:0], raw_word[15:8]};
        ip_checksum += swapped_word;
      end
    end

    while (ip_checksum > 16'hFFFF) begin
      logic [31:0] new_checksum = ip_checksum[15:0] + ip_checksum[31:16];
      ip_checksum = new_checksum;
    end

    return ip_checksum[15:0];
  endfunction

  function automatic expect_t get_expected_data(header_data_t header_data, tx_data_t tx_data);
    expect_t e;
    logic [31:0] header_copy [] = new[header_data.data.size()];
    logic [15:0] ip_total_length;
    logic [15:0] udp_length;
    logic [15:0] ip_checksum;

    for (int i = 0; i < header_copy.size(); i++) begin
      header_copy[i] = header_data.data[i];
    end

    ip_total_length = eth_ipv4_header_length + eth_udp_header_length + tx_data.data.size();
    udp_length = eth_udp_header_length + tx_data.data.size();

    header_copy[0][31:16] = {ip_total_length[7:0], ip_total_length[15:8]};
    header_copy[6][15:0] = {udp_length[7:0], udp_length[15:8]};

    header_copy[2][31:16] = 0;
    ip_checksum = ~get_ip_checksum(header_copy);
    header_copy[2][31:16] = {ip_checksum[7:0], ip_checksum[15:8]};

    for (int i = 0; i < header_copy.size(); i++) begin
      for (int j = 0; j < 4; j++) begin
        e.data.push_back(header_copy[i][j*8 +: 8]);
      end
    end

    for (int i = 0; i < tx_data.data.size(); i++) begin
      e.data.push_back(tx_data.data[i]);
    end

    $display("%0t: get_expected_data: ip_total_length=%0d udp_len=%0d ip_checksum=%04X", $time, ip_total_length, udp_length, ip_checksum);

    return e;
  endfunction


  function automatic header_data_t randomize_header();
    header_data_t r;
    logic [15:0] ip_partial_checksum;

    r.data = new[7];

    r.data[0][7:0]    = 8'h45;    // ver, IHL
    r.data[0][15:8]   = 0;        // DSCP, ECN
    r.data[0][31:16]  = 0;        // total length

    r.data[1][15:0]   = $urandom; // ID
    r.data[1][31:29]  = 3'h2;     // flags - don't fragment
    r.data[1][28:16]  = $urandom; // fragment offset

    r.data[2][7:0]    = 64;       // TTL
    r.data[2][15:8]   = 17;       // protocol = Udp_data
    r.data[2][31:16]  = 0;        // header checksum

    r.data[3]         = $urandom; // source address
    r.data[4]         = $urandom; // dest address

    r.data[5][15:0]   = $urandom; // source port
    r.data[5][31:16]  = $urandom; // dest port

    r.data[6][15:0]   = 0;        // UDP length
    r.data[6][31:16]  = 0;        // UDP checksum

    ip_partial_checksum = get_ip_checksum(r.data);
    r.data[2][31:16] = {ip_partial_checksum[7:0], ip_partial_checksum[15:8]};

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
          packet_len = $urandom_range(1400, 1);
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
