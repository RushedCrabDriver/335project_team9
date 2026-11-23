`timescale 1ns/1ps
module min_fault_A;
  logic [7:0] a = 8'h80, b = 8'h01;      
  logic [2:0] op = 3'b101;               
  logic [7:0] result;
  logic zero, negative, carry, overflow;
  alu8 dut (.a(a), .b(b), .alu_control(op), .result(result),
            .zero(zero), .negative(negative), .carry(carry), .overflow(overflow));
  initial begin
    #1;
    $display("SLT a=0x%02h (-128) b=0x%02h (+1): expected result=0x01, actual result=0x%02h", a, b, result);
    if (result === 8'h01) $display("PASS: IMPLEMENTATION IS CORRECT");
    else                  $display("FAIL: FAULT DETECTED");
    $finish;
  end
endmodule
