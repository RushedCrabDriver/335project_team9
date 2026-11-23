`timescale 1ns/1ps
module branch_unit (
  input  logic [7:0] a, b,
  input  logic       branch, jump,
  input  logic [2:0] branch_control,
  input  logic [7:0] branch_target, jump_target,
  output logic       take_branch, redirect,
  output logic [7:0] redirect_target
);
  logic [7:0] difference;
  logic subtraction_cout, subtraction_overflow;
  logic eq, ult, slt, condition;
  addsub8 subtractor (
    .a(a), .b(b), .sub(1'b1), .sum(difference),
    .cout(subtraction_cout), .overflow(subtraction_overflow)
  );
  assign eq = (difference == 8'h00);
  assign ult = ~subtraction_cout;
  assign slt = difference[7] ^ subtraction_overflow;
  always_comb begin
    condition = 1'b0;
    case (branch_control)
      3'b000: condition = eq;
      3'b001: condition = ~eq;
      3'b010: condition = slt;
      3'b011: condition = ~slt;
      3'b100: condition = ult;
      3'b101: condition = ~ult;
      default: condition = 1'b0;
    endcase
    take_branch = branch & condition;
    redirect = jump | take_branch;
    redirect_target = 8'h00;
    if (jump) redirect_target = jump_target;
    else if (take_branch) redirect_target = branch_target;
  end
endmodule
