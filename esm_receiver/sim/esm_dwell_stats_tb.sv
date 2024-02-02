`timescale 1ns/1ps

import math::*;
import esm_pkg::*;
import dsp_pkg::*;

typedef struct {
  int channel;
  bit last;
  int unsigned power;
} dwell_channel_data_t;

interface dwell_stats_tx_intf (input logic Clk);
  logic                                         dwell_active;
  esm_dwell_metadata_t                          dwell_data;
  logic [esm_dwell_sequence_num_width - 1 : 0]  dwell_sequence_num;

  channelizer_control_t                         input_ctrl;
  logic [chan_power_width - 1 : 0]              input_pwr;

  task write(esm_dwell_metadata_t data, int unsigned seq_num, dwell_channel_data_t input_data [$]);
    automatic dwell_channel_data_t d;

    dwell_active        = 1;
    dwell_data          = data;
    dwell_sequence_num  = seq_num;

    repeat (5) @(posedge Clk);

    while(input_data.size() > 0) begin
      d = input_data.pop_front();
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
  parameter time CLK_HALF_PERIOD  = 8ns;
  parameter AXI_DATA_WIDTH        = 32;
  parameter MODULE_ID             = 99;
  parameter NUM_CHANNELS          = 8;

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
    bit [15:0]  padding_1;
    bit [15:0]  threshold_narrow;
    bit [15:0]  threshold_wide;
    bit [63:0]  channel_mask_narrow;
    bit [7:0]   channel_mask_wide;
    bit [23:0]  padding_2;

    bit [31:0]  duration_actual;
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

  logic Clk;
  logic Rst;

  dwell_stats_tx_intf                             dwell_tx_intf (.*);
  axi_rx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  rpt_rx_intf   (.*);

  expect_t    expected_data [$];
  int         num_received = 0;
  logic       r_axi_rx_ready;
  logic       w_axi_rx_valid;

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

  esm_dwell_stats
  #(
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .DATA_WIDTH     (16),
    .NUM_CHANNELS   (NUM_CHANNELS),
    .MODULE_ID      (MODULE_ID)
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
    .Input_data         (),
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
  endtask

  function automatic esm_dwell_report_header_t unpack_report(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    esm_dwell_report_header_t   report_header;
    dwell_report_header_bits_t  packed_report_header;

    $display("unpack_report: data=%p", data);

    for (int i = 0; i < $size(packed_report_header)/AXI_DATA_WIDTH; i++) begin
      packed_report_header[i*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_back();
    end

    $display("unpack_report: packed=%X", packed_report_header);

    report_header = esm_dwell_report_header_t'(packed_report_header);
    return report_header;
  endfunction

/*
  function automatic bit data_match(logic [AXI_DATA_WIDTH - 1 : 0] a [$], logic [AXI_DATA_WIDTH - 1 : 0] b []);
    esm_dwell_report_header_t report_a = unpack_report_header(a);
    esm_dwell_report_header_t report_b = unpack_report_header(b);

    if (a.size() != b.size()) begin
      $display("%0t: size mismatch: a=%0d b=%0d", $time, a.size(), b.size());
      return 0;
    end

    $display("a[0]=%X b[0]=%X", a[0], b[0]);

    if (report_a.magic_num !== report_b.magic_num) begin
      $display("magic_num mismatch: %X %X", report_a.magic_num, report_b.magic_num);
      return 0;
    end

    if (report_a.sequence_num !== report_b.sequence_num) begin
      $display("sequence_num mismatch: %X %X", report_a.sequence_num, report_b.sequence_num);
      return 0;
    end

    if (report_a.message_crc !== report_b.message_crc) begin
      $display("message_crc mismatch: %X %X", report_a.message_crc, report_b.message_crc);
      return 0;
    end

    if (report_a.message_data !== report_b.message_data) begin
      $display("message_data mismatch: %X %X", report_a.message_data, report_b.message_data);
      return 0;
    end

    return 1;
  endfunction
*/

  initial begin
    automatic logic [AXI_DATA_WIDTH - 1 : 0] read_data [$];

    wait_for_reset();

    forever begin
      rpt_rx_intf.read(read_data);

      /*if (data_match(read_data, expected_data[0].data)) begin
        //$display("%0t: data match - %X", $time, read_data);
      end else begin
        $error("%0t: error -- data mismatch: expected = %p  actual = %p", $time, expected_data[0].data, read_data);
      end*/
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
/*
  function automatic expect_t populate_report(bit [adsb_message_width - 1 : 0] output_msg);
    expect_t r;
    static int seq_num = 0;

    adsb_report_packed_t report;
    adsb_report_bits_t packed_report;

    report.magic_num     = 32'hAD5B0001;
    report.sequence_num  = seq_num;
    report.timestamp     = 0;
    report.preamble_s    = 0;
    report.preamble_sn   = 0;
    report.message_crc   = 1;
    report.message_data  = output_msg;

    packed_report = adsb_report_bits_t'(report);
    for (int i = 0; i < $size(packed_report)/AXI_DATA_WIDTH; i++) begin
      r.data.push_front(packed_report[i*AXI_DATA_WIDTH +: AXI_DATA_WIDTH]);
    end

    $display("report: %p", report);
    $display("packed_report: %p", packed_report);
    $display("axi report: %p [0]", r.data, r.data[0]);

    seq_num++;

    return r;
  endfunction

  function automatic adsb_report_packed_t unpack_report(logic [AXI_DATA_WIDTH - 1 : 0] data [$]);
    adsb_report_packed_t report;
    adsb_report_bits_t packed_report;

    $display("unpack_report: data=%p", data);

    for (int i = 0; i < $size(packed_report)/AXI_DATA_WIDTH; i++) begin
      packed_report[i*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = data.pop_back();
    end

    $display("unpack_report: packed=%X", packed_report);

    report = adsb_report_packed_t'(packed_report);
    return report;
  endfunction
*/
  task automatic standard_test();
    /*string str_iq [$];
    string str_msg [$];
    string line;
    adc_data_t adc_data;
    bit [MSG_WIDTH - 1 : 0] output_msg;
    int fd_test_iq  = $fopen("./test_data/adsb_test_data_2023_12_29_iq.txt", "r");
    int fd_test_msg = $fopen("./test_data/adsb_test_data_2023_12_29_msg.txt", "r");
    int max_write_delay = 5;


    while ($fscanf(fd_test_iq, "%f %f", adc_data.d_i, adc_data.d_q) == 2) begin
      input_data.push_back(adc_data);
    end
    $fclose(fd_test_iq);

    while ($fscanf(fd_test_msg, "%X", output_msg) == 1) begin
      expected_data.push_back(populate_report(output_msg));
    end
    $fclose(fd_test_msg);

    $display("%0t: Test started - max_write_delay=%0d", $time, max_write_delay);
    foreach (input_data[i]) begin
      bit signed [ADC_WIDTH - 1 : 0] input_i = input_data[i].d_i * (2**(ADC_WIDTH-1));
      bit signed [ADC_WIDTH - 1 : 0] input_q = input_data[i].d_q * (2**(ADC_WIDTH-1));
      adc_tx_intf.write(input_i, input_q);
      //repeat($urandom_range(max_write_delay)) @(posedge(Clk));
    end*/

    begin
      int wait_cycles = 0;
      while ((expected_data.size() != 0) && (wait_cycles < 1e5)) begin
        @(posedge Clk);
        wait_cycles++;
      end
      assert (wait_cycles < 1e5) else $error("Timeout while waiting for expected queue to empty during test.");
    end

    $display("%0t: Test finished: num_received = %0d", $time, num_received);
  endtask

  initial
  begin
    wait_for_reset();
    standard_test();
    repeat(100) @(posedge Clk);
    $finish;
  end

endmodule
