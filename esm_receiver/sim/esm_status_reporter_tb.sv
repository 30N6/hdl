`timescale 1ns/1ps

import math::*;
import esm_pkg::*;

typedef struct {
  bit [1:0]                     enable_channelizer;
  bit [1:0]                     enable_pdw_encoder;
  esm_channelizer_warnings_t    channelizer_warnings [1:0];
  esm_channelizer_errors_t      channelizer_errors [1:0];
  esm_dwell_stats_errors_t      dwell_stats_errors [1:0];
  esm_pdw_encoder_errors_t      pdw_encoder_errors [1:0];
  esm_status_reporter_errors_t  status_reporter_errors;
  int                           pre_write_delay;
} esm_status_data_t;

typedef esm_status_data_t esm_status_data_array_t [];

interface esm_status_tx_intf (input logic Clk);
  bit [1:0]                   enable_channelizer;
  bit [1:0]                   enable_pdw_encoder;
  esm_channelizer_warnings_t  channelizer_warnings [1:0];
  esm_channelizer_errors_t    channelizer_errors [1:0];
  esm_dwell_stats_errors_t    dwell_stats_errors [1:0];
  esm_pdw_encoder_errors_t    pdw_encoder_errors [1:0];

  task clear();
    enable_channelizer    = 0;
    enable_pdw_encoder    = 0;
    channelizer_warnings  = {default:0};
    channelizer_errors    = {default:0};
    dwell_stats_errors    = {default:0};
    pdw_encoder_errors    = {default:0};
  endtask

  task write(esm_status_data_t input_data);
    repeat(input_data.pre_write_delay) @(posedge Clk);
    enable_channelizer    = input_data.enable_channelizer;
    enable_pdw_encoder    = input_data.enable_pdw_encoder;
    channelizer_warnings  = input_data.channelizer_warnings;
    channelizer_errors    = input_data.channelizer_errors;
    dwell_stats_errors    = input_data.dwell_stats_errors;
    pdw_encoder_errors    = input_data.pdw_encoder_errors;
    @(posedge Clk);
    channelizer_warnings  = {default:0};
    channelizer_errors    = {default:0};
    dwell_stats_errors    = {default:0};
    pdw_encoder_errors    = {default:0};
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

module esm_status_reporter_tb;
  parameter time CLK_HALF_PERIOD      = 2ns;
  parameter time AXI_CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH            = 32;
  parameter logic [7:0] MODULE_ID     = 99;
  parameter HEARTBEAT_INTERVAL        = 1000;

  typedef struct
  {
    logic [AXI_DATA_WIDTH - 1 : 0] data [$];
  } expect_t;

  typedef struct packed
  {
    bit [31:0]  magic_num;
    bit [31:0]  sequence_num;
    bit [7:0]   module_id;
    bit [7:0]   message_type;
    bit [15:0]  padding_0;

    bit [31:0]  enables;
    bit [31:0]  status;
    bit [63:0]  timestamp;
  } esm_status_report_header_t;

  typedef struct packed
  {
    bit error_status_reporter_overflow;
    bit error_status_reporter_timeout;

    bit chan1_error_pdw_reporter_overflow;
    bit chan1_error_pdw_reporter_timeout;
    bit chan1_error_pdw_sample_buffer_overflow;
    bit chan1_error_pdw_sample_buffer_underflow;
    bit chan1_error_pdw_sample_buffer_busy;
    bit chan1_error_pdw_fifo_underflow;
    bit chan1_error_pdw_fifo_overflow;

    bit chan0_error_pdw_reporter_overflow;
    bit chan0_error_pdw_reporter_timeout;
    bit chan0_error_pdw_sample_buffer_overflow;
    bit chan0_error_pdw_sample_buffer_underflow;
    bit chan0_error_pdw_sample_buffer_busy;
    bit chan0_error_pdw_fifo_underflow;
    bit chan0_error_pdw_fifo_overflow;

    bit chan1_error_dwell_reporter_overflow;
    bit chan1_error_dwell_reporter_timeout;

    bit chan0_error_dwell_reporter_overflow;
    bit chan0_error_dwell_reporter_timeout;

    bit chan1_error_mux_collision;
    bit chan1_error_mux_underflow;
    bit chan1_error_mux_overflow;
    bit chan1_error_filter_overflow;
    bit chan1_error_demux_overflow;

    bit chan0_error_mux_collision;
    bit chan0_error_mux_underflow;
    bit chan0_error_mux_overflow;
    bit chan0_error_filter_overflow;
    bit chan0_error_demux_overflow;

    bit chan1_warning_demux_gap;
    bit chan0_warning_demux_gap;
  } esm_status_flags_packed_t;

  typedef bit [$bits(esm_status_report_header_t) - 1 : 0] esm_status_report_header_bits_t;
  typedef bit [$bits(esm_status_flags_packed_t) - 1 : 0] esm_status_flags_packed_bits_t;

  parameter MAX_WORDS_PER_PACKET = 64;
  parameter NUM_HEADER_WORDS = ($bits(esm_status_report_header_t) / AXI_DATA_WIDTH);

  logic Clk_axi;
  logic Clk;
  logic Rst;

  esm_status_tx_intf                              status_tx_intf (.*);
  axi_rx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  rpt_rx_intf    (.Clk(Clk_axi));

  int unsigned  report_seq_num = 0;
  expect_t      expected_data [$];
  int           num_received = 0;
  logic         r_axi_rx_ready;
  logic         w_axi_rx_valid;

  initial begin
    Clk_axi = 0;
    forever begin
      #(AXI_CLK_HALF_PERIOD);
      Clk_axi = ~Clk_axi;
    end
  end

  initial begin
    Clk = 0;
    forever begin
      #(CLK_HALF_PERIOD);
      Clk = ~Clk;
    end
  end

  initial begin
    Rst = 1;
    repeat(10) @(posedge Clk);
    Rst = 0;
  end

  always_ff @(posedge Clk_axi) begin
    r_axi_rx_ready <= $urandom_range(99) < 80;
  end

  esm_status_reporter
  #(
    .AXI_DATA_WIDTH     (AXI_DATA_WIDTH),
    .MODULE_ID          (MODULE_ID),
    .HEARTBEAT_INTERVAL (HEARTBEAT_INTERVAL)
  )
  dut
  (
    .Clk_axi              (Clk_axi),
    .Clk                  (Clk),
    .Rst                  (Rst),

    .Enable_status        (1'b1),
    .Enable_channelizer   (status_tx_intf.enable_channelizer),
    .Enable_pdw_encoder   (status_tx_intf.enable_pdw_encoder),

    .Channelizer_warnings (status_tx_intf.channelizer_warnings),
    .Channelizer_errors   (status_tx_intf.channelizer_errors),
    .Dwell_stats_errors   (status_tx_intf.dwell_stats_errors),
    .Pdw_encoder_errors   (status_tx_intf.pdw_encoder_errors),

    .Axis_ready           (r_axi_rx_ready),
    .Axis_valid           (w_axi_rx_valid),
    .Axis_data            (rpt_rx_intf.data),
    .Axis_last            (rpt_rx_intf.last)
  );

  assign rpt_rx_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
    repeat(100) @(posedge Clk);
  endtask

  function automatic esm_status_report_header_t unpack_report_header(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    esm_status_report_header_t      report_header;
    esm_status_report_header_bits_t packed_report_header;

    //$display("unpack_report: data=%p", data);

    for (int i = 0; i < $size(packed_report_header)/AXI_DATA_WIDTH; i++) begin
      //$display("unpack_report_header [%0d] = %X", i, data[0]);
      packed_report_header[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_front();
    end

    //$display("unpack_report: packed=%X", packed_report_header);

    report_header = esm_status_report_header_t'(packed_report_header);
    return report_header;
  endfunction


  function automatic bit data_match(logic [AXI_DATA_WIDTH - 1 : 0] a [$], logic [AXI_DATA_WIDTH - 1 : 0] b []);
    esm_status_report_header_t report_a = unpack_report_header(a);
    esm_status_report_header_t report_b = unpack_report_header(b);

    $display("data_match: a=%p", report_a);
    $display("data_match: b=%p", report_b);

    if (a.size() != b.size()) begin
      $display("%0t: size mismatch: a=%0d b=%0d", $time, a.size(), b.size());
      return 0;
    end

    //$display("a[0]=%X b[0]=%X  size: %0d %0d", a[0], b[0], a.size(), b.size());

    if (report_a.magic_num !== report_b.magic_num) begin
      $display("magic_num mismatch: %X %X", report_a.magic_num, report_b.magic_num);
      return 0;
    end

    if (report_a.sequence_num !== report_b.sequence_num) begin
      $display("sequence_num mismatch: %X %X", report_a.sequence_num, report_b.sequence_num);
      return 0;
    end

    if (report_a.module_id !== report_b.module_id) begin
      $display("module_id mismatch: %X %X", report_a.module_id, report_b.module_id);
      return 0;
    end

    if (report_a.message_type !== report_b.message_type) begin
      $display("message_type mismatch: %X %X", report_a.message_type, report_b.message_type);
      return 0;
    end

    if (report_a.enables !== report_b.enables) begin
      $display("enables mismatch: %X %X", report_a.enables, report_b.enables);
      return 0;
    end

    if (report_a.status !== report_b.status) begin
      $display("status mismatch: %X %X", report_a.status, report_b.status);
      return 0;
    end

    for (int i = NUM_HEADER_WORDS; i < MAX_WORDS_PER_PACKET; i++) begin
      if (a[i] !== b[i]) begin
        $display("trailer mismatch [%0d]: %X %X", i, a[i], b[i]);
        return 0;
      end
    end

    return 1;
  endfunction

  initial begin
    automatic logic [AXI_DATA_WIDTH - 1 : 0] read_data [$];

    wait_for_reset();

    forever begin
      rpt_rx_intf.read(read_data);

      if (data_match(read_data, expected_data[0].data)) begin
        $display("%0t: data match - %p", $time, read_data);
      end else begin
        $error("%0t: error -- data mismatch: expected = %p  actual = %p", $time, expected_data[0].data, read_data);
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

  function automatic void expect_report(esm_status_data_t input_data);
    int                               num_padding_words = 0;
    expect_t                          r;
    esm_status_report_header_t        report_header;
    esm_status_report_header_bits_t   report_header_packed;
    esm_status_flags_packed_t         status_flags;
    esm_status_flags_packed_bits_t    status_flags_packed;

    //$display("%0t: expect_report: input=%p", $time, input_data);

    status_flags.chan0_warning_demux_gap                  = input_data.channelizer_warnings[0].demux_gap;
    status_flags.chan1_warning_demux_gap                  = input_data.channelizer_warnings[1].demux_gap;

    status_flags.chan0_error_demux_overflow               = input_data.channelizer_errors[0].demux_overflow;
    status_flags.chan0_error_filter_overflow              = input_data.channelizer_errors[0].filter_overflow;
    status_flags.chan0_error_mux_overflow                 = input_data.channelizer_errors[0].mux_overflow;
    status_flags.chan0_error_mux_underflow                = input_data.channelizer_errors[0].mux_underflow;
    status_flags.chan0_error_mux_collision                = input_data.channelizer_errors[0].mux_collision;
    status_flags.chan1_error_demux_overflow               = input_data.channelizer_errors[1].demux_overflow;
    status_flags.chan1_error_filter_overflow              = input_data.channelizer_errors[1].filter_overflow;
    status_flags.chan1_error_mux_overflow                 = input_data.channelizer_errors[1].mux_overflow;
    status_flags.chan1_error_mux_underflow                = input_data.channelizer_errors[1].mux_underflow;
    status_flags.chan1_error_mux_collision                = input_data.channelizer_errors[1].mux_collision;

    status_flags.chan0_error_dwell_reporter_overflow      = input_data.dwell_stats_errors[0].reporter_overflow;
    status_flags.chan0_error_dwell_reporter_timeout       = input_data.dwell_stats_errors[0].reporter_timeout;
    status_flags.chan1_error_dwell_reporter_overflow      = input_data.dwell_stats_errors[1].reporter_overflow;
    status_flags.chan1_error_dwell_reporter_timeout       = input_data.dwell_stats_errors[1].reporter_timeout;

    status_flags.chan0_error_pdw_reporter_overflow        = input_data.pdw_encoder_errors[0].reporter_overflow;
    status_flags.chan0_error_pdw_reporter_timeout         = input_data.pdw_encoder_errors[0].reporter_timeout;
    status_flags.chan0_error_pdw_sample_buffer_overflow   = input_data.pdw_encoder_errors[0].sample_buffer_overflow;
    status_flags.chan0_error_pdw_sample_buffer_underflow  = input_data.pdw_encoder_errors[0].sample_buffer_underflow;
    status_flags.chan0_error_pdw_sample_buffer_busy       = input_data.pdw_encoder_errors[0].sample_buffer_busy;
    status_flags.chan0_error_pdw_fifo_underflow           = input_data.pdw_encoder_errors[0].pdw_fifo_underflow;
    status_flags.chan0_error_pdw_fifo_overflow            = input_data.pdw_encoder_errors[0].pdw_fifo_overflow;
    status_flags.chan1_error_pdw_reporter_overflow        = input_data.pdw_encoder_errors[1].reporter_overflow;
    status_flags.chan1_error_pdw_reporter_timeout         = input_data.pdw_encoder_errors[1].reporter_timeout;
    status_flags.chan1_error_pdw_sample_buffer_overflow   = input_data.pdw_encoder_errors[1].sample_buffer_overflow;
    status_flags.chan1_error_pdw_sample_buffer_underflow  = input_data.pdw_encoder_errors[1].sample_buffer_underflow;
    status_flags.chan1_error_pdw_sample_buffer_busy       = input_data.pdw_encoder_errors[1].sample_buffer_busy;
    status_flags.chan1_error_pdw_fifo_underflow           = input_data.pdw_encoder_errors[1].pdw_fifo_underflow;
    status_flags.chan1_error_pdw_fifo_overflow            = input_data.pdw_encoder_errors[1].pdw_fifo_overflow;

    status_flags.error_status_reporter_overflow           = input_data.status_reporter_errors.reporter_overflow;
    status_flags.error_status_reporter_timeout            = input_data.status_reporter_errors.reporter_timeout;

    status_flags_packed = esm_status_flags_packed_bits_t'(status_flags);

    report_header.magic_num     = esm_report_magic_num;
    report_header.sequence_num  = report_seq_num;
    report_header.module_id     = MODULE_ID;
    report_header.message_type  = esm_report_message_type_status;
    report_header.enables       = {27'h0, input_data.enable_pdw_encoder, input_data.enable_channelizer, 1'b1};
    report_header.status        = status_flags_packed;
    report_header.timestamp     = 0;

    report_header_packed = esm_status_report_header_bits_t'(report_header);
    //$display("report_packed: %X", report_header_packed);
    $display("report_header: %p", report_header);

    for (int i = 0; i < $size(report_header_packed)/AXI_DATA_WIDTH; i++) begin
      r.data.push_back(report_header_packed[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]);
    end

    num_padding_words = MAX_WORDS_PER_PACKET - r.data.size();
    for (int i_padding = 0; i_padding < num_padding_words; i_padding++) begin
      r.data.push_back(0);
    end

    /*for (int i = 0; i < r.data.size(); i++) begin
      $display("r.data[%02d]=%X", i, r.data[i]);
    end*/

    expected_data.push_back(r);

    /*$display("report_header: %p", report_header);
    $display("report_header_packed: %p", report_header_packed);
    $display("axi report: %p [0]", r.data, r.data[0]);*/

    report_seq_num++;
  endfunction


  function automatic esm_status_data_array_t randomize_status_input(int num_packets);
    esm_status_data_array_t r = new [num_packets];
    int packet_cycle [] = new [num_packets];

    for (int i = 0; i < num_packets; i++) begin
      packet_cycle[i] = (i + 1) * HEARTBEAT_INTERVAL - $urandom_range(0.9*HEARTBEAT_INTERVAL, 0.2*HEARTBEAT_INTERVAL);

      if (i == 0) begin
        r[i].pre_write_delay = packet_cycle[i];
      end else begin
        r[i].pre_write_delay = packet_cycle[i] - packet_cycle[i - 1];
      end

      for (int j = 0; j < 2; j++) begin
        r[i].enable_channelizer[j]                          = $urandom_range(1);
        r[i].enable_pdw_encoder[j]                          = $urandom_range(1);

        r[i].channelizer_warnings[j].demux_gap              = $urandom_range(1);

        r[i].channelizer_errors[j].demux_overflow           = $urandom_range(1);
        r[i].channelizer_errors[j].filter_overflow          = $urandom_range(1);
        r[i].channelizer_errors[j].mux_overflow             = $urandom_range(1);
        r[i].channelizer_errors[j].mux_underflow            = $urandom_range(1);
        r[i].channelizer_errors[j].mux_collision            = $urandom_range(1);

        r[i].dwell_stats_errors[j].reporter_overflow        = $urandom_range(1);
        r[i].dwell_stats_errors[j].reporter_timeout         = $urandom_range(1);

        r[i].pdw_encoder_errors[j].reporter_overflow        = $urandom_range(1);
        r[i].pdw_encoder_errors[j].reporter_timeout         = $urandom_range(1);
        r[i].pdw_encoder_errors[j].sample_buffer_busy       = $urandom_range(1);
        r[i].pdw_encoder_errors[j].sample_buffer_overflow   = $urandom_range(1);
        r[i].pdw_encoder_errors[j].sample_buffer_underflow  = $urandom_range(1);
        r[i].pdw_encoder_errors[j].pdw_fifo_underflow       = $urandom_range(1);
        r[i].pdw_encoder_errors[j].pdw_fifo_overflow        = $urandom_range(1);
      end

      r[i].status_reporter_errors.reporter_overflow = 0;
      r[i].status_reporter_errors.reporter_timeout  = 0;
    end

    return r;
  endfunction

  task automatic standard_test();
    parameter NUM_TESTS = 20;
    parameter HEARTBEATS_PER_TEST = 20;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      esm_status_data_array_t status_input = randomize_status_input(HEARTBEATS_PER_TEST);
      $display("%0t: Test[%0d] started", $time, i_test);
      report_seq_num = 0;

      for (int i_hb = 0; i_hb < HEARTBEATS_PER_TEST; i_hb++) begin
        expect_report(status_input[i_hb]);
        status_tx_intf.write(status_input[i_hb]);
      end

      repeat(100) @(posedge Clk);
      begin
        int wait_cycles = 0;
        while ((expected_data.size() != 0) && (wait_cycles < 1e5)) begin
          @(posedge Clk);
          wait_cycles++;
        end
        assert (wait_cycles < 1e5) else $error("Timeout while waiting for expected queue to empty during test.");
      end

      $display("%0t: Test finished: num_received = %0d", $time, num_received);
      Rst = 1;
      repeat(100) @(posedge Clk);
      Rst = 0;
      repeat(100) @(posedge Clk);
    end
  endtask

  initial
  begin
    status_tx_intf.clear();
    wait_for_reset();
    standard_test();
    repeat(100) @(posedge Clk);
    $finish;
  end

endmodule
