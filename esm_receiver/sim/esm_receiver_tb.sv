`timescale 1ns/1ps

import math::*;
import esm_pkg::*;

typedef struct {
  int data_i;
  int data_q;
} adc_transaction_t;

interface adc_tx_intf #(parameter ADC_WIDTH) (input logic Clk);
  logic                             valid = 0;
  logic signed [ADC_WIDTH - 1 : 0]  data_i;
  logic signed [ADC_WIDTH - 1 : 0]  data_q;

  task write(input adc_transaction_t tx);
    data_i  <= tx.data_i;
    data_q  <= tx.data_q;
    valid   <= 1;
    @(posedge Clk);
    data_i  <= 0;
    data_q  <= 0;
    valid   <= 0;
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

module esm_receiver_tb;
  parameter time ADC_CLK_HALF_PERIOD  = 8ns;
  parameter time AXI_CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH            = 32;
  parameter ADC_WIDTH                 = 16;
  parameter IQ_WIDTH                  = 12;

  logic Adc_clk;
  logic Adc_clk_x4;
  logic Adc_rst;
  logic Axi_clk;
  logic Axi_rstn;

  adc_tx_intf #(.ADC_WIDTH(ADC_WIDTH))            tx_intf     (.Clk(Adc_clk));
  axi_tx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  cfg_tx_intf (.Clk(Axi_clk));
  axi_rx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  rpt_rx_intf (.Clk(Axi_clk));

  logic [3:0]                                     w_ad9361_control;
  logic [3:0]                                     r_ad9361_control;
  logic [7:0]                                     w_ad9361_status;
  logic                                           r_axi_rx_ready;
  logic                                           w_axi_rx_valid;

  bit [31:0]                                      config_seq_num = 0;
  esm_dwell_metadata_t                            dwell_entry_mem [esm_num_dwell_entries - 1 : 0];

  initial begin
    Adc_clk = 0;
    forever begin
      #(ADC_CLK_HALF_PERIOD);
      Adc_clk = ~Adc_clk;
    end
  end

  initial begin
    Adc_clk_x4 = 0;
    forever begin
      #(ADC_CLK_HALF_PERIOD/4);
      Adc_clk_x4 = ~Adc_clk_x4;
    end
  end

  initial begin
    Axi_clk = 0;
    forever begin
      #(AXI_CLK_HALF_PERIOD);
      Axi_clk = ~Axi_clk;
    end
  end

  initial begin
    Adc_rst = 1;
    repeat(100) @(posedge Adc_clk);
    Adc_rst = 0;
  end

  initial begin
    Axi_rstn = 0;
    repeat(10) @(posedge Axi_clk);
    Axi_rstn = 1;
  end

  esm_receiver #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH), .ADC_WIDTH(ADC_WIDTH), .IQ_WIDTH(IQ_WIDTH)) dut
  (
    .Adc_clk        (Adc_clk),
    .Adc_clk_x4     (Adc_clk_x4),
    .Adc_rst        (Adc_rst),

    .Ad9361_control (w_ad9361_control),
    .Ad9361_status  (w_ad9361_status),

    .Adc_valid      (tx_intf.valid),
    .Adc_data_i     (tx_intf.data_i),
    .Adc_data_q     (tx_intf.data_q),

    .S_axis_clk     (Axi_clk),
    .S_axis_resetn  (Axi_rstn),
    .S_axis_ready   (cfg_tx_intf.ready),
    .S_axis_valid   (cfg_tx_intf.valid),
    .S_axis_data    (cfg_tx_intf.data),
    .S_axis_last    (cfg_tx_intf.last),

    .M_axis_clk     (Axi_clk),
    .M_axis_resetn  (Axi_rstn),
    .M_axis_ready   (r_axi_rx_ready),
    .M_axis_valid   (w_axi_rx_valid),
    .M_axis_data    (rpt_rx_intf.data),
    .M_axis_last    (rpt_rx_intf.last)
  );

  always_ff @(posedge Axi_clk) begin
    r_axi_rx_ready <= $urandom_range(99) < 80;
  end

  assign rpt_rx_intf.valid = w_axi_rx_valid && r_axi_rx_ready;

  always_ff @(posedge Adc_clk) begin
    r_ad9361_control <= w_ad9361_control;
  end

  initial begin
    w_ad9361_status <= '1;
    /*w_ad9361_status <= 0;
    while (1) begin
      if (w_ad9361_control != r_ad9361_control) begin
        w_ad9361_status <= '0;
        repeat ($urandom_range(10, 5)) @(posedge Adc_clk);
        w_ad9361_status <= '1;
      end
      @(posedge Adc_clk);
    end*/
  end

  task automatic wait_for_reset();
    do begin
      @(posedge Adc_clk);
    end while (Adc_rst);
  endtask

  task automatic write_config(bit [31:0] config_data []);
    @(posedge Axi_clk)
    cfg_tx_intf.write(config_data);
    repeat(10) @(posedge Axi_clk);
  endtask

  task automatic send_initial_config();
    bit [31:0] config_data [][] = '{{esm_control_magic_num, config_seq_num++, 32'h00000000, 32'h01000000},
                                    {esm_control_magic_num, config_seq_num++, 32'h00000000, 32'h00030301}};
    foreach (config_data[i]) begin
      write_config(config_data[i]);
    end
  endtask

  task automatic send_dwell_entry(esm_message_dwell_entry_t entry);
    bit [esm_message_dwell_entry_packed_width - 1 : 0] packed_entry = '0;
    bit [31:0] config_data [] = new[3 + esm_message_dwell_entry_packed_width/32];

    $display("%0t: send_dwell_entry[%0d] = %p", $time, entry.entry_index, entry.entry_data);

    packed_entry[7   :   0] = entry.entry_index;
    packed_entry[47  :  32] = entry.entry_data.tag;
    packed_entry[63  :  48] = entry.entry_data.frequency;
    packed_entry[95  :  64] = entry.entry_data.duration;
    packed_entry[103 :  96] = entry.entry_data.gain;
    packed_entry[111 : 104] = entry.entry_data.fast_lock_profile;
    packed_entry[159 : 128] = entry.entry_data.threshold_narrow;
    packed_entry[191 : 160] = entry.entry_data.threshold_wide;
    packed_entry[255 : 192] = entry.entry_data.channel_mask_narrow;
    packed_entry[263 : 256] = entry.entry_data.channel_mask_wide;

    config_data[0] = esm_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {esm_module_id_dwell_controller, esm_control_message_type_dwell_entry, 16'h0000};

    for (int i = 0; i < (esm_message_dwell_entry_packed_width/32); i++) begin
      config_data[3 + i] = packed_entry[i*32 +: 32];
    end

    write_config(config_data);
  endtask

  function automatic bit [31:0] pack_dwell_instruction(esm_dwell_instruction_t instruction);
    bit [31:0] r = '0;

    r[0]      = instruction.valid;
    r[1]      = instruction.global_counter_check;
    r[2]      = instruction.global_counter_dec;
    r[15:8]   = instruction.repeat_count;
    r[23:16]  = instruction.entry_index;
    r[31:24]  = instruction.next_instruction_index;

    return r;
  endfunction

  task automatic send_dwell_program(esm_message_dwell_program_t dwell_program);
    bit [esm_message_dwell_program_header_packed_width - 1 : 0] packed_header = '0;
    bit [31:0] config_data [] = new[3 + esm_message_dwell_program_header_packed_width/32 + esm_num_dwell_instructions];

    $display("%0t: send_dwell_program = %p", $time, dwell_program);

    packed_header[7:0]    = dwell_program.enable_program;
    packed_header[15:8]   = dwell_program.enable_delayed_start;
    packed_header[63:32]  = dwell_program.global_counter_init;
    packed_header[127:64] = dwell_program.delayed_start_time;

    config_data[0] = esm_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {esm_module_id_dwell_controller, esm_control_message_type_dwell_program, 16'h0000};

    for (int i = 0; i < (esm_message_dwell_program_header_packed_width/32); i++) begin
      config_data[3 + i] = packed_header[i*32 +: 32];
    end

    for (int i = 0; i < esm_num_dwell_instructions; i++) begin
      config_data[3 + (esm_message_dwell_program_header_packed_width/32) + i] = pack_dwell_instruction(dwell_program.instructions[i]);
    end

    write_config(config_data);
  endtask

  function automatic void randomize_instructions(inout esm_message_dwell_program_t dwell_program, bit global_counter_enable);
    int random_order = $urandom_range(99) < 50;
    int loop = ($urandom_range(99) < 50) && global_counter_enable;
    int num_instructions = $urandom_range(10, esm_num_dwell_instructions - 1);
    int indices [$];

    for (int i = 1; i < num_instructions; i++) begin
      indices.push_back(i);
    end
    indices.shuffle();
    indices.push_front(0);

    for (int i = 0; i < esm_num_dwell_instructions; i++) begin
      dwell_program.instructions[i].valid = 0;
    end

    //$display("%0t: randomize_instructions: global_counter_enable=%0d", $time, global_counter_enable);

    for (int i = 0; i < num_instructions; i++) begin
      int idx = random_order ? indices[i] : i;

      dwell_program.instructions[idx].valid = 1;
      dwell_program.instructions[idx].global_counter_check    = global_counter_enable;
      dwell_program.instructions[idx].global_counter_dec      = global_counter_enable;
      dwell_program.instructions[idx].repeat_count            = $urandom_range(4);
      dwell_program.instructions[idx].entry_index             = $urandom_range(esm_num_dwell_entries - 1);

      if (i == (num_instructions - 1)) begin
        if (loop) begin
          dwell_program.instructions[idx].next_instruction_index = 0;
        end else begin
          dwell_program.instructions[idx].next_instruction_index = esm_num_dwell_instructions - 1;
        end
      end else begin
        if (random_order) begin
          dwell_program.instructions[idx].next_instruction_index = indices[i + 1];
        end else begin
          dwell_program.instructions[idx].next_instruction_index = idx + 1;
        end
      end
      //$display("%0t: randomize_instructions[%0d]: idx=%0d inst=%p", $time, i, idx, dwell_program.instructions[idx]);
    end
  endfunction

  task automatic standard_tests();
    parameter NUM_TESTS = 20;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int wait_cycles;

      send_initial_config();

      for (int i_dwell = 0; i_dwell < esm_num_dwell_entries; i_dwell++) begin
        esm_message_dwell_entry_t entry;
        entry.entry_index                     = i_dwell;
        entry.entry_data.tag                  = $urandom;
        entry.entry_data.frequency            = $urandom;
        entry.entry_data.duration             = 10000;
        entry.entry_data.gain                 = $urandom;
        entry.entry_data.fast_lock_profile    = i_dwell;
        entry.entry_data.threshold_narrow     = 100;
        entry.entry_data.threshold_wide       = $urandom;
        entry.entry_data.channel_mask_narrow  = 64'hFFFFFFFFFFFFFFFF;
        entry.entry_data.channel_mask_wide    = 8'hFF;

        send_dwell_entry(entry);
        dwell_entry_mem[i_dwell] = entry.entry_data;
      end

      begin
        esm_message_dwell_program_t dwell_program;
        dwell_program.enable_program        = 1;
        dwell_program.enable_delayed_start  = 0;
        dwell_program.global_counter_init   = 0;
        dwell_program.delayed_start_time    = 0;

        //for (int i_dwell = 0; i_dwell < esm_num_dwell_entries; i_dwell++) begin
        for (int i_dwell = 0; i_dwell < 10; i_dwell++) begin
          dwell_program.instructions[i_dwell].valid                   = 1;
          dwell_program.instructions[i_dwell].global_counter_check    = 0;
          dwell_program.instructions[i_dwell].global_counter_dec      = 0;
          dwell_program.instructions[i_dwell].repeat_count            = 0;
          dwell_program.instructions[i_dwell].entry_index             = i_dwell;
          dwell_program.instructions[i_dwell].next_instruction_index  = i_dwell + 1;
        end
        dwell_program.instructions[10].valid = 0;

        send_dwell_program(dwell_program);
      end

      repeat(50000) @(posedge Adc_clk);

      /*for (int i_rep = 0; i_rep < 10; i_rep++) begin
        int global_counter_init   = $urandom_range(500);
        bit global_counter_enable = $urandom;
        int delayed_start_time    = $urandom_range(5000);
        int delayed_start_enable  = $urandom;

        esm_message_dwell_program_t dwell_program;
        dwell_program.enable_program        = 1;
        dwell_program.enable_delayed_start  = delayed_start_enable;
        dwell_program.global_counter_init   = global_counter_init;
        dwell_program.delayed_start_time    = delayed_start_time;

        randomize_instructions(dwell_program, global_counter_enable);
        //$display("dwell_program: %p", dwell_program);
        //for (int i = 0; i < esm_num_dwell_instructions; i++) begin
        //  $display("  inst[%0d] = %p", i, dwell_program.instructions[i]);
        //end
        send_dwell_program(dwell_program);

        //repeat(300000) @(posedge Clk);

        wait_cycles = 0;
        while ((expected_data.size() != 0) && (wait_cycles < 3e5)) begin
          @(posedge Clk);
          wait_cycles++;
        end
        assert (wait_cycles < 3e5) else $error("Timeout while waiting for expected queue to empty during standard test");

        foreach (expected_data[i]) begin
          $display("%0t: end of rep: expected_data[%0d]=%p", $time, i, expected_data[i]);
        end
      end

      $display("%0t: Standard test finished: num_received = %0d", $time, num_received);*/

      Adc_rst = 1;
      repeat(100) @(posedge Adc_clk);
      Adc_rst = 0;
    end
  endtask

  initial
  begin
    wait_for_reset();
    standard_tests();

    $finish;
  end

endmodule
