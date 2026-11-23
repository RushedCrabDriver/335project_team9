`timescale 1ns/1ps

module sequence_detector (
  input  logic clk, reset, bit_in,
  output logic detected
);
  
  localparam logic [2:0] S0=3'b000, S1=3'b001, S2=3'b010,
                         S3=3'b011, S4=3'b100;
  logic [2:0] state, next_state;

  // synchronous active-high reset.
  always_ff @(posedge clk) begin
    if (reset) state <= S0;
    else state <= next_state;
  end

  // Next-state logic.
  always_comb begin
    next_state = S0;                       // safe default
    case (state)
      S0: next_state = bit_in ? S1 : S0;
      S1: next_state = bit_in ? S1 : S2;   // "11" keeps prefix "1"
      S2: next_state = bit_in ? S3 : S0;   // "100" loses all progress
      S3: next_state = bit_in ? S4 : S2;   // "1010" falls back to "10"
      S4: next_state = bit_in ? S1 : S2;   // overlap: "1011"+0 -> "10", +1 -> "1"
      default: next_state = S0;            // unused encodings recover to S0
    endcase
  end

  assign detected = (state == S4);
endmodule
