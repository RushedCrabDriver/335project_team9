`timescale 1ns/1ps
module program_counter (
  input  logic       clk, reset, stall, redirect,
  input  logic [7:0] redirect_target,
  output logic [7:0] pc
);
  logic [7:0] pc_next;
  always_comb begin
    pc_next = pc + 8'd4;
    if (redirect) pc_next = redirect_target;
    if (stall) pc_next = pc;
    if (reset) pc_next = 8'h00;
  end
  always_ff @(posedge clk) pc <= pc_next;
endmodule
