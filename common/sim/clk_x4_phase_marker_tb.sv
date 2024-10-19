`timescale 1ns/1ps

module clk_x4_phase_marker_tb;
  parameter time CLK_HALF_PERIOD  = 16ns;

  logic Clk;
  logic Clk_x4;

  initial begin
    Clk = 0;
    forever begin
      #(CLK_HALF_PERIOD);
      Clk = ~Clk;
    end
  end

  initial begin
    Clk_x4 = 0;
    #(11*CLK_HALF_PERIOD/4);
    forever begin
      #(CLK_HALF_PERIOD/4);
      Clk_x4 = ~Clk_x4;
    end
  end

  logic w_clk_x4_p0;
  logic w_clk_x4_p1;
  logic w_clk_x4_p2;
  logic w_clk_x4_p3;

  clk_x4_phase_marker dut
  (
    .Clk        (Clk),
    .Clk_x4     (Clk_x4),

    .Clk_x4_p0  (w_clk_x4_p0),
    .Clk_x4_p1  (w_clk_x4_p1),
    .Clk_x4_p2  (w_clk_x4_p2),
    .Clk_x4_p3  (w_clk_x4_p3)
  );

  initial
  begin
    repeat(1000) @(posedge Clk);
    $finish;
  end

endmodule
