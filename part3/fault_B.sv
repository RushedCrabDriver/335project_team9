`timescale 1ns/1ps
// Fault B: stall given priority over redirect
module min_fault_B;
  logic clk = 0, reset = 1, stall = 0, redirect = 0;
  logic [7:0] redirect_target = 8'h00, pc;
  program_counter dut (.clk(clk), .reset(reset), .stall(stall), .redirect(redirect),
                       .redirect_target(redirect_target), .pc(pc));
  always #5 clk = ~clk;
  initial begin
    @(posedge clk); #1;                          
    reset = 0;
    @(posedge clk); #1;                         
    stall = 1; redirect = 1; redirect_target = 8'h67; 
    @(posedge clk); #1;
    $display("stall=1 redirect=1 target=0x%02h (pc was 0x04): expected pc=0x%02h, actual pc=0x%02h", redirect_target, redirect_target, pc);
    if (pc === redirect_target) $display("PASS: fault B not detected (design correct)");
    else              $display("FAIL: fault B DETECTED");
    $finish;
  end
endmodule
