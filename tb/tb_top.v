`timescale 1ns/1ps

module tb_top;
  reg clk = 1'b0;
  wire LED;

  // 12 MHz: Periode ~83.333 ns → wir nehmen 83 ns (ok für Demo)
  always #41.5 clk = ~clk;

  top dut (
    .clk(clk),
    .LED(LED)
  );

  initial begin
    $dumpfile("build/tb_top.vcd");
    $dumpvars(0, tb_top);
    $display("Start sim...");
    // Simuliere ~50 ms → genug, um LED-Kanten zu sehen
    #50_000_000;
    $display("Stop sim.");
    $finish;
  end
endmodule
