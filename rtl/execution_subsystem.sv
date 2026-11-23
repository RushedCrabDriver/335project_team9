`timescale 1ns/1ps
module execution_subsystem (
  input  logic       clk, reset, write_enable, init_enable,
  input  logic [2:0] write_address, read_address1, read_address2,
  input  logic [7:0] init_data,
  input  logic [2:0] alu_control,
  output logic [7:0] read_data1, read_data2, result,
  output logic       zero, negative, carry, overflow
);
  logic [7:0] write_data;
  assign write_data = init_enable ? init_data : result;
  register_file rf (
    .clk(clk), .reset(reset), .write_enable(write_enable),
    .write_address(write_address), .write_data(write_data),
    .read_address1(read_address1), .read_address2(read_address2),
    .read_data1(read_data1), .read_data2(read_data2)
  );
  alu8 alu (
    .a(read_data1), .b(read_data2), .alu_control(alu_control),
    .result(result), .zero(zero), .negative(negative),
    .carry(carry), .overflow(overflow)
  );
endmodule
