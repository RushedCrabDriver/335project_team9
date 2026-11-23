`timescale 1ns/1ps
module addsub8 (
  input  logic [7:0] a, b,
  input  logic       sub,
  output logic [7:0] sum,
  output logic       cout, overflow
);
  logic [7:0] b_effective;
  logic [8:0] arithmetic_full;
  assign b_effective = b ^ {8{sub}};
  assign arithmetic_full = {1'b0, a} + {1'b0, b_effective} + {8'b0, sub};
  assign sum = arithmetic_full[7:0];
  assign cout = arithmetic_full[8];
  assign overflow = (a[7] ^ sum[7]) & ~(a[7] ^ b[7] ^ sub);
endmodule
