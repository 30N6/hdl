`timescale 1ns/1ps

import math::*;
import ecm_pkg::*;
import dsp_pkg::*;

typedef struct {
  int data_i;
  int data_q;
  int index;
  int wait_cycles;
} channelizer_transaction_t;

interface channelizer_tx_intf #(parameter DATA_WIDTH) (input logic Clk);
  channelizer_control_t             ctrl;
  logic signed [DATA_WIDTH - 1 : 0] data [1:0];

  task clear();
    ctrl.valid      <= 0;
    ctrl.last       <= 'x;
    ctrl.data_index <= 'x;
    data[0]         <= 'x;
    data[1]         <= 'x;
  endtask

  task write(input channelizer_transaction_t tx);
    ctrl.valid      <= 1;
    ctrl.last       <= (tx.index == (ecm_num_channels - 1));
    ctrl.data_index <= tx.index;
    data[0]         <= tx.data_i;
    data[1]         <= tx.data_q;
    @(posedge Clk);
    clear();
    repeat(tx.wait_cycles) @(posedge Clk);
  endtask
endinterface

interface channelizer_rx_intf #(parameter DATA_WIDTH) (input logic Clk);
  channelizer_control_t             ctrl;
  logic signed [DATA_WIDTH - 1 : 0] data [1:0];

  task read(output channelizer_transaction_t rx);
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

interface control_intf (input logic Clk);
  ecm_output_control_t data;

  task clear();
    data.valid          <= 0;
    data.channel_index  <= 'x;
    data.control        <= 'x;
  endtask

  task write(input ecm_output_control_t tx);
    data                <= tx;
    data.valid          <= 1;
    @(posedge Clk);
    clear();
  endtask
endinterface

module ecm_output_block_tb;
  parameter time CLK_HALF_PERIOD    = 4ns;

  typedef struct
  {
    channelizer_transaction_t data;
  } expect_t;

  logic Clk;
  logic Rst;

  control_intf                                                    ctrl_intf   (.*);
  channelizer_tx_intf #(.DATA_WIDTH(ecm_dds_data_width))          dds_intf    (.*);
  channelizer_tx_intf #(.DATA_WIDTH(ecm_drfm_data_width))         drfm_intf   (.*);
  channelizer_rx_intf #(.DATA_WIDTH(ecm_synthesizer_data_width))  output_intf (.*);

  expect_t                                          expected_data [$];
  int                                               num_received = 0;
  ecm_output_control_t                              control_tx [$];
  channelizer_transaction_t                         dds_tx [$];
  channelizer_transaction_t                         drfm_tx [$];

  logic                                             w_error_dds_drfm_sync;
  channelizer_control_t                             w_output_ctrl;
  logic signed [ecm_synthesizer_data_width - 1 : 0] w_output_data [1 : 0];
  logic [ecm_synthesizer_data_width - 1 : 0]        r_output_i [ecm_num_channels - 1 : 0];
  logic [ecm_synthesizer_data_width - 1 : 0]        r_output_q [ecm_num_channels - 1 : 0];

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

  ecm_output_block #(.ENABLE_DDS(1), .ENABLE_DRFM(1)) dut
  (
  .Clk                    (Clk),
  .Rst                    (Rst),

  .Dwell_active_transmit  (1'b1),
  .Output_control         (ctrl_intf.data),

  .Dds_ctrl               (dds_intf.ctrl),
  .Dds_data               (dds_intf.data),

  .Drfm_ctrl              (drfm_intf.ctrl),
  .Drfm_data              (drfm_intf.data),

  .Synthesizer_ctrl       (w_output_ctrl),
  .Synthesizer_data       (w_output_data),

  .Error_dds_drfm_sync    (w_error_dds_drfm_sync)
);

  assign output_intf.ctrl = w_output_ctrl;
  assign output_intf.data = w_output_data;

  always_ff @(posedge Clk) begin
    if (!Rst) begin
      if (w_error_dds_drfm_sync) begin
        $error("%0t: dds drfm sync error", $time);
      end
    end
  end

  always_ff @(posedge Clk) begin
    if (w_output_ctrl.valid) begin
      r_output_i[w_output_ctrl.data_index] <= w_output_data[0];
      r_output_q[w_output_ctrl.data_index] <= w_output_data[1];
    end

    /*if (w_output_ctrl.valid) begin
      $display("%0d %0d %0d", w_output_ctrl.data_index, w_output_data[0], w_output_data[1]);
    end*/
  end

  function automatic bit compare_data(channelizer_transaction_t a, channelizer_transaction_t b);
    if (a.data_i !== b.data_i) begin
      return 0;
    end
    if (a.data_q !== b.data_q) begin
      return 0;
    end
    if (a.index !== b.index) begin
      return 0;
    end

    return 1;
  endfunction

  initial begin
    automatic channelizer_transaction_t read_data;

    wait_for_reset();

    forever begin
      output_intf.read(read_data);
      if (compare_data(read_data, expected_data[0].data)) begin
        //$display("%0t: data match - frame=%0d - %p", $time, expected_data[0].frame_index, read_data);
      end else begin
        $error("%0t: error -- data mismatch: expected=%p  actual=%p", $time, expected_data[0].data, read_data);
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

  initial begin
    automatic ecm_output_control_t tx_data;
    @(posedge Clk);

    forever begin
      while (control_tx.size() > 0) begin
        tx_data = control_tx.pop_front();
        ctrl_intf.write(tx_data);
      end
      @(posedge Clk);
    end
  end

  initial begin
    automatic channelizer_transaction_t tx_data;
    @(posedge Clk);

    forever begin
      while (dds_tx.size() > 0) begin
        tx_data = dds_tx.pop_front();
        dds_intf.write(tx_data);
      end
      @(posedge Clk);
    end
  end

  initial begin
    automatic channelizer_transaction_t tx_data;
    @(posedge Clk);

    forever begin
      while (drfm_tx.size() > 0) begin
        tx_data = drfm_tx.pop_front();
        drfm_intf.write(tx_data);
      end
      @(posedge Clk);
    end
  end

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
    repeat(5) @(posedge Clk);
  endtask

  function automatic logic signed [ecm_dds_data_width - 1 : 0] randomize_dds();
    logic signed [ecm_dds_data_width - 1 : 0] r = $urandom;
    return r;
  endfunction

  function automatic logic signed [ecm_drfm_data_width - 1 : 0] randomize_drfm();
    logic signed [ecm_drfm_data_width - 1 : 0] r = $urandom;
    return r;
  endfunction

  task automatic standard_tests();
    int channel_control [ecm_num_channels - 1 : 0];

    $display("%0t: Standard test started", $time);

    for (int i_test = 0; i_test < 20; i_test++) begin
      int data_length = $urandom_range(1000, 100);

      for (int i = 0; i < ecm_num_channels; i++) begin
        ecm_output_control_t control;
        control.channel_index = i;
        control.control       = $urandom;
        control_tx.push_back(control);

        channel_control[i] = control.control;
      end

      while(control_tx.size() > 0) begin
        @(posedge Clk);
      end

      repeat ($urandom_range(50, 10)) @(posedge Clk);

      for (int i = 0; i < data_length; i++) begin
        channelizer_transaction_t dds;
        channelizer_transaction_t drfm;
        expect_t result;
        logic signed [(ecm_dds_data_width + ecm_drfm_data_width) : 0] mixer_i, mixer_q;
        logic signed [ecm_synthesizer_data_width - 1 : 0] result_i, result_q;

        dds.index         = $urandom_range(ecm_num_channels - 1, 0);
        dds.data_i        = randomize_dds();
        dds.data_q        = randomize_dds();
        dds.wait_cycles   = $urandom_range(5);
        drfm.index        = dds.index;
        drfm.data_i       = randomize_drfm();
        drfm.data_q       = randomize_drfm();
        drfm.wait_cycles  = dds.wait_cycles;

        mixer_i = (dds.data_i * drfm.data_i) - (dds.data_q * drfm.data_q);
        mixer_q = (dds.data_i * drfm.data_q) + (dds.data_q * drfm.data_i);

        if (channel_control[dds.index] == ecm_tx_output_control_dds) begin
          result_i = dds.data_i[ecm_synthesizer_data_width - 1 : 0];
          result_q = dds.data_q[ecm_synthesizer_data_width - 1 : 0];
        end else if (channel_control[dds.index] == ecm_tx_output_control_drfm) begin
          result_i = drfm.data_i[ecm_synthesizer_data_width - 1 : 0];
          result_q = drfm.data_q[ecm_synthesizer_data_width - 1 : 0];
        end else if (channel_control[dds.index] == ecm_tx_output_control_mixer) begin
          result_i = mixer_i[(ecm_dds_data_width + ecm_drfm_data_width) : (ecm_dds_data_width + ecm_drfm_data_width - ecm_synthesizer_data_width + 1)];
          result_q = mixer_q[(ecm_dds_data_width + ecm_drfm_data_width) : (ecm_dds_data_width + ecm_drfm_data_width - ecm_synthesizer_data_width + 1)];
        end else begin
          result_i = '0;
          result_q = '0;
        end

        result.data.index = dds.index;
        result.data.data_i = result_i;
        result.data.data_q = result_q;

        dds_tx.push_back(dds);
        drfm_tx.push_back(drfm);
        expected_data.push_back(result);
      end

      while((dds_tx.size() > 0) || (drfm_tx.size() > 0)) begin
        @(posedge Clk);
      end

      $display("%0t: Subtest %0d finished: received=%0d", $time, i_test, num_received);

      repeat (50) @(posedge Clk);
    end

    $display("%0t: Standard test finished", $time);

    Rst = 1;
    repeat(500) @(posedge Clk);
    Rst = 0;
  endtask

  initial
  begin
    ctrl_intf.clear();
    dds_intf.clear();
    drfm_intf.clear();
    wait_for_reset();

    standard_tests();
    $finish;
  end

endmodule
