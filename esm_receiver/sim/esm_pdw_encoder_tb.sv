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
} dwell_channel_data_t;

typedef dwell_channel_data_t dwell_channel_array_t [];

interface dwell_data_tx_intf (input logic Clk);
  logic                                         dwell_active = 0;
  esm_dwell_metadata_t                          dwell_data;
  logic [esm_dwell_sequence_num_width - 1 : 0]  dwell_sequence_num;

  channelizer_control_t                         input_ctrl = {valid:0, default:0};
  logic [chan_power_width - 1 : 0]              input_pwr;
  logic signed [15:0]                           input_data [1:0];

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
      input_pwr             = d.power;
      input_data[0]         = d.data_i;
      input_data[1]         = d.data_q;
      @(posedge Clk);
      input_ctrl.valid      = 0;
      input_ctrl.last       = 'x;
      input_ctrl.data_index = 'x;
      input_pwr             = 'x;
      input_data[0]         = 'x;
      input_data[1]         = 'x;
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

module esm_pdw_encoder_tb;
  parameter time CLK_HALF_PERIOD  = 8ns;
  parameter AXI_DATA_WIDTH        = 32;
  parameter logic [7:0] MODULE_ID = 99;
  parameter NUM_CHANNELS          = 64;

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
    bit [31:0]  dwell_pulse_count;
  } esm_pdw_summary_report_header_t;

  typedef bit [$bits(esm_pdw_report_header_t) - 1 : 0]          pdw_report_header_bits_t;
  typedef bit [$bits(esm_pdw_pulse_report_header_t) - 1 : 0]    pdw_pulse_report_header_bits_t;
  typedef bit [$bits(esm_pdw_summary_report_header_t) - 1 : 0]  pdw_summary_report_header_bits_t;

  parameter MAX_WORDS_PER_PACKET      = 64;
  parameter NUM_HEADER_WORDS          = ($bits(pdw_report_header_bits_t) / AXI_DATA_WIDTH);
  parameter NUM_PULSE_HEADER_WORDS    = ($bits(pdw_pulse_report_header_bits_t) / AXI_DATA_WIDTH);
  parameter NUM_SUMMARY_HEADER_WORDS  = ($bits(pdw_summary_report_header_bits_t) / AXI_DATA_WIDTH);

  logic Clk;
  logic Rst;

  dwell_data_tx_intf                              dwell_tx_intf (.*);
  axi_rx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  rpt_rx_intf   (.*);

  int unsigned  report_seq_num = 0;
  int unsigned  pulse_seq_num = 0;
  expect_t      expected_data [$];
  int           num_received = 0;
  logic         r_axi_rx_ready;
  logic         w_axi_rx_valid;

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

  esm_pdw_encoder
  #(
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .DATA_WIDTH     (16),
    .NUM_CHANNELS   (NUM_CHANNELS),
    .MODULE_ID      (MODULE_ID),
    .WIDE_BANDWIDTH (NUM_CHANNELS < 64)
  )
  dut
  (
    .Clk                (Clk),
    .Rst                (Rst),

    .Enable             (1'b1),

    .Dwell_active       (dwell_tx_intf.dwell_active),
    .Dwell_data         (dwell_tx_intf.dwell_data),
    .Dwell_sequence_num (dwell_tx_intf.dwell_sequence_num),

    .Input_ctrl         (dwell_tx_intf.input_ctrl),
    .Input_data         (dwell_tx_intf.input_data),
    .Input_pwr          (dwell_tx_intf.input_pwr),

    .Axis_ready         (r_axi_rx_ready),
    .Axis_valid         (w_axi_rx_valid),
    .Axis_data          (rpt_rx_intf.data),
    .Axis_last          (rpt_rx_intf.last)
  );

  assign rpt_rx_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

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

  function automatic bit data_match(logic [AXI_DATA_WIDTH - 1 : 0] a [$], logic [AXI_DATA_WIDTH - 1 : 0] b []);
    esm_pdw_report_header_t header_a = unpack_report_header(a);
    esm_pdw_report_header_t header_b = unpack_report_header(b);

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

    if (header_a.message_type == esm_report_message_type_pdw_summary) begin
      esm_pdw_summary_report_header_t report_a = unpack_summary_report_header(a);
      esm_pdw_summary_report_header_t report_b = unpack_summary_report_header(b);

      //TODO: check dwell_duration

      if (report_a.dwell_sequence_num !== report_b.dwell_sequence_num) begin
        $display("dwell_sequence_num mismatch: %X %X", report_a.dwell_sequence_num, report_b.dwell_sequence_num);
        return 0;
      end

      if (report_a.pulse_count !== report_b.pulse_count) begin
        $display("pulse_count mismatch: %X %X", report_a.pulse_count, report_b.pulse_count);
        return 0;
      end

      for (int i = NUM_SUMMARY_HEADER_WORDS; i < MAX_WORDS_PER_PACKET; i++) begin
        if (a[i] !== b[i]) begin
          $display("trailer mismatch [%0d]: %X %X", i, a[i], b[i]);
          return 0;
        end
      end

    end else if (header_a.message_type == esm_report_message_type_pdw_pulse) begin
      esm_pdw_pulse_report_header_t report_a = unpack_pulse_report_header(a);
      esm_pdw_pulse_report_header_t report_b = unpack_pulse_report_header(b);

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
      if (report_a.pulse_threshold !== report_b.pulse_threshold) begin
        $display("pulse_threshold mismatch: %X %X", report_a.pulse_threshold, report_b.pulse_threshold);
        return 0;
      end
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

      for (int i = NUM_PULSE_HEADER_WORDS; i < MAX_WORDS_PER_PACKET; i++) begin
        if (a[i] !== b[i]) begin
          $display("trailer mismatch [%0d]: %X %X", i, a[i], b[i]);
          return 0;
        end
      end

    end else begin
      $display("invalid message type: %X", header_a.message_type);
      return 0;
    end if;

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

  function automatic void expect_reports(esm_dwell_metadata_t dwell_data, int unsigned dwell_seq_num, dwell_channel_data_t dwell_input []);
    int num_padding_words = 0;
    bit [NUM_CHANNELS - 1 : 0]  pulse_active = '0;
    longint unsigned            pulse_power_accum [NUM_CHANNELS] = {default:0};
    int                         pulse_duration [NUM_CHANNELS] = {default:0};
    int                         pulse_count = 0;

    int unsigned new_threshold = (NUM_CHANNELS < 64) ? dwell_data.threshold_wide : dwell_data.threshold_narrow;
    int unsigned continued_threshold = new_threshold / 2;

    //$display("%0t: num_header_words=%0d channels_per_packet=%0d num_packets=%0d", $time, NUM_HEADER_WORDS, channels_per_packet, num_packets);

    for (int i = 0; i < dwell_input.size(); i++) begin
      dwell_channel_data_t di = dwell_input[i];
      int i_ch                = dwell_input[i].channel;

      if (pulse_active[i_ch]) begin
        pulse_duration[i_ch]++;
        pulse_power_accum[i_ch] += di.power;

        if ((di.power <= continued_threshold) or (i == (dwell_input.size() - 1))) begin
          expect_t r;
          esm_pdw_pulse_report_header_t report_header;
          pdw_pulse_report_header_bits_t report_header_packed;

          report_header.magic_num           = esm_report_magic_num;
          report_header.sequence_num        = report_seq_num;
          report_header.module_id           = MODULE_ID;
          report_header.message_type        = esm_report_message_type_pdw_pulse;

          report_header.dwell_sequence_num  = dwell_seq_num;
          report_header.pulse_sequence_num  = pulse_seq_num;
          report_header.pulse_channel       = i_ch;
          report_header.pulse_threshold     = new_threshold;
          report_header.pulse_power_accum   = pulse_power_accum[i_ch];
          report_header.pulse_duration      = pulse_duration[i_ch];
          report_header.pulse_frequency     = 0;
          report_header.pulse_start_time    = 0;

          report_header_packed = pdw_pulse_report_header_bits_t'(report_header);
          //$display("report_packed: %X", report_header_packed);
          $display("pulse_report_header: %p", report_header);

          for (int i = 0; i < $size(report_header_packed)/AXI_DATA_WIDTH; i++) begin
            r.data.push_back(report_header_packed[(NUM_PULSE_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]);
          end
          num_padding_words = MAX_WORDS_PER_PACKET - r.data.size();
          for (int i_padding = 0; i_padding < num_padding_words; i_padding++) begin
            r.data.push_back(0);
          end
          expected_data.push_back(r);
          report_seq_num++;

          pulse_seq_num++;
          pulse_active[i_ch] = 0;
          pulse_duration[i_ch] = 0;
          pulse_power_accum[i_ch] = 0;
        end
      end else if (!pulse_active[i_ch] && (di.power > new_threshold)) begin
        pulse_active[i_ch] = 1;
        pulse_duration[i_ch] = 1;
        pulse_power_accum[i_ch] = di.power;
        pulse_count++;
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

      report_header.dwell_sequence_num  = dwell_seq_num;
      report_header.dwell_start_time    = 0;
      report_header.dwell_duration      = 0; //TODO
      report_header.dwell_pulse_count   = pulse_count;

      report_header_packed = pdw_summary_report_header_bits_t'(report_header);
      //$display("report_packed: %X", report_header_packed);
      $display("pulse_report_header: %p", report_header);

      for (int i = 0; i < $size(report_header_packed)/AXI_DATA_WIDTH; i++) begin
        r.data.push_back(report_header_packed[(NUM_SUMMARY_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]);
      end
      num_padding_words = MAX_WORDS_PER_PACKET - r.data.size();
      for (int i_padding = 0; i_padding < num_padding_words; i_padding++) begin
        r.data.push_back(0);
      end
      expected_data.push_back(r);
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
    r.threshold_narrow        = $urandom_range(10e6, 1000);
    r.threshold_wide          = $urandom_range(10e6, 1000);
    r.channel_mask_narrow     = {$urandom, $urandom};
    r.channel_mask_wide       = $urandom;
    return r;
  endfunction

  function automatic dwell_channel_array_t randomize_dwell_input(esm_dwell_metadata_t dwell_data);
    dwell_channel_array_t r; // = new [$urandom_range(10000, 500)];
    dwell_channel_array_t channel_data [NUM_CHANNELS][];
    int pulse_start_time [NUM_CHANNELS][$];
    int pulse_duration [NUM_CHANNELS][$];
    int time_offset [NUM_CHANNELS];
    int max_dwell_time = $urandom_range(10000, 500);
    int threshold = (NUM_CHANNELS < 64) ? dwell_data.threshold_wide : dwell_data.threshold_narrow;
    int rnd = 0;

    for (int i = 0; i < NUM_CHANNELS; i++) begin
      pulse_start_time[i].delete();
      pulse_duration[i].delete();
      time_offset[i] = 0;

      if ($urandom_range(99) < 50) begin
        time_offset[i] = $urandom_range(100);
        int num_pulses = $urandom_range(10, 1);

        for (int p = 0; p < num_pulses; p++) begin
          pulse_start_time[i].push_back(time_offset[i]);

          rnd = $urandom_range(99);
          if (rnd < 25) begin
            pulse_duration[i].push_back($urandom_range(5,1));
          end else if (rnd < 50) begin
            pulse_duration[i].push_back($urandom_range(50,10));
          end else if (rnd < 75) begin
            pulse_duration[i].push_back($urandom_range(500,100));
          end else begin
            pulse_duration[i].push_back($urandom_range(5000,1000));
          end

          time_offset[i] += pulse_duration[i][p];

          rnd = $urandom_range(99);
          if (rnd < 30) begin
            time_offset[i] += $urandom_range(10, 5);
          end else if (rnd < 70) begin
            time_offset[i] += $urandom_range(100, 20);
          end else begin
            time_offset[i] += $urandom_range(1000, 200);
          end
        end

        if (time_offset[i] > max_dwell_time) begin
          max_dwell_time = time_offset[i];
        end
      end
    end

    max_dwell_time += $urandom_range(100, 10);

    for (int i = 0; i < NUM_CHANNELS; i++) begin
      channel_data[i] = new[max_dwell_time];

      for (int j = 0; j < max_dwell_time; j++) begin
        channel_data[i][j].channel_index  = i;
        channel_data[i][j].last           = (i == (NUM_CHANNELS - 1));
        channel_data[i][j].data_i         = $urandom_range(100);
        channel_data[i][j].data_q         = $urandom_range(100);
        channel_data[i][j].power          = $urandom_range(threshold / 4, 1);
      end

      for (int p = 0; p < pulse_start_time[i].size(); p++) begin
        int ps = pulse_start_time[i][p];
        int pd = pulse_duration[i][p];
        for (int j = ps; j < (ps + pd); j++) begin
          channel_data[i][j].data_i = $urandom_range(1000);
          channel_data[i][j].data_q = $urandom_range(1000);
          channel_data[i][j].power  = $urandom_range(threshold * 2, threshold + 1);
        end
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
    parameter NUM_TESTS = 20;
    int max_write_delay = 5;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      $display("%0t: Test started - max_write_delay=%0d", $time, max_write_delay);
      report_seq_num = 0;
      pulse_seq_num = 0;

      for (int i_dwell = 0; i_dwell < 100; i_dwell++) begin
        int unsigned          dwell_seq_num   = $urandom;
        esm_dwell_metadata_t  dwell_data      = randomize_dwell_metadata();
        dwell_channel_data_t  dwell_input []  = randomize_dwell_input(dwell_data);

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
