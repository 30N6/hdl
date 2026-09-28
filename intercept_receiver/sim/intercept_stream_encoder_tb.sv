`timescale 1ns/1ps

import math::*;
import intercept_pkg::*;
import dsp_pkg::*;

typedef struct {
  int channel;
  bit last;
  int unsigned power;
  bit signed [15:0] iq [1:0];
} channelizer_data_t;

typedef channelizer_data_t channelizer_data_array_t [];

interface channelizer_tx_intf #(parameter DATA_WIDTH) (input logic Clk);
  channelizer_control_t             input_ctrl = '{valid:0, default:0};
  logic [chan_power_width - 1 : 0]  input_pwr;
  logic signed [DATA_WIDTH - 1 : 0] input_iq [1:0];

  task write(channelizer_data_t input_data []);
    automatic channelizer_data_t d;

    repeat (5) @(posedge Clk);

    //$display("%0t: input_data = %p", $time, input_data);

    for (int i = 0; i < input_data.size(); i++) begin
      d = input_data[i];

      input_ctrl.valid      = 1;
      input_ctrl.last       = d.last;
      input_ctrl.data_index = d.channel;
      input_pwr             = d.power;
      input_iq[0]           = d.iq[0];
      input_iq[1]           = d.iq[1];
      @(posedge Clk);
      input_ctrl.valid      = 0;
      input_ctrl.last       = 'x;
      input_ctrl.data_index = 'x;
      input_pwr             = 'x;
      input_iq              = '{default: 'x};
      repeat($urandom_range(1,0)) @(posedge Clk);
    end
  endtask
endinterface

interface axi_tx_intf #(parameter AXI_DATA_WIDTH) (input logic Clk);
  logic                           valid = 0;
  logic                           last;
  logic [AXI_DATA_WIDTH - 1 : 0]  data;
  logic                           ready;

  task write(input bit [AXI_DATA_WIDTH - 1 : 0] d []);
    for (int i = 0; i < d.size(); i++) begin
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

module intercept_stream_encoder_tb;
  parameter time CLK_HALF_PERIOD      = 2ns;
  parameter time AXI_CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH            = 32;
  parameter DATA_WIDTH                = 25;

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
    bit [31:0]  padding_1;

    bit [31:0]  dwell_seq_num;
    bit [31:0]  dwell_frequency;
    bit [15:0]  dwell_tag;
    bit [15:0]  padding_2;
    bit [31:0]  padding_3;

    bit [63:0]  timestamp;
  } intercept_stream_report_header_t;

  typedef struct packed
  {
    bit [7:0]         trigger_type;
    bit [7:0]         stream_index;
    bit [15:0]        channel_index;
    bit [31:0]        sample_index;
    bit signed [31:0] data_i;
    bit signed [31:0] data_q;
  } intercept_stream_sample_entry_t;

  typedef bit [$bits(intercept_stream_report_header_t) - 1 : 0] intercept_stream_report_header_bits_t;
  typedef bit [$bits(intercept_stream_sample_entry_t) - 1 : 0]  intercept_stream_sample_entry_bits_t;

  parameter NUM_HEADER_WORDS = ($bits(intercept_stream_report_header_t) / AXI_DATA_WIDTH);

  logic Clk_axi;
  logic Clk;
  logic Rst;

  axi_tx_intf         #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  cfg_tx_intf         (.Clk(Clk_axi));
  channelizer_tx_intf #(.DATA_WIDTH(DATA_WIDTH))          channelizer_tx_intf (.*);
  axi_rx_intf         #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  rpt_rx_intf         (.Clk(Clk_axi));

  int unsigned  report_seq_num = 0;
  int unsigned  dwell_seq_num = 1;
  expect_t      expected_data [$];
  int           num_received = 0;
  bit [31:0]    config_seq_num = 0;

  intercept_message_dwell_controller_control_t        dwell_data                              = '{default:0};
  intercept_message_stream_encoder_channel_control_t  m_channel_data [intercept_num_channels] = '{default:0};
  bit [intercept_num_streams-1:0]                     stream_enable                           = '0;

  logic                   w_rst_out;
  logic                   w_enable_chan;
  logic                   w_enable_stream;
  logic                   w_enable_status;
  intercept_config_data_t w_module_config;
  intercept_dwell_data_t  w_dwell_data;
  logic                   w_dwell_active;
  logic                   r_axi_rx_ready;
  logic                   w_axi_rx_valid;
  logic                   w_error_fifo_overflow;
  logic                   w_error_fifo_underflow;
  logic                   w_error_reporter_timeout;
  logic                   w_error_reporter_overflow;

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
    repeat(1000) @(posedge Clk);
    Rst = 0;
  end

  always_ff @(posedge Clk_axi) begin
    r_axi_rx_ready <= $urandom_range(99) < 80;
  end

  intercept_config #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH)) cfg
  (
    .Clk_x4         (Clk),

    .S_axis_clk     (Clk_axi),
    .S_axis_resetn  (!Rst),
    .S_axis_ready   (cfg_tx_intf.ready),
    .S_axis_valid   (cfg_tx_intf.valid),
    .S_axis_data    (cfg_tx_intf.data),
    .S_axis_last    (cfg_tx_intf.last),

    .Rst_out        (w_rst_out),
    .Enable_status  (w_enable_status),
    .Enable_chan    (w_enable_chan),
    .Enable_stream  (w_enable_stream),

    .Module_config  (w_module_config)
  );

  intercept_dwell_controller dwell_ctrl
  (
    .Clk            (Clk),
    .Rst            (Rst),

    .Module_config  (w_module_config),

    .Dwell_data     (w_dwell_data),
    .Dwell_active   (w_dwell_active)
  );

  intercept_stream_encoder
  #(
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .DATA_WIDTH     (DATA_WIDTH)
  )
  dut
  (
    .Clk_axi                  (Clk_axi),
    .Clk                      (Clk),
    .Rst                      (Rst),

    .Enable                   (1'b1),
    .Module_config            (w_module_config),

    .Dwell_data               (w_dwell_data),
    .Dwell_active             (w_dwell_active),

    .Input_ctrl               (channelizer_tx_intf.input_ctrl),
    .input_data               (channelizer_tx_intf.input_iq),
    .Input_pwr                (channelizer_tx_intf.input_pwr),

    .Axis_ready               (r_axi_rx_ready),
    .Axis_valid               (w_axi_rx_valid),
    .Axis_data                (rpt_rx_intf.data),
    .Axis_last                (rpt_rx_intf.last),

    .Error_fifo_overflow      (w_error_fifo_overflow),
    .Error_fifo_underflow     (w_error_fifo_underflow),
    .Error_reporter_timeout   (w_error_reporter_timeout),
    .Error_reporter_overflow  (w_error_reporter_overflow)
  );

  assign rpt_rx_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

  always_ff @(posedge Clk) begin
    if (!Rst) begin
      if (w_error_fifo_overflow)      $error("fifo overflow");
      if (w_error_fifo_underflow)     $error("fifo underflow");
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

  task automatic write_config(bit [31:0] config_data []);
    @(posedge Clk_axi)
    cfg_tx_intf.write(config_data);
    repeat(10) @(posedge Clk_axi);
  endtask

  function automatic bit [intercept_message_dwell_controller_control_aligned_width - 1 : 0] pack_intercept_message_dwell_controller_control(intercept_message_dwell_controller_control_t data);
    bit [intercept_message_dwell_controller_control_aligned_width - 1 : 0] r;

    r[0]      = data.enable;
    r[31:16]  = data.dwell_tag;
    r[63:32]  = data.dwell_frequency;
    r[95:64]  = data.window_duration;

    return r;
  endfunction

  function automatic [intercept_message_stream_encoder_channel_control_aligned_width - 1 : 0] pack_intercept_message_stream_encoder_channel_control(intercept_message_stream_encoder_channel_control_t data);
    bit [intercept_message_stream_encoder_channel_control_aligned_width - 1 : 0] r;

    r[0]        = data.enable;
    r[8]        = data.force_trigger;
    r[23:16]    = data.force_stream;
    r[47:32]    = data.stream_encoder_tag;
    r[95:64]    = data.threshold_start;
    r[127:96]   = data.threshold_continue;
    r[159:128]  = data.coast_cycles;
    r[191:160]  = data.integration_cycles;

    return r;
  endfunction

  function automatic [intercept_message_stream_encoder_stream_control_aligned_width - 1 : 0] pack_intercept_message_stream_encoder_stream_control(intercept_message_stream_encoder_stream_control_t data);
    bit [intercept_message_stream_encoder_stream_control_aligned_width - 1 : 0] r;

    r[0]      = data.enable;
    r[31:16]  = data.stream_encoder_tag;

    return r;
  endfunction

  function automatic intercept_message_dwell_controller_control_t randomize_dwell_controller_control();
    intercept_message_dwell_controller_control_t r;
    r.enable          = 1;
    r.dwell_tag       = $urandom;
    r.dwell_frequency = $urandom;
    r.window_duration = $urandom;

    return r;
  endfunction

  function automatic intercept_message_stream_encoder_channel_control_t randomize_channel_control();
    intercept_message_stream_encoder_channel_control_t r;

    r.enable              = $urandom;
    r.force_trigger       = 0;
    r.force_stream        = $urandom;
    r.stream_encoder_tag  = $urandom;
    r.threshold_start     = $urandom_range(255, 128);
    r.threshold_continue  = $urandom_range(127, 64);
    r.coast_cycles        = $urandom_range(32, 8);
    r.integration_cycles  = 0;

    return r;
  endfunction

  function automatic intercept_message_stream_encoder_stream_control_t randomize_stream_control();
    intercept_message_stream_encoder_stream_control_t r;
    r.enable              = $urandom;
    r.stream_encoder_tag  = $urandom;

    return r;
  endfunction

  task automatic send_dwell_controller_control(intercept_message_dwell_controller_control_t data);
    bit [31:0] config_data [] = new[4 + intercept_message_dwell_controller_control_aligned_width/32];
    bit [intercept_message_dwell_controller_control_aligned_width - 1 : 0] packed_control = pack_intercept_message_dwell_controller_control(data);

    $display("%0t: sending dwell controller control: %p", $time, data);

    config_data[0] = intercept_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {intercept_module_id_dwell_controller, intercept_control_message_type_dwell_controller_config, 16'h0000};
    config_data[3] = 32'hDEADBEEF;

    for (int i = 0; i < intercept_message_dwell_controller_control_aligned_width/32; i++) begin
      config_data[4 + i] = packed_control[i*32 +: 32];
    end

    write_config(config_data);

    dwell_data = data;
  endtask

  task automatic send_channel_control(intercept_message_stream_encoder_channel_control_t data, bit [15:0] address);
    bit [31:0] config_data [] = new[4 + intercept_message_stream_encoder_channel_control_aligned_width/32];
    bit [intercept_message_stream_encoder_channel_control_aligned_width - 1 : 0] packed_control = pack_intercept_message_stream_encoder_channel_control(data);

    $display("%0t: sending channel control [%0d]: %p", $time, address, data);

    config_data[0] = intercept_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {intercept_module_id_stream_encoder, intercept_control_message_type_channel_config, address};
    config_data[3] = 32'hDEADBEEF;

    for (int i = 0; i < intercept_message_stream_encoder_channel_control_aligned_width/32; i++) begin
      config_data[4 + i] = packed_control[i*32 +: 32];
    end

    write_config(config_data);

    m_channel_data[address] = data;
  endtask

  task automatic send_stream_control(intercept_message_stream_encoder_stream_control_t data, bit [15:0] address);
    bit [31:0] config_data [] = new[4 + intercept_message_stream_encoder_stream_control_aligned_width/32];
    bit [intercept_message_stream_encoder_stream_control_aligned_width - 1 : 0] packed_control = pack_intercept_message_stream_encoder_stream_control(data);

    $display("%0t: sending stream control [%0d]: %p", $time, address, data);

    config_data[0] = intercept_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {intercept_module_id_stream_encoder, intercept_control_message_type_stream_config, address};
    config_data[3] = 32'hDEADBEEF;

    for (int i = 0; i < intercept_message_stream_encoder_stream_control_aligned_width/32; i++) begin
      config_data[4 + i] = packed_control[i*32 +: 32];
    end

    write_config(config_data);

    stream_enable[address] = data.enable;
  endtask

  function automatic intercept_stream_report_header_t unpack_report_header(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    intercept_stream_report_header_t      report_header;
    intercept_stream_report_header_bits_t packed_report_header;

    //$display("unpack_report: data=%p", data);

    for (int i = 0; i < $size(packed_report_header)/AXI_DATA_WIDTH; i++) begin
      //$display("unpack_report_header [%0d] = %X", i, data[0]);
      packed_report_header[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_front();
    end

    //$display("unpack_report: packed=%X", packed_report_header);

    report_header = intercept_stream_report_header_t'(packed_report_header);
    return report_header;
  endfunction

  function automatic bit data_match(logic [AXI_DATA_WIDTH - 1 : 0] a [$], logic [AXI_DATA_WIDTH - 1 : 0] b []);
    intercept_stream_report_header_t report_a = unpack_report_header(a);
    intercept_stream_report_header_t report_b = unpack_report_header(b);

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

    if (report_a.dwell_seq_num !== report_b.dwell_seq_num) begin
      $display("dwell_seq_num mismatch: %X %X", report_a.dwell_seq_num, report_b.dwell_seq_num);
      return 0;
    end

    if (report_a.dwell_frequency !== report_b.dwell_frequency) begin
      $display("dwell_frequency mismatch: %X %X", report_a.dwell_frequency, report_b.dwell_frequency);
      return 0;
    end
    if (report_a.dwell_tag !== report_b.dwell_tag) begin
      $display("dwell_tag mismatch: %X %X", report_a.dwell_tag, report_b.dwell_tag);
      return 0;
    end

    for (int i = NUM_HEADER_WORDS; i < a.size(); i++) begin
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
    $display("%0t: reset complete - starting report read", $time);

    forever begin
      rpt_rx_intf.read(read_data);
      $display("%0t: report read -- %p", $time, read_data);

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

  function automatic int get_next_stream_index(bit [intercept_num_streams-1:0] stream_pending);
    bit [intercept_num_streams-1:0] stream_available = ~stream_pending & stream_enable;
    for (int i = 0; i < intercept_num_streams; i++) begin
      if (stream_available[i]) begin
        return i;
      end
    end
    return -1;
  endfunction

  function automatic void expect_reports(channelizer_data_array_t channelizer_input);
    int samples_per_packet = (intercept_max_words_per_packet_large - NUM_HEADER_WORDS - 1) / 4;
    bit [intercept_num_streams-1:0] stream_pending = '0;
    int channel_state [intercept_num_channels] = '{default:-1};
    int sample_index [intercept_num_channels] = '{default:0};
    int coast_index [intercept_num_channels] = '{default:0};
    int stream_index [intercept_num_channels] = '{default:0};

    intercept_stream_sample_entry_t reported_samples [$];
    int num_packets = 0;

    for (int i_sample = 0; i_sample < channelizer_input.size(); i_sample++) begin
      int i_channel = channelizer_input[i_sample].channel;
      intercept_message_stream_encoder_channel_control_t channel_entry = m_channel_data[i_channel];
      if (!channel_entry.enable) begin
        continue;
      end

      if (channel_state[i_channel] == intercept_stream_trigger_type_normal) begin
        if (channelizer_input[i_sample].power <= channel_entry.threshold_continue) begin
          if (channel_entry.coast_cycles > 0) begin
            channel_state[i_channel] = intercept_stream_trigger_type_coast;
            coast_index[i_channel] = 0;
          end else begin
            channel_state[i_channel] = intercept_stream_trigger_type_last;
          end
        end

        sample_index[i_channel]++;
      end else if (channel_state[i_channel] == intercept_stream_trigger_type_coast) begin
        if (channelizer_input[i_sample].power > channel_entry.threshold_continue) begin
          channel_state[i_channel] = intercept_stream_trigger_type_normal;
        end else if (coast_index[i_channel] == channel_entry.coast_cycles) begin
          channel_state[i_channel] = intercept_stream_trigger_type_last;
        end
        sample_index[i_channel]++;
        coast_index[i_channel]++;
      end else if (channel_state[i_channel] == intercept_stream_trigger_type_forced) begin
        //TODO: not implemented
        sample_index[i_channel]++;
      end else if (channel_state[i_channel] == intercept_stream_trigger_type_last) begin
        stream_pending[stream_index[i_channel]] = 0;
        channel_state[i_channel] = -1;
        sample_index[i_channel]++;
      end else begin
        if (channel_entry.force_trigger) begin
          channel_state[i_channel] = intercept_stream_trigger_type_forced;
          stream_index[i_channel] = channel_entry.force_stream;
          stream_pending[channel_entry.force_stream] = 1;
        end else if (channelizer_input[i_sample].power > channel_entry.threshold_start) begin
          int next_stream_index = get_next_stream_index(stream_pending);
          $display("   trying to start: next_stream_index=%0d", next_stream_index);
          if (next_stream_index != -1) begin
            channel_state[i_channel] = intercept_stream_trigger_type_normal;
            stream_index[i_channel] = next_stream_index;
            stream_pending[next_stream_index] = 1;
          end
        end
        sample_index[i_channel] = 0;
      end

      /*$display("[%0d] channel_entry[%0d] = %p -- state=%0d  power=%0d iq={%p}", i_sample, i_channel, channel_entry, channel_state[i_channel],
        channelizer_input[i_sample].power, channelizer_input[i_sample].iq);*/

      if (channel_state[i_channel] != -1) begin
        intercept_stream_sample_entry_t sample  = '{default:0};
        sample.trigger_type                     = channel_state[i_channel];
        sample.stream_index                     = stream_index[i_channel];
        sample.channel_index                    = i_channel;
        sample.sample_index                     = sample_index[i_channel];
        sample.data_i                           = channelizer_input[i_sample].iq[0];
        sample.data_q                           = channelizer_input[i_sample].iq[1];
        reported_samples.push_back(sample);
      end
    end

    num_packets = (reported_samples.size() * 4) / samples_per_packet;

    while (reported_samples.size() > 0) begin
      expect_t r;
      intercept_stream_report_header_t      report_header;
      intercept_stream_report_header_bits_t report_header_packed;

      report_header.magic_num               = intercept_report_magic_num;
      report_header.sequence_num            = report_seq_num;
      report_header.module_id               = intercept_module_id_stream_encoder;
      report_header.message_type            = intercept_report_message_type_stream;
      report_header.padding_0               = 0;
      report_header.padding_1               = 0;
      report_header.dwell_seq_num           = dwell_seq_num;
      report_header.dwell_frequency         = dwell_data.dwell_frequency;
      report_header.dwell_tag               = dwell_data.dwell_tag;
      report_header.padding_2               = 0;
      report_header.padding_3               = 0;
      report_header.timestamp               = 0;

      report_header_packed = intercept_stream_report_header_bits_t'(report_header);
      $display("report_header: %p", report_header);

      for (int i = 0; i < $size(report_header_packed)/AXI_DATA_WIDTH; i++) begin
        r.data.push_back(report_header_packed[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]);
      end

      while ((reported_samples.size() > 0) && (r.data.size() < (intercept_max_words_per_packet_large - 5))) begin
        intercept_stream_sample_entry_t sample = reported_samples.pop_front();
        bit [31:0] words [4];

        words[0] = {sample.channel_index, sample.stream_index, sample.trigger_type};
        words[1] = sample.sample_index;
        words[2] = sample.data_i;
        words[3] = sample.data_q;
        for (int i = 0; i < $size(words); i++) begin
          r.data.push_back(words[i]);
        end
      end

      r.data.push_back(32'hCAFEF00D);

      expected_data.push_back(r);

      report_seq_num++;
    end
  endfunction

  function automatic channelizer_data_array_t randomize_channelizer_input(int window_duration);
    channelizer_data_array_t r = new [intercept_num_channels * window_duration];
    int channel_index = 0;

    for (int i = 0; i < r.size(); i++) begin
      r[i].channel  = channel_index;
      r[i].last     = (channel_index == (intercept_num_channels - 1));
      r[i].power    = $urandom_range(32);
      r[i].iq       = {$urandom, $urandom};
      channel_index = (channel_index + 1) % intercept_num_channels;
    end

    return r;
  endfunction

  task automatic single_channel_test();
    parameter NUM_TESTS = 10;
    int max_write_delay = 5;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int num_frames        = $urandom_range(300, 250);
      int channel_index     = $urandom_range(intercept_num_channels - 1);
      int stream_index      = $urandom_range(intercept_num_streams - 1);
      int trigger_duration  = $urandom_range(200, 10);
      int trigger_index     = $urandom_range(10);

      intercept_message_dwell_controller_control_t control_data = randomize_dwell_controller_control();
      channelizer_data_t channelizer_input [] = randomize_channelizer_input(num_frames);

      intercept_message_stream_encoder_channel_control_t  channel_control;
      intercept_message_stream_encoder_stream_control_t   stream_control;

      channel_control.enable              = $urandom_range(99) < 75;
      channel_control.force_trigger       = 0; //$urandom_range(99) < 25;
      channel_control.force_stream        = stream_index;
      channel_control.stream_encoder_tag  = $urandom;
      channel_control.threshold_start     = $urandom_range(255, 128);
      channel_control.threshold_continue  = $urandom_range(127, 64);
      channel_control.coast_cycles        = $urandom_range(32, 8);
      channel_control.integration_cycles  = 0;

      stream_control.enable = 1;

      for (int i_sample = 0; i_sample < channelizer_input.size(); i_sample++) begin
        int i_frame = i_sample / intercept_num_channels;
        if (channelizer_input[i_sample].channel != channel_index) begin
          continue;
        end

        if (i_frame == trigger_index) begin
          channelizer_input[i_sample].power = $urandom_range(1024, channel_control.threshold_start + 1);
        end else if ((i_frame > trigger_index) && (i_frame < (trigger_index + trigger_duration))) begin
          channelizer_input[i_sample].power = $urandom_range(channel_control.threshold_start - 1, channel_control.threshold_continue + 1);
        end
      end

      $display("%0t: Test started - max_write_delay=%0d control_data=%p", $time, max_write_delay, control_data);
      send_dwell_controller_control(control_data);
      send_channel_control(channel_control, channel_index);
      send_stream_control(stream_control, stream_index);

      expect_reports(channelizer_input);

      repeat(20) @(posedge Clk);

      channelizer_tx_intf.write(channelizer_input);

      repeat(1000) @(posedge Clk);

      channel_control.enable = 0;
      stream_control.enable = 0;
      send_channel_control(channel_control, channel_index);
      send_stream_control(stream_control, stream_index);

      begin
        int wait_cycles = 0;
        while ((expected_data.size() != 0) && (wait_cycles < 1e5)) begin
          @(posedge Clk);
          wait_cycles++;
        end
        assert (wait_cycles < 1e5) else $error("Timeout while waiting for expected queue to empty during test.");
      end

      $display("%0t: Test finished: num_received = %0d", $time, num_received);
      dwell_seq_num++;
    end
  endtask

  initial
  begin
    repeat(10) @(posedge Clk);
    wait_for_reset();

    report_seq_num  = 0;
    dwell_seq_num   = 1;
    m_channel_data  = '{default:0};
    stream_enable   = '0;

    single_channel_test();

    repeat(100) @(posedge Clk);
    $finish;
  end

endmodule
