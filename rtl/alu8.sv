`timescale 1ns/1ps
module alu8 (
  input  logic [7:0] a, b,
  input  logic [2:0] alu_control,
  output logic [7:0] result,
  output logic       zero, negative, carry, overflow
);
  logic sub;
  logic [7:0] arithmetic_result;
  logic arithmetic_cout, arithmetic_overflow;
  assign sub = (alu_control == 3'b001) || (alu_control == 3'b101);
  addsub8 arithmetic_unit (
    .a(a), .b(b), .sub(sub), .sum(arithmetic_result),
    .cout(arithmetic_cout), .overflow(arithmetic_overflow)
  );
  always_comb begin
    result = 8'h00;
    carry = 1'b0;
    overflow = 1'b0;
    case (alu_control)
      3'b000, 3'b001: begin
        result = arithmetic_result;
        carry = arithmetic_cout;
        overflow = arithmetic_overflow;
      end
      3'b010: result = a & b;
      3'b011: result = a | b;
      3'b100: result = a ^ b;
      3'b101: result = {7'b0, arithmetic_result[7] ^ arithmetic_overflow};
      3'b110: result = a << b[2:0];
      3'b111: result = a >> b[2:0];
      default: begin end
    endcase
  end
  assign zero = (result == 8'h00);
  assign negative = result[7];
endmodule
