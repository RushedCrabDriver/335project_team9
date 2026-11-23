`timescale 1ns/1ps
module control_flow_subsystem (
  input  logic       clk, reset, stall,
  input  logic [3:0] opcode,
  input  logic [7:0] a, b, branch_target, jump_target,
  input  logic [2:0] branch_control,
  output logic [7:0] pc, redirect_target,
  output logic       take_branch, redirect, illegal
);
  logic branch, jump;
  logic unused_reg_write, unused_alu_src, unused_mem_read, unused_mem_write;
  logic [1:0] unused_result_src, unused_alu_op;
  control_unit decoder (
    .opcode(opcode), .reg_write(unused_reg_write), .alu_src(unused_alu_src),
    .mem_read(unused_mem_read), .mem_write(unused_mem_write),
    .result_src(unused_result_src), .branch(branch), .jump(jump),
    .alu_op(unused_alu_op), .illegal(illegal)
  );
  branch_unit branch_logic (
    .a(a), .b(b), .branch(branch), .jump(jump),
    .branch_control(branch_control), .branch_target(branch_target),
    .jump_target(jump_target), .take_branch(take_branch),
    .redirect(redirect), .redirect_target(redirect_target)
  );
  program_counter counter (
    .clk(clk), .reset(reset), .stall(stall), .redirect(redirect),
    .redirect_target(redirect_target), .pc(pc)
  );
endmodule
