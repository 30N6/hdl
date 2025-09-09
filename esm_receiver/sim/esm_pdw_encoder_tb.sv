`timescale 1ns/1ps

import math::*;
import esm_pkg::*;
import dsp_pkg::*;

typedef struct {
  int channel;
  bit last;
  int unsigned power;
  int data_i;
  int data_q;
  bit pulse_valid;
} dwell_channel_data_t;

typedef dwell_channel_data_t dwell_channel_array_t [];

interface dwell_data_tx_intf (input logic Clk);
  logic                                         dwell_active = 0;
  esm_dwell_metadata_t                          dwell_data;
  logic [esm_dwell_sequence_num_width - 1 : 0]  dwell_sequence_num;

  channelizer_control_t                         input_ctrl = {valid:0, default:0};
  logic [chan_power_width - 1 : 0]              input_power;
  logic signed [15:0]                           input_iq [1:0];

  task write(esm_dwell_metadata_t data, int unsigned seq_num, dwell_channel_data_t input_data []);
    automatic dwell_channel_data_t d;

    dwell_active        = 1;
    dwell_data          = data;
    dwell_sequence_num  = seq_num;

    repeat (4) @(posedge Clk);

    //$display("%0t: input_data = %p", $time, input_data);

    for (int i = 0; i < input_data.size(); i++) begin
      d = input_data[i];

      input_ctrl.valid      = 1;
      input_ctrl.last       = d.last;
      input_ctrl.data_index = d.channel;
      input_power           = d.power;
      input_iq[0]           = d.data_i;
      input_iq[1]           = d.data_q;
      @(posedge Clk);
      input_ctrl.valid      = 0;
      input_ctrl.last       = 'x;
      input_ctrl.data_index = 'x;
      input_power           = '0;
      input_iq[0]           = 'x;
      input_iq[1]           = 'x;
      repeat($urandom_range(1,0)) @(posedge Clk);
    end

    dwell_active        = 0;
    dwell_data          = '{default: 'x};
    dwell_sequence_num  = 'x;
  endtask

  task clear();
    input_ctrl.valid      = 0;
    input_ctrl.last       = 'x;
    input_ctrl.data_index = 'x;
    input_power           = '0;
    input_iq[0]           = 'x;
    input_iq[1]           = 'x;
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

module esm_pdw_encoder_tb;
  parameter time CLK_HALF_PERIOD      = 2ns;
  parameter time AXI_CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH            = 32;
  parameter logic [7:0] MODULE_ID     = 99;
  parameter NUM_CHANNELS              = 64;

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
  } esm_pdw_report_header_t;

  typedef struct packed
  {
    bit [31:0]  magic_num;
    bit [31:0]  sequence_num;
    bit [7:0]   module_id;
    bit [7:0]   message_type;
    bit [15:0]  padding_0;

    bit [31:0]  dwell_sequence_num;
    bit [31:0]  pulse_sequence_num;
    bit [31:0]  pulse_channel;
    bit [31:0]  pulse_threshold;
    bit [63:0]  pulse_power_accum;
    bit [31:0]  pulse_duration;
    bit [31:0]  pulse_frequency;
    bit [63:0]  pulse_start_time;
    bit [7:0]   buffered_frame_valid;
    bit [7:0]   buffered_frame_index;
    bit [15:0]  padding_1;
  } esm_pdw_pulse_report_header_t;

  typedef struct packed
  {
    bit [31:0]  magic_num;
    bit [31:0]  sequence_num;
    bit [7:0]   module_id;
    bit [7:0]   message_type;
    bit [15:0]  padding_0;

    bit [31:0]  dwell_sequence_num;
    bit [63:0]  dwell_start_time;
    bit [31:0]  dwell_duration;
    bit [31:0]  dwell_pulse_total_count;
    bit [31:0]  dwell_pulse_drop_count;
    bit [31:0]  ack_delay_report;
    bit [31:0]  ack_delay_sample_processor;
  } esm_pdw_summary_report_header_t;

  typedef bit [$bits(esm_pdw_report_header_t) - 1 : 0]          pdw_report_header_bits_t;
  typedef bit [$bits(esm_pdw_pulse_report_header_t) - 1 : 0]    pdw_pulse_report_header_bits_t;
  typedef bit [$bits(esm_pdw_summary_report_header_t) - 1 : 0]  pdw_summary_report_header_bits_t;

  parameter NUM_HEADER_WORDS          = ($bits(pdw_report_header_bits_t) / AXI_DATA_WIDTH);
  parameter NUM_PULSE_HEADER_WORDS    = ($bits(pdw_pulse_report_header_bits_t) / AXI_DATA_WIDTH);
  parameter NUM_SUMMARY_HEADER_WORDS  = ($bits(pdw_summary_report_header_bits_t) / AXI_DATA_WIDTH);

  logic Clk_axi;
  logic Clk;
  logic Rst;

  dwell_data_tx_intf                              dwell_tx_intf (.*);
  axi_rx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  rpt_rx_intf   (.Clk(Clk_axi));

  int unsigned  report_seq_num = 0;
  int unsigned  pulse_seq_num [NUM_CHANNELS] = {default:0};
  expect_t      expected_data [NUM_CHANNELS][$];
  int           num_received = 0;
  logic         r_axi_rx_ready;
  logic         w_axi_rx_valid;
  logic         w_error_pdw_fifo_busy;
  logic         w_error_pdw_fifo_overflow;
  logic         w_error_pdw_fifo_underflow;
  logic         w_error_sample_buffer_busy;
  logic         w_error_sample_buffer_underflow;
  logic         w_error_sample_buffer_overflow;
  logic         w_error_reporter_timeout;
  logic         w_error_reporter_overflow;

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
    repeat(3000) @(posedge Clk);
    Rst = 0;
  end

  always_ff @(posedge Clk_axi) begin
    r_axi_rx_ready <= $urandom_range(99) < 80;
  end

  esm_pdw_encoder
  #(
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .DATA_WIDTH     (16),
    .NUM_CHANNELS   (NUM_CHANNELS),
    .MODULE_ID      (MODULE_ID),
    .WIDE_BANDWIDTH (NUM_CHANNELS < 64),
    .DEBUG_ENABLE   (0)
  )
  dut
  (
    .Clk_axi                        (Clk_axi),
    .Clk                            (Clk),
    .Rst                            (Rst),

    .Enable                         (1'b1),

    .Dwell_active                   (dwell_tx_intf.dwell_active),
    .Dwell_data                     (dwell_tx_intf.dwell_data),
    .Dwell_sequence_num             (dwell_tx_intf.dwell_sequence_num),

    .Input_ctrl                     (dwell_tx_intf.input_ctrl),
    .Input_data                     (dwell_tx_intf.input_iq),
    .Input_power                    (dwell_tx_intf.input_power),

    .Axis_ready                     (r_axi_rx_ready),
    .Axis_valid                     (w_axi_rx_valid),
    .Axis_data                      (rpt_rx_intf.data),
    .Axis_last                      (rpt_rx_intf.last),

    .Error_pdw_fifo_busy            (w_error_pdw_fifo_busy),
    .Error_pdw_fifo_overflow        (w_error_pdw_fifo_overflow),
    .Error_pdw_fifo_underflow       (w_error_pdw_fifo_underflow),
    .Error_sample_buffer_busy       (w_error_sample_buffer_busy),
    .Error_sample_buffer_underflow  (w_error_sample_buffer_underflow),
    .Error_sample_buffer_overflow   (w_error_sample_buffer_overflow),
    .Error_reporter_timeout         (w_error_reporter_timeout),
    .Error_reporter_overflow        (w_error_reporter_overflow)
  );

  assign rpt_rx_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

  always_ff @(posedge Clk) begin
    if (!Rst) begin
      if (w_error_pdw_fifo_busy)            $error("pdw fifo busy");
      if (w_error_pdw_fifo_overflow)        $error("pdw fifo overflow");
      if (w_error_pdw_fifo_underflow)       $error("pdw fifo underflow");
      if (w_error_sample_buffer_busy)       $error("sample buffer busy");
      if (w_error_sample_buffer_underflow)  $error("sample buffer underflow");
      if (w_error_sample_buffer_overflow)   $error("sample buffer overflow");
      if (w_error_reporter_timeout)         $error("reporter timeout");
      if (w_error_reporter_overflow)        $error("reporter overflow");
    end
  end

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
    repeat(100) @(posedge Clk);
  endtask

  function automatic esm_pdw_report_header_t unpack_report_header(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    esm_pdw_report_header_t   report_header;
    pdw_report_header_bits_t  packed_report_header;

    //$display("unpack_report: data=%p", data);

    for (int i = 0; i < $size(packed_report_header)/AXI_DATA_WIDTH; i++) begin
      //$display("unpack_report_header [%0d] = %X", i, data[0]);
      packed_report_header[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_front();
    end

    //$display("unpack_report: packed=%X", packed_report_header);

    report_header = esm_pdw_report_header_t'(packed_report_header);
    return report_header;
  endfunction

  function automatic esm_pdw_summary_report_header_t unpack_summary_report_header(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    esm_pdw_summary_report_header_t   report_header;
    pdw_summary_report_header_bits_t  packed_report_header;

    //$display("unpack_report: data=%p", data);

    for (int i = 0; i < $size(packed_report_header)/AXI_DATA_WIDTH; i++) begin
      //$display("unpack_report_header [%0d] = %X", i, data[0]);
      packed_report_header[(NUM_SUMMARY_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_front();
    end

    //$display("unpack_report: packed=%X", packed_report_header);

    report_header = esm_pdw_summary_report_header_t'(packed_report_header);
    return report_header;
  endfunction

  function automatic esm_pdw_pulse_report_header_t unpack_pulse_report_header(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    esm_pdw_pulse_report_header_t   report_header;
    pdw_pulse_report_header_bits_t  packed_report_header;

    //$display("unpack_report: data=%p", data);

    for (int i = 0; i < $size(packed_report_header)/AXI_DATA_WIDTH; i++) begin
      //$display("unpack_report_header [%0d] = %X", i, data[0]);
      packed_report_header[(NUM_PULSE_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_front();
    end

    //$display("unpack_report: packed=%X", packed_report_header);

    report_header = esm_pdw_pulse_report_header_t'(packed_report_header);
    return report_header;
  endfunction

  function automatic int get_data_channel(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    esm_pdw_report_header_t header = unpack_report_header(data);

    if (header.message_type == esm_report_message_type_pdw_summary) begin
      return 0;
    end else if (header.message_type == esm_report_message_type_pdw_pulse) begin
      esm_pdw_pulse_report_header_t report = unpack_pulse_report_header(data);
      return report.pulse_channel;
    end else begin
      $error("get_data_channel: unknown message type");
      return 0;
    end
  endfunction

  function automatic bit data_match(logic [AXI_DATA_WIDTH - 1 : 0] a [$], logic [AXI_DATA_WIDTH - 1 : 0] b []);
    esm_pdw_report_header_t header_a = unpack_report_header(a);
    esm_pdw_report_header_t header_b = unpack_report_header(b);

    $display("%0t: data_match: header_a=%p", $time, header_a);
    $display("%0t: data_match: header_b=%p", $time, header_b);
    /*if (header_a.message_type == esm_report_message_type_pdw_summary) begin
      esm_pdw_summary_report_header_t report_a = unpack_summary_report_header(a);
      esm_pdw_summary_report_header_t report_b = unpack_summary_report_header(b);
      $display("%0t: data_match: report_a=%p", $time, report_a);
      $display("%0t: data_match: report_b=%p", $time, report_b);
    end
    if (header_a.message_type == esm_report_message_type_pdw_pulse) begin
      esm_pdw_pulse_report_header_t report_a = unpack_pulse_report_header(a);
      esm_pdw_pulse_report_header_t report_b = unpack_pulse_report_header(b);

      $display("%0t: data_match: report_a=%p", $time, report_a);
      $display("%0t: data_match: report_b=%p", $time, report_b);
    end*/

    if (a.size() != b.size()) begin
      $display("%0t: size mismatch: a=%0d b=%0d", $time, a.size(), b.size());
      return 0;
    end

    if (header_a.magic_num !== header_b.magic_num) begin
      $display("magic_num mismatch: %X %X", header_a.magic_num, header_b.magic_num);
      return 0;
    end

    //PDWs can be reordered -- only check for summaries
    /*if (header_a.sequence_num !== header_b.sequence_num) begin
      $display("sequence_num mismatch: %X %X", header_a.sequence_num, header_b.sequence_num);
      return 0;
    end*/

    if (header_a.module_id !== header_b.module_id) begin
      $display("module_id mismatch: %X %X", header_a.module_id, header_b.module_id);
      return 0;
    end

    if (header_a.message_type !== header_b.message_type) begin
      $display("message_type mismatch: %X %X", header_a.message_type, header_b.message_type);
      return 0;
    end

    if (header_a.message_type == esm_report_message_type_pdw_summary) begin
      esm_pdw_summary_report_header_t report_a = unpack_summary_report_header(a);
      esm_pdw_summary_report_header_t report_b = unpack_summary_report_header(b);

      $display("%0t: data_match: report_a=%p", $time, report_a);
      $display("%0t: data_match: report_b=%p", $time, report_b);

      //TODO: check dwell_duration

      if (header_a.sequence_num !== header_b.sequence_num) begin
        $display("sequence_num mismatch: %X %X", header_a.sequence_num, header_b.sequence_num);
        return 0;
      end

      if (report_a.dwell_sequence_num !== report_b.dwell_sequence_num) begin
        $display("dwell_sequence_num mismatch: %X %X", report_a.dwell_sequence_num, report_b.dwell_sequence_num);
        return 0;
      end

      if (report_a.dwell_pulse_total_count !== report_b.dwell_pulse_total_count) begin
        $display("dwell_pulse_total_count mismatch: %X %X", report_a.dwell_pulse_total_count, report_b.dwell_pulse_total_count);
        return 0;
      end

      if (report_a.dwell_pulse_drop_count !== report_b.dwell_pulse_drop_count) begin
        $display("dwell_pulse_drop_count mismatch: %X %X", report_a.dwell_pulse_drop_count, report_b.dwell_pulse_drop_count);
        return 0;
      end

      for (int i = NUM_SUMMARY_HEADER_WORDS; i < esm_max_words_per_packet; i++) begin
        if (a[i] !== b[i]) begin
          $display("trailer mismatch [%0d]: %X %X", i, a[i], b[i]);
          return 0;
        end
      end

    end else if (header_a.message_type == esm_report_message_type_pdw_pulse) begin
      esm_pdw_pulse_report_header_t report_a = unpack_pulse_report_header(a);
      esm_pdw_pulse_report_header_t report_b = unpack_pulse_report_header(b);

      $display("%0t: data_match: report_a=%p", $time, report_a);
      $display("%0t: data_match: report_b=%p", $time, report_b);

      if (report_a.dwell_sequence_num !== report_b.dwell_sequence_num) begin
        $display("dwell_sequence_num mismatch: %X %X", report_a.dwell_sequence_num, report_b.dwell_sequence_num);
        return 0;
      end
      if (report_a.pulse_sequence_num !== report_b.pulse_sequence_num) begin
        $display("pulse_sequence_num mismatch: %X %X", report_a.pulse_sequence_num, report_b.pulse_sequence_num);
        return 0;
      end
      if (report_a.pulse_channel !== report_b.pulse_channel) begin
        $display("pulse_channel mismatch: %X %X", report_a.pulse_channel, report_b.pulse_channel);
        return 0;
      end
      /*if (report_a.pulse_threshold !== report_b.pulse_threshold) begin
        $display("pulse_threshold mismatch: %X %X", report_a.pulse_threshold, report_b.pulse_threshold);
        return 0;
      end*/
      if (report_a.pulse_power_accum !== report_b.pulse_power_accum) begin
        $display("pulse_power_accum mismatch: %X %X", report_a.pulse_power_accum, report_b.pulse_power_accum);
        return 0;
      end
      if (report_a.pulse_duration !== report_b.pulse_duration) begin
        $display("pulse_duration mismatch: %X %X", report_a.pulse_duration, report_b.pulse_duration);
        return 0;
      end
      if (report_a.pulse_frequency !== report_b.pulse_frequency) begin
        $display("pulse_frequency mismatch: %X %X", report_a.pulse_frequency, report_b.pulse_frequency);
        return 0;
      end
      /*if (report_a.pulse_start_time !== report_b.pulse_start_time) begin
        $display("pulse_start_time mismatch: %X %X", report_a.pulse_start_time, report_b.pulse_start_time);
        return 0;
      end*/

      /*for (int i = NUM_PULSE_HEADER_WORDS; i < esm_max_words_per_packet; i++) begin
        if (a[i] !== b[i]) begin
          $display("trailer mismatch [%0d]: %X %X", i, a[i], b[i]);
          return 0;
        end
      end*/

    end else begin
      $display("invalid message type: %X", header_a.message_type);
      return 0;
    end

    return 1;
  endfunction

  initial begin
    automatic logic [AXI_DATA_WIDTH - 1 : 0] read_data [$];

    wait_for_reset();

    forever begin
      int channel;
      rpt_rx_intf.read(read_data);

      channel = get_data_channel(read_data);

      if (data_match(read_data, expected_data[channel][0].data)) begin
        $display("%0t: data match successful - %p", $time, read_data);
      end else begin
        $error("%0t: error -- data mismatch on channel=%0d: expected = %p  actual = %p", $time, channel, expected_data[channel][0].data, read_data);
      end
      num_received++;
      void'(expected_data[channel].pop_front());
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

  function automatic void expect_reports(esm_dwell_metadata_t dwell_data, int unsigned dwell_seq_num, dwell_channel_data_t dwell_input []);
    int num_padding_words = 0;
    bit [NUM_CHANNELS - 1 : 0]  pulse_active = '0;
    longint unsigned            pulse_power_accum [NUM_CHANNELS] = {default:0};
    int                         pulse_duration [NUM_CHANNELS] = {default:0};
    int                         pulse_total_count = 0;
    int                         pulse_drop_count = 0;
    bit [NUM_CHANNELS - 1 : 0]  channel_mask = (NUM_CHANNELS < 64) ? dwell_data.channel_mask_wide : dwell_data.channel_mask_narrow;

    //$display("%0t: num_header_words=%0d channels_per_packet=%0d num_packets=%0d", $time, NUM_HEADER_WORDS, channels_per_packet, num_packets);

    for (int i = 0; i < dwell_input.size(); i++) begin
      dwell_channel_data_t di = dwell_input[i];
      int i_ch                = dwell_input[i].channel;

      if (pulse_active[i_ch]) begin
        if (di.pulse_valid) begin
          pulse_duration[i_ch]++;
          pulse_power_accum[i_ch] += di.power;
        end

        if (!di.pulse_valid || (i == (dwell_input.size() - 1))) begin
          expect_t r;
          esm_pdw_pulse_report_header_t report_header;
          pdw_pulse_report_header_bits_t report_header_packed;

          report_header.magic_num             = esm_report_magic_num;
          report_header.sequence_num          = report_seq_num;
          report_header.module_id             = MODULE_ID;
          report_header.message_type          = esm_report_message_type_pdw_pulse;

          report_header.dwell_sequence_num    = dwell_seq_num;
          report_header.pulse_sequence_num    = pulse_seq_num[i_ch];
          report_header.pulse_channel         = i_ch;
          report_header.pulse_threshold       = 0;
          report_header.pulse_power_accum     = pulse_power_accum[i_ch];
          report_header.pulse_duration        = pulse_duration[i_ch];
          report_header.pulse_frequency       = 0;
          report_header.pulse_start_time      = 0;
          report_header.buffered_frame_valid  = 0;
          report_header.buffered_frame_index  = 0;

          report_header_packed = pdw_pulse_report_header_bits_t'(report_header);
          //$display("report_packed: %X", report_header_packed);

          for (int i = 0; i < $size(report_header_packed)/AXI_DATA_WIDTH; i++) begin
            r.data.push_back(report_header_packed[(NUM_PULSE_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]);
          end
          num_padding_words = esm_max_words_per_packet - r.data.size();
          for (int i_padding = 0; i_padding < num_padding_words; i_padding++) begin
            r.data.push_back(0);
          end

          if (pulse_duration[i_ch] >= dwell_data.min_pulse_duration) begin
            $display("pulse_report_header expect: %p", report_header);
            expected_data[i_ch].push_back(r);
            report_seq_num++;
          end else begin
            $display("pulse_report_header drop: %p", report_header);
            pulse_drop_count++;
          end

          pulse_seq_num[i_ch]++;
          pulse_active[i_ch] = 0;
          pulse_duration[i_ch] = 0;
          pulse_power_accum[i_ch] = 0;
        end
      end else if (!pulse_active[i_ch] && di.pulse_valid && channel_mask[i_ch]) begin
        pulse_active[i_ch] = 1;
        pulse_duration[i_ch] = 1;
        pulse_power_accum[i_ch] = di.power;
        pulse_total_count++; //TODO: move above
      end
    end

    assert (!pulse_active) else $error("unexpected pulse_active: %X", pulse_active);

    begin
      expect_t r;
      esm_pdw_summary_report_header_t report_header;
      pdw_summary_report_header_bits_t report_header_packed;

      report_header.magic_num           = esm_report_magic_num;
      report_header.sequence_num        = report_seq_num;
      report_header.module_id           = MODULE_ID;
      report_header.message_type        = esm_report_message_type_pdw_summary;

      report_header.dwell_sequence_num      = dwell_seq_num;
      report_header.dwell_start_time        = 0;
      report_header.dwell_duration          = 0; //TODO
      report_header.dwell_pulse_total_count = pulse_total_count;
      report_header.dwell_pulse_drop_count  = pulse_drop_count;

      report_header_packed = pdw_summary_report_header_bits_t'(report_header);
      //$display("report_packed: %X", report_header_packed);
      $display("pulse_report_header ex: %p", report_header);

      for (int i = 0; i < $size(report_header_packed)/AXI_DATA_WIDTH; i++) begin
        r.data.push_back(report_header_packed[(NUM_SUMMARY_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]);
      end
      num_padding_words = esm_max_words_per_packet - r.data.size();
      for (int i_padding = 0; i_padding < num_padding_words; i_padding++) begin
        r.data.push_back(0);
      end
      expected_data[0].push_back(r);  //summaries are processed in the channel 0 queue
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
    r.threshold_shift_narrow  = $urandom_range(4, 2);
    r.threshold_shift_wide    = $urandom_range(4, 2);

    for (int i = 0; i < esm_num_channels_narrow; i++) begin
      r.channel_mask_narrow[i] = ($urandom_range(99) < 75);
    end
    for (int i = 0; i < esm_num_channels_wide; i++) begin
      r.channel_mask_wide[i] = ($urandom_range(99) < 75);
    end

    if ($urandom_range(99) < 50) begin
      r.min_pulse_duration = 0;
    end else begin
      r.min_pulse_duration = $urandom_range(10);
    end
    return r;
  endfunction

  function automatic dwell_channel_array_t randomize_dwell_input(esm_dwell_metadata_t dwell_data);
    dwell_channel_array_t r;
    dwell_channel_array_t channel_data [NUM_CHANNELS];
    int pulse_start_time [NUM_CHANNELS][$];
    int pulse_duration [NUM_CHANNELS][$];
    int time_offset [NUM_CHANNELS];
    int max_dwell_time = $urandom_range(5000, 500);
    int threshold_shift = (NUM_CHANNELS < 64) ? dwell_data.threshold_shift_wide : dwell_data.threshold_shift_narrow;
    int rnd = 0;

    for (int i = 0; i < NUM_CHANNELS; i++) begin
      pulse_start_time[i].delete();
      pulse_duration[i].delete();
      time_offset[i] = 0;

      if ($urandom_range(99) < 50) begin
        int num_pulses = $urandom_range(10, 1);
        time_offset[i] = $urandom_range(400, 200);

        for (int p = 0; p < num_pulses; p++) begin
          pulse_start_time[i].push_back(time_offset[i]);

          //TODO: bring back a wider range of durations and PRIs
          pulse_duration[i].push_back($urandom_range(10,1));
          /*rnd = $urandom_range(99);
          if (rnd < 25) begin
            pulse_duration[i].push_back($urandom_range(5,1));
          end else if (rnd < 75) begin
            pulse_duration[i].push_back($urandom_range(20,10));
          end else begin
            pulse_duration[i].push_back($urandom_range(200, 50));
          end*/

          time_offset[i] += pulse_duration[i][p];

          rnd = $urandom_range(99);
          time_offset[i] += pulse_duration[i][pulse_duration[i].size() - 1] * $urandom_range(50, 20) + $urandom_range(500, 200);
          /*if (rnd < 10) begin
            time_offset[i] += $urandom_range(64, 32);
          end else if (rnd < 70) begin
            time_offset[i] += $urandom_range(256, 64);
          end else begin
            time_offset[i] += $urandom_range(1024, 256);
          end*/
        end

        if (time_offset[i] > max_dwell_time) begin
          max_dwell_time = time_offset[i];
        end
      end
    end

    max_dwell_time += $urandom_range(200, 50);

    for (int i = 0; i < NUM_CHANNELS; i++) begin
      int noise_floor     = $urandom_range(100, 1);
      int pulse_threshold = noise_floor << threshold_shift;
      channel_data[i] = new[max_dwell_time];

      for (int j = 0; j < max_dwell_time; j++) begin
        channel_data[i][j].channel        = i;
        channel_data[i][j].last           = (i == (NUM_CHANNELS - 1));
        channel_data[i][j].data_i         = $urandom_range(100);
        channel_data[i][j].data_q         = $urandom_range(100);
        channel_data[i][j].power          = $urandom_range(1.5 * noise_floor, 0.5 * noise_floor); //noise floor is the average
        channel_data[i][j].pulse_valid    = 0;
      end

      for (int p = 0; p < pulse_start_time[i].size(); p++) begin
        int ps = pulse_start_time[i][p];
        int pd = pulse_duration[i][p];
        for (int j = ps; j < (ps + pd); j++) begin
          channel_data[i][j].data_i       = $urandom_range(1000);
          channel_data[i][j].data_q       = $urandom_range(1000);
          channel_data[i][j].power        = $urandom_range(pulse_threshold * 4, pulse_threshold * 2);
          channel_data[i][j].pulse_valid  = 1;
          //$display("channel_data[%0d][%0d]: j=%0d   power=%0d  noise_floor=%0d", i, p, j, channel_data[i][j].power, noise_floor);
        end

        $display("channel[%0d] pulse[%0d]: start=%0d  duration=%0d", i, p, ps, pd);
      end
    end

    r = new [NUM_CHANNELS * max_dwell_time];

    for (int i = 0; i < r.size(); i++) begin
      int channel_index = i % NUM_CHANNELS;
      int sample_index = i / NUM_CHANNELS;
      r[i] = channel_data[channel_index][sample_index];
    end

    return r;
  endfunction

  task automatic standard_test();
    parameter NUM_TESTS = 5;
    parameter NUM_DWELLS = (NUM_CHANNELS < 64) ? 10 : 2;
    int max_write_delay = 5;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      $display("%0t: Test started - max_write_delay=%0d", $time, max_write_delay);
      report_seq_num = 0;
      pulse_seq_num = {default:0};

      for (int i_dwell = 0; i_dwell < NUM_DWELLS; i_dwell++) begin
        int unsigned          dwell_seq_num   = $urandom;
        esm_dwell_metadata_t  dwell_data      = randomize_dwell_metadata();
        dwell_channel_data_t  dwell_input []  = randomize_dwell_input(dwell_data);

        expect_reports(dwell_data, dwell_seq_num, dwell_input);
        dwell_tx_intf.write(dwell_data, dwell_seq_num, dwell_input);

        repeat(1000) @(posedge Clk);

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

      end

      $display("%0t: Test finished: num_received = %0d", $time, num_received);
      Rst = 1;
      repeat(3000) @(posedge Clk);
      Rst = 0;
      repeat(100) @(posedge Clk);
    end
  endtask

  initial
  begin
    dwell_tx_intf.clear();
    wait_for_reset();
    standard_test();
    repeat(100) @(posedge Clk);
    $finish;
  end

endmodule
