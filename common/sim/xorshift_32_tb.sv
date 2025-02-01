`timescale 1ns/1ps

module xorshift_32_tb;
  parameter time CLK_HALF_PERIOD  = 16ns;

  logic Clk;
  logic Rst;

  initial begin
    Clk = 0;
    forever begin
      #(CLK_HALF_PERIOD);
      Clk = ~Clk;
    end
  end

  initial begin
    Rst = 1;
    repeat(2) @(posedge Clk);
    Rst = 0;
  end

  logic [31:0] w_output;

  xorshift_32 dut
  (
    .Clk    (Clk),
    .Rst    (Rst),

    .Output (w_output)
  );

  initial
  begin
    repeat(1000) @(posedge Clk);
    $finish;
  end

endmodule
