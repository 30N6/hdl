`timescale 1ns/1ps

import math::*;
import ecm_pkg::*;
import dsp_pkg::*;

typedef struct {
  int channel;
  bit last;
  int unsigned power;
} dwell_channel_data_t;

typedef dwell_channel_data_t dwell_channel_array_t [];

interface dwell_stats_tx_intf (input logic Clk);
  logic                                           dwell_active = 0;
  logic                                           dwell_measurement_active = 0;
  logic                                           dwell_transmit_active = 0;
  ecm_dwell_entry_t                               dwell_data;
  logic [ecm_dwell_sequence_num_width - 1 : 0]    dwell_sequence_num;
  logic [ecm_dwell_global_counter_width - 1 : 0]  dwell_global_counter;
  logic [ecm_dwell_tag_width - 1 : 0]             dwell_program_tag;
  logic                                           dwell_report_enable;
  logic                                           dwell_report_done;

  channelizer_control_t                           input_ctrl = '{valid:0, default:0};
  logic [chan_power_width - 1 : 0]                input_pwr;

  task write(ecm_dwell_entry_t data, int unsigned seq_num, int unsigned global_counter, int unsigned program_tag, bit dwell_tx_active, bit report_enable, dwell_channel_data_t input_data []);
    automatic dwell_channel_data_t d;
    automatic bit tx_active_sent = 0;

    dwell_active              = 1;
    dwell_measurement_active  = 1;
    dwell_transmit_active     = 0;
    dwell_data                = data;
    dwell_sequence_num        = seq_num;
    dwell_global_counter      = global_counter;
    dwell_program_tag         = program_tag;
    dwell_report_enable       = report_enable;

    repeat (5) @(posedge Clk);

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

    @(posedge Clk);
    dwell_measurement_active = 0;
    repeat($urandom_range(10, 5)) @(posedge Clk);

    repeat ($urandom_range(1000, 500)) begin
      if (!tx_active_sent && dwell_tx_active) begin
        dwell_transmit_active = 1;
        tx_active_sent = 1;
      end

      input_ctrl.valid      = 1;
      input_ctrl.last       = $urandom;
      input_ctrl.data_index = $urandom;
      input_pwr             = $urandom;
      @(posedge Clk);
      dwell_transmit_active = 0;
      input_ctrl.valid      = 0;
      input_ctrl.last       = 'x;
      input_ctrl.data_index = 'x;
      input_pwr             = 'x;
      repeat ($urandom_range(3, 1)) @(posedge Clk);
    end

    dwell_active          = 0;
    dwell_data            = '{default: 'x};
    dwell_sequence_num    = 'x;
    dwell_global_counter  = 'x;
    dwell_program_tag     = 'x;

    while (!dwell_report_done) begin
      @(posedge Clk);
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

module ecm_dwell_stats_tb;
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

    /*bit         dwell_valid;
    bit         dwell_global_counter_check;
    bit         dwell_global_counter_dec;
    bit         dwell_skip_pll_prelock_wait;
    bit         dwell_skip_pll_lock_check;
    bit         dwell_skip_pll_postlock_wait;
    bit         dwell_force_full_duration;
    bit         dwell_padding;*/
    bit [7:0]   dwell_flags;
    bit [7:0]   dwell_repeat_count;
    bit [7:0]   dwell_fast_lock_profile;
    bit [7:0]   dwell_next_dwell_index;

    bit [15:0]  dwell_pll_pre_lock_delay;
    bit [15:0]  dwell_pll_post_lock_delay;

    bit [15:0]  dwell_tag;
    bit [15:0]  dwell_frequency;

    bit [31:0]  dwell_measurement_duration;
    bit [31:0]  dwell_total_duration_max;

    bit [15:0]  dwell_min_trigger_duration;
    bit [15:0]  padding_1;

    bit [31:0]  dwell_sequence_num;
    bit [15:0]  dwell_program_tag;
    bit [15:0]  dwell_global_counter;
    bit [31:0]  dwell_actual_measurement_duration;
    bit         dwell_tx_active;
    bit [30:0]  dwell_actual_total_duration;
    bit [63:0]  ts_dwell_start;
    bit [63:0]  cycles_total;
    bit [63:0]  cycles_active_meas;
    bit [63:0]  cycles_active_tx;
  } ecm_dwell_report_header_t;

  typedef struct packed
  {
    bit [31:0]  channel_cycles;
    bit [63:0]  channel_accum;
    bit [31:0]  channel_max;
  } ecm_dwell_report_channel_entry_t;

  typedef bit [$bits(ecm_dwell_report_header_t) - 1 : 0]        dwell_report_header_bits_t;
  typedef bit [$bits(ecm_dwell_report_channel_entry_t) - 1 : 0] dwell_report_channel_entry_bits_t;

  parameter NUM_HEADER_WORDS = ($bits(ecm_dwell_report_header_t) / AXI_DATA_WIDTH);

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
    repeat(100) @(posedge Clk);
    Rst = 0;
  end

  always_ff @(posedge Clk_axi) begin
    r_axi_rx_ready <= $urandom_range(99) < 80;
  end

  ecm_dwell_stats
  #(
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH)
  )
  dut
  (
    .Clk_axi                  (Clk_axi),
    .Clk                      (Clk),
    .Rst                      (Rst),

    .Enable                   (1'b1),

    .Dwell_active             (dwell_tx_intf.dwell_active),
    .Dwell_active_measurement (dwell_tx_intf.dwell_measurement_active),
    .Dwell_active_transmit    (dwell_tx_intf.dwell_transmit_active),
    .Dwell_data               (dwell_tx_intf.dwell_data),
    .Dwell_sequence_num       (dwell_tx_intf.dwell_sequence_num),
    .Dwell_global_counter     (dwell_tx_intf.dwell_global_counter),
    .Dwell_program_tag        (dwell_tx_intf.dwell_program_tag),
    .Dwell_report_enable      (dwell_tx_intf.dwell_report_enable),
    .Dwell_report_done        (dwell_tx_intf.dwell_report_done),

    .Input_ctrl               (dwell_tx_intf.input_ctrl),
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

  function automatic ecm_dwell_report_header_t unpack_report_header(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    ecm_dwell_report_header_t   report_header;
    dwell_report_header_bits_t  packed_report_header;

    for (int i = 0; i < $size(packed_report_header)/AXI_DATA_WIDTH; i++) begin
      packed_report_header[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_front();
    end

    report_header = ecm_dwell_report_header_t'(packed_report_header);
    return report_header;
  endfunction


  function automatic bit data_match(logic [AXI_DATA_WIDTH - 1 : 0] a [$], logic [AXI_DATA_WIDTH - 1 : 0] b []);
    ecm_dwell_report_header_t report_a = unpack_report_header(a);
    ecm_dwell_report_header_t report_b = unpack_report_header(b);

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

    if (report_a.dwell_flags !== report_b.dwell_flags) begin
      $display("dwell_flags mismatch: %X %X", report_a.dwell_flags, report_b.dwell_flags);
      return 0;
    end
    if (report_a.dwell_repeat_count !== report_b.dwell_repeat_count) begin
      $display("dwell_repeat_count mismatch: %X %X", report_a.dwell_repeat_count, report_b.dwell_repeat_count);
      return 0;
    end
    if (report_a.dwell_fast_lock_profile !== report_b.dwell_fast_lock_profile) begin
      $display("dwell_fast_lock_profile mismatch: %X %X", report_a.dwell_fast_lock_profile, report_b.dwell_fast_lock_profile);
      return 0;
    end
    if (report_a.dwell_next_dwell_index !== report_b.dwell_next_dwell_index) begin
      $display("dwell_next_dwell_index mismatch: %X %X", report_a.dwell_next_dwell_index, report_b.dwell_next_dwell_index);
      return 0;
    end

    if (report_a.dwell_pll_pre_lock_delay !== report_b.dwell_pll_pre_lock_delay) begin
      $display("dwell_pll_pre_lock_delay mismatch: %X %X", report_a.dwell_pll_pre_lock_delay, report_b.dwell_pll_pre_lock_delay);
      return 0;
    end
    if (report_a.dwell_pll_post_lock_delay !== report_b.dwell_pll_post_lock_delay) begin
      $display("dwell_pll_post_lock_delay mismatch: %X %X", report_a.dwell_pll_post_lock_delay, report_b.dwell_pll_post_lock_delay);
      return 0;
    end

    if (report_a.dwell_tag !== report_b.dwell_tag) begin
      $display("dwell_tag mismatch: %X %X", report_a.dwell_tag, report_b.dwell_tag);
      return 0;
    end
    if (report_a.dwell_frequency !== report_b.dwell_frequency) begin
      $display("dwell_frequency mismatch: %X %X", report_a.dwell_frequency, report_b.dwell_frequency);
      return 0;
    end

    if (report_a.dwell_measurement_duration !== report_b.dwell_measurement_duration) begin
      $display("dwell_measurement_duration mismatch: %X %X", report_a.dwell_measurement_duration, report_b.dwell_measurement_duration);
      return 0;
    end

    if (report_a.dwell_total_duration_max !== report_b.dwell_total_duration_max) begin
      $display("dwell_total_duration_max mismatch: %X %X", report_a.dwell_total_duration_max, report_b.dwell_total_duration_max);
      return 0;
    end

    if (report_a.dwell_min_trigger_duration !== report_b.dwell_min_trigger_duration) begin
      $display("dwell_min_trigger_duration mismatch: %X %X", report_a.dwell_min_trigger_duration, report_b.dwell_min_trigger_duration);
      return 0;
    end

    if (report_a.dwell_sequence_num !== report_b.dwell_sequence_num) begin
      $display("dwell_sequence_num mismatch: %X %X", report_a.dwell_sequence_num, report_b.dwell_sequence_num);
      return 0;
    end

    if (report_a.dwell_global_counter !== report_b.dwell_global_counter) begin
      $display("dwell_global_counter mismatch: %X %X", report_a.dwell_global_counter, report_b.dwell_global_counter);
      return 0;
    end

    if (report_a.dwell_program_tag !== report_b.dwell_program_tag) begin
      $display("dwell_program_tag mismatch: %X %X", report_a.dwell_program_tag, report_b.dwell_program_tag);
      return 0;
    end

    if (report_a.dwell_tx_active !== report_b.dwell_tx_active) begin
      $display("dwell_tx_active mismatch: %X %X", report_a.dwell_tx_active, report_b.dwell_tx_active);
      return 0;
    end

    /*if (report_a.dwell_actual_measurement_duration !== report_b.dwell_actual_measurement_duration) begin
      $display("dwell_actual_measurement_duration mismatch: %X %X", report_a.dwell_actual_measurement_duration, report_b.dwell_actual_measurement_duration);
      return 0;
    end
    if (report_a.dwell_actual_total_duration !== report_b.dwell_actual_total_duration) begin
      $display("dwell_actual_total_duration mismatch: %X %X", report_a.dwell_actual_total_duration, report_b.dwell_actual_total_duration);
      return 0;
    end*/

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

  function automatic void expect_reports(ecm_dwell_entry_t dwell_data, int unsigned dwell_seq_num, int unsigned dwell_global_counter, int unsigned dwell_program_tag,
                                         bit dwell_tx_active, bit report_enable, dwell_channel_data_t  dwell_input []);
    expect_t r;
    ecm_dwell_report_header_t   report_header;
    dwell_report_header_bits_t  report_header_packed;
    int num_padding_words = 0;
    int channel_index = 0;

    int unsigned      channel_cycles  [ecm_num_channels - 1 : 0] = '{default:0};
    longint unsigned  channel_accum   [ecm_num_channels - 1 : 0] = '{default:0};
    int unsigned      channel_max     [ecm_num_channels - 1 : 0] = '{default:0};

    if (!report_enable) begin
      return;
    end

    for (int i = 0; i < dwell_input.size(); i++) begin
      channel_cycles[dwell_input[i].channel]  += 1;
      channel_accum[dwell_input[i].channel]   += dwell_input[i].power;
      channel_max[dwell_input[i].channel]     = (dwell_input[i].power > channel_max[dwell_input[i].channel]) ? dwell_input[i].power : channel_max[dwell_input[i].channel];
    end

    report_header.magic_num               = ecm_report_magic_num;
    report_header.sequence_num            = report_seq_num;
    report_header.module_id               = ecm_module_id_dwell_stats;
    report_header.message_type            = ecm_report_message_type_dwell_stats;

    report_header.dwell_flags                       = {1'b0, 1'b0, dwell_data.skip_pll_postlock_wait, dwell_data.skip_pll_lock_check,
                                                       dwell_data.skip_pll_prelock_wait, dwell_data.global_counter_dec, dwell_data.global_counter_check, dwell_data.valid};
    report_header.dwell_repeat_count                = dwell_data.repeat_count;
    report_header.dwell_fast_lock_profile           = dwell_data.fast_lock_profile;
    report_header.dwell_next_dwell_index            = dwell_data.next_dwell_index;
    report_header.dwell_pll_pre_lock_delay          = dwell_data.pll_pre_lock_delay;
    report_header.dwell_pll_post_lock_delay         = dwell_data.pll_post_lock_delay;
    report_header.dwell_tag                         = dwell_data.tag;
    report_header.dwell_frequency                   = dwell_data.frequency;
    report_header.dwell_measurement_duration        = dwell_data.measurement_duration;
    report_header.dwell_total_duration_max          = dwell_data.total_duration_max;
    report_header.dwell_min_trigger_duration        = dwell_data.min_trigger_duration;
    report_header.dwell_sequence_num                = dwell_seq_num;
    report_header.dwell_global_counter              = dwell_global_counter;
    report_header.dwell_program_tag                 = dwell_program_tag;
    report_header.dwell_actual_measurement_duration = 0;
    report_header.dwell_actual_total_duration       = 0;
    report_header.dwell_tx_active                   = dwell_tx_active;
    report_header.ts_dwell_start                    = 0;
    report_header.cycles_total                      = 0;
    report_header.cycles_active_meas                = 0;
    report_header.cycles_active_tx                  = 0;

    report_header_packed = dwell_report_header_bits_t'(report_header);
    $display("expecting report_header: %p", report_header);

    for (int i = 0; i < $size(report_header_packed)/AXI_DATA_WIDTH; i++) begin
      r.data.push_back(report_header_packed[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]);
      //$display("  expecting word: %08X", report_header_packed[(NUM_HEADER_WORDS - i - 1)*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]);
    end

    for (int i_channel = 0; i_channel < ecm_num_channels; i_channel++) begin
      bit [31:0] words [4];

      words[0] = channel_cycles[channel_index];
      words[1] = channel_accum[channel_index][63:32];
      words[2] = channel_accum[channel_index][31:0];
      words[3] = channel_max[channel_index];
      for (int i = 0; i < $size(words); i++) begin
        r.data.push_back(words[i]);
      end
      channel_index++;
    end

    num_padding_words = ecm_words_per_dma_packet - r.data.size();
    for (int i_padding = 0; i_padding < num_padding_words; i_padding++) begin
      r.data.push_back(0);
    end

    expected_data.push_back(r);

    report_seq_num++;
  endfunction

  function automatic ecm_dwell_entry_t randomize_dwell_entry();
    ecm_dwell_entry_t r;
    r.valid                   = $urandom;
    r.global_counter_check    = $urandom;
    r.global_counter_dec      = $urandom;
    r.skip_pll_prelock_wait   = $urandom;
    r.skip_pll_lock_check     = $urandom;
    r.skip_pll_postlock_wait  = $urandom;
    r.pll_pre_lock_delay      = $urandom;
    r.pll_post_lock_delay     = $urandom;
    r.repeat_count            = $urandom;
    r.tag                     = $urandom;
    r.frequency               = $urandom;
    r.measurement_duration    = $urandom;
    r.total_duration_max      = $urandom;
    r.fast_lock_profile       = $urandom;
    r.next_dwell_index        = $urandom;
    return r;
  endfunction

  function automatic dwell_channel_array_t randomize_dwell_input();
    dwell_channel_array_t r = new [$urandom_range(2000, 500)];
    int channel_index = 0;

    for (int i = 0; i < r.size(); i++) begin
      r[i].channel  = channel_index;
      r[i].last     = (channel_index == (ecm_num_channels - 1));
      r[i].power    = $urandom;
      channel_index = (channel_index + 1) % ecm_num_channels;
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
        int unsigned          dwell_seq_num         = $urandom;
        int unsigned          dwell_global_counter  = $urandom_range(2**ecm_dwell_global_counter_width-1, 0);
        int unsigned          dwell_program_tag     = $urandom_range(2**ecm_dwell_tag_width-1, 0);
        bit                   dwell_tx_active       = $urandom;
        bit                   dwell_report_enable   = $urandom_range(99) < 95;
        ecm_dwell_entry_t     dwell_data            = randomize_dwell_entry();
        dwell_channel_data_t  dwell_input []        = randomize_dwell_input();

        expect_reports(dwell_data, dwell_seq_num, dwell_global_counter, dwell_program_tag, dwell_tx_active, dwell_report_enable, dwell_input);
        dwell_tx_intf.write(dwell_data, dwell_seq_num, dwell_global_counter, dwell_program_tag, dwell_tx_active, dwell_report_enable, dwell_input);

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
