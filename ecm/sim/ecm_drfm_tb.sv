`timescale 1ns/1ps

import math::*;
import ecm_pkg::*;
import dsp_pkg::*;

typedef ecm_drfm_write_req_t ecm_drfm_write_req_queue_t[$];
typedef ecm_drfm_read_req_t ecm_drfm_read_req_queue_t[$];
typedef logic signed [ecm_drfm_data_width - 1 : 0] iq_data_t [1:0];

function automatic iq_data_t get_iq_data_from_write_req(ecm_drfm_write_req_t d);
  iq_data_t r;
  for (int i = 0; i < 2; i++) begin
    r[i] = {>>{d.data[i]}};
    /*for (int j = 0; j < ecm_drfm_data_width; j++) begin
      r[i][j] = d.data[i][j];
    end*/
  end
  return r;
endfunction

function automatic ecm_drfm_write_req_t set_iq_data_in_write_req(ecm_drfm_write_req_t d, iq_data_t iq);
  for (int i = 0; i < 2; i++) begin
    for (int j = 0; j < ecm_drfm_data_width; j++) begin
      d.data[i][j] = iq[i][j];
    end
  end
  return d;
endfunction


interface dwell_tx_intf (input logic Clk);
  logic                                         dwell_active = 0;
  logic                                         dwell_done;
  logic [ecm_dwell_sequence_num_width - 1 : 0]  dwell_sequence_num;
  logic                                         dwell_reports_done;

  ecm_drfm_write_req_t                          write_req;
  ecm_drfm_read_req_t                           read_req;

  task clear();
    dwell_active        = 0;
    dwell_done          = 0;
    dwell_sequence_num  = 'x;
    read_req.valid      = 0;
    write_req.valid     = 0;
    @(posedge Clk);
  endtask

  task write(int unsigned seq_num, ecm_drfm_write_req_queue_t write_req_data, ecm_drfm_read_req_queue_t read_req_data);
    automatic int burst_length = 0;
    automatic int gap_length = 0;

    dwell_active        = 1;
    dwell_done          = 0;
    dwell_sequence_num  = seq_num;
    read_req.valid      = 0;
    write_req.valid     = 0;

    repeat ($urandom_range(200, 20)) @(posedge Clk);

    while (write_req_data.size() > 0) begin
      /*if (burst_length > 0) begin
        burst_length--;
        repeat ($urandom_range(1)) @(posedge Clk);
      end else if (gap_length > 0) begin
        gap_length--;
        @(posedge Clk);
        continue;
      end else begin
        automatic int r = $urandom_range(99);
        if (r < 5) begin
          burst_length = $urandom_range(20, 10);
        end else if (r < 10) begin
          gap_length = $urandom_range(20, 10);
        end
        repeat ($urandom_range(10)) @(posedge Clk);
      end*/

      write_req = write_req_data.pop_front();
      @(posedge Clk);
      write_req.valid         = 0;
      write_req.first         = 'x;
      write_req.last          = 'x;
      write_req.channel_index = 'x;
      write_req.address       = 'x;
      write_req.data          = {default: 'x};
      repeat ($urandom_range(1, 0)) @(posedge Clk);
    end

    repeat($urandom_range(100)) @(posedge Clk);

    while (read_req_data.size() > 0) begin
      if (burst_length > 0) begin
        burst_length--;
        repeat ($urandom_range(1)) @(posedge Clk);
      end else if (gap_length > 0) begin
        gap_length--;
        @(posedge Clk);
        continue;
      end else begin
        automatic int r = $urandom_range(99);
        if (r < 5) begin
          burst_length = $urandom_range(20, 10);
        end else if (r < 10) begin
          gap_length = $urandom_range(20, 10);
        end
        repeat ($urandom_range(10)) @(posedge Clk);
      end

      read_req = read_req_data.pop_front();
      @(posedge Clk);
      read_req.valid         = 0;
      read_req.address       = 'x;
      read_req.channel_index = 'x;
      read_req.channel_last  = 'x;
      repeat(1) @(posedge Clk);
    end

    dwell_active = 0;
    repeat ($urandom_range(10)) @(posedge Clk);
    dwell_done = 1;

    while (!dwell_reports_done) begin
      @(posedge Clk);
    end

  endtask
endinterface

typedef struct {
  int data_i;
  int data_q;
  int index;
} drfm_output_t;

interface drfm_rx_intf (input logic Clk);
  channelizer_control_t                       ctrl;
  logic signed [ecm_drfm_data_width - 1 : 0]  data [1:0];

  task read(output drfm_output_t rx);
    logic v;
    do begin
      rx.data_i <= data[0];
      rx.data_q <= data[1];
      rx.index  <= ctrl.data_index;
      v         <= ctrl.valid;
      @(posedge Clk);
    end while (v !== 1);
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

module ecm_drfm_tb;
  parameter time CLK_HALF_PERIOD      = 2ns;
  parameter time AXI_CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH            = 32;

  typedef struct
  {
    logic [AXI_DATA_WIDTH - 1 : 0] data [$];
  } expect_report_t;

  typedef struct packed
  {
    bit [31:0]  magic_num;
    bit [31:0]  sequence_num;
    bit [7:0]   module_id;
    bit [7:0]   message_type;
    bit [15:0]  padding_0;
    bit [31:0]  dwell_sequence_num;
  } ecm_common_report_header_t;

  typedef struct packed
  {
    bit [31:0]  magic_num;
    bit [31:0]  sequence_num;
    bit [7:0]   module_id;
    bit [7:0]   message_type;
    bit [15:0]  padding_0;

    bit [31:0]  dwell_sequence_num;

    bit [7:0]   channel_index;
    bit [7:0]   max_iq_bits;
    bit [15:0]  padding;

    bit [31:0]  segment_seq_num;
    bit [63:0]  segment_timestamp;

    bit [15:0]  segment_addr_first;
    bit [15:0]  segment_addr_last;

    bit [15:0]  slice_addr;
    bit [15:0]  slice_length;
  } ecm_drfm_channel_report_header_t;

  typedef struct packed
  {
    bit [31:0]  magic_num;
    bit [31:0]  sequence_num;
    bit [7:0]   module_id;
    bit [7:0]   message_type;
    bit [15:0]  padding_0;

    bit [31:0]  dwell_sequence_num;

    bit [15:0]  channel_was_written;
    bit [15:0]  channel_was_read;
  } ecm_drfm_summary_report_header_t;

  typedef bit [$bits(ecm_common_report_header_t) - 1 : 0]       ecm_common_report_header_bits_t;
  typedef bit [$bits(ecm_drfm_channel_report_header_t) - 1 : 0] ecm_drfm_channel_report_header_bits_t;
  typedef bit [$bits(ecm_drfm_summary_report_header_t) - 1 : 0] ecm_drfm_summary_report_header_bits_t;

  parameter NUM_COMMON_HEADER_WORDS   = ($bits(ecm_common_report_header_t) / AXI_DATA_WIDTH);
  parameter NUM_CHANNEL_HEADER_WORDS  = ($bits(ecm_drfm_channel_report_header_t) / AXI_DATA_WIDTH);
  parameter NUM_SUMMARY_HEADER_WORDS  = ($bits(ecm_drfm_summary_report_header_t) / AXI_DATA_WIDTH);

  logic Clk_axi;
  logic Clk;
  logic Rst;

  dwell_tx_intf                                   tx_intf         (.*);
  drfm_rx_intf                                    output_rx_intf  (.*);
  axi_rx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  report_rx_intf  (.Clk(Clk_axi));

  int unsigned    report_seq_num = 0;
  expect_report_t expected_report_data [$];
  drfm_output_t   expected_output_data [$];

  int             num_received = 0;
  logic           r_axi_rx_ready;
  logic           w_axi_rx_valid;
  logic           w_error_ext_read_overflow;
  logic           w_error_int_read_overflow;
  logic           w_error_invalid_read;
  logic           w_error_reporter_timeout;
  logic           w_error_reporter_overflow;

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

  ecm_drfm
  #(
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .READ_LATENCY   (4)
  )
  dut
  (
    .Clk_axi                  (Clk_axi),
    .Clk                      (Clk),
    .Rst                      (Rst),

    .Dwell_active             (tx_intf.dwell_active),
    .Dwell_done               (tx_intf.dwell_done),
    .Dwell_sequence_num       (tx_intf.dwell_sequence_num),
    .Dwell_reports_done       (tx_intf.dwell_reports_done),

    .Write_req                (tx_intf.write_req),
    .Read_req                 (tx_intf.read_req),

    .Output_ctrl              (output_rx_intf.ctrl),
    .Output_data              (output_rx_intf.data),

    .Axis_ready               (r_axi_rx_ready),
    .Axis_valid               (w_axi_rx_valid),
    .Axis_data                (report_rx_intf.data),
    .Axis_last                (report_rx_intf.last),

    .Error_ext_read_overflow  (w_error_ext_read_overflow),
    .Error_int_read_overflow  (w_error_int_read_overflow),
    .Error_invalid_read       (w_error_invalid_read),
    .Error_reporter_timeout   (w_error_reporter_timeout),
    .Error_reporter_overflow  (w_error_reporter_overflow)
  );

  assign report_rx_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

  always_ff @(posedge Clk) begin
    if (!Rst) begin
      if (w_error_ext_read_overflow)  $error("ext read overflow");
      if (w_error_int_read_overflow)  $error("int read overflow");
      if (w_error_invalid_read)       $error("invalid read");
      if (w_error_reporter_timeout)   $error("reporter timeout");
      if (w_error_reporter_overflow)  $error("reporter overflow");
    end
  end

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
    repeat(100) @(posedge Clk);
  endtask

  function automatic ecm_common_report_header_t unpack_common_report_header(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    ecm_common_report_header_t      report_header;
    ecm_common_report_header_bits_t packed_report_header;

    for (int i = 0; i < $size(packed_report_header)/AXI_DATA_WIDTH; i++) begin
      packed_report_header[(NUM_COMMON_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_front();
    end

    report_header = ecm_common_report_header_t'(packed_report_header);
    return report_header;
  endfunction

  function automatic ecm_drfm_channel_report_header_t unpack_channel_report_header(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    ecm_drfm_channel_report_header_t      report_header;
    ecm_drfm_channel_report_header_bits_t packed_report_header;

    //$display("unpack_report: data=%p", data);

    for (int i = 0; i < $size(packed_report_header)/AXI_DATA_WIDTH; i++) begin
      //$display("unpack_report_header [%0d] = %X", i, data[0]);
      packed_report_header[(NUM_CHANNEL_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_front();
    end

    //$display("unpack_report: packed=%X", packed_report_header);

    report_header = ecm_drfm_channel_report_header_t'(packed_report_header);
    return report_header;
  endfunction

  function automatic ecm_drfm_summary_report_header_t unpack_summary_report_header(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    ecm_drfm_summary_report_header_t      report_header;
    ecm_drfm_summary_report_header_bits_t packed_report_header;

    //$display("unpack_report: data=%p", data);

    for (int i = 0; i < $size(packed_report_header)/AXI_DATA_WIDTH; i++) begin
      //$display("unpack_report_header [%0d] = %X", i, data[0]);
      packed_report_header[(NUM_SUMMARY_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_front();
    end

    //$display("unpack_report: packed=%X", packed_report_header);

    report_header = ecm_drfm_summary_report_header_t'(packed_report_header);
    return report_header;
  endfunction

  function automatic bit report_data_match(logic [AXI_DATA_WIDTH - 1 : 0] a [$], logic [AXI_DATA_WIDTH - 1 : 0] b []);
    ecm_common_report_header_t header_a = unpack_common_report_header(a);
    ecm_common_report_header_t header_b = unpack_common_report_header(a);

    if (a.size() != b.size()) begin
      $display("%0t: size mismatch: a=%0d b=%0d", $time, a.size(), b.size());
      return 0;
    end

    if (header_a.magic_num !== header_b.magic_num) begin
      $display("magic_num mismatch: %X %X", header_a.magic_num, header_b.magic_num);
      return 0;
    end

    if (header_a.sequence_num !== header_b.sequence_num) begin
      $display("sequence_num mismatch: %X %X", header_a.sequence_num, header_b.sequence_num);
      return 0;
    end

    if (header_a.module_id !== header_b.module_id) begin
      $display("module_id mismatch: %X %X", header_a.module_id, header_b.module_id);
      return 0;
    end

    if (header_a.message_type !== header_b.message_type) begin
      $display("message_type mismatch: %X %X", header_a.message_type, header_b.message_type);
      return 0;
    end

    if (header_a.dwell_sequence_num !== header_b.dwell_sequence_num) begin
      $display("dwell_sequence_num mismatch: %X %X", header_a.dwell_sequence_num, header_b.dwell_sequence_num);
      return 0;
    end

    if (header_a.message_type == ecm_report_message_type_drfm_channel_data) begin
      ecm_drfm_channel_report_header_t report_a = unpack_channel_report_header(a);
      ecm_drfm_channel_report_header_t report_b = unpack_channel_report_header(b);

      if (report_a.channel_index !== report_b.channel_index) begin
        $display("channel_index mismatch: %X %X", report_a.channel_index, report_b.channel_index);
        return 0;
      end
      if (report_a.max_iq_bits !== report_b.max_iq_bits) begin
        $display("max_iq_bits mismatch: %X %X", report_a.max_iq_bits, report_b.max_iq_bits);
        return 0;
      end
      if (report_a.segment_seq_num !== report_b.segment_seq_num) begin
        $display("segment_seq_num mismatch: %X %X", report_a.segment_seq_num, report_b.segment_seq_num);
        return 0;
      end
      if (report_a.segment_timestamp !== report_b.segment_timestamp) begin
        $display("segment_timestamp mismatch: %X %X", report_a.segment_timestamp, report_b.segment_timestamp);
        return 0;
      end
      if (report_a.segment_addr_first !== report_b.segment_addr_first) begin
        $display("segment_addr_first mismatch: %X %X", report_a.segment_addr_first, report_b.segment_addr_first);
        return 0;
      end
      if (report_a.segment_addr_last !== report_b.segment_addr_last) begin
        $display("segment_addr_last mismatch: %X %X", report_a.segment_addr_last, report_b.segment_addr_last);
        return 0;
      end
      if (report_a.slice_addr !== report_b.slice_addr) begin
        $display("slice_addr mismatch: %X %X", report_a.slice_addr, report_b.slice_addr);
        return 0;
      end
      if (report_a.slice_length !== report_b.slice_length) begin
        $display("slice_length mismatch: %X %X", report_a.slice_length, report_b.slice_length);
        return 0;
      end

      for (int i = NUM_CHANNEL_HEADER_WORDS; i < ecm_words_per_dma_packet; i++) begin
        if (a[i] !== b[i]) begin
          $display("trailer mismatch [%0d]: %X %X", i, a[i], b[i]);
          return 0;
        end
      end

    end else if (header_a.message_type == ecm_report_message_type_drfm_summary) begin
      ecm_drfm_summary_report_header_t report_a = unpack_summary_report_header(a);
      ecm_drfm_summary_report_header_t report_b = unpack_summary_report_header(b);

      if (report_a.channel_was_written !== report_b.channel_was_written) begin
        $display("channel_was_written mismatch: %X %X", report_a.channel_was_written, report_b.channel_was_written);
        return 0;
      end
      if (report_a.channel_was_read !== report_b.channel_was_read) begin
        $display("channel_was_read mismatch: %X %X", report_a.channel_was_read, report_b.channel_was_read);
        return 0;
      end

      for (int i = NUM_SUMMARY_HEADER_WORDS; i < ecm_words_per_dma_packet; i++) begin
        if (a[i] !== b[i]) begin
          $display("trailer mismatch [%0d]: %X %X", i, a[i], b[i]);
          return 0;
        end
      end
    end else begin
      $error("invalid message type");
      return 0;
    end

    return 1;
  endfunction

  function automatic bit output_data_match(drfm_output_t a, drfm_output_t b);
    if (a.data_i !== b.data_i) begin
      $display("data_i mismatch: %X %X", a.data_i, b.data_i);
      return 0;
    end
    if (a.data_q !== b.data_q) begin
      $display("data_q mismatch: %X %X", a.data_q, b.data_q);
      return 0;
    end
    if (a.index !== b.index) begin
      $display("index mismatch: %X %X", a.index, b.index);
      return 0;
    end

    return 1;
  endfunction

  initial begin
    automatic logic [AXI_DATA_WIDTH - 1 : 0] read_data [$];

    wait_for_reset();

    forever begin
      report_rx_intf.read(read_data);

      if (report_data_match(read_data, expected_report_data[0].data)) begin
        $display("%0t: data match - %p", $time, read_data);
      end else begin
        $error("%0t: error -- data mismatch: expected = %p  actual = %p", $time, expected_report_data[0].data, read_data);
      end
      num_received++;
      void'(expected_report_data.pop_front());
    end
  end

  final begin
    if ( expected_report_data.size() != 0 ) begin
      $error("Unexpected data remaining in queue:");
      while ( expected_report_data.size() != 0 ) begin
        $display("%p", expected_report_data[0].data);
        void'(expected_report_data.pop_front());
      end
    end
  end

  initial begin
    automatic drfm_output_t read_data;

    wait_for_reset();

    forever begin
      output_rx_intf.read(read_data);

      if (output_data_match(read_data, expected_output_data[0])) begin
        $display("%0t: data match - %p", $time, read_data);
      end else begin
        $error("%0t: error -- data mismatch: expected = %p  actual = %p", $time, expected_output_data[0], read_data);
      end
      num_received++;
      void'(expected_output_data.pop_front());
    end
  end

  final begin
    if ( expected_output_data.size() != 0 ) begin
      $error("Unexpected data remaining in queue:");
      while ( expected_output_data.size() != 0 ) begin
        $display("%p", expected_output_data[0]);
        void'(expected_output_data.pop_front());
      end
    end
  end

/*
  function automatic void expect_reports(esm_dwell_metadata_t dwell_data, int unsigned dwell_seq_num, dwell_channel_data_t  dwell_input []);
    int channels_per_packet = (MAX_WORDS_PER_PACKET - NUM_HEADER_WORDS) / 4;
    int num_packets = (NUM_CHANNELS + channels_per_packet - 1) / channels_per_packet;
    int num_padding_words = 0;
    int channel_index = 0;

    longint unsigned channel_accum [NUM_CHANNELS] = {default:0};
    int unsigned channel_max [NUM_CHANNELS] = {default:0};

    $display("%0t: num_header_words=%0d channels_per_packet=%0d num_packets=%0d", $time, NUM_HEADER_WORDS, channels_per_packet, num_packets);

    for (int i = 0; i < dwell_input.size(); i++) begin
      channel_accum[dwell_input[i].channel] += dwell_input[i].power;
      channel_max[dwell_input[i].channel] = (dwell_input[i].power > channel_max[dwell_input[i].channel]) ? dwell_input[i].power : channel_max[dwell_input[i].channel];
    end

    for (int i_packet = 0; i_packet < num_packets; i_packet++) begin
      expect_t r;
      esm_dwell_report_header_t   report_header;
      dwell_report_header_bits_t  report_header_packed;

      report_header.magic_num               = esm_report_magic_num;
      report_header.sequence_num            = report_seq_num;
      report_header.module_id               = MODULE_ID;
      report_header.message_type            = esm_report_message_type_dwell_stats;
      report_header.dwell_sequence_num      = dwell_seq_num;
      report_header.tag                     = dwell_data.tag;
      report_header.frequency               = dwell_data.frequency;
      report_header.duration_requested      = dwell_data.duration;
      report_header.gain                    = dwell_data.gain;
      report_header.fast_lock_profile       = dwell_data.fast_lock_profile;
      report_header.num_channels            = NUM_CHANNELS;
      report_header.report_starting_channel = channel_index;
      report_header.threshold_shift_narrow  = dwell_data.threshold_shift_narrow;
      report_header.threshold_shift_wide    = dwell_data.threshold_shift_wide;
      report_header.channel_mask_narrow     = 0; //dwell_data.channel_mask_narrow;
      report_header.channel_mask_wide       = 0; //dwell_data.channel_mask_wide;
      report_header.duration_actual         = 0;
      report_header.num_samples             = dwell_input.size();
      report_header.ts_dwell_start          = 0;
      report_header.ts_dwell_end            = 0;

      report_header_packed = dwell_report_header_bits_t'(report_header);
      //$display("report_packed: %X", report_header_packed);
      $display("report_header: %p", report_header);

      for (int i = 0; i < $size(report_header_packed)/AXI_DATA_WIDTH; i++) begin
        r.data.push_back(report_header_packed[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]);
      end

      for (int i_channel = 0; i_channel < channels_per_packet; i_channel++) begin
        bit [31:0] words [4];
        if (channel_index >= NUM_CHANNELS) begin
          break;
        end

        words[0] = channel_index;
        words[1] = channel_accum[channel_index][63:32];
        words[2] = channel_accum[channel_index][31:0];
        words[3] = channel_max[channel_index];
        for (int i = 0; i < $size(words); i++) begin
          r.data.push_back(words[i]);
        end
        channel_index++;
      end

      num_padding_words = MAX_WORDS_PER_PACKET - r.data.size();
      for (int i_padding = 0; i_padding < num_padding_words; i_padding++) begin
        r.data.push_back(0);
      end

      //for (int i = 0; i < r.data.size(); i++) begin
      //  $display("r.data[%02d]=%X", i, r.data[i]);
      //end

      expected_data.push_back(r);

      //$display("report_header: %p", report_header);
      //$display("report_header_packed: %p", report_header_packed);
      //$display("axi report: %p [0]", r.data, r.data[0]);

      report_seq_num++;
    end
  endfunction

  function automatic esm_dwell_metadata_t randomize_dwell_metadata();
    esm_dwell_metadata_t r;
    r.tag                     = $urandom;
    r.frequency               = $urandom;
    r.duration                = $urandom;
    r.gain                    = $urandom;
    r.fast_lock_profile       = $urandom;
    r.threshold_shift_narrow  = $urandom;
    r.threshold_shift_wide    = $urandom;
    r.channel_mask_narrow     = {$urandom, $urandom};
    r.channel_mask_wide       = $urandom;
    return r;
  endfunction

  function automatic dwell_channel_array_t randomize_dwell_input();
    dwell_channel_array_t r = new [$urandom_range(2000, 500)];
    int channel_index = 0;

    for (int i = 0; i < r.size(); i++) begin
      r[i].channel  = channel_index;
      r[i].last     = (channel_index == (NUM_CHANNELS - 1));
      r[i].power    = $urandom;
      channel_index = (channel_index + 1) % NUM_CHANNELS;
    end

    return r;
  endfunction
*/
  function automatic ecm_drfm_write_req_queue_t randomize_drfm_writes(int max_bits);
    bit [ecm_num_channels - 1 : 0]  channel_valid = '0;
    int                             channel_duration    [ecm_num_channels - 1 : 0];
    int                             channel_addr_start  [ecm_num_channels - 1 : 0];
    int                             channel_addr_end    [ecm_num_channels - 1 : 0];
    int                             channel_frame_start [ecm_num_channels - 1 : 0];
    int                             channel_data_index  [ecm_num_channels - 1 : 0];
    int                             num_frames;
    ecm_drfm_write_req_queue_t      r;
    ecm_drfm_write_req_t            empty_req = {valid:0, default:'x};
    int                             current_bits = 1;
    bit                             channel_active = 0;

    num_frames = $urandom_range(20 * ecm_drfm_mem_depth / ecm_num_channels, 2 * ecm_drfm_mem_depth / ecm_num_channels);

    for (int i = 0; i < ecm_num_channels; i++) begin
      channel_valid[i]    = ($urandom_range(99) < 75);

      if ($urandom_range(99) < 50) begin
        channel_duration[i] = $urandom_range(ecm_drfm_mem_depth / ecm_num_channels, 500);
      end else begin
        channel_duration[i] = $urandom_range(100, 5);
      end

      channel_addr_start[i] = i * ecm_drfm_mem_depth / ecm_num_channels;
      //channel_addr_end[i]   = channel_addr_start[i] + channel_duration[i] - 1;  TODO: remove

      channel_frame_start[i] = $urandom_range(num_frames - ecm_drfm_mem_depth / ecm_num_channels, 0);
      channel_data_index[i] = 0;
    end

    for (int f = 0; f < num_frames; f++) begin
      logic [ecm_drfm_data_width - 1 : 0] iq_bit_mask = 2**current_bits - 1;
      if (channel_active && (current_bits < max_bits) && (f % 5 == 1)) begin
        current_bits++;
        $display("%0t: frame=%0d current_bits=%0d max_bits=%0d -- iq_bit_mask=%0X, r.size=%0d", $time, f, current_bits, max_bits, iq_bit_mask, r.size());
      end

      for (int i = 0; i < ecm_num_channels; i++) begin
        ecm_drfm_write_req_t d = {valid:0, default:'x};
        iq_data_t iq;

        if(channel_valid[i] && (f >= channel_frame_start[i]) && (channel_data_index[i] < channel_duration[i])) begin
          channel_active  = 1;

          d.valid         = 1;
          d.first         = (channel_data_index[i] == 0);
          d.last          = (channel_data_index[i] == (channel_duration[i] - 1));
          d.channel_index = i;
          d.address       = channel_addr_start[i] + channel_data_index[i];

          for (int j = 0; j < 2; j++) begin
            iq[j] = ($urandom & iq_bit_mask);
            if ($urandom_range(1)) begin
              iq[j] |= (~iq_bit_mask);
            end
          end

          d = set_iq_data_in_write_req(d, iq);

          channel_data_index[i]++;
        end

        r.push_back(d);
      end
    end

    return r;
  endfunction

  function automatic ecm_drfm_read_req_queue_t randomize_drfm_reads(ecm_drfm_write_req_queue_t writes);
    ecm_drfm_read_req_queue_t r;
    return r;
  endfunction

  task automatic standard_test();
    parameter NUM_TESTS = 20;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      $display("%0t: Test started - %0d", $time, i_test);
      report_seq_num = 0;

      for (int i_dwell = 0; i_dwell < 100; i_dwell++) begin
        int unsigned          dwell_seq_num       = $urandom;
        int                   max_bits            = $urandom_range(ecm_drfm_data_width - 1, 4);
        ecm_drfm_write_req_t  write_req_data [$]  = randomize_drfm_writes(max_bits);
        ecm_drfm_read_req_t   read_req_data [$]   = randomize_drfm_reads(write_req_data);

        $display("dwell %0d started: seq=%0X max_bits=%0d", i_dwell, dwell_seq_num, max_bits);

        //expect_reports(dwell_data, dwell_seq_num, dwell_input);
        tx_intf.write(dwell_seq_num, write_req_data, read_req_data);

        repeat(1000) @(posedge Clk);

        begin
          int wait_cycles = 0;
          while ((expected_report_data.size() != 0) && (expected_output_data.size() != 0) && (wait_cycles < 1e5)) begin
            @(posedge Clk);
            wait_cycles++;
          end
          assert (wait_cycles < 1e5) else $error("Timeout while waiting for expected queue to empty during test.");
        end

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
    tx_intf.clear();
    wait_for_reset();
    standard_test();
    repeat(100) @(posedge Clk);
    $finish;
  end

endmodule
