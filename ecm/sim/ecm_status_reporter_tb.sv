`timescale 1ns/1ps

import math::*;
import ecm_pkg::*;

typedef struct {
  bit                           enable_channelizer;
  bit                           enable_synthesizer;
  ecm_channelizer_warnings_t    channelizer_warnings;
  ecm_channelizer_errors_t      channelizer_errors;
  ecm_synthesizer_errors_t      synthesizer_errors;
  ecm_dwell_stats_errors_t      dwell_stats_errors;
  ecm_drfm_errors_t             drfm_errors;
  ecm_output_block_errors_t     output_block_errors;
  ecm_dwell_controller_errors_t dwell_controller_errors;
  ecm_status_reporter_errors_t  status_reporter_errors;
  int                           pre_write_delay;
} ecm_status_data_t;

typedef ecm_status_data_t ecm_status_data_array_t [];

interface ecm_status_tx_intf (input logic Clk);
  bit                           enable_channelizer;
  bit                           enable_synthesizer;
  ecm_channelizer_warnings_t    channelizer_warnings;
  ecm_channelizer_errors_t      channelizer_errors;
  ecm_synthesizer_errors_t      synthesizer_errors;
  ecm_dwell_stats_errors_t      dwell_stats_errors;
  ecm_drfm_errors_t             drfm_errors;
  ecm_output_block_errors_t     output_block_errors;
  ecm_dwell_controller_errors_t dwell_controller_errors;

  task clear();
    enable_channelizer      = 0;
    enable_synthesizer      = 0;
    channelizer_warnings    = '{default:0};
    channelizer_errors      = '{default:0};
    synthesizer_errors      = '{default:0};
    dwell_stats_errors      = '{default:0};
    drfm_errors             = '{default:0};
    output_block_errors     = '{default:0};
    dwell_controller_errors = '{default:0};
  endtask

  task write(ecm_status_data_t input_data);
    repeat(input_data.pre_write_delay) @(posedge Clk);
    enable_channelizer      = input_data.enable_channelizer;
    enable_synthesizer      = input_data.enable_synthesizer;
    channelizer_warnings    = input_data.channelizer_warnings;
    channelizer_errors      = input_data.channelizer_errors;
    synthesizer_errors      = input_data.synthesizer_errors;
    dwell_stats_errors      = input_data.dwell_stats_errors;
    drfm_errors             = input_data.drfm_errors;
    output_block_errors     = input_data.output_block_errors;
    dwell_controller_errors = input_data.dwell_controller_errors;
    @(posedge Clk);
    channelizer_warnings    = '{default:0};
    channelizer_errors      = '{default:0};
    synthesizer_errors      = '{default:0};
    dwell_stats_errors      = '{default:0};
    drfm_errors             = '{default:0};
    output_block_errors     = '{default:0};
    dwell_controller_errors = '{default:0};
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

module ecm_status_reporter_tb;
  parameter time CLK_HALF_PERIOD      = 2ns;
  parameter time AXI_CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH            = 32;
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
    bit [31:0]  status_main;
    bit [31:0]  status_reporter;
    bit [63:0]  timestamp;
  } ecm_status_report_header_t;

  typedef struct packed
  {
    bit error_status_reporter_overflow;
    bit error_status_reporter_timeout;
  } ecm_status_reporter_errors_packed_t;

  typedef struct packed
  {
    bit error_dwell_controller_fifo_underflow;
    bit error_dwell_controller_fifo_overflow;

    bit error_output_block_drfm_sync_mismatch;

    bit error_drfm_reporter_overflow;
    bit error_drfm_reporter_timeout;
    bit error_drfm_invalid_read;
    bit error_drfm_int_read_overflow;
    bit error_drfm_ext_read_overflow;

    bit error_dwell_stats_overflow;
    bit error_dwell_stats_timeout;

    bit error_synth_mux_fifo_underflow;
    bit error_synth_mux_fifo_overflow;
    bit error_synth_mux_input_overflow;
    bit error_synth_filter_overflow;
    bit error_synth_stretcher_underflow;
    bit error_synth_stretcher_overflow;

    bit error_chan_stretcher_underflow;
    bit error_chan_stretcher_overflow;
    bit error_chan_mux_collision;
    bit error_chan_mux_underflow;
    bit error_chan_mux_overflow;
    bit error_chan_filter_overflow;
    bit error_chan_demux_overflow;

    bit warning_demux_gap;
  } ecm_status_flags_packed_t;

  typedef bit [$bits(ecm_status_report_header_t) - 1 : 0]           ecm_status_report_header_bits_t;
  typedef bit [$bits(ecm_status_flags_packed_t) - 1 : 0]            ecm_status_flags_packed_bits_t;
  typedef bit [$bits(ecm_status_reporter_errors_packed_t) - 1 : 0]  ecm_status_reporter_errors_packed_bits_t;

  parameter NUM_HEADER_WORDS = ($bits(ecm_status_report_header_t) / AXI_DATA_WIDTH);

  logic Clk_axi;
  logic Clk;
  logic Rst;

  ecm_status_tx_intf                              status_tx_intf (.*);
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

  ecm_status_reporter
  #(
    .AXI_DATA_WIDTH     (AXI_DATA_WIDTH),
    .HEARTBEAT_INTERVAL (HEARTBEAT_INTERVAL)
  )
  dut
  (
    .Clk_axi                  (Clk_axi),
    .Clk                      (Clk),
    .Rst                      (Rst),

    .Enable_status            (1'b1),
    .Enable_channelizer       (status_tx_intf.enable_channelizer),
    .Enable_synthesizer       (status_tx_intf.enable_synthesizer),

    .Channelizer_warnings     (status_tx_intf.channelizer_warnings),
    .Channelizer_errors       (status_tx_intf.channelizer_errors),
    .Synthesizer_errors       (status_tx_intf.synthesizer_errors),
    .Dwell_stats_errors       (status_tx_intf.dwell_stats_errors),
    .Drfm_errors              (status_tx_intf.drfm_errors),
    .Output_block_errors      (status_tx_intf.output_block_errors),
    .Dwell_controller_errors  (status_tx_intf.dwell_controller_errors),

    .Axis_ready               (r_axi_rx_ready),
    .Axis_valid               (w_axi_rx_valid),
    .Axis_data                (rpt_rx_intf.data),
    .Axis_last                (rpt_rx_intf.last)
  );

  assign rpt_rx_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
    repeat(100) @(posedge Clk);
  endtask

  function automatic ecm_status_report_header_t unpack_report_header(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    ecm_status_report_header_t      report_header;
    ecm_status_report_header_bits_t packed_report_header;

    //$display("unpack_report: data=%p", data);

    for (int i = 0; i < $size(packed_report_header)/AXI_DATA_WIDTH; i++) begin
      //$display("unpack_report_header [%0d] = %X", i, data[0]);
      packed_report_header[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_front();
    end

    //$display("unpack_report: packed=%X", packed_report_header);

    report_header = ecm_status_report_header_t'(packed_report_header);
    return report_header;
  endfunction


  function automatic bit data_match(logic [AXI_DATA_WIDTH - 1 : 0] a [$], logic [AXI_DATA_WIDTH - 1 : 0] b []);
    ecm_status_report_header_t report_a = unpack_report_header(a);
    ecm_status_report_header_t report_b = unpack_report_header(b);

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

    if (report_a.status_main !== report_b.status_main) begin
      $display("status_main mismatch: %X %X", report_a.status_main, report_b.status_main);
      return 0;
    end
    if (report_a.status_reporter !== report_b.status_reporter) begin
      $display("status_reporter mismatch: %X %X", report_a.status_reporter, report_b.status_reporter);
      return 0;
    end

    for (int i = NUM_HEADER_WORDS; i < ecm_words_per_dma_packet; i++) begin
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

  function automatic void expect_report(ecm_status_data_t input_data);
    int                                       num_padding_words = 0;
    expect_t                                  r;
    ecm_status_report_header_t                report_header;
    ecm_status_report_header_bits_t           report_header_packed;
    ecm_status_reporter_errors_packed_t       reporter_errors;
    ecm_status_reporter_errors_packed_bits_t  reporter_errors_packed;
    ecm_status_flags_packed_t                 status_flags;
    ecm_status_flags_packed_bits_t            status_flags_packed;

    //$display("%0t: expect_report: input=%p", $time, input_data);
    reporter_errors.error_status_reporter_overflow      = input_data.status_reporter_errors.reporter_overflow;
    reporter_errors.error_status_reporter_timeout       = input_data.status_reporter_errors.reporter_timeout;

    status_flags.warning_demux_gap                      = input_data.channelizer_warnings.demux_gap;

    status_flags.error_chan_demux_overflow              = input_data.channelizer_errors.demux_overflow;
    status_flags.error_chan_filter_overflow             = input_data.channelizer_errors.filter_overflow;
    status_flags.error_chan_mux_overflow                = input_data.channelizer_errors.mux_overflow;
    status_flags.error_chan_mux_underflow               = input_data.channelizer_errors.mux_underflow;
    status_flags.error_chan_mux_collision               = input_data.channelizer_errors.mux_collision;
    status_flags.error_chan_stretcher_overflow          = input_data.channelizer_errors.stretcher_overflow;
    status_flags.error_chan_stretcher_underflow         = input_data.channelizer_errors.stretcher_underflow;

    status_flags.error_synth_stretcher_overflow         = input_data.synthesizer_errors.stretcher_overflow;
    status_flags.error_synth_stretcher_underflow        = input_data.synthesizer_errors.stretcher_underflow;
    status_flags.error_synth_filter_overflow            = input_data.synthesizer_errors.filter_overflow;
    status_flags.error_synth_mux_input_overflow         = input_data.synthesizer_errors.mux_input_overflow;
    status_flags.error_synth_mux_fifo_overflow          = input_data.synthesizer_errors.mux_fifo_overflow;
    status_flags.error_synth_mux_fifo_underflow         = input_data.synthesizer_errors.mux_fifo_underflow;

    status_flags.error_dwell_stats_timeout              = input_data.dwell_stats_errors.reporter_timeout;
    status_flags.error_dwell_stats_overflow             = input_data.dwell_stats_errors.reporter_overflow;

    status_flags.error_drfm_ext_read_overflow           = input_data.drfm_errors.ext_read_overflow;
    status_flags.error_drfm_int_read_overflow           = input_data.drfm_errors.int_read_overflow;
    status_flags.error_drfm_invalid_read                = input_data.drfm_errors.invalid_read;
    status_flags.error_drfm_reporter_timeout            = input_data.drfm_errors.reporter_timeout;
    status_flags.error_drfm_reporter_overflow           = input_data.drfm_errors.reporter_overflow;

    status_flags.error_output_block_drfm_sync_mismatch  = input_data.output_block_errors.dds_drfm_sync_mismatch;

    status_flags.error_dwell_controller_fifo_overflow   = input_data.dwell_controller_errors.program_fifo_overflow;
    status_flags.error_dwell_controller_fifo_underflow  = input_data.dwell_controller_errors.program_fifo_underflow;

    status_flags_packed = ecm_status_flags_packed_bits_t'(status_flags);

    report_header.magic_num         = ecm_report_magic_num;
    report_header.sequence_num      = report_seq_num;
    report_header.module_id         = ecm_module_id_status;
    report_header.message_type      = ecm_report_message_type_status;
    report_header.enables           = {27'h0, input_data.enable_synthesizer, input_data.enable_channelizer, 1'b1};
    report_header.status_main       = status_flags_packed;
    report_header.status_reporter   = reporter_errors;
    report_header.timestamp         = 0;

    report_header_packed = ecm_status_report_header_bits_t'(report_header);
    //$display("report_packed: %X", report_header_packed);
    $display("report_header: %p", report_header);

    for (int i = 0; i < $size(report_header_packed)/AXI_DATA_WIDTH; i++) begin
      r.data.push_back(report_header_packed[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]);
    end

    num_padding_words = ecm_words_per_dma_packet - r.data.size();
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


  function automatic ecm_status_data_array_t randomize_status_input(int num_packets);
    ecm_status_data_array_t r = new [num_packets];
    int packet_cycle [] = new [num_packets];

    for (int i = 0; i < num_packets; i++) begin
      packet_cycle[i] = (i + 1) * HEARTBEAT_INTERVAL - $urandom_range(0.9*HEARTBEAT_INTERVAL, 0.2*HEARTBEAT_INTERVAL);

      if (i == 0) begin
        r[i].pre_write_delay = packet_cycle[i];
      end else begin
        r[i].pre_write_delay = packet_cycle[i] - packet_cycle[i - 1];
      end

      r[i].enable_channelizer                             = $urandom_range(1);
      r[i].enable_synthesizer                             = $urandom_range(1);

      r[i].channelizer_warnings.demux_gap                 = $urandom_range(1);
      r[i].channelizer_errors.demux_overflow              = $urandom_range(1);
      r[i].channelizer_errors.filter_overflow             = $urandom_range(1);
      r[i].channelizer_errors.mux_overflow                = $urandom_range(1);
      r[i].channelizer_errors.mux_underflow               = $urandom_range(1);
      r[i].channelizer_errors.mux_collision               = $urandom_range(1);
      r[i].channelizer_errors.stretcher_overflow          = $urandom_range(1);
      r[i].channelizer_errors.stretcher_underflow         = $urandom_range(1);
      r[i].synthesizer_errors.stretcher_overflow          = $urandom_range(1);
      r[i].synthesizer_errors.stretcher_underflow         = $urandom_range(1);
      r[i].synthesizer_errors.filter_overflow             = $urandom_range(1);
      r[i].synthesizer_errors.mux_input_overflow          = $urandom_range(1);
      r[i].synthesizer_errors.mux_fifo_overflow           = $urandom_range(1);
      r[i].synthesizer_errors.mux_fifo_underflow          = $urandom_range(1);
      r[i].dwell_stats_errors.reporter_timeout            = $urandom_range(1);
      r[i].dwell_stats_errors.reporter_overflow           = $urandom_range(1);
      r[i].drfm_errors.ext_read_overflow                  = $urandom_range(1);
      r[i].drfm_errors.int_read_overflow                  = $urandom_range(1);
      r[i].drfm_errors.invalid_read                       = $urandom_range(1);
      r[i].drfm_errors.reporter_timeout                   = $urandom_range(1);
      r[i].drfm_errors.reporter_overflow                  = $urandom_range(1);
      r[i].output_block_errors.dds_drfm_sync_mismatch     = $urandom_range(1);
      r[i].dwell_controller_errors.program_fifo_overflow  = $urandom_range(1);
      r[i].dwell_controller_errors.program_fifo_underflow = $urandom_range(1);

      r[i].status_reporter_errors.reporter_overflow       = 0;
      r[i].status_reporter_errors.reporter_timeout        = 0;
    end

    return r;
  endfunction

  task automatic standard_test();
    parameter NUM_TESTS = 20;
    parameter HEARTBEATS_PER_TEST = 20;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      ecm_status_data_array_t status_input = randomize_status_input(HEARTBEATS_PER_TEST);
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
