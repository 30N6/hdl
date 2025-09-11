`timescale 1ns/1ps

import math::*;
import esm_pkg::*;

interface dwell_rx_intf (input logic Clk);
  esm_dwell_entry_t  data;
  logic                 valid;

  task read(output esm_dwell_entry_t d);
    logic v;
    do begin
      d <= data;
      v <= valid;
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
  parameter time CLK_HALF_PERIOD      = 2ns;
  parameter time AXI_CLK_HALF_PERIOD  = 5ns;
  parameter AXI_DATA_WIDTH = 32;

  typedef struct
  {
    esm_dwell_entry_t data;
  } expect_t;

  logic Clk_axi;
  logic Clk;
  logic Rst;

  axi_tx_intf #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH))  cfg_tx_intf (.Clk(Clk_axi));
  dwell_rx_intf                                   rx_intf (.*);

  logic                                           w_rst_out;
  logic [1:0]                                     w_enable_chan;
  logic [1:0]                                     w_enable_pdw;
  logic                                           w_enable_status;
  esm_config_data_t                               w_module_config;
  logic                                           w_dwell_active;
  logic                                           r_dwell_active;
  esm_dwell_entry_t                               w_dwell_data;
  logic [31:0]                                    w_dwell_seq_num;

  logic [3:0]                                     w_ad9361_control;
  logic [3:0]                                     r_ad9361_control;
  logic [7:0]                                     w_ad9361_status;

  bit [31:0]                                      config_seq_num = 0;
  esm_dwell_entry_t                               dwell_entry_mem [esm_num_dwell_entries - 1 : 0];

  expect_t                                        expected_data [$];
  int                                             num_received = 0;

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

  esm_config #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH)) cfg
  (
    .Clk_x4         (Clk),


    .S_axis_clk     (Clk_axi),
    .S_axis_resetn  (!Rst),
    .S_axis_ready   (cfg_tx_intf.ready),
    .S_axis_valid   (cfg_tx_intf.valid),
    .S_axis_data    (cfg_tx_intf.data),
    .S_axis_last    (cfg_tx_intf.last),


    .Rst_out       (w_rst_out),
    .Enable_status (w_enable_status),
    .Enable_chan   (w_enable_chan),
    .Enable_pdw    (w_enable_pdw),

    .Module_config (w_module_config)
  );

  esm_dwell_controller #(.PLL_PRE_LOCK_DELAY_CYCLES(8), .PLL_POST_LOCK_DELAY_CYCLES(10)) dut
  (
    .Clk                (Clk),
    .Rst                (Rst),

    .Module_config      (w_module_config),

    .Ad9361_control     (w_ad9361_control),
    .Ad9361_status      (w_ad9361_status),

    .Dwell_active       (w_dwell_active),
    .Dwell_data         (w_dwell_data),
    .Dwell_sequence_num (w_dwell_seq_num)
  );

  always_ff @(posedge Clk) begin
    r_ad9361_control  <= w_ad9361_control;
    r_dwell_active    <= w_dwell_active;
  end

  initial begin
    w_ad9361_status <= 0;

    while (1) begin
      if (w_ad9361_control != r_ad9361_control) begin
        w_ad9361_status <= '0;
        repeat ($urandom_range(10, 5)) @(posedge Clk);
        w_ad9361_status <= '1;
      end
      @(posedge Clk);
    end
  end

  assign rx_intf.valid  = w_dwell_active && !r_dwell_active;
  assign rx_intf.data   = w_dwell_data;

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
  endtask

  task automatic write_config(bit [31:0] config_data []);
    @(posedge Clk_axi)
    cfg_tx_intf.write(config_data);
    repeat(10) @(posedge Clk_axi);
  endtask

  task automatic send_initial_config();
    bit [31:0] config_data [][] = '{{esm_control_magic_num, config_seq_num++, 32'h00000000, 32'hDEADBEEF, 32'h01000000, 32'hDEADBEEF},
                                    {esm_control_magic_num, config_seq_num++, 32'h00000000, 32'hDEADBEEF, 32'h00030300, 32'hDEADBEEF}};
    foreach (config_data[i]) begin
      write_config(config_data[i]);
    end
  endtask

  task automatic send_dwell_entry(int index, esm_dwell_entry_t entry);
    bit [esm_dwell_entry_packed_width - 1 : 0] packed_entry = '0;
    bit [31:0] config_data [] = new[4 + esm_dwell_entry_packed_width/32];
    bit [15:0] addr = index;

    $display("%0t: send_dwell_entry[%0d] = %p", $time, index, entry);

    packed_entry[15  :  0]  = entry.tag;
    packed_entry[31  :  16] = entry.frequency;
    packed_entry[64 :  32]  = entry.duration;
    packed_entry[71 : 64]   = entry.gain;
    packed_entry[79 : 72]   = entry.fast_lock_profile;
    packed_entry[103 : 96]  = entry.threshold_shift_narrow;
    packed_entry[111 : 104] = entry.threshold_shift_wide;
    packed_entry[191 : 128] = entry.channel_mask_narrow;
    packed_entry[199 : 192] = entry.channel_mask_wide;
    packed_entry[223 : 208] = entry.min_pulse_duration;

    config_data[0] = esm_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {esm_module_id_dwell_controller, esm_control_message_type_dwell_entry, addr};
    config_data[3] = 32'hDEADBEEF;

    for (int i = 0; i < (esm_dwell_entry_packed_width/32); i++) begin
      config_data[4 + i] = packed_entry[i*32 +: 32];
    end

    write_config(config_data);
  endtask

  function automatic bit [31:0] pack_dwell_instruction(esm_dwell_instruction_t instruction);
    bit [31:0] r = '0;

    r[0]      = instruction.valid;
    r[1]      = instruction.global_counter_check;
    r[2]      = instruction.global_counter_dec;
    r[3]      = instruction.skip_pll_prelock_wait;
    r[4]      = instruction.skip_pll_lock_check;
    r[5]      = instruction.skip_pll_postlock_wait;
    r[15:8]   = instruction.repeat_count;
    r[23:16]  = instruction.entry_index;
    r[31:24]  = instruction.next_instruction_index;

    return r;
  endfunction

  task automatic send_dwell_program(esm_dwell_program_t dwell_program);
    bit [esm_dwell_program_header_packed_width - 1 : 0] packed_header = '0;
    bit [31:0] config_data [] = new[4 + esm_dwell_program_header_packed_width/32 + esm_num_dwell_instructions];

    $display("%0t: send_dwell_program = %p", $time, dwell_program);

    packed_header[7:0]    = dwell_program.enable_program;
    packed_header[15:8]   = dwell_program.enable_delayed_start;
    packed_header[63:32]  = dwell_program.global_counter_init;
    packed_header[127:64] = dwell_program.delayed_start_time;

    config_data[0] = esm_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {esm_module_id_dwell_controller, esm_control_message_type_dwell_program, 16'h0000};
    config_data[3] = 32'hDEADBEEF;

    for (int i = 0; i < (esm_dwell_program_header_packed_width/32); i++) begin
      config_data[4 + i] = packed_header[i*32 +: 32];
    end

    for (int i = 0; i < esm_num_dwell_instructions; i++) begin
      config_data[4 + (esm_dwell_program_header_packed_width/32) + i] = pack_dwell_instruction(dwell_program.instructions[i]);
    end

    write_config(config_data);
  endtask

  function automatic bit compare_data(esm_dwell_entry_t a, esm_dwell_entry_t b);
    if(a.tag                    !== b.tag)                    return 0;
    if(a.frequency              !== b.frequency)              return 0;
    if(a.duration               !== b.duration)               return 0;
    if(a.gain                   !== b.gain)                   return 0;
    if(a.fast_lock_profile      !== b.fast_lock_profile)      return 0;
    if(a.threshold_shift_narrow !== b.threshold_shift_narrow) return 0;
    if(a.threshold_shift_wide   !== b.threshold_shift_wide)   return 0;
    if(a.channel_mask_narrow    !== b.channel_mask_narrow)    return 0;
    if(a.channel_mask_wide      !== b.channel_mask_wide)      return 0;
    if(a.min_pulse_duration     !== b.min_pulse_duration)     return 0;
    return 1;
  endfunction

  initial begin
    automatic esm_dwell_entry_t read_data;

    wait_for_reset();

    forever begin
      rx_intf.read(read_data);
      if (compare_data(read_data, expected_data[0].data)) begin
        $display("%0t: data match (remaining=%0d) - %p", $time, expected_data.size(), read_data);
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

  function automatic void randomize_instructions(inout esm_dwell_program_t dwell_program, bit global_counter_enable);
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
      dwell_program.instructions[idx].skip_pll_prelock_wait   = $urandom_range(1);
      dwell_program.instructions[idx].skip_pll_lock_check     = $urandom_range(1);
      dwell_program.instructions[idx].skip_pll_postlock_wait  = $urandom_range(1);
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

  function automatic void expect_dwell_program(esm_dwell_program_t dwell_program);
    int global_counter = dwell_program.global_counter_init;
    int inst_index = 0;
    bit done = 0;

    while (1) begin
      esm_dwell_instruction_t inst = dwell_program.instructions[inst_index];
      expect_t e;

      //$display("%0t: expect_dwell_program - initial: inst[%0d]=%p", $time, inst_index, inst);

      if (!inst.valid) begin
        break;
      end

      for (int i = 0; i < inst.repeat_count + 1; i++) begin
        if (inst.global_counter_check && (global_counter <= 0)) begin
          done = 1;
          break;
        end

        //$display("%0t: expecting dwell: inst_index=%0d  entry_index=%0d  next_instruction_index=%0d  global_counter=%0d", $time, inst_index, inst.entry_index, inst.next_instruction_index, global_counter);
        e.data = dwell_entry_mem[inst.entry_index];
        $display("%0t: expecting dwell: inst_index=%0d  dwell_entry=%p", $time, inst_index, e.data);

        expected_data.push_back(e);
        if (inst.global_counter_dec) begin
          global_counter--;
        end
      end

      if (done) begin
        break;
      end

      inst_index = inst.next_instruction_index;
      //$display("%0t: expect_dwell_program - final: inst_index=%0d", $time, inst_index);
    end
  endfunction

  task automatic standard_tests();
    parameter NUM_TESTS = 20;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int wait_cycles;

      send_initial_config();

      for (int i_dwell = 0; i_dwell < esm_num_dwell_entries; i_dwell++) begin
        esm_dwell_entry_t entry;

        entry.tag                    = $urandom;
        entry.frequency              = $urandom;
        entry.duration               = $urandom_range(1000);
        entry.gain                   = $urandom;
        entry.fast_lock_profile      = $urandom;
        entry.threshold_shift_narrow = $urandom;
        entry.threshold_shift_wide   = $urandom;
        entry.channel_mask_narrow    = $urandom;
        entry.channel_mask_wide      = $urandom;
        entry.min_pulse_duration     = $urandom;

        send_dwell_entry(i_dwell, entry);
        dwell_entry_mem[i_dwell] = entry;
      end

      for (int i_rep = 0; i_rep < 10; i_rep++) begin
        int global_counter_init   = $urandom_range(500);
        bit global_counter_enable = $urandom;
        int delayed_start_time    = $urandom_range(5000);
        int delayed_start_enable  = $urandom;

        esm_dwell_program_t dwell_program;
        dwell_program.enable_program        = 1;
        dwell_program.enable_delayed_start  = delayed_start_enable;
        dwell_program.global_counter_init   = global_counter_init;
        dwell_program.delayed_start_time    = delayed_start_time;

        randomize_instructions(dwell_program, global_counter_enable);
        /*$display("dwell_program: %p", dwell_program);
        for (int i = 0; i < esm_num_dwell_instructions; i++) begin
          $display("  inst[%0d] = %p", i, dwell_program.instructions[i]);
        end*/

        expect_dwell_program(dwell_program);

        send_dwell_program(dwell_program);

        //repeat(300000) @(posedge Clk);

        wait_cycles = 0;
        while ((expected_data.size() != 0) && (wait_cycles < 6e5)) begin
          @(posedge Clk);
          wait_cycles++;
        end
        assert (wait_cycles < 6e5) else $error("Timeout while waiting for expected queue to empty during standard test");

        foreach (expected_data[i]) begin
          $display("%0t: end of rep: expected_data[%0d]=%p", $time, i, expected_data[i]);
        end
      end

      $display("%0t: Standard test finished: num_received = %0d", $time, num_received);

      Rst = 1;
      repeat(100) @(posedge Clk);
      Rst = 0;
    end
  endtask

  initial
  begin
    wait_for_reset();
    standard_tests();

    $finish;
  end

endmodule
