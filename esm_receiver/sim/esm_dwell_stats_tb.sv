`timescale 1ns/1ps

import math::*;
import esm_pkg::*;
import dsp_pkg::*;

typedef struct {
  int channel;
  bit last;
  int unsigned power;
} dwell_channel_data_t;

typedef dwell_channel_data_t dwell_channel_array_t [];

interface dwell_stats_tx_intf (input logic Clk);
  logic                                         dwell_active = 0;
  esm_dwell_entry_t                             dwell_data;
  logic [esm_dwell_sequence_num_width - 1 : 0]  dwell_sequence_num;

  channelizer_control_t                         input_ctrl = '{valid:0, default:0};
  logic [chan_power_width - 1 : 0]              input_pwr;

  task write(esm_dwell_entry_t data, int unsigned seq_num, dwell_channel_data_t input_data []);
    automatic dwell_channel_data_t d;

    dwell_active        = 1;
    dwell_data          = data;
    dwell_sequence_num  = seq_num;

    repeat (5) @(posedge Clk);

    //$display("%0t: input_data = %p", $time, input_data);

    for (int i = 0; i < input_data.size(); i++) begin
      d = input_data[i];

      input_ctrl.valid      = 1;
      input_ctrl.last       = d.last;
      input_ctrl.data_index = d.channel;
      input_pwr             = d.power;
      @(posedge Clk);
      input_ctrl.valid      = 0;
      input_ctrl.last       = 'x;
      input_ctrl.data_index = 'x;
      input_pwr             = 'x;
      repeat($urandom_range(1,0)) @(posedge Clk);
    end

    dwell_active        = 0;
    dwell_data          = '{default: 'x};
    dwell_sequence_num  = 'x;
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

module esm_dwell_stats_tb;
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

    bit [31:0]  dwell_sequence_num;

    bit [15:0]  tag;
    bit [15:0]  frequency;
    bit [31:0]  duration_requested;
    bit [7:0]   gain;
    bit [7:0]   fast_lock_profile;
    bit [7:0]   num_channels;
    bit [7:0]   report_starting_channel;
    bit [2:0]   padding_t0;
    bit [4:0]   threshold_shift_narrow;
    bit [2:0]   padding_t1;
    bit [4:0]   threshold_shift_wide;
    bit [15:0]  padding_1;
    bit [31:0]  padding_2;
    bit [63:0]  channel_mask_narrow;
    bit [7:0]   channel_mask_wide;
    bit [23:0]  padding_3;

    bit [31:0]  duration_actual;
    bit [31:0]  num_samples;
    bit [63:0]  ts_dwell_start;
    bit [63:0]  ts_dwell_end;
  } esm_dwell_report_header_t;

  typedef struct packed
  {
    bit [31:0]  channel_index;
    bit [63:0]  channel_accum;
    bit [31:0]  channel_max;
  } esm_dwell_report_channel_entry_t;

  typedef bit [$bits(esm_dwell_report_header_t) - 1 : 0]        dwell_report_header_bits_t;
  typedef bit [$bits(esm_dwell_report_channel_entry_t) - 1 : 0] dwell_report_channel_entry_bits_t;

  parameter NUM_HEADER_WORDS = ($bits(esm_dwell_report_header_t) / AXI_DATA_WIDTH);

  logic Clk_axi;
  logic Clk;
  logic Rst;

  dwell_stats_tx_intf                             dwell_tx_intf (.*);
  axi_rx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  rpt_rx_intf   (.Clk(Clk_axi));

  int unsigned  report_seq_num = 0;
  expect_t      expected_data [$];
  int           num_received = 0;
  logic         r_axi_rx_ready;
  logic         w_axi_rx_valid;
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
    repeat(10) @(posedge Clk);
    Rst = 0;
  end

  always_ff @(posedge Clk_axi) begin
    r_axi_rx_ready <= $urandom_range(99) < 80;
  end

  esm_dwell_stats
  #(
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .DATA_WIDTH     (16),
    .NUM_CHANNELS   (NUM_CHANNELS),
    .MODULE_ID      (MODULE_ID)
  )
  dut
  (
    .Clk_axi                  (Clk_axi),
    .Clk                      (Clk),
    .Rst                      (Rst),

    .Enable                   (1'b1),

    .Dwell_active             (dwell_tx_intf.dwell_active),
    .Dwell_data               (dwell_tx_intf.dwell_data),
    .Dwell_sequence_num       (dwell_tx_intf.dwell_sequence_num),

    .Input_ctrl               (dwell_tx_intf.input_ctrl),
    .Input_data               (),
    .Input_pwr                (dwell_tx_intf.input_pwr),

    .Axis_ready               (r_axi_rx_ready),
    .Axis_valid               (w_axi_rx_valid),
    .Axis_data                (rpt_rx_intf.data),
    .Axis_last                (rpt_rx_intf.last),

    .Error_reporter_timeout   (w_error_reporter_timeout),
    .Error_reporter_overflow  (w_error_reporter_overflow)
  );

  assign rpt_rx_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

  always_ff @(posedge Clk) begin
    if (!Rst) begin
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

  function automatic esm_dwell_report_header_t unpack_report_header(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    esm_dwell_report_header_t   report_header;
    dwell_report_header_bits_t  packed_report_header;

    //$display("unpack_report: data=%p", data);

    for (int i = 0; i < $size(packed_report_header)/AXI_DATA_WIDTH; i++) begin
      //$display("unpack_report_header [%0d] = %X", i, data[0]);
      packed_report_header[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_front();
    end

    //$display("unpack_report: packed=%X", packed_report_header);

    report_header = esm_dwell_report_header_t'(packed_report_header);
    return report_header;
  endfunction


  function automatic bit data_match(logic [AXI_DATA_WIDTH - 1 : 0] a [$], logic [AXI_DATA_WIDTH - 1 : 0] b []);
    esm_dwell_report_header_t report_a = unpack_report_header(a);
    esm_dwell_report_header_t report_b = unpack_report_header(b);

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

    if (report_a.dwell_sequence_num !== report_b.dwell_sequence_num) begin
      $display("dwell_sequence_num mismatch: %X %X", report_a.dwell_sequence_num, report_b.dwell_sequence_num);
      return 0;
    end

    if (report_a.tag !== report_b.tag) begin
      $display("tag mismatch: %X %X", report_a.tag, report_b.tag);
      return 0;
    end
    if (report_a.frequency !== report_b.frequency) begin
      $display("frequency mismatch: %X %X", report_a.frequency, report_b.frequency);
      return 0;
    end
    if (report_a.duration_requested !== report_b.duration_requested) begin
      $display("duration_requested mismatch: %X %X", report_a.duration_requested, report_b.duration_requested);
      return 0;
    end
    if (report_a.gain !== report_b.gain) begin
      $display("gain mismatch: %X %X", report_a.gain, report_b.gain);
      return 0;
    end
    if (report_a.fast_lock_profile !== report_b.fast_lock_profile) begin
      $display("fast_lock_profile mismatch: %X %X", report_a.fast_lock_profile, report_b.fast_lock_profile);
      return 0;
    end
    if (report_a.num_channels !== report_b.num_channels) begin
      $display("num_channels mismatch: %X %X", report_a.num_channels, report_b.num_channels);
      return 0;
    end
    if (report_a.report_starting_channel !== report_b.report_starting_channel) begin
      $display("report_starting_channel mismatch: %X %X", report_a.report_starting_channel, report_b.report_starting_channel);
      return 0;
    end
    if (report_a.threshold_shift_narrow !== report_b.threshold_shift_narrow) begin
      $display("threshold_shift_narrow mismatch: %X %X", report_a.threshold_shift_narrow, report_b.threshold_shift_narrow);
      return 0;
    end
    if (report_a.threshold_shift_wide !== report_b.threshold_shift_wide) begin
      $display("threshold_shift_wide mismatch: %X %X", report_a.threshold_shift_wide, report_b.threshold_shift_wide);
      return 0;
    end
    if (report_a.channel_mask_narrow !== report_b.channel_mask_narrow) begin
      $display("channel_mask_narrow mismatch: %X %X", report_a.channel_mask_narrow, report_b.channel_mask_narrow);
      return 0;
    end
    if (report_a.channel_mask_wide !== report_b.channel_mask_wide) begin
      $display("channel_mask_wide mismatch: %X %X", report_a.channel_mask_wide, report_b.channel_mask_wide);
      return 0;
    end

    /*
    if (report_a.duration_actual !== report_b.duration_actual) begin
      $display("duration_actual mismatch: %X %X", report_a.duration_actual, report_b.duration_actual);
      return 0;
    end
    */
    if (report_a.num_samples !== report_b.num_samples) begin
      $display("num_samples mismatch: %X %X", report_a.num_samples, report_b.num_samples);
      return 0;
    end

    for (int i = NUM_HEADER_WORDS; i < esm_max_words_per_packet; i++) begin
      if (a[i] !== b[i]) begin
        $display("trailer mismatch [%0d]: %X %X", i, a[i], b[i]);
        return 0;
      end
    end

    //TODO: check channel data

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

  function automatic void expect_reports(esm_dwell_entry_t dwell_data, int unsigned dwell_seq_num, dwell_channel_data_t  dwell_input []);
    int channels_per_packet = (esm_max_words_per_packet - NUM_HEADER_WORDS) / 4;
    int num_packets = (NUM_CHANNELS + channels_per_packet - 1) / channels_per_packet;
    int num_padding_words = 0;
    int channel_index = 0;

    longint unsigned channel_accum [NUM_CHANNELS] = '{default:0};
    int unsigned channel_max [NUM_CHANNELS] = '{default:0};

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

      num_padding_words = esm_max_words_per_packet - r.data.size();
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
    end
  endfunction

  function automatic esm_dwell_entry_t randomize_dwell_entry();
    esm_dwell_entry_t r;
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

  task automatic standard_test();
    parameter NUM_TESTS = 20;
    int max_write_delay = 5;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      $display("%0t: Test started - max_write_delay=%0d", $time, max_write_delay);
      report_seq_num = 0;

      for (int i_dwell = 0; i_dwell < 100; i_dwell++) begin
        int unsigned          dwell_seq_num   = $urandom;
        esm_dwell_entry_t     dwell_data      = randomize_dwell_entry();
        dwell_channel_data_t  dwell_input []  = randomize_dwell_input();

        expect_reports(dwell_data, dwell_seq_num, dwell_input);
        dwell_tx_intf.write(dwell_data, dwell_seq_num, dwell_input);

        repeat(1000) @(posedge Clk);

        begin
          int wait_cycles = 0;
          while ((expected_data.size() != 0) && (wait_cycles < 1e5)) begin
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
    wait_for_reset();
    standard_test();
    repeat(100) @(posedge Clk);
    $finish;
  end

endmodule
