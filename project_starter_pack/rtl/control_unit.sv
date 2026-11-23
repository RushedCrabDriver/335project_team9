`timescale 1ns/1ps
module control_unit (
  input  logic [3:0] opcode,
  output logic       reg_write, alu_src, mem_read, mem_write,
  output logic [1:0] result_src,
  output logic       branch, jump,
  output logic [1:0] alu_op,
  output logic       illegal
);
  always_comb begin
    reg_write = 1'b0;
    alu_src = 1'b0;
    mem_read = 1'b0;
    mem_write = 1'b0;
    result_src = 2'b00;
    branch = 1'b0;
    jump = 1'b0;
    alu_op = 2'b00;
    illegal = 1'b0;
    case (opcode)
      4'b0000: begin reg_write = 1'b1; alu_op = 2'b10; end
      4'b0001: begin reg_write = 1'b1; alu_src = 1'b1; alu_op = 2'b10; end
      4'b0010: begin
        reg_write = 1'b1; alu_src = 1'b1;
        mem_read = 1'b1; result_src = 2'b01;
      end
      4'b0011: begin alu_src = 1'b1; mem_write = 1'b1; end
      4'b0100: begin branch = 1'b1; alu_op = 2'b01; end
      4'b0101: begin reg_write = 1'b1; result_src = 2'b10; jump = 1'b1; end
      default: illegal = 1'b1;
    endcase
  end
endmodule
