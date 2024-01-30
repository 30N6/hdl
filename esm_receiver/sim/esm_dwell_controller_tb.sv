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

  bit [31:0]                                      config_seq_num = 0;
  esm_dwell_metadata_t                            dwell_entry_mem [esm_num_dwell_entries - 1 : 0];

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

  esm_dwell_controller #(.PLL_PRE_LOCK_DELAY_CYCLES(8), .PLL_POST_LOCK_DELAY_CYCLES(10)) dut
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
        repeat ($urandom_range(10, 5)) @(posedge Clk);
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

  task automatic write_config(bit [31:0] config_data []);
    @(posedge Clk)
    cfg_tx_intf.write(config_data);
    repeat(10) @(posedge Clk);
  endtask

  task automatic send_initial_config();
    bit [31:0] config_data [][] = '{{esm_control_magic_num, config_seq_num++, 32'h00000000, 32'h00030300}, {esm_control_magic_num, config_seq_num++, 32'h00000000, 32'h00030300}};
    foreach (config_data[i]) begin
      write_config(config_data[i]);
    end
  endtask

  //type esm_dwell_metadata_packed_t is record
  //  tag                       : unsigned(15 downto 0);
  //  frequency                 : unsigned(15 downto 0);
  //  duration                  : unsigned(31 downto 0);
  //  gain                      : unsigned(7 downto 0);
  //  fast_lock_profile         : unsigned(7 downto 0);
  //  threshold_narrow          : unsigned(15 downto 0);
  //  threshold_wide            : unsigned(15 downto 0);
  //  channel_mask_narrow       : std_logic_vector(63 downto 0);
  //  channel_mask_wide         : std_logic_vector(7 downto 0);
  //end record;
  //type esm_message_dwell_entry_packed_t is record
  //  entry_index               : unsigned(7 downto 0);
  //  entry_data                : esm_dwell_metadata_packed_t;
  //end record;

  task automatic send_dwell_entry(esm_message_dwell_entry_t entry);
    bit [esm_message_dwell_entry_packed_width - 1 : 0] packed_entry = '0;
    bit [31:0] config_data [] = new[3 + esm_message_dwell_entry_packed_width/32];

    $display("%0t: send_dwell_entry[%0d] = %p", $time, entry.entry_index, entry.entry_data);

    packed_entry[7  :   0] = entry.entry_index;
    packed_entry[23 :   8] = entry.entry_data.tag;
    packed_entry[39 :  24] = entry.entry_data.frequency;
    packed_entry[71 :  40] = entry.entry_data.duration;
    packed_entry[79 :  72] = entry.entry_data.gain;
    packed_entry[87 :  80] = entry.entry_data.fast_lock_profile;
    packed_entry[103:  88] = entry.entry_data.threshold_narrow;
    packed_entry[119: 104] = entry.entry_data.threshold_wide;
    packed_entry[183: 120] = entry.entry_data.channel_mask_narrow;
    packed_entry[191: 184] = entry.entry_data.channel_mask_wide;

    config_data[0] = esm_control_magic_num;
    config_data[1] = config_seq_num++;
    config_data[2] = {esm_module_id_dwell, esm_control_message_type_dwell_entry, 16'h0000};

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
    config_data[2] = {esm_module_id_dwell, esm_control_message_type_dwell_program, 16'h0000};

    for (int i = 0; i < (esm_message_dwell_program_header_packed_width/32); i++) begin
      config_data[3 + i] = packed_header[i*32 +: 32];
    end

    for (int i = 0; i < esm_num_dwell_instructions; i++) begin
      config_data[3 + (esm_message_dwell_program_header_packed_width/32) + i] = pack_dwell_instruction(dwell_program.instructions[i]);
    end

    write_config(config_data);
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

  function automatic void randomize_instructions(inout esm_message_dwell_program_t dwell_program, bit global_counter_enable);
    int random_order = $urandom_range(99) < 50;
    int loop = $urandom_range(99) < 50;
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
        entry.entry_data.duration             = $urandom_range(1000);
        entry.entry_data.gain                 = $urandom;
        entry.entry_data.fast_lock_profile    = $urandom;
        entry.entry_data.threshold_narrow     = $urandom;
        entry.entry_data.threshold_wide       = $urandom;
        entry.entry_data.channel_mask_narrow  = $urandom;
        entry.entry_data.channel_mask_wide    = $urandom;

        send_dwell_entry(entry);
        dwell_entry_mem[i_dwell] = entry.entry_data;
      end

      for (int i_rep = 0; i_rep < 10; i_rep++) begin
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

        send_dwell_program(dwell_program);

        repeat(40000) @(posedge Clk);
      end

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
    end
  endtask

  initial
  begin
    wait_for_reset();
    standard_tests();

    $finish;
  end

endmodule
