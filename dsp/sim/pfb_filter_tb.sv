`timescale 1ns/1ps

import math::*;
import dsp_pkg::*;

typedef struct {
  int data_i;
  int data_q;
  int index;
  bit last;
} pfb_transaction_t;

interface pfb_intf #(parameter DATA_WIDTH, parameter INDEX_WIDTH) (input logic Clk);
  logic                             valid = 0;
  logic [INDEX_WIDTH - 1 : 0]       index = 0;
  logic                             last = 0;
  logic signed [DATA_WIDTH - 1 : 0] data_i = 0;
  logic signed [DATA_WIDTH - 1 : 0] data_q = 0;

  task write(input pfb_transaction_t tx);
    data_i  <= tx.data_i;
    data_q  <= tx.data_q;
    index   <= tx.index;
    last    <= tx.last;
    valid   <= 1;
    @(posedge Clk);
    data_i  <= 0;
    data_q  <= 0;
    valid   <= 0;
    @(posedge Clk);
  endtask

  task read(output pfb_transaction_t rx);
    logic v;
    do begin
      rx.data_i <= data_i;
      rx.data_q <= data_q;
      rx.index  <= index;
      rx.last   <= last;
      v         <= valid;
      @(posedge Clk);
    end while (v !== 1);
  endtask
endinterface

module pfb_filter_tb;
  parameter time CLK_HALF_PERIOD  = 4ns;
  parameter NUM_CHANNELS          = 32;
  parameter CHANNEL_INDEX_WIDTH   = $clog2(NUM_CHANNELS);
  parameter COEF_WIDTH            = 18;
  parameter NUM_COEFS             = 384;
  parameter NUM_COEFS_PER_CHANNEL = NUM_COEFS / NUM_CHANNELS;
  parameter INPUT_DATA_WIDTH      = 12;
  parameter OUTPUT_DATA_WIDTH     = 12 + $clog2(NUM_COEFS_PER_CHANNEL);

  parameter bit signed  [COEF_WIDTH - 1 : 0] COEF_DATA [NUM_COEFS - 1 : 0] = {
          0: 18'h00000,   1: 18'hFFFFE,   2: 18'hFFFFB,   3: 18'hFFFF7,   4: 18'hFFFF3,   5: 18'hFFFEE,   6: 18'hFFFE9,   7: 18'hFFFE3,
          8: 18'hFFFDC,   9: 18'hFFFD6,  10: 18'hFFFCF,  11: 18'hFFFC9,  12: 18'hFFFC3,  13: 18'hFFFBE,  14: 18'hFFFB9,  15: 18'hFFFB7,
         16: 18'hFFFB5,  17: 18'hFFFB6,  18: 18'hFFFB8,  19: 18'hFFFBD,  20: 18'hFFFC5,  21: 18'hFFFCF,  22: 18'hFFFDD,  23: 18'hFFFED,
         24: 18'h00000,  25: 18'h00016,  26: 18'h0002F,  27: 18'h0004A,  28: 18'h00067,  29: 18'h00085,  30: 18'h000A4,  31: 18'h000C4,
         32: 18'h000E3,  33: 18'h00101,  34: 18'h0011D,  35: 18'h00136,  36: 18'h0014B,  37: 18'h0015B,  38: 18'h00166,  39: 18'h00169,
         40: 18'h00165,  41: 18'h00159,  42: 18'h00144,  43: 18'h00126,  44: 18'h000FE,  45: 18'h000CC,  46: 18'h00091,  47: 18'h0004D,
         48: 18'h00000,  49: 18'hFFFAB,  50: 18'hFFF50,  51: 18'hFFEEF,  52: 18'hFFE8A,  53: 18'hFFE23,  54: 18'hFFDBD,  55: 18'hFFD58,
         56: 18'hFFCF8,  57: 18'hFFC9F,  58: 18'hFFC50,  59: 18'hFFC0C,  60: 18'hFFBD7,  61: 18'hFFBB2,  62: 18'hFFBA1,  63: 18'hFFBA4,
         64: 18'hFFBBE,  65: 18'hFFBF0,  66: 18'hFFC3B,  67: 18'hFFC9F,  68: 18'hFFD1D,  69: 18'hFFDB4,  70: 18'hFFE63,  71: 18'hFFF27,
         72: 18'h00000,  73: 18'h000EA,  74: 18'h001E1,  75: 18'h002E3,  76: 18'h003EA,  77: 18'h004F1,  78: 18'h005F4,  79: 18'h006ED,
         80: 18'h007D6,  81: 18'h008A9,  82: 18'h00962,  83: 18'h009F9,  84: 18'h00A6A,  85: 18'h00AB0,  86: 18'h00AC7,  87: 18'h00AAA,
         88: 18'h00A57,  89: 18'h009CC,  90: 18'h00907,  91: 18'h00809,  92: 18'h006D2,  93: 18'h00565,  94: 18'h003C5,  95: 18'h001F6,
         96: 18'h00000,  97: 18'hFFDE8,  98: 18'hFFBB8,  99: 18'hFF977, 100: 18'hFF730, 101: 18'hFF4EE, 102: 18'hFF2BC, 103: 18'hFF0A6,
        104: 18'hFEEB8, 105: 18'hFECFE, 106: 18'hFEB83, 107: 18'hFEA53, 108: 18'hFE977, 109: 18'hFE8F9, 110: 18'hFE8E2, 111: 18'hFE938,
        112: 18'hFEA00, 113: 18'hFEB3D, 114: 18'hFECF1, 115: 18'hFEF1A, 116: 18'hFF1B5, 117: 18'hFF4BC, 118: 18'hFF827, 119: 18'hFFBED,
        120: 18'h00000, 121: 18'h00451, 122: 18'h008D1, 123: 18'h00D6B, 124: 18'h0120B, 125: 18'h0169D, 126: 18'h01B0A, 127: 18'h01F3A,
        128: 18'h02317, 129: 18'h02688, 130: 18'h02978, 131: 18'h02BD1, 132: 18'h02D7F, 133: 18'h02E70, 134: 18'h02E94, 135: 18'h02DDF,
        136: 18'h02C47, 137: 18'h029C5, 138: 18'h02658, 139: 18'h02201, 140: 18'h01CC6, 141: 18'h016B0, 142: 18'h00FD0, 143: 18'h00838,
        144: 18'h00000, 145: 18'hFF743, 146: 18'hFEE21, 147: 18'hFE4BE, 148: 18'hFDB40, 149: 18'hFD1D0, 150: 18'hFC89A, 151: 18'hFBFCC,
        152: 18'hFB795, 153: 18'hFB022, 154: 18'hFA9A4, 155: 18'hFA448, 156: 18'hFA039, 157: 18'hF9DA4, 158: 18'hF9CAD, 159: 18'hF9D77,
        160: 18'hFA023, 161: 18'hFA4C8, 162: 18'hFAB7B, 163: 18'hFB449, 164: 18'hFBF3B, 165: 18'hFCC50, 166: 18'hFDB82, 167: 18'hFECC4,
        168: 18'h00000, 169: 18'h0151B, 170: 18'h02BF2, 171: 18'h0445B, 172: 18'h05E27, 173: 18'h07920, 174: 18'h0950B, 175: 18'h0B1A9,
        176: 18'h0CEB7, 177: 18'h0EBED, 178: 18'h10905, 179: 18'h125B5, 180: 18'h141B2, 181: 18'h15CB3, 182: 18'h17671, 183: 18'h18EA5,
        184: 18'h1A510, 185: 18'h1B972, 186: 18'h1CB94, 187: 18'h1DB44, 188: 18'h1E854, 189: 18'h1F2A2, 190: 18'h1FA0F, 191: 18'h1FE87,
        192: 18'h1FFFD, 193: 18'h1FE6D, 194: 18'h1F9DB, 195: 18'h1F256, 196: 18'h1E7F1, 197: 18'h1DACB, 198: 18'h1CB08, 199: 18'h1B8D5,
        200: 18'h1A465, 201: 18'h18DEF, 202: 18'h175B2, 203: 18'h15BF0, 204: 18'h140ED, 205: 18'h124F3, 206: 18'h10849, 207: 18'h0EB39,
        208: 18'h0CE0E, 209: 18'h0B10F, 210: 18'h09483, 211: 18'h078AB, 212: 18'h05DC7, 213: 18'h04412, 214: 18'h02BC1, 215: 18'h01502,
        216: 18'h00000, 217: 18'hFECDC, 218: 18'hFDBB2, 219: 18'hFCC97, 220: 18'hFBF97, 221: 18'hFB4BA, 222: 18'hFABFD, 223: 18'hFA559,
        224: 18'hFA0C0, 225: 18'hF9E1E, 226: 18'hF9D5A, 227: 18'hF9E55, 228: 18'hFA0EB, 229: 18'hFA4F6, 230: 18'hFAA4D, 231: 18'hFB0C3,
        232: 18'hFB82A, 233: 18'hFC055, 234: 18'hFC913, 235: 18'hFD237, 236: 18'hFDB94, 237: 18'hFE4FE, 238: 18'hFEE4C, 239: 18'hFF759,
        240: 18'h00000, 241: 18'h00823, 242: 18'h00FA7, 243: 18'h01674, 244: 18'h01C77, 245: 18'h021A2, 246: 18'h025EB, 247: 18'h0294D,
        248: 18'h02BC4, 249: 18'h02D55, 250: 18'h02E06, 251: 18'h02DDF, 252: 18'h02CEE, 253: 18'h02B43, 254: 18'h028EF, 255: 18'h02607,
        256: 18'h0229F, 257: 18'h01ECE, 258: 18'h01AAB, 259: 18'h0164C, 260: 18'h011C9, 261: 18'h00D39, 262: 18'h008AF, 263: 18'h00441,
        264: 18'h00000, 265: 18'hFFBFD, 266: 18'hFF847, 267: 18'hFF4EA, 268: 18'hFF1F0, 269: 18'hFEF61, 270: 18'hFED42, 271: 18'hFEB97,
        272: 18'hFEA61, 273: 18'hFE99E, 274: 18'hFE94B, 275: 18'hFE963, 276: 18'hFE9E0, 277: 18'hFEAB9, 278: 18'hFEBE5, 279: 18'hFED5B,
        280: 18'hFEF0E, 281: 18'hFF0F3, 282: 18'hFF300, 283: 18'hFF527, 284: 18'hFF75E, 285: 18'hFF999, 286: 18'hFFBCF, 287: 18'hFFDF4,
        288: 18'h00000, 289: 18'h001EB, 290: 18'h003AF, 291: 18'h00546, 292: 18'h006AA, 293: 18'h007D9, 294: 18'h008D1, 295: 18'h00990,
        296: 18'h00A18, 297: 18'h00A68, 298: 18'h00A83, 299: 18'h00A6C, 300: 18'h00A27, 301: 18'h009B8, 302: 18'h00923, 303: 18'h0086F,
        304: 18'h007A1, 305: 18'h006BD, 306: 18'h005CB, 307: 18'h004CE, 308: 18'h003CE, 309: 18'h002CE, 310: 18'h001D4, 311: 18'h000E3,
        312: 18'h00000, 313: 18'hFFF2E, 314: 18'hFFE6F, 315: 18'hFFDC6, 316: 18'hFFD34, 317: 18'hFFCBB, 318: 18'hFFC5A, 319: 18'hFFC12,
        320: 18'hFFBE2, 321: 18'hFFBC9, 322: 18'hFFBC6, 323: 18'hFFBD8, 324: 18'hFFBFB, 325: 18'hFFC2F, 326: 18'hFFC71, 327: 18'hFFCBE,
        328: 18'hFFD15, 329: 18'hFFD71, 330: 18'hFFDD2, 331: 18'hFFE36, 332: 18'hFFE99, 333: 18'hFFEFA, 334: 18'hFFF57, 335: 18'hFFFAF,
        336: 18'h00000, 337: 18'h0004A, 338: 18'h0008B, 339: 18'h000C4, 340: 18'h000F3, 341: 18'h00119, 342: 18'h00136, 343: 18'h00149,
        344: 18'h00155, 345: 18'h00158, 346: 18'h00155, 347: 18'h0014B, 348: 18'h0013B, 349: 18'h00127, 350: 18'h0010F, 351: 18'h000F4,
        352: 18'h000D7, 353: 18'h000BA, 354: 18'h0009B, 355: 18'h0007E, 356: 18'h00061, 357: 18'h00045, 358: 18'h0002C, 359: 18'h00015,
        360: 18'h00000, 361: 18'hFFFEE, 362: 18'hFFFDF, 363: 18'hFFFD3, 364: 18'hFFFC9, 365: 18'hFFFC2, 366: 18'hFFFBD, 367: 18'hFFFBB,
        368: 18'hFFFBB, 369: 18'hFFFBC, 370: 18'hFFFBF, 371: 18'hFFFC3, 372: 18'hFFFC8, 373: 18'hFFFCE, 374: 18'hFFFD4, 375: 18'hFFFDA,
        376: 18'hFFFE0, 377: 18'hFFFE6, 378: 18'hFFFEB, 379: 18'hFFFF0, 380: 18'hFFFF4, 381: 18'hFFFF8, 382: 18'hFFFFC, 383: 18'hFFFFE
  };

  typedef struct
  {
    pfb_transaction_t data;
  } expect_t;

  logic Clk;
  logic Rst;

  pfb_intf #(.DATA_WIDTH(INPUT_DATA_WIDTH),   .INDEX_WIDTH(CHANNEL_INDEX_WIDTH))  tx_intf (.*);
  pfb_intf #(.DATA_WIDTH(OUTPUT_DATA_WIDTH),  .INDEX_WIDTH(CHANNEL_INDEX_WIDTH))  rx_intf (.*);

  bit signed [INPUT_DATA_WIDTH - 1 : 0] filter_data_i [NUM_CHANNELS - 1 : 0][2*NUM_COEFS_PER_CHANNEL - 1 : 0];
  bit signed [INPUT_DATA_WIDTH - 1 : 0] filter_data_q [NUM_CHANNELS - 1 : 0][2*NUM_COEFS_PER_CHANNEL - 1 : 0];

  expect_t          expected_data [$];
  int               num_received = 0;
  int               num_matched = 0;
  logic             w_error;

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

  pfb_filter #(
    .NUM_CHANNELS         (NUM_CHANNELS),
    .CHANNEL_INDEX_WIDTH  ($clog2(NUM_CHANNELS)),
    .INPUT_DATA_WIDTH     (INPUT_DATA_WIDTH),
    .OUTPUT_DATA_WIDTH    (OUTPUT_DATA_WIDTH),
    .COEF_WIDTH           (COEF_WIDTH),
    .NUM_COEFS            (NUM_COEFS),
    .COEF_DATA            (COEF_DATA),
    .ANALYSIS_MODE        (1)
  )
  dut
  (
    .Clk            (Clk),
    .Rst            (Rst),

    .Input_valid    (tx_intf.valid),
    .Input_index    (tx_intf.index),
    .Input_last     (tx_intf.last),
    .Input_i        (tx_intf.data_i),
    .Input_q        (tx_intf.data_q),

    .Output_valid   (rx_intf.valid),
    .Output_index   (rx_intf.index),
    .Output_last    (rx_intf.last),
    .Output_i       (rx_intf.data_i),
    .Output_q       (rx_intf.data_q),

    .Error_input_overflow (w_error)
  );

  always_ff @(posedge Clk) begin
    if (!Rst) begin
      if (w_error) begin
        $error("%0t: overflow error", $time);
      end
    end
  end

  task automatic clear_filter_state();
    bit [CHANNEL_INDEX_WIDTH - 1 : 0] channel_index = NUM_CHANNELS - 1;
    for (int i = 0; i < 1024; i++) begin
      pfb_transaction_t tx;
      tx.data_i = 0;
      tx.data_q = 0;
      tx.index  = channel_index;
      tx.last   = (channel_index == 0);
      channel_index--;
      tx_intf.write(tx);

      void'(process_filter_sample(tx));
    end
  endtask

  task automatic wait_for_reset();
    do begin
      @(posedge Clk);
    end while (Rst);
  endtask

  function automatic bit compare_data(pfb_transaction_t r, pfb_transaction_t e);
    if (e.index !== r.index) begin
      return 0;
    end
    if (e.last !== r.last) begin
      return 0;
    end
    if (e.data_i !== r.data_i) begin
      return 0;
    end
    if (e.data_q !== r.data_q) begin
      return 0;
    end
    return 1;
  endfunction

  initial begin
    automatic pfb_transaction_t read_data;

    wait_for_reset();

    forever begin
      rx_intf.read(read_data);
      if (expected_data.size() == 0) begin
        //skipping
      end else if (compare_data(read_data, expected_data[0].data)) begin
        num_matched++;
        //$display("%0t: data match - %p", $time, expected_data[0].data);
      end else begin
        $error("%0t: error -- data mismatch: expected = %p  actual = %p - remaining=%0d", $time, expected_data[0].data, read_data, expected_data.size());
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

  function automatic pfb_transaction_t process_filter_sample(pfb_transaction_t d);
    pfb_transaction_t r;
    bit signed [OUTPUT_DATA_WIDTH - 1 : 0] accum_i;
    bit signed [OUTPUT_DATA_WIDTH - 1 : 0] accum_q;

    for (int i = 2*NUM_COEFS_PER_CHANNEL - 1; i > 0; i--) begin
      filter_data_i[d.index][i] = filter_data_i[d.index][i - 1];
      filter_data_q[d.index][i] = filter_data_q[d.index][i - 1];
    end
    filter_data_i[d.index][0] = d.data_i;
    filter_data_q[d.index][0] = d.data_q;

    /*$display("%0t: process_filter_sample: d.i=%X d.q=%X", $time, d.data_i, d.data_q);
    for (int i = 0; i < 2*NUM_COEFS_PER_CHANNEL; i++) begin
      $display("    filter_data[%0d][%0d]:  I=%0X Q=%0X", d.index, i, filter_data_i[d.index][i], filter_data_q[d.index][i]);
    end*/

    accum_i = 0;
    accum_q = 0;
    for (int i = 0; i < NUM_COEFS_PER_CHANNEL; i++) begin
      bit signed [COEF_WIDTH - 1 : 0]                     coef          = COEF_DATA[NUM_CHANNELS * i + d.index];
      bit signed [INPUT_DATA_WIDTH + COEF_WIDTH - 1 : 0]  mult_i        = coef * filter_data_i[d.index][i*2];
      bit signed [INPUT_DATA_WIDTH + COEF_WIDTH - 1 : 0]  mult_q        = coef * filter_data_q[d.index][i*2];
      bit signed [INPUT_DATA_WIDTH : 0]                   mult_scaled_i = mult_i[INPUT_DATA_WIDTH + COEF_WIDTH - 1 : (COEF_WIDTH - 1)];
      bit signed [INPUT_DATA_WIDTH : 0]                   mult_scaled_q = mult_q[INPUT_DATA_WIDTH + COEF_WIDTH - 1 : (COEF_WIDTH - 1)];
      accum_i += mult_scaled_i;
      accum_q += mult_scaled_q;

      //$display("%0t: process_filter_sample: i=%0d  coef=%X  mult_i=%X mult_q=%X  mult_scaled_i=%X mult_scaled_q=%X  accum_i=%X accum_q=%X", $time,
      //  i, coef, mult_i, mult_q, mult_scaled_i, mult_scaled_q, accum_i, accum_q);
    end

    r.index   = d.index;
    r.last    = d.last;
    r.data_i  = accum_i;
    r.data_q  = accum_q;

    //$display("%0t: process_filter_sample: d=%p r=%p", $time, d, r);

    return r;
  endfunction

  task automatic standard_tests();
    parameter NUM_TESTS = 20;

    for (int i_test = 0; i_test < NUM_TESTS; i_test++) begin
      int max_write_delay = $urandom_range(5, 0);
      int wait_cycles;
      bit [CHANNEL_INDEX_WIDTH - 1 : 0] channel_index = NUM_CHANNELS - 1;

      clear_filter_state();

      repeat(10) @(posedge Clk);
      $display("%0t: Standard test started", $time);

      for (int i_iteration = 0; i_iteration < 10000; i_iteration++) begin
        expect_t e;
        pfb_transaction_t tx;
        pfb_transaction_t rx;

        tx.data_i = $urandom_range(2**INPUT_DATA_WIDTH - 1, 0);
        tx.data_q = $urandom_range(2**INPUT_DATA_WIDTH - 1, 0);
        tx.index  = channel_index;
        tx.last   = (channel_index == 0);
        channel_index--;

        rx = process_filter_sample(tx);
        //$display("  expecting data: %p", rx);
        e.data = rx;
        expected_data.push_back(e);

        tx_intf.write(tx);
        repeat($urandom_range(max_write_delay)) @(posedge(Clk));
      end

      wait_cycles = 0;
      while ((expected_data.size() != 0) && (wait_cycles < 1e5)) begin
        @(posedge Clk);
        wait_cycles++;
      end
      assert (wait_cycles < 1e5) else $error("Timeout while waiting for expected queue to empty during standard test");

      $display("%0t: Standard test finished: num_received = %0d num_matched=%0d", $time, num_received, num_matched);

      Rst = 1;
      repeat(500) @(posedge Clk);
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
