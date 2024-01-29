`timescale 1ns/1ps

import math::*;
import esm_pkg::*;

interface dwell_rx_intf (input logic Clk);
  esm_dwell_metadata_t  data;
  logic                 valid;

  task read(output esm_dwell_metadata_t d);
    logic v;
    do begin
      d <= data;
      @(posedge Clk);
    end while (v !== 1);
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

module esm_dwell_controller_tb;
  parameter time CLK_HALF_PERIOD = 4ns;
  parameter AXI_DATA_WIDTH = 32;

  typedef struct
  {
    esm_dwell_metadata_t data;
  } expect_t;

  logic Clk;
  logic Rst;

  axi_tx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  cfg_tx_intf (.*);
  dwell_rx_intf                                   rx_intf (.*);

  logic                                           w_rst_out;
  logic [1:0]                                     w_enable_chan;
  logic [1:0]                                     w_enable_pdw;
  esm_config_data_t                               w_module_config;
  logic                                           w_dwell_active;
  esm_dwell_metadata_t                            w_dwell_data;

  logic [3:0]                                     w_ad9361_control;
  logic [3:0]                                     r_ad9361_control;
  logic [7:0]                                     w_ad9361_status;

  expect_t                                        expected_data [$];
  int                                             num_received = 0;

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

  esm_config #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH)) cfg
  (
    .Clk           (Clk),
    .Rst           (Rst),

    .Axis_ready    (cfg_tx_intf.ready),
    .Axis_valid    (cfg_tx_intf.valid),
    .Axis_last     (cfg_tx_intf.last),
    .Axis_data     (cfg_tx_intf.data),

    .Rst_out       (w_rst_out),
    .Enable_chan   (w_enable_chan),
    .Enable_pdw    (w_enable_pdw),

    .Module_config (w_module_config)
  );

  esm_dwell_controller dut
  (
    .Clk             (Clk),
    .Rst             (Rst),

    .Module_config   (w_module_config),

    .Ad9361_control  (w_ad9361_control),
    .Ad9361_status   (w_ad9361_status),

    .Dwell_active    (w_dwell_active),
    .Dwell_data      (w_dwell_data)
  );

  always_ff @(posedge Clk) begin
    r_ad9361_control <= w_ad9361_control;
  end

  initial begin
    w_ad9361_status <= 0;

    while (1) begin
      if (w_ad9361_control != r_ad9361_control) begin
        w_ad9361_status <= '0;
        repeat ($urandom_range(500, 50)) @(posedge Clk);
        w_ad9361_status <= '1;
      end
      @(posedge Clk);
    end
  end



  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
  endtask

  task automatic write_config(bit [31:0] config_data [][]);
    @(posedge Clk)
    foreach (config_data[i]) begin
      cfg_tx_intf.write(config_data[i]);
      repeat(10) @(posedge Clk);
    end
  endtask

  function automatic bit compare_data(esm_dwell_metadata_t a, esm_dwell_metadata_t b);
    if(a.tag                  !== b.tag)                    return 0;
    if(a.frequency            !== b.frequency)              return 0;
    if(a.duration             !== b.duration)               return 0;
    if(a.gain                 !== b.gain)                   return 0;
    if(a.fast_lock_profile    !== b.fast_lock_profile)      return 0;
    if(a.threshold_narrow     !== b.threshold_narrow)       return 0;
    if(a.threshold_wide       !== b.threshold_wide)         return 0;
    if(a.channel_mask_narrow  !== b.channel_mask_narrow)    return 0;
    if(a.channel_mask_wide    !== b.channel_mask_wide)      return 0;

    return 1;
  endfunction

  initial begin
    automatic esm_dwell_metadata_t read_data;

    wait_for_reset();

    forever begin
      rx_intf.read(read_data);
      if (compare_data(read_data, expected_data[0].data)) begin
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

  task automatic standard_tests();
    int wait_cycles;
    /*int max_frame_delay = 64;
    int max_sample_delay = $urandom_range(5);
    fft_transfer_t tx_queue[$];
    fft_transfer_t rx_queue[$];
    fft_transfer_t transfer_data;
    int d_i, d_q;
    int frame_index;
    int current_max_sample_delay = 0;
    int tx_tag [*];

    int fd_test_in  = $fopen(fn_in, "r");
    int fd_test_out = $fopen(fn_out, "r");

    repeat(10) @(posedge Clk);
    $display("%0t: Standard test started: fn_in=%s fn_out=%s max_frame_delay=%0d max_sample_delay=%0d", $time, fn_in, fn_out, max_frame_delay, max_sample_delay);

    while ($fscanf(fd_test_in, "%d %d %d %d %d", frame_index, transfer_data.index, transfer_data.last, d_i, d_q) == 5) begin
      //$display("input_transfer: frame=%0d index=%0d last=%0d d_i=%0d", frame_index, transfer_data.index, transfer_data.last, d_i, d_q);
      if (!tx_tag.exists(frame_index)) begin
        tx_tag[frame_index] = $urandom_range(255, 0);
      end
      transfer_data.tag     = tx_tag[frame_index];
      transfer_data.reverse = reverse;
      transfer_data.data_i  = d_i;
      transfer_data.data_q  = d_q;
      tx_queue.push_back(transfer_data);
    end
    $fclose(fd_test_in);

    while ($fscanf(fd_test_out, "%d %d %d %d %d", frame_index, transfer_data.index, transfer_data.last, d_i, d_q) == 5) begin
      expect_t e;
      transfer_data.tag     = tx_tag[frame_index];
      transfer_data.reverse = reverse;
      transfer_data.data_i  = d_i;
      transfer_data.data_q  = d_q;
      e.data = transfer_data;
      e.frame_index = frame_index;
      expected_data.push_back(e);
    end
    $fclose(fd_test_out);

    $display("%0t: TX queue size = %0d", $time, tx_queue.size());

    while (tx_queue.size() > 0) begin
      transfer_data = tx_queue.pop_front();
      tx_intf.write(transfer_data);
      if (transfer_data.last) begin
        int frame_delay = ($urandom_range(99) < 50) ? 0 : $urandom_range(max_frame_delay, 0);
        repeat (frame_delay) @(posedge Clk);
        current_max_sample_delay = ($urandom_range(99) < 50) ? 0 : $urandom_range(max_sample_delay);
      end else begin
        repeat (current_max_sample_delay) @(posedge Clk);
      end
    end*/

    wait_cycles = 0;
    while ((expected_data.size() != 0) && (wait_cycles < 1e5)) begin
      @(posedge Clk);
      wait_cycles++;
    end
    assert (wait_cycles < 1e5) else $error("Timeout while waiting for expected queue to empty during standard test");

    $display("%0t: Standard test finished: num_received = %0d", $time, num_received);

    Rst = 1;
    repeat(100) @(posedge Clk);
    Rst = 0;
  endtask

  initial
  begin
    wait_for_reset();

    begin
      automatic bit [31:0] config_data [][] = '{{esm_control_magic_num, 32'h00000001, 32'h00000000, 32'h00030300}, {esm_control_magic_num, 32'h00000001, 32'h00000000, 32'h00030300}};
      write_config(config_data);
    end

    standard_tests();

    $finish;
  end

endmodule
