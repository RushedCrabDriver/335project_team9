`timescale 1ns/1ps
module register_file (
  input  logic       clk, reset, write_enable,
  input  logic [2:0] write_address,
  input  logic [7:0] write_data,
  input  logic [2:0] read_address1, read_address2,
  output logic [7:0] read_data1, read_data2
);
  logic [7:0] registers [1:7];
  integer i;
  always_ff @(posedge clk) begin
    if (reset) begin
      for (i = 1; i <= 7; i = i + 1) registers[i] <= 8'h00;
    end else if (write_enable && (write_address != 3'd0)) begin
      registers[write_address] <= write_data;
    end
  end
  always_comb begin
    read_data1 = 8'h00;
    read_data2 = 8'h00;
    if (read_address1 != 3'd0) read_data1 = registers[read_address1];
    if (read_address2 != 3'd0) read_data2 = registers[read_address2];
  end
endmodule
