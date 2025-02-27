`timescale 1ns/1ps

import eth_pkg::*;
import udp_intf_pkg::*;

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
  logic       error;
  logic [7:0] data;

  task read(output logic [7:0] d [$]);
    automatic bit started = 0;
    automatic bit done = 0;
    automatic bit e = 0;
    d.delete();

    do begin
      if (error) begin
        e = 1;
      end
      if (valid) begin
        d.push_back(data);
        started = 1;
      end else if (started) begin
        done = 1;
      end
      @(posedge Clk);
    end while(!done);

    assert (!e) else $error("error during gmii rx read");
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

module udp_intf_tb;
  parameter time AXI_CLK_HALF_PERIOD  = 5ns;
  parameter time GMII_CLK_HALF_PERIOD = 7ns;
  parameter AXI_DATA_WIDTH            = 32;
  parameter OUTPUT_FIFO_DEPTH         = 64;

  typedef struct
  {
    logic [AXI_DATA_WIDTH - 1 : 0] data [$];
    int byte_length;
  } axi_expect_t;

  typedef struct
  {
    logic [AXI_DATA_WIDTH - 1 : 0] data [$];
    int post_packet_delay;
  } axi_tx_data_t;

  typedef struct {
    logic [7:0] data [$];
  } gmii_expect_t;

  typedef struct {
    logic [7:0] data [$];
    logic error [$];
    int post_packet_delay;
  } gmii_tx_data_t;

  logic Clk_axi;
  logic Rst_axi;
  logic Clk_gmii;
  logic Rst_gmii;

  gmii_tx_intf                                    from_hw_gmii_tx_intf  (.Clk(Clk_gmii));
  gmii_tx_intf                                    from_ps_gmii_tx_intf  (.Clk(Clk_gmii));

  gmii_rx_intf                                    to_hw_gmii_rx_intf    (.Clk(Clk_gmii));
  gmii_rx_intf                                    to_ps_gmii_rx_intf    (.Clk(Clk_gmii));

  axi_tx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  tx_axi_intf           (.Clk(Clk_axi));
  axi_rx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  rx_axi_intf           (.Clk(Clk_axi));

  axi_tx_data_t axi_tx_queue[$];
  axi_expect_t  axi_expected_data[$];

  gmii_tx_data_t from_ps_tx_queue[$];
  gmii_expect_t to_hw_expected_data[$];

  gmii_tx_data_t from_hw_tx_queue[$];
  gmii_expect_t to_ps_expected_data[$];

  int   num_received_axi = 0;
  int   num_received_gmii_ps = 0;
  int   num_received_gmii_hw = 0;

  logic r_axi_rx_ready;

  logic w_axi_rx_valid;
  logic w_axi_rx_ready;
  logic w_axi_rx_last;
  logic [AXI_DATA_WIDTH - 1 : 0] w_axi_rx_data;

  initial begin
    Clk_axi = 0;
    forever begin
      #(AXI_CLK_HALF_PERIOD);
      Clk_axi = ~Clk_axi;
    end
  end

  initial begin
    Clk_gmii = 0;
    forever begin
      #(GMII_CLK_HALF_PERIOD);
      Clk_gmii = ~Clk_gmii;
    end
  end

  initial begin
    Rst_axi = 1;
    repeat(10) @(posedge Clk_axi);
    Rst_axi = 0;
  end

  initial begin
    Rst_gmii = 1;
    repeat(10) @(posedge Clk_gmii);
    Rst_gmii = 0;
  end

  always_ff @(posedge Clk_axi) begin
    r_axi_rx_ready <= $urandom_range(99) < 80;
  end

  udp_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH), .OUTPUT_FIFO_DEPTH(OUTPUT_FIFO_DEPTH)) dut
  (
    .Sys_clk        (Clk_axi),
    .Sys_rst        (Rst_axi),

    .Ps_gmii_rx_clk (),
    .Ps_gmii_tx_clk (),
    .Ps_gmii_col    (),
    .Ps_gmii_crs    (),
    .Ps_gmii_rx_dv  (to_ps_gmii_rx_intf.valid),
    .Ps_gmii_rx_er  (to_ps_gmii_rx_intf.error),
    .Ps_gmii_rxd    (to_ps_gmii_rx_intf.data),
    .Ps_gmii_tx_en  (from_ps_gmii_tx_intf.valid),
    .Ps_gmii_tx_er  (from_ps_gmii_tx_intf.error),
    .Ps_gmii_txd    (from_ps_gmii_tx_intf.data),

    .Hw_gmii_rx_clk (Clk_gmii),
    .Hw_gmii_tx_clk (Clk_gmii),
    .Hw_gmii_col    (1'b0),
    .Hw_gmii_crs    (1'b0),
    .Hw_gmii_rx_dv  (from_hw_gmii_tx_intf.valid),
    .Hw_gmii_rx_er  (from_hw_gmii_tx_intf.error),
    .Hw_gmii_rxd    (from_hw_gmii_tx_intf.data),
    .Hw_gmii_tx_en  (to_hw_gmii_rx_intf.valid),
    .Hw_gmii_tx_er  (to_hw_gmii_rx_intf.error),
    .Hw_gmii_txd    (to_hw_gmii_rx_intf.data),

    .S_axis_clk     (Clk_axi),
    .S_axis_resetn  (!Rst_axi),
    .S_axis_valid   (tx_axi_intf.valid),
    .S_axis_data    (tx_axi_intf.data),
    .S_axis_last    (tx_axi_intf.last),
    .S_axis_ready   (tx_axi_intf.ready),

    .M_axis_clk     (Clk_axi),
    .M_axis_valid   (w_axi_rx_valid),
    .M_axis_data    (rx_axi_intf.data),
    .M_axis_last    (rx_axi_intf.last),
    .M_axis_ready   (r_axi_rx_ready)
/*
    //loopback
    .S_axis_clk     (Clk_axi),
    .S_axis_resetn  (!Rst_axi),
    .S_axis_valid   (w_axi_rx_valid),
    .S_axis_data    (w_axi_rx_data),
    .S_axis_last    (w_axi_rx_last),
    .S_axis_ready   (w_axi_rx_ready),

    .M_axis_clk     (Clk_axi),
    .M_axis_valid   (w_axi_rx_valid),
    .M_axis_data    (w_axi_rx_data),
    .M_axis_last    (w_axi_rx_last),
    .M_axis_ready   (w_axi_rx_ready)
*/
  );

  assign rx_axi_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

  task automatic wait_for_reset_axi();
    do begin
      @(posedge Clk_axi);
    end while (Rst_axi);
  endtask

  task automatic wait_for_reset_gmii();
    do begin
      @(posedge Clk_gmii);
    end while (Rst_gmii);
  endtask

  function automatic bit data_match_axi(logic [AXI_DATA_WIDTH - 1 : 0] a [$], logic [AXI_DATA_WIDTH - 1 : 0] b [], int b_byte_len);
    logic [7:0] bytes_a [$];
    logic [7:0] bytes_b [$];

    if (a.size() != b.size()) begin
      $display("%0t: size mismatch: a=%0d b=%0d", $time, a.size(), b.size());
      return 0;
    end

    assert ((b_byte_len + AXI_DATA_WIDTH/8 - 1) / (AXI_DATA_WIDTH/8) == b.size()) else $error("unexpected byte_len");

    for (int i = 0; i < b_byte_len; i++) begin
      int word_index = i / (AXI_DATA_WIDTH/8);
      int byte_index = i % (AXI_DATA_WIDTH/8);

      bytes_a.push_back(a[word_index][8*byte_index +: 8]);
      bytes_b.push_back(b[word_index][8*byte_index +: 8]);
    end

    for (int i = 0; i < b_byte_len; i++) begin
      if (bytes_a[i] !== bytes_b[i]) begin
        $display("%0t: data mismatch [%0d]: %X %X", $time, i, bytes_a[i], bytes_b[i]);
        return 0;
      end
    end

    return 1;
  endfunction

  function automatic bit data_match_gmii(logic [7:0] a [$], logic [7:0] b []);
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
/*
  initial begin
    automatic logic [AXI_DATA_WIDTH - 1 : 0] read_data [$];

    wait_for_reset_axi();
    @(posedge Clk_axi);

    forever begin
      rx_axi_intf.read(read_data);

      if (data_match_axi(read_data, axi_expected_data[0].data, axi_expected_data[0].byte_length)) begin
        $display("%0t: [AXI] data match - %p", $time, read_data);
      end else begin
        $error("%0t: [AXI] error -- data mismatch: expected = %p  actual = %p", $time, axi_expected_data[0].data, read_data);
      end
      void'(axi_expected_data.pop_front());

      num_received_axi++;
    end
  end

  initial begin
    automatic logic [7:0] read_data [$];

    wait_for_reset_gmii();
    @(posedge Clk_gmii);

    forever begin
      to_hw_gmii_rx_intf.read(read_data);

      if (data_match_gmii(read_data, to_hw_expected_data[0].data)) begin
        $display("%0t: [HW] data match - %p", $time, read_data);
      end else begin
        $error("%0t: [HW] error -- data mismatch: expected = %p  actual = %p", $time, to_hw_expected_data[0].data, read_data);
      end
      void'(to_hw_expected_data.pop_front());

      num_received_gmii_hw++;
    end
  end

  initial begin
    automatic logic [7:0] read_data [$];

    wait_for_reset_gmii();
    @(posedge Clk_gmii);

    forever begin
      to_ps_gmii_rx_intf.read(read_data);

      if (data_match_gmii(read_data, to_ps_expected_data[0].data)) begin
        $display("%0t: [PS] data match - %p", $time, read_data);
      end else begin
        $error("%0t: [PS] error -- data mismatch: expected = %p  actual = %p", $time, to_ps_expected_data[0].data, read_data);
      end
      void'(to_ps_expected_data.pop_front());

      num_received_gmii_ps++;
    end
  end*/

  final begin
    if ( axi_expected_data.size() != 0 ) begin
      $error("Unexpected data remaining in axi queue");
      while ( axi_expected_data.size() != 0 ) begin
        $display("%p", axi_expected_data[0].data);
        void'(axi_expected_data.pop_front());
      end
    end
  end

  final begin
    if ( to_hw_expected_data.size() != 0 ) begin
      $error("Unexpected data remaining in to_hw queue");
      while ( to_hw_expected_data.size() != 0 ) begin
        $display("%p", to_hw_expected_data[0].data);
        void'(to_hw_expected_data.pop_front());
      end
    end
  end

  final begin
    if ( to_ps_expected_data.size() != 0 ) begin
      $error("Unexpected data remaining in to_ps queue");
      while ( to_ps_expected_data.size() != 0 ) begin
        $display("%p", to_ps_expected_data[0].data);
        void'(to_ps_expected_data.pop_front());
      end
    end
  end

  initial begin
    while (1) begin
      @(posedge Clk_axi);
      if (axi_tx_queue.size() > 0) begin
        $display("%0t: writing: %p", $time, axi_tx_queue[0].data);
        tx_axi_intf.write(axi_tx_queue[0].data);
        repeat(axi_tx_queue[0].post_packet_delay) @(posedge Clk_axi);
        void'(axi_tx_queue.pop_front());
      end
    end
  end

  initial begin
    while (1) begin
      @(posedge Clk_gmii);
      if (from_hw_tx_queue.size() > 0) begin
        $display("%0t: writing: %p", $time, from_hw_tx_queue[0].data);
        from_hw_gmii_tx_intf.write(from_hw_tx_queue[0].data, from_hw_tx_queue[0].error);
        repeat(from_hw_tx_queue[0].post_packet_delay) @(posedge Clk_gmii);
        void'(from_hw_tx_queue.pop_front());
      end
    end
  end

  initial begin
    while (1) begin
      @(posedge Clk_gmii);
      if (from_ps_tx_queue.size() > 0) begin
        $display("%0t: writing: %p", $time, from_ps_tx_queue[0].data);
        from_ps_gmii_tx_intf.write(from_ps_tx_queue[0].data, from_ps_tx_queue[0].error);
        repeat(from_ps_tx_queue[0].post_packet_delay) @(posedge Clk_gmii);
        void'(from_ps_tx_queue.pop_front());
      end
    end
  end

  function automatic bit get_expected_data_axi_from_gmii(gmii_tx_data_t tx_data, output axi_expect_t e);
    logic [31:0] output_data;
    logic [7:0] udp_payload [$];
    logic [15:0] udp_dest_port;
    logic [15:0] udp_len;
    int packet_start = 0;

    while (tx_data.data[packet_start] != eth_sfd_byte) begin
      packet_start++;
    end
    packet_start++;

    udp_dest_port = {tx_data.data[packet_start + 36], tx_data.data[packet_start + 37]};
    udp_len = {tx_data.data[packet_start + 38], tx_data.data[packet_start + 39]};

    $display("packet_start=%0d dest_port=%0d len=%0d", packet_start, udp_dest_port, udp_len);

    if (udp_dest_port != udp_filter_port) begin
      return 0;
    end

    for (int i = 0; i < udp_len; i++) begin
      udp_payload.push_back(tx_data.data[packet_start + 42 + i]);
    end

    for (int i = 0; i < udp_payload.size(); i++) begin
      output_data = {output_data[23:0], udp_payload[i]};

      if (i % 4 == 3) begin
        e.data.push_back(output_data);
      end
    end

    if (udp_payload.size() % 4 != 0) begin
      e.data.push_back(output_data);
    end

    e.byte_length = udp_payload.size();

    return 1;
  endfunction

  function automatic gmii_tx_data_t randomize_udp_packet_header(logic [15:0] udp_len);
    gmii_tx_data_t d;
    int r;

    r = $urandom_range(7,0);
    for (int i = 0; i < r; i++) begin
      d.data.push_back(eth_preamble_byte);
    end
    d.data.push_back(eth_sfd_byte);

    for (int i = 0; i < 2*eth_mac_length; i++) begin
      d.data.push_back($urandom);
    end
    for (int i = 0; i < 2; i++) begin
      d.data.push_back(eth_type_ip[i*8 +: 8]);
    end

    d.data.push_back(eth_ip_ver_ihl);
    for (int i = 0; i < 8; i++) begin
      d.data.push_back($urandom);
    end
    d.data.push_back(eth_ip_proto_udp);
    for (int i = 0; i < (eth_ipv4_header_length - 10); i++) begin
      d.data.push_back($urandom);
    end

    for (int i = 0; i < 2; i++) begin
      d.data.push_back($urandom);
    end
    for (int i = 0; i < 2; i++) begin
      d.data.push_back(udp_filter_port[(1 - i)*8 +: 8]);
    end
    for (int i = 0; i < 2; i++) begin
      d.data.push_back(udp_len[(1 - i)*8 +: 8]);
    end
    for (int i = 0; i < 2; i++) begin
      d.data.push_back($urandom);
    end

    return d;
  endfunction

  function automatic gmii_tx_data_t generate_tx_header();
    gmii_tx_data_t r;

    for (int i = 0; i < eth_tx_header_byte_length; i++) begin
      r.data.push_back($urandom);
    end

    r.data[12] = eth_type_ip[7:0];
    r.data[13] = eth_type_ip[15:8];

    r.data[14] = eth_ip_ver_ihl;

    r.data[16] = 0; //len [0]
    r.data[17] = 0; //len [1]

    r.data[23] = eth_ip_proto_udp;

    r.data[24] = 0; //checksum [0]
    r.data[25] = 0; //checksum [1]

    //TODO: set partial checksum, verify in rx data

    return r;
  endfunction

  function automatic gmii_tx_data_t generate_setup_packet(gmii_tx_data_t header_data);
    string udp_setup_magic = "UDPSETUP";
    gmii_tx_data_t d = randomize_udp_packet_header(udp_setup_magic.len() + header_data.data.size());
    int r;

    for (int i = 0; i < udp_setup_magic.len(); i++) begin
      d.data.push_back(udp_setup_magic.getc(i));
    end

    for (int i = 0; i < header_data.data.size(); i++) begin
      d.data.push_back(header_data.data[i]);
    end

    r = $urandom_range(20, 4);
    for (int i = 0; i < r; i++) begin
      d.data.push_back($urandom);
    end

    return d;
  endfunction

  function automatic gmii_tx_data_t generate_udp_packet(gmii_tx_data_t header_data);
    int payload_len = 50;
    gmii_tx_data_t d = randomize_udp_packet_header(payload_len);
    int r;

    for (int i = 0; i < payload_len; i++) begin
      d.data.push_back($urandom);
    end

    r = 4; //$urandom_range(20, 4);
    for (int i = 0; i < r; i++) begin
      d.data.push_back($urandom);
    end

    return d;
  endfunction

  task automatic standard_test();
    parameter NUM_TESTS = 20;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int max_write_delay = $urandom_range(5);
      int num_packets = $urandom_range(200, 100);
      logic [31:0] udp_seq_num = 0;

      axi_tx_data_t   axi_tx_data;
      axi_expect_t    axi_e;
      gmii_tx_data_t  ps_tx_data;   //from_ps_tx_queue[$];
      gmii_expect_t   hw_e;         //to_hw_expected_data[$];
      gmii_tx_data_t  hw_tx_data;   //from_hw_tx_queue[$];
      gmii_expect_t   ps_e;         //to_ps_expected_data[$];

      gmii_tx_data_t  tx_header;
      gmii_tx_data_t  udp_packet;

      $display("%0t: Test started - max_write_delay=%0d", $time, max_write_delay);

      tx_header     = generate_tx_header();
      udp_packet  = generate_setup_packet(tx_header);
      from_hw_tx_queue.push_back(udp_packet);

      to_ps_expected_data.push_back('{data: udp_packet.data});

      if (get_expected_data_axi_from_gmii(udp_packet, axi_e)) begin
        axi_expected_data.push_back(axi_e);
      end

      repeat(1000) @(posedge Clk_axi);

      /*from_hw_tx_queue.push_back(setup_packet);
      to_ps_expected_data.push_back('{data: setup_packet.data});*/

      //random packets from PS to HW
      for (int i = 0; i < num_packets; i++) begin
        int packet_len = $urandom_range(200, 10);

        ps_tx_data.post_packet_delay = $urandom_range(max_write_delay);
        ps_tx_data.data.delete();

        for (int j = 0; j < packet_len; j++) begin
          ps_tx_data.data.push_back($urandom);
          ps_tx_data.error.push_back(0);
        end

        from_ps_tx_queue.push_back(ps_tx_data);

        hw_e.data = ps_tx_data.data;
        to_hw_expected_data.push_back(hw_e);
      end

      while (from_ps_tx_queue.size() > 0) begin
        @(posedge Clk_axi);
      end
      repeat(1000) @(posedge Clk_axi);

      //random packets from HW to PS
      for (int i = 0; i < num_packets; i++) begin
        int packet_len = $urandom_range(200, 10);

        hw_tx_data.post_packet_delay = $urandom_range(max_write_delay);
        hw_tx_data.data.delete();

        for (int j = 0; j < packet_len; j++) begin
          hw_tx_data.data.push_back($urandom);
          hw_tx_data.error.push_back(0);
        end

        from_hw_tx_queue.push_back(hw_tx_data);

        ps_e.data = hw_tx_data.data;
        to_ps_expected_data.push_back(ps_e);
      end

      while (from_hw_tx_queue.size() > 0) begin
        @(posedge Clk_axi);
      end
      repeat(1000) @(posedge Clk_axi);

      //random UDP packets from HW to PS
      for (int i = 0; i < num_packets; i++) begin
        int packet_len = $urandom_range(200, 10);

        udp_packet = generate_udp_packet(tx_header);
        hw_tx_data.post_packet_delay = $urandom_range(max_write_delay);
        from_hw_tx_queue.push_back(udp_packet);

        ps_e.data = udp_packet.data;
        to_ps_expected_data.push_back(ps_e);
      end

      while (from_hw_tx_queue.size() > 0) begin
        @(posedge Clk_axi);
      end
      repeat(1000) @(posedge Clk_axi);

      for (int i = 0; i < num_packets; i++) begin
        int r = $urandom_range(99);
        int packet_len;

        if (r < 25) begin
          packet_len = $urandom_range(10, 1);
        end else begin
          packet_len = $urandom_range(1000, 1);
        end

        axi_tx_data.post_packet_delay = $urandom_range(max_write_delay);
        axi_tx_data.data.delete();
        repeat(packet_len) axi_tx_data.data.push_back($urandom);
        axi_tx_queue.push_back(axi_tx_data);

        //$display("%0t: expecting: %p", $time, tx_data);

        //e = get_expected_data_axi(axi_tx_data);
        //axi_expected_data.push_back(e);
      end

      begin
        int wait_cycles = 0;
        while (1) begin
          if (((axi_tx_queue.size() == 0) && (axi_expected_data.size() == 0)) || (wait_cycles > 1e6)) begin
            break;
          end

          @(posedge Clk_axi);
          wait_cycles++;
        end
        assert (wait_cycles < 1e6) else $error("Timeout while waiting for expected queue to empty during test.");
      end

      $display("%0t: Test finished: num_received = %0d %0d %0d", $time, num_received_axi, num_received_gmii_hw, num_received_gmii_ps);
      Rst_axi = 1;
      repeat(10) @(posedge Clk_axi);
      Rst_axi = 0;
      repeat(10) @(posedge Clk_axi);
    end
  endtask

  initial
  begin
    wait_for_reset_axi();
    repeat(10) @(posedge Clk_axi);
    standard_test();
    $finish;
  end

endmodule
