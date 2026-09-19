`timescale 1ns/1ps

import math::*;
import intercept_pkg::*;
import dsp_pkg::*;

typedef struct {
  int channel;
  bit last;
  int unsigned power;
} dwell_channel_data_t;

typedef dwell_channel_data_t dwell_channel_array_t [];

interface dwell_stats_tx_intf (input logic Clk);
  channelizer_control_t             input_ctrl = '{valid:0, default:0};
  logic [chan_power_width - 1 : 0]  input_pwr;

  task write(dwell_channel_data_t input_data []);
    automatic dwell_channel_data_t d;

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

module intercept_dwell_stats_tb;
  parameter time CLK_HALF_PERIOD      = 2ns;
  parameter time AXI_CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH            = 32;

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

    bit [31:0]  dwell_seq_num;
    bit [31:0]  dwell_frequency;
    bit [15:0]  dwell_tag;
    bit [15:0]  padding_1;

    bit [31:0]  window_seq_num;
    bit [15:0]  window_duration;
    bit [15:0]  padding_2;
    bit [63:0]  window_timestamp;
  } intercept_dwell_report_header_t;

  typedef struct packed
  {
    bit [31:0]  channel_index;
    bit [63:0]  channel_accum;
    bit [31:0]  channel_max;
  } intercept_dwell_report_channel_entry_t;

  typedef bit [$bits(intercept_dwell_report_header_t) - 1 : 0]        dwell_report_header_bits_t;
  typedef bit [$bits(intercept_dwell_report_channel_entry_t) - 1 : 0] dwell_report_channel_entry_bits_t;

  parameter NUM_HEADER_WORDS = ($bits(intercept_dwell_report_header_t) / AXI_DATA_WIDTH);

  logic Clk_axi;
  logic Clk;
  logic Rst;

  axi_tx_intf         #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  cfg_tx_intf   (.Clk(Clk_axi));
  dwell_stats_tx_intf                                     dwell_tx_intf (.*);
  axi_rx_intf         #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  rpt_rx_intf   (.Clk(Clk_axi));

  int unsigned  report_seq_num = 0;
  expect_t      expected_data [$];
  int           num_received = 0;
  bit [31:0]    config_seq_num = 0;

  logic                   w_rst_out;
  logic                   w_enable_chan;
  logic                   w_enable_stream;
  logic                   w_enable_status;
  intercept_config_data_t w_module_config;
  logic                   r_axi_rx_ready;
  logic                   w_axi_rx_valid;
  logic                   w_error_reporter_busy;
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
    repeat(10) @(posedge Clk);
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

  intercept_dwell_stats
  #(
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH)
  )
  dut
  (
    .Clk_axi                  (Clk_axi),
    .Clk                      (Clk),
    .Rst                      (Rst),

    .Enable                   (1'b1),
    .Module_config            (w_module_config),

    .Input_ctrl               (dwell_tx_intf.input_ctrl),
    .Input_pwr                (dwell_tx_intf.input_pwr),

    .Axis_ready               (r_axi_rx_ready),
    .Axis_valid               (w_axi_rx_valid),
    .Axis_data                (rpt_rx_intf.data),
    .Axis_last                (rpt_rx_intf.last),

    .Error_reporter_busy      (w_error_reporter_busy),
    .Error_reporter_timeout   (w_error_reporter_timeout),
    .Error_reporter_overflow  (w_error_reporter_overflow)
  );

  assign rpt_rx_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

  always_ff @(posedge Clk) begin
    if (!Rst) begin
      if (w_error_reporter_busy)      $error("reporter busy");
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

  task automatic send_initial_config();
    bit [31:0] config_data [][] = '{{intercept_control_magic_num, config_seq_num++, 32'h00000000, 32'hDEADBEEF, 32'h01000000, 32'hDEADBEEF},
                                    {intercept_control_magic_num, config_seq_num++, 32'h00000000, 32'hDEADBEEF, 32'h00010100, 32'hDEADBEEF}};
    foreach (config_data[i]) begin
      write_config(config_data[i]);
    end
  endtask

  function automatic bit [intercept_message_dwell_stats_control_aligned_width - 1 : 0] pack_intercept_message_dwell_stats_control(intercept_message_dwell_stats_control_t data);
    bit [intercept_message_dwell_stats_control_aligned_width - 1 : 0] r;

    r[0]      = data.enable;
    r[31:16]  = data.dwell_tag;
    r[63:32]  = data.dwell_frequency;
    r[95:64]  = data.window_duration;

    return r;
  endfunction

  function automatic intercept_message_dwell_stats_control_t randomize_dwell_stats_control();
    intercept_message_dwell_stats_control_t r;
    r.enable          = 1;
    r.dwell_tag       = $urandom;
    r.dwell_frequency = $urandom;
    r.window_duration = $urandom_range(64, intercept_dwell_duration_min_frames);

    return r;
  endfunction

  task automatic send_dwell_stats_control(intercept_message_dwell_stats_control_t data);
    bit [31:0] config_data [] = new[4 + intercept_message_dwell_stats_control_aligned_width/32];
    bit [intercept_message_dwell_stats_control_aligned_width - 1 : 0] packed_control = pack_intercept_message_dwell_stats_control(data);

    $display("%0t: sending dwell stats control: %p", $time, data);

    config_data[0] = intercept_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {intercept_module_id_dwell_stats, intercept_control_message_type_dwell_stats_config, 16'h0000};
    config_data[3] = 32'hDEADBEEF;

    for (int i = 0; i < intercept_message_dwell_stats_control_aligned_width/32; i++) begin
      config_data[4 + i] = packed_control[i*32 +: 32];
    end

    write_config(config_data);
  endtask

  function automatic intercept_dwell_report_header_t unpack_report_header(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    intercept_dwell_report_header_t report_header;
    dwell_report_header_bits_t      packed_report_header;

    //$display("unpack_report: data=%p", data);

    for (int i = 0; i < $size(packed_report_header)/AXI_DATA_WIDTH; i++) begin
      //$display("unpack_report_header [%0d] = %X", i, data[0]);
      packed_report_header[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_front();
    end

    //$display("unpack_report: packed=%X", packed_report_header);

    report_header = intercept_dwell_report_header_t'(packed_report_header);
    return report_header;
  endfunction

  function automatic bit data_match(logic [AXI_DATA_WIDTH - 1 : 0] a [$], logic [AXI_DATA_WIDTH - 1 : 0] b []);
    intercept_dwell_report_header_t report_a = unpack_report_header(a);
    intercept_dwell_report_header_t report_b = unpack_report_header(b);

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
    if (report_a.window_seq_num !== report_b.window_seq_num) begin
      $display("window_seq_num mismatch: %X %X", report_a.window_seq_num, report_b.window_seq_num);
      return 0;
    end
    if (report_a.window_duration !== report_b.window_duration) begin
      $display("window_duration mismatch: %X %X", report_a.window_duration, report_b.window_duration);
      return 0;
    end

    for (int i = NUM_HEADER_WORDS; i < intercept_max_words_per_packet_large; i++) begin
      if (a[i] !== b[i]) begin
        $display("trailer mismatch [%0d]: %X %X", i, a[i], b[i]);
        return 0;
      end
    end

    //TODO: check channel data!!!

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

  function automatic void expect_reports(intercept_message_dwell_stats_control_t control_data, int unsigned dwell_seq_num, int unsigned window_seq_num, dwell_channel_data_t window_data []);
    int channels_per_packet = (intercept_max_words_per_packet_large - NUM_HEADER_WORDS) / 4;
    int num_packets = (intercept_num_channels + channels_per_packet - 1) / channels_per_packet;
    int num_padding_words = 0;
    int channel_index = 0;

    longint unsigned channel_accum [intercept_num_channels] = '{default:0};
    int unsigned channel_max [intercept_num_channels] = '{default:0};

    $display("%0t: num_header_words=%0d channels_per_packet=%0d num_packets=%0d", $time, NUM_HEADER_WORDS, channels_per_packet, num_packets);

    for (int i = 0; i < window_data.size(); i++) begin
      channel_accum[window_data[i].channel] += window_data[i].power;
      channel_max[window_data[i].channel] = (window_data[i].power > channel_max[window_data[i].channel]) ? window_data[i].power : channel_max[window_data[i].channel];
    end

    for (int i_packet = 0; i_packet < num_packets; i_packet++) begin
      expect_t r;
      intercept_dwell_report_header_t report_header;
      dwell_report_header_bits_t      report_header_packed;

      report_header.magic_num               = intercept_report_magic_num;
      report_header.sequence_num            = report_seq_num;
      report_header.module_id               = intercept_module_id_dwell_stats;
      report_header.message_type            = intercept_report_message_type_dwell_stats;
      report_header.dwell_seq_num           = dwell_seq_num;
      report_header.dwell_frequency         = control_data.dwell_frequency;
      report_header.dwell_tag               = control_data.dwell_tag;
      report_header.window_seq_num          = window_seq_num;
      report_header.window_duration         = control_data.window_duration;
      report_header.window_timestamp        = 0;

      report_header_packed = dwell_report_header_bits_t'(report_header);
      //$display("report_packed: %X", report_header_packed);
      $display("report_header: %p", report_header);

      for (int i = 0; i < $size(report_header_packed)/AXI_DATA_WIDTH; i++) begin
        r.data.push_back(report_header_packed[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]);
      end

      for (int i_channel = 0; i_channel < channels_per_packet; i_channel++) begin
        bit [31:0] words [4];
        if (channel_index >= intercept_num_channels) begin
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

      num_padding_words = intercept_max_words_per_packet_large - r.data.size();
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

  function automatic dwell_channel_array_t randomize_dwell_input(int num_windows, int window_duration);
    dwell_channel_array_t r = new [intercept_num_channels * num_windows * window_duration + $urandom_range(intercept_num_channels - 1)];
    int channel_index = 0;

    for (int i = 0; i < r.size(); i++) begin
      r[i].channel  = channel_index;
      r[i].last     = (channel_index == (intercept_num_channels - 1));
      r[i].power    = $urandom;
      channel_index = (channel_index + 1) % intercept_num_channels;
    end

    return r;
  endfunction

  task automatic standard_test();
    parameter NUM_TESTS = 20;
    int max_write_delay = 5;
    int dwell_seq_num = 1;
    int window_seq_num = 0;

    report_seq_num = 0;

    send_initial_config();

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int num_windows = $urandom_range(20, 3);
      intercept_message_dwell_stats_control_t control_data = randomize_dwell_stats_control();

      dwell_channel_data_t dwell_input [] = randomize_dwell_input(num_windows, control_data.window_duration);

      $display("%0t: Test started - max_write_delay=%0d control_data=%p", $time, max_write_delay, control_data);
      send_dwell_stats_control(control_data);
      repeat(20) @(posedge Clk);

      for (int i_window = 0; i_window < num_windows; i_window++) begin
        dwell_channel_data_t window_data [] = {>>{dwell_input with [(intercept_num_channels * control_data.window_duration * i_window): (intercept_num_channels * control_data.window_duration * (i_window + 1) - 1)]}};

        expect_reports(control_data, dwell_seq_num, window_seq_num, window_data);
        window_seq_num++;
      end

      dwell_tx_intf.write(dwell_input);

      repeat(1000) @(posedge Clk);

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
    Rst = 1;
    repeat(10) @(posedge Clk);
    Rst = 0;
    repeat(10) @(posedge Clk);

    wait_for_reset();
    standard_test();
    repeat(100) @(posedge Clk);
    $finish;
  end

endmodule
